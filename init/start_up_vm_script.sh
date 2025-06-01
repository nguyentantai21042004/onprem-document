#!/bin/bash

WEBHOOK_URL="https://discord.com/api/webhooks/1378781253406425218/CBpEqEsBfyCBq1M_zF_qmB5KdoHqWnrB6x37K_6JIyVDPNBdxfy8fqCW8AILpHt8Qw0s"

# Function gửi message
send_discord() {
    curl -H "Content-Type: application/json" \
        -X POST \
        -d "{\"content\":\"$1\"}" \
        $WEBHOOK_URL
}

cd /home/tanca-test

CURRENT_TIME=$(TZ='Asia/Ho_Chi_Minh' date '+%Y-%m-%d %H:%M:%S')
HOST_NAME=$(hostname)

# Send message to discord
send_discord "🚀 Bot starting on $HOST_NAME at $CURRENT_TIME..."

# Start bot
nohup python3 tanca-employee-shift-bot/bot.py > output.log 2>&1 &
BOT_PID=$!

# Wait a moment to let the process start and possibly fail
sleep 2

# Check if the process is still running
if ps -p $BOT_PID > /dev/null; then
    CURRENT_TIME=$(TZ='Asia/Ho_Chi_Minh' date '+%Y-%m-%d %H:%M:%S')
    # Send message to discord
    send_discord "✅ Bot started successfully!\nPID: $BOT_PID\nHost: $HOST_NAME\nTime: $CURRENT_TIME"
    echo -e "Bot started with PID: $BOT_PID"
else
    CURRENT_TIME=$(date '+%Y-%m-%d %H:%M:%S')
    # Get last 20 lines of output.log
    LOG_TAIL=$(tail -n 20 output.log | sed 's/"/\\"/g')
    # Send message to discord with log
    send_discord "❌ Bot failed to start on $HOST_NAME at $CURRENT_TIME.\nCheck output.log for details.\n\`\`\`\n$LOG_TAIL\n\`\`\`"
    echo -e "Bot failed to start. Check output.log for details."
fi