#!/bin/bash
# Agentfy Notification Script for Claude Code
#
# Usage: ./agentfy-notify.sh <event> [message]
# Events: start, permission, complete, error, stop, heartbeat, status
#
# Setup:
# 1. Copy this script to your PATH
# 2. Set AGENTFY_WEBHOOK_URL environment variable or edit below
# 3. chmod +x agentfy-notify.sh

# Configuration
WEBHOOK_URL="${AGENTFY_WEBHOOK_URL:-YOUR_WEBHOOK_URL_HERE}"
SESSION_ID="${CLAUDE_SESSION_ID:-$(cat /proc/sys/kernel/random/uuid 2>/dev/null || uuidgen 2>/dev/null || date +%s)}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to send event
send_event() {
    local event="$1"
    local message="${2:-}"
    local status="${3:-RUNNING}"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    local payload=$(cat <<EOF
{
    "event": "$event",
    "agent_id": "$SESSION_ID",
    "status": "$status",
    "message": "$message",
    "timestamp": "$timestamp"
}
EOF
)

    local response=$(curl -s -w "\n%{http_code}" -X POST "$WEBHOOK_URL" \
        -H "Content-Type: application/json" \
        -d "$payload" 2>/dev/null)

    local http_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | sed '$d')

    if [ "$http_code" = "200" ] || [ "$http_code" = "201" ]; then
        echo -e "${GREEN}✓${NC} Event '$event' sent successfully"
        return 0
    else
        echo -e "${RED}✗${NC} Failed to send event '$event' (HTTP $http_code)"
        echo -e "${YELLOW}Response:${NC} $body"
        return 1
    fi
}

# Function to show usage
show_usage() {
    cat <<EOF
Agentfy Notification Script

Usage: $0 <event> [message]

Events:
  start       - Send agent_started event
  permission  - Send permission_required event
  complete    - Send task_completed event
  error       - Send error event
  stop        - Send agent_stopped event
  heartbeat   - Send heartbeat event
  status      - Send status_change event

Options:
  -h, --help  - Show this help message
  -u URL      - Override webhook URL
  -s ID       - Override session ID

Examples:
  $0 start
  $0 permission "Need to edit src/app.ts"
  $0 complete "Implemented user authentication"
  $0 error "Build failed: missing dependency"
  $0 stop

Environment Variables:
  AGENTFY_WEBHOOK_URL - Your webhook URL
  CLAUDE_SESSION_ID   - Session identifier

EOF
}

# Parse arguments
while getopts "hu:s:" opt; do
    case $opt in
        h)
            show_usage
            exit 0
            ;;
        u)
            WEBHOOK_URL="$OPTARG"
            ;;
        s)
            SESSION_ID="$OPTARG"
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            show_usage
            exit 1
            ;;
    esac
done
shift $((OPTIND-1))

# Check for required arguments
if [ $# -lt 1 ]; then
    show_usage
    exit 1
fi

# Validate webhook URL
if [ "$WEBHOOK_URL" = "YOUR_WEBHOOK_URL_HERE" ]; then
    echo -e "${RED}Error:${NC} Webhook URL not configured"
    echo "Set AGENTFY_WEBHOOK_URL environment variable or use -u option"
    exit 1
fi

# Process event
event="$1"
message="${2:-}"

case "$event" in
    start)
        send_event "agent_started" "${message:-Session started}" "RUNNING"
        ;;
    permission)
        send_event "permission_required" "${message:-Permission needed}" "AWAITING_INPUT"
        ;;
    complete)
        send_event "task_completed" "${message:-Task completed}" "COMPLETED"
        ;;
    error)
        send_event "error" "${message:-An error occurred}" "ERROR"
        ;;
    stop)
        send_event "agent_stopped" "${message:-Session ended}" "IDLE"
        ;;
    heartbeat)
        send_event "heartbeat" "${message:-Agent is running}" "RUNNING"
        ;;
    status)
        send_event "status_change" "${message:-Status updated}" "${3:-RUNNING}"
        ;;
    *)
        echo -e "${RED}Error:${NC} Unknown event '$event'"
        show_usage
        exit 1
        ;;
esac
