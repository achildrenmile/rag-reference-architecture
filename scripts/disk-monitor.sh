#!/bin/bash
# Disk space monitor for Uptime Kuma (Push)
# Pushes status to Uptime Kuma every 5 minutes via cron

# Configuration
PUSH_URL="https://uptime.strali.solutions/api/push/nI3kKnRAfk"
THRESHOLD_GB=10  # Alert if less than this many GB free

# Check if PUSH_URL is set
if [ -z "$PUSH_URL" ]; then
    echo "Error: UPTIME_KUMA_PUSH_URL not set"
    exit 1
fi

# Get free space in GB on root partition
FREE_GB=$(df -BG / | awk 'NR==2 {print $4}' | tr -d 'G')
TOTAL_GB=$(df -BG / | awk 'NR==2 {print $2}' | tr -d 'G')
USED_PERCENT=$(df / | awk 'NR==2 {print $5}' | tr -d '%')

# Determine status
if [ "$FREE_GB" -lt "$THRESHOLD_GB" ]; then
    STATUS="down"
    MSG="LOW DISK: ${FREE_GB}GB free (${USED_PERCENT}% used)"
else
    STATUS="up"
    MSG="OK: ${FREE_GB}GB free of ${TOTAL_GB}GB (${USED_PERCENT}% used)"
fi

# Push to Uptime Kuma
curl -s "${PUSH_URL}?status=${STATUS}&msg=${MSG// /%20}&ping=" > /dev/null

echo "$(date): ${STATUS} - ${MSG}"
