# Grafana Complete Documentation

## Table of Contents

1. [Grafana Overview](#grafana-overview)
2. [Architecture](#architecture)
3. [Data Sources](#data-sources)
4. [Dashboard Creation](#dashboard-creation)
5. [Panel Types](#panel-types)
6. [Variables and Templating](#variables-and-templating)
7. [Alerting](#alerting)
8. [User Management](#user-management)
9. [Provisioning](#provisioning)
10. [Best Practices](#best-practices)

## Grafana Overview

### What is Grafana?
Grafana là một open-source analytics và monitoring platform cho phép query, visualize, alert và explore metrics từ nhiều data sources khác nhau.

### Key Features

- **Multi-datasource support**: Kết nối với 60+ data sources
- **Rich visualization**: Nhiều panel types cho different use cases
- **Alerting**: Flexible alerting với multiple notification channels
- **Dashboard sharing**: Share dashboards với teams và organizations
- **Templating**: Dynamic dashboards với variables
- **User management**: Role-based access control
- **Plugins**: Extensible với custom panels và data sources

### Use Cases

- Infrastructure monitoring dashboards
- Application performance monitoring
- Business metrics visualization
- IoT data monitoring
- Log analysis và troubleshooting
- Real-time data exploration

## Grafana Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        Grafana Frontend                     │
│  ┌─────────────────┐  ┌─────────────────┐  ┌──────────────┐ │
│  │   Dashboards    │  │     Alerting    │  │ User Manager │ │
│  └─────────────────┘  └─────────────────┘  └──────────────┘ │
│  ┌─────────────────┐  ┌─────────────────┐  ┌──────────────┐ │
│  │     Panels      │  │   Explore UI    │  │   Settings   │ │
│  └─────────────────┘  └─────────────────┘  └──────────────┘ │
└─────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────┐
│                      Grafana Backend                        │
│  ┌─────────────────┐  ┌─────────────────┐  ┌──────────────┐ │
│  │   HTTP Server   │  │  Query Engine   │  │   Auth       │ │
│  └─────────────────┘  └─────────────────┘  └──────────────┘ │
│  ┌─────────────────┐  ┌─────────────────┐  ┌──────────────┐ │
│  │   Alerting      │  │   Provisioning  │  │   Plugins    │ │
│  └─────────────────┘  └─────────────────┘  └──────────────┘ │
└─────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────┐
│                       Database                              │
│               (SQLite/MySQL/PostgreSQL)                     │
└─────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────┐
│                      Data Sources                           │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐   │
│  │  Prometheus  │  │   InfluxDB   │  │   Elasticsearch  │   │
│  └──────────────┘  └──────────────┘  └──────────────────┘   │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐   │
│  │    MySQL     │  │  CloudWatch  │  │      Loki        │   │
│  └──────────────┘  └──────────────┘  └──────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

### Core Components

#### Frontend (React)
- Dashboard renderer
- Panel editors
- Query builders
- User interface

#### Backend (Go)
- HTTP API server
- Query execution engine
- Alerting engine
- Plugin management
- Authentication/Authorization

#### Database
- Stores dashboards, users, organizations
- Supports SQLite, MySQL, PostgreSQL

#### Data Sources
- Pluggable architecture
- Protocol-specific adapters
- Query translation layer

## Data Sources

### Prometheus Data Source

#### Configuration
```json
{
  "name": "Prometheus",
  "type": "prometheus", 
  "url": "http://prometheus:9090",
  "access": "proxy",
  "basicAuth": false,
  "isDefault": true,
  "jsonData": {
    "httpMethod": "POST",
    "queryTimeout": "60s",
    "timeInterval": "30s",
    "exemplarTraceIdDestinations": [
      {
        "name": "traceID",
        "datasourceUid": "jaeger-uid"
      }
    ]
  }
}
```

#### Query Examples
```promql
# Basic metric
up

# Rate calculation  
rate(http_requests_total[5m])

# Aggregation
sum by (job) (rate(http_requests_total[5m]))

# Mathematical operations
(rate(http_requests_total{status_code=~"5.."}[5m]) / rate(http_requests_total[5m])) * 100
```

### InfluxDB Data Source

#### Configuration
```json
{
  "name": "InfluxDB",
  "type": "influxdb",
  "url": "http://influxdb:8086", 
  "database": "mydb",
  "user": "username",
  "password": "password",
  "access": "proxy",
  "jsonData": {
    "timeInterval": "10s",
    "httpMode": "GET"
  }
}
```

#### Query Examples
```sql
-- Basic query
SELECT mean("value") FROM "cpu_usage" WHERE $timeFilter GROUP BY time($__interval)

-- With tags
SELECT mean("value") FROM "cpu_usage" WHERE "host" = 'server1' AND $timeFilter GROUP BY time($__interval)

-- Multiple series
SELECT mean("value") FROM "cpu_usage" WHERE $timeFilter GROUP BY time($__interval), "host"
```

### Elasticsearch Data Source

#### Configuration
```json
{
  "name": "Elasticsearch",
  "type": "elasticsearch",
  "url": "http://elasticsearch:9200",
  "index": "logstash-*",
  "timeField": "@timestamp",
  "access": "proxy",
  "jsonData": {
    "esVersion": "7.10.0",
    "timeInterval": "10s",
    "maxConcurrentShardRequests": 5
  }
}
```

#### Query Examples
```json
{
  "query": {
    "bool": {
      "filter": [
        {"range": {"@timestamp": {"gte": "$__timeFrom", "lte": "$__timeTo"}}},
        {"term": {"level": "error"}}
      ]
    }
  },
  "aggs": {
    "time_buckets": {
      "date_histogram": {
        "field": "@timestamp",
        "interval": "$__interval"
      }
    }
  }
}
```

### Loki Data Source

#### Configuration
```json
{
  "name": "Loki",
  "type": "loki",
  "url": "http://loki:3100",
  "access": "proxy",
  "jsonData": {
    "maxLines": 1000,
    "derivedFields": [
      {
        "matcherRegex": "traceID=(\\w+)",
        "name": "traceID", 
        "url": "http://jaeger:16686/trace/${__value.raw}"
      }
    ]
  }
}
```

#### LogQL Examples
```logql
# Basic log query
{job="nginx"} |= "error"

# With regex
{job="application"} |~ "ERROR|FATAL"

# Rate queries
rate({job="nginx"}[5m])

# Aggregation
sum by (job) (rate({job=~".*"}[5m]))
```

## Dashboard Creation

### Dashboard JSON Structure
```json
{
  "dashboard": {
    "id": null,
    "title": "My Dashboard",
    "description": "Dashboard description",
    "tags": ["monitoring", "infrastructure"],
    "timezone": "browser",
    "refresh": "30s",
    "schemaVersion": 30,
    "version": 1,
    "time": {
      "from": "now-1h",
      "to": "now"
    },
    "timepicker": {
      "refresh_intervals": ["5s", "10s", "30s", "1m", "5m", "15m", "30m", "1h", "2h", "1d"],
      "time_options": ["5m", "15m", "1h", "6h", "12h", "24h", "2d", "7d", "30d"]
    },
    "templating": {
      "list": []
    },
    "annotations": {
      "list": []
    },
    "panels": []
  }
}
```

### Panel Configuration
```json
{
  "id": 1,
  "title": "CPU Usage",
  "type": "stat",
  "gridPos": {
    "h": 4,
    "w": 6,
    "x": 0,
    "y": 0
  },
  "targets": [
    {
      "expr": "100 - (avg by (instance) (rate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)",
      "legendFormat": "{{instance}}"
    }
  ],
  "fieldConfig": {
    "defaults": {
      "unit": "percent",
      "min": 0,
      "max": 100,
      "thresholds": {
        "steps": [
          {"color": "green", "value": null},
          {"color": "yellow", "value": 70},
          {"color": "red", "value": 90}
        ]
      }
    }
  },
  "options": {
    "reduceOptions": {
      "values": false,
      "calcs": ["lastNotNull"],
      "fields": ""
    },
    "orientation": "auto",
    "textMode": "auto",
    "colorMode": "value"
  }
}
```

### Dashboard Organization

#### Folder Structure
```
Dashboards/
├── Infrastructure/
│   ├── System Overview
│   ├── Network Monitoring  
│   └── Storage Metrics
├── Applications/
│   ├── Web Services
│   ├── Database Performance
│   └── Message Queues
├── Business/
│   ├── Sales Metrics
│   ├── User Analytics
│   └── Revenue Tracking
└── Alerts/
    ├── Critical Issues
    ├── Warnings
    └── System Health
```

#### Dashboard Tags
```json
{
  "tags": [
    "infrastructure",
    "production", 
    "kubernetes",
    "monitoring",
    "team:sre"
  ]
}
```

## Panel Types

### Time Series Panel

#### Configuration
```json
{
  "type": "timeseries",
  "title": "Request Rate",
  "targets": [
    {
      "expr": "sum(rate(http_requests_total[5m]))",
      "legendFormat": "Total Requests/sec"
    }
  ],
  "fieldConfig": {
    "defaults": {
      "custom": {
        "drawStyle": "line",
        "lineInterpolation": "linear",
        "lineWidth": 2,
        "fillOpacity": 10,
        "gradientMode": "none",
        "spanNulls": false,
        "pointSize": 5,
        "stacking": {
          "mode": "none",
          "group": "A"
        },
        "axisPlacement": "auto",
        "axisLabel": "Requests/sec",
        "scaleDistribution": {
          "type": "linear"
        }
      },
      "unit": "reqps",
      "min": 0
    }
  }
}
```

### Stat Panel

#### Single Value Display
```json
{
  "type": "stat",
  "title": "Current Active Users",
  "targets": [
    {
      "expr": "active_users_total",
      "legendFormat": "Active Users"
    }
  ],
  "fieldConfig": {
    "defaults": {
      "unit": "short",
      "thresholds": {
        "steps": [
          {"color": "red", "value": null},
          {"color": "yellow", "value": 100},
          {"color": "green", "value": 1000}
        ]
      }
    }
  },
  "options": {
    "reduceOptions": {
      "values": false,
      "calcs": ["lastNotNull"]
    },
    "orientation": "auto",
    "textMode": "auto",
    "colorMode": "background"
  }
}
```

### Gauge Panel

#### Progress Indicator
```json
{
  "type": "gauge",
  "title": "Memory Usage",
  "targets": [
    {
      "expr": "(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100",
      "legendFormat": "{{instance}}"
    }
  ],
  "fieldConfig": {
    "defaults": {
      "unit": "percent",
      "min": 0,
      "max": 100,
      "thresholds": {
        "steps": [
          {"color": "green", "value": null},
          {"color": "yellow", "value": 70},
          {"color": "red", "value": 90}
        ]
      }
    }
  },
  "options": {
    "reduceOptions": {
      "calcs": ["lastNotNull"]
    },
    "orientation": "auto",
    "showThresholdLabels": false,
    "showThresholdMarkers": true
  }
}
```

### Table Panel

#### Tabular Data Display
```json
{
  "type": "table",
  "title": "Service Health",
  "targets": [
    {
      "expr": "up",
      "format": "table",
      "instant": true
    }
  ],
  "fieldConfig": {
    "defaults": {
      "custom": {
        "align": "auto",
        "displayMode": "auto"
      }
    },
    "overrides": [
      {
        "matcher": {"id": "byName", "options": "Value"},
        "properties": [
          {
            "id": "custom.displayMode",
            "value": "color-background"
          },
          {
            "id": "mappings",
            "value": [
              {
                "options": {
                  "0": {"text": "Down", "color": "red"},
                  "1": {"text": "Up", "color": "green"}
                },
                "type": "value"
              }
            ]
          }
        ]
      }
    ]
  }
}
``` 