#!/usr/bin/env python3
"""
OVPM Health Check Script
Monitors OpenVPN server with OVPM and sends status to Discord
Author: DevOps Health Monitor
Version: 1.0
"""

import subprocess
import requests
import socket
import psutil
import json
import logging
import schedule
import time
import os
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

class VietnamFormatter(logging.Formatter):
    """Custom formatter to show Vietnam timezone (+7)"""
    def formatTime(self, record, datefmt=None):
        dt = datetime.fromtimestamp(record.created, tz=timezone(timedelta(hours=7)))
        if datefmt:
            s = dt.strftime(datefmt)
        else:
            s = dt.strftime('%Y-%m-%d %H:%M:%S %Z+07')
        return s

class OVPMHealthChecker:
    def __init__(self, config_file='ovpm_config.json'):
        self.config = self.load_config(config_file)
        self.setup_logging()
        self.logger = logging.getLogger(__name__)
        
    def load_config(self, config_file):
        """Load configuration from JSON file"""
        try:
            with open(config_file, 'r') as f:
                return json.load(f)
        except FileNotFoundError:
            print(f"Config file {config_file} not found. Creating default config...")
            self.create_default_config(config_file)
            return self.load_config(config_file)
            
    def create_default_config(self, config_file):
        """Create default configuration file"""
        default_config = {
            "discord_webhook": "https://discord.com/api/webhooks/1378816244697796648/FlpeNbvNXObplrYfpAx_-AqznA8xDbdxUuqMrbWJ2EVqoLVs4CULGqUq4VKqaO2kGob0",
            "ovpm_server_ip": "192.168.1.210",
            "ovpm_hostname": "vpn.ngtantai.pro",
            "ovpm_port": 1197,
            "web_ui_port": 8080,
            "log_file": "/var/log/ovpm_health.log",
            "alert_thresholds": {
                "cpu_percent": 80,
                "memory_percent": 85,
                "disk_percent": 90,
                "response_time_ms": 5000
            },
            "notifications": {
                "send_hourly_status": True,
                "send_only_errors": False
            }
        }
        
        with open(config_file, 'w') as f:
            json.dump(default_config, f, indent=4)
        print(f"Default config created: {config_file}")
        print("Please edit the config file and add your Discord webhook URL!")
        
    def setup_logging(self):
        """Setup logging configuration with Vietnam timezone"""
        log_file = self.config.get('log_file', '/var/log/ovpm_health.log')
        
        # Create log directory if not exists
        os.makedirs(os.path.dirname(log_file), exist_ok=True)
        
        # Create custom formatter with Vietnam timezone
        vietnam_formatter = VietnamFormatter('[%(levelname)s] %(message)s')
        
        # Create handlers
        file_handler = logging.FileHandler(log_file)
        file_handler.setFormatter(vietnam_formatter)
        
        console_handler = logging.StreamHandler(sys.stdout)
        console_handler.setFormatter(vietnam_formatter)
        
        # Setup root logger
        logging.basicConfig(
            level=logging.INFO,
            handlers=[file_handler, console_handler]
        )
        
    def get_vietnam_time(self):
        """Get current time in Vietnam timezone"""
        return datetime.now(tz=timezone(timedelta(hours=7)))
        
    def run_command(self, command, shell=False):
        """Run system command and return result"""
        try:
            result = subprocess.run(
                command, 
                shell=shell, 
                capture_output=True, 
                text=True, 
                timeout=30
            )
            return {
                'success': result.returncode == 0,
                'output': result.stdout.strip(),
                'error': result.stderr.strip(),
                'returncode': result.returncode
            }
        except subprocess.TimeoutExpired:
            return {
                'success': False,
                'output': '',
                'error': 'Command timeout after 30 seconds',
                'returncode': -1
            }
        except Exception as e:
            return {
                'success': False,
                'output': '',
                'error': str(e),
                'returncode': -1
            }
            
    def check_ovpmd_service(self):
        """Check ovpmd service status"""
        self.logger.info("Checking ovpmd service status...")
        
        # Check if service is active
        result = self.run_command(['systemctl', 'is-active', 'ovpmd'])
        service_active = result['success'] and result['output'] == 'active'
        
        # Get detailed service status
        status_result = self.run_command(['systemctl', 'status', 'ovpmd', '--no-pager', '-l'])
        
        # Check if OpenVPN process is running
        openvpn_processes = []
        for proc in psutil.process_iter(['pid', 'name', 'cpu_percent', 'memory_info']):
            if 'openvpn' in proc.info['name'].lower():
                openvpn_processes.append({
                    'pid': proc.info['pid'],
                    'name': proc.info['name'],
                    'cpu_percent': proc.info['cpu_percent'],
                    'memory_mb': round(proc.info['memory_info'].rss / 1024 / 1024, 1)
                })
        
        return {
            'service_active': service_active,
            'service_output': status_result['output'],
            'openvpn_processes': openvpn_processes,
            'status': '✅ Running' if service_active else '❌ Stopped'
        }
        
    def check_ovpm_status(self):
        """Check OVPM VPN status"""
        self.logger.info("Checking OVPM VPN status...")
        
        # Get VPN status
        vpn_status = self.run_command(['ovpm', 'vpn', 'status'])
        
        # Get user list
        user_list = self.run_command(['ovpm', 'user', 'list'])
        
        # Parse active connections (this will depend on OVPM output format)
        active_users = []
        total_users = 0
        
        if user_list['success']:
            lines = user_list['output'].split('\n')
            for line in lines:
                if line.strip() and not line.startswith('NAME'):
                    total_users += 1
                    # You might need to adjust this parsing based on actual ovpm output
                    if 'connected' in line.lower() or 'active' in line.lower():
                        active_users.append(line.strip())
        
        return {
            'vpn_status_raw': vpn_status['output'],
            'user_list_raw': user_list['output'],
            'total_users': total_users,
            'active_users': len(active_users),
            'active_user_details': active_users,
            'status': '✅ Operational' if vpn_status['success'] else '❌ Error'
        }
        
    def check_network_connectivity(self):
        """Check network ports and connectivity"""
        self.logger.info("Checking network connectivity...")
        
        results = {}
        
        # Check OpenVPN port (UDP 1197)
        ovpn_port = self.config['ovpm_port']
        try:
            sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            sock.settimeout(5)
            # For UDP, we can only check if we can bind to the port locally
            # or use netstat to check if it's listening
            netstat_result = self.run_command(['netstat', '-tulpn'], shell=False)
            ovpn_listening = f":{ovpn_port}" in netstat_result['output']
            results['ovpn_port'] = {
                'status': '✅ Listening' if ovpn_listening else '❌ Not Listening',
                'listening': ovpn_listening
            }
        except Exception as e:
            results['ovpn_port'] = {
                'status': f'❌ Error: {str(e)}',
                'listening': False
            }
        
        # Check Web UI port (TCP 8080)
        web_port = self.config['web_ui_port']
        start_time = time.time()
        try:
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(5)
            result = sock.connect_ex(('localhost', web_port))
            response_time = round((time.time() - start_time) * 1000, 1)
            
            if result == 0:
                results['web_ui'] = {
                    'status': f'✅ Responding ({response_time}ms)',
                    'responding': True,
                    'response_time_ms': response_time
                }
            else:
                results['web_ui'] = {
                    'status': '❌ Not Responding',
                    'responding': False,
                    'response_time_ms': None
                }
            sock.close()
        except Exception as e:
            results['web_ui'] = {
                'status': f'❌ Error: {str(e)}',
                'responding': False,
                'response_time_ms': None
            }
        
        # Check DNS resolution
        hostname = self.config['ovpm_hostname']
        try:
            resolved_ip = socket.gethostbyname(hostname)
            results['dns'] = {
                'status': f'✅ Resolved to {resolved_ip}',
                'resolved': True,
                'ip': resolved_ip
            }
        except Exception as e:
            results['dns'] = {
                'status': f'❌ Resolution failed: {str(e)}',
                'resolved': False,
                'ip': None
            }
            
        return results
        
    def check_system_resources(self):
        """Check system resources"""
        self.logger.info("Checking system resources...")
        
        # CPU usage
        cpu_percent = psutil.cpu_percent(interval=1)
        
        # Memory usage
        memory = psutil.virtual_memory()
        memory_percent = memory.percent
        memory_used_gb = round(memory.used / 1024**3, 1)
        memory_total_gb = round(memory.total / 1024**3, 1)
        
        # Disk usage for OVPM directory
        try:
            disk = psutil.disk_usage('/var/lib/ovpm/')
            disk_percent = round((disk.used / disk.total) * 100, 1)
            disk_used_gb = round(disk.used / 1024**3, 1)
            disk_total_gb = round(disk.total / 1024**3, 1)
        except:
            disk_percent = 0
            disk_used_gb = 0
            disk_total_gb = 0
        
        # System uptime
        boot_time = datetime.fromtimestamp(psutil.boot_time())
        uptime = datetime.now() - boot_time
        uptime_str = f"{uptime.days}d {uptime.seconds//3600}h {(uptime.seconds//60)%60}m"
        
        # Check thresholds
        thresholds = self.config['alert_thresholds']
        warnings = []
        
        if cpu_percent > thresholds['cpu_percent']:
            warnings.append(f"High CPU usage: {cpu_percent}%")
        if memory_percent > thresholds['memory_percent']:
            warnings.append(f"High memory usage: {memory_percent}%")
        if disk_percent > thresholds['disk_percent']:
            warnings.append(f"High disk usage: {disk_percent}%")
            
        return {
            'cpu_percent': cpu_percent,
            'memory_percent': memory_percent,
            'memory_used_gb': memory_used_gb,
            'memory_total_gb': memory_total_gb,
            'disk_percent': disk_percent,
            'disk_used_gb': disk_used_gb,
            'disk_total_gb': disk_total_gb,
            'uptime': uptime_str,
            'warnings': warnings,
            'status': '⚠️ Warnings' if warnings else '✅ Normal'
        }
        
    def get_recent_logs(self, lines=10):
        """Get recent OVPM logs"""
        try:
            # Try to get OpenVPN logs
            log_files = [
                '/var/log/openvpn/server.log',
                '/var/log/openvpn.log',
                '/var/log/ovpmd.log'
            ]
            
            for log_file in log_files:
                if os.path.exists(log_file):
                    result = self.run_command(['tail', '-n', str(lines), log_file])
                    if result['success']:
                        return result['output'].split('\n')[-lines:]
            
            # Fallback to journalctl
            result = self.run_command(['journalctl', '-u', 'ovpmd', '-n', str(lines), '--no-pager'])
            if result['success']:
                return result['output'].split('\n')[-lines:]
                
        except Exception as e:
            self.logger.error(f"Error getting logs: {e}")
            
        return ["No recent logs available"]
        
    def perform_health_check(self):
        """Perform complete health check"""
        vietnam_time = self.get_vietnam_time()
        self.logger.info("=" * 60)
        self.logger.info(f"Starting OVPM Health Check - {vietnam_time.strftime('%Y-%m-%d %H:%M:%S +07')}")
        self.logger.info("=" * 60)
        
        # Collect all health data
        health_data = {
            'timestamp': vietnam_time.isoformat(),
            'vietnam_time': vietnam_time.strftime('%Y-%m-%d %H:%M:%S +07'),
            'ovpmd_service': self.check_ovpmd_service(),
            'ovpm_status': self.check_ovpm_status(),
            'network': self.check_network_connectivity(),
            'system': self.check_system_resources(),
            'recent_logs': self.get_recent_logs(5)
        }
        
        # Determine overall status
        critical_issues = []
        warnings = []
        
        if not health_data['ovpmd_service']['service_active']:
            critical_issues.append("OVPMD service not running")
            
        if not health_data['network']['ovpn_port']['listening']:
            critical_issues.append("OpenVPN port not listening")
            
        if not health_data['network']['web_ui']['responding']:
            critical_issues.append("Web UI not responding")
            
        warnings.extend(health_data['system']['warnings'])
        
        overall_status = "CRITICAL" if critical_issues else ("WARNING" if warnings else "HEALTHY")
        
        health_data['overall_status'] = overall_status
        health_data['critical_issues'] = critical_issues
        health_data['warnings'] = warnings
        
        # Log detailed status
        self.log_detailed_status(health_data)
        
        # Send Discord notification
        self.send_discord_notification(health_data)
        
        self.logger.info("Health check completed")
        return health_data
        
    def log_detailed_status(self, health_data):
        """Log detailed health status"""
        self.logger.info("🔧 OVPMD Service Status:")
        self.logger.info(f"   {health_data['ovpmd_service']['status']}")
        
        if health_data['ovpmd_service']['openvpn_processes']:
            for proc in health_data['ovpmd_service']['openvpn_processes']:
                self.logger.info(f"   Process {proc['name']} (PID {proc['pid']}): CPU {proc['cpu_percent']}%, MEM {proc['memory_mb']}MB")
        
        self.logger.info("🌐 Network Status:")
        for key, value in health_data['network'].items():
            self.logger.info(f"   {key}: {value['status']}")
            
        self.logger.info("👥 VPN Status:")
        self.logger.info(f"   Total Users: {health_data['ovpm_status']['total_users']}")
        self.logger.info(f"   Active Connections: {health_data['ovpm_status']['active_users']}")
        
        self.logger.info("💻 System Resources:")
        sys_data = health_data['system']
        self.logger.info(f"   CPU: {sys_data['cpu_percent']}%")
        self.logger.info(f"   Memory: {sys_data['memory_used_gb']}GB/{sys_data['memory_total_gb']}GB ({sys_data['memory_percent']}%)")
        self.logger.info(f"   Disk: {sys_data['disk_used_gb']}GB/{sys_data['disk_total_gb']}GB ({sys_data['disk_percent']}%)")
        self.logger.info(f"   Uptime: {sys_data['uptime']}")
        
        if health_data['critical_issues']:
            self.logger.error(f"🚨 CRITICAL ISSUES: {', '.join(health_data['critical_issues'])}")
            
        if health_data['warnings']:
            self.logger.warning(f"⚠️ WARNINGS: {', '.join(health_data['warnings'])}")
            
    def send_discord_notification(self, health_data):
        """Send notification to Discord"""
        webhook_url = self.config.get('discord_webhook')
        
        if not webhook_url or webhook_url == "YOUR_DISCORD_WEBHOOK_URL_HERE":
            self.logger.warning("Discord webhook URL not configured")
            return
            
        # Check notification settings
        notifications = self.config.get('notifications', {})
        send_hourly = notifications.get('send_hourly_status', True)
        send_only_errors = notifications.get('send_only_errors', False)
        
        # Skip if only errors and status is healthy
        if send_only_errors and health_data['overall_status'] == 'HEALTHY':
            return
            
        try:
            # Create Discord embed
            embed = self.create_discord_embed(health_data)
            
            payload = {
                "embeds": [embed]
            }
            
            response = requests.post(webhook_url, json=payload, timeout=10)
            
            if response.status_code == 204:
                self.logger.info("✅ Discord notification sent successfully")
            else:
                self.logger.error(f"❌ Discord notification failed: {response.status_code}")
                
        except Exception as e:
            self.logger.error(f"❌ Error sending Discord notification: {e}")
            
    def create_discord_embed(self, health_data):
        """Create Discord embed message"""
        status = health_data['overall_status']
        
        # Set color based on status
        colors = {
            'HEALTHY': 0x00ff00,    # Green
            'WARNING': 0xffff00,    # Yellow
            'CRITICAL': 0xff0000    # Red
        }
        
        # Set emoji based on status
        emojis = {
            'HEALTHY': '🟢',
            'WARNING': '🟡',
            'CRITICAL': '🔴'
        }
        
        embed = {
            "title": f"{emojis[status]} OVPM Health Check - {status}",
            "description": f"🕐 Vietnam Time: {health_data['vietnam_time']}",
            "color": colors[status],
            "timestamp": health_data['timestamp'],
            "fields": [
                {
                    "name": "🔧 Service Status",
                    "value": health_data['ovpmd_service']['status'],
                    "inline": True
                },
                {
                    "name": "👥 VPN Users",
                    "value": f"Active: {health_data['ovpm_status']['active_users']}/{health_data['ovpm_status']['total_users']}",
                    "inline": True
                },
                {
                    "name": "💻 CPU Usage",
                    "value": f"{health_data['system']['cpu_percent']}%",
                    "inline": True
                },
                {
                    "name": "🌐 Network",
                    "value": f"OpenVPN: {health_data['network']['ovpn_port']['status']}\nWeb UI: {health_data['network']['web_ui']['status']}",
                    "inline": True
                },
                {
                    "name": "💾 Memory",
                    "value": f"{health_data['system']['memory_used_gb']}GB/{health_data['system']['memory_total_gb']}GB ({health_data['system']['memory_percent']}%)",
                    "inline": True
                },
                {
                    "name": "⏰ Uptime",
                    "value": health_data['system']['uptime'],
                    "inline": True
                }
            ]
        }
        
        # Add issues if any
        if health_data['critical_issues']:
            embed["fields"].append({
                "name": "🚨 Critical Issues",
                "value": "\n".join(health_data['critical_issues']),
                "inline": False
            })
            
        if health_data['warnings']:
            embed["fields"].append({
                "name": "⚠️ Warnings",
                "value": "\n".join(health_data['warnings']),
                "inline": False
            })
            
        # Add server info
        embed["footer"] = {
            "text": f"OVPM Server: {self.config['ovpm_hostname']} ({self.config['ovpm_server_ip']})"
        }
        
        return embed

def run_health_check():
    """Function to run health check - used by scheduler"""
    try:
        checker = OVPMHealthChecker()
        checker.perform_health_check()
    except Exception as e:
        print(f"Error running health check: {e}")
        logging.error(f"Error running health check: {e}")

def main():
    """Main function"""
    print("🏥 OVPM Health Checker Starting...")
    
    # Create checker instance
    checker = OVPMHealthChecker()
    
    # Run initial check
    print("Running initial health check...")
    checker.perform_health_check()
    
    # Schedule hourly checks
    print("Scheduling hourly health checks...")
    schedule.every().hour.do(run_health_check)
    
    print("✅ Health checker is running. Press Ctrl+C to stop.")
    print(f"📊 Logs are written to: {checker.config['log_file']}")
    print(f"⏰ Next check scheduled in 1 hour")
    
    try:
        while True:
            schedule.run_pending()
            time.sleep(60)  # Check every minute for scheduled tasks
    except KeyboardInterrupt:
        print("\n👋 Health checker stopped by user")
    except Exception as e:
        print(f"❌ Unexpected error: {e}")
        logging.error(f"Unexpected error in main loop: {e}")

if __name__ == "__main__":
    main() 