# Claude Code Integration Setup

This guide explains how to configure Claude Code to send notifications to the Agentfy app.

## Prerequisites

1. Install the Agentfy app on your iPhone
2. Complete the onboarding to get your personal webhook URL
3. Have Claude Code installed and configured

## Setup Methods

### Method 1: Using Claude Code Hooks (Recommended)

Claude Code supports hooks that can execute commands on specific events. Add the following to your Claude Code configuration:

#### Step 1: Get Your Webhook URL

Open the Agentfy app and copy your webhook URL from Settings. It looks like:
```
https://your-api.com/api/webhook/YOUR_TOKEN_HERE
```

#### Step 2: Configure Hooks

Create or edit your Claude Code hooks configuration file. The location depends on your setup:

**Linux/macOS:** `~/.config/claude-code/hooks.json`
**Windows:** `%APPDATA%\claude-code\hooks.json`

Add the following configuration:

```json
{
  "hooks": {
    "onSessionStart": {
      "command": "curl -s -X POST '{{WEBHOOK_URL}}' -H 'Content-Type: application/json' -d '{\"event\":\"agent_started\",\"agent_id\":\"{{SESSION_ID}}\",\"name\":\"Claude Code Session\"}'"
    },
    "onPermissionRequest": {
      "command": "curl -s -X POST '{{WEBHOOK_URL}}' -H 'Content-Type: application/json' -d '{\"event\":\"permission_required\",\"agent_id\":\"{{SESSION_ID}}\",\"message\":\"{{PERMISSION_MESSAGE}}\"}'"
    },
    "onTaskComplete": {
      "command": "curl -s -X POST '{{WEBHOOK_URL}}' -H 'Content-Type: application/json' -d '{\"event\":\"task_completed\",\"agent_id\":\"{{SESSION_ID}}\",\"message\":\"Task completed successfully\"}'"
    },
    "onError": {
      "command": "curl -s -X POST '{{WEBHOOK_URL}}' -H 'Content-Type: application/json' -d '{\"event\":\"error\",\"agent_id\":\"{{SESSION_ID}}\",\"message\":\"{{ERROR_MESSAGE}}\"}'"
    },
    "onSessionEnd": {
      "command": "curl -s -X POST '{{WEBHOOK_URL}}' -H 'Content-Type: application/json' -d '{\"event\":\"agent_stopped\",\"agent_id\":\"{{SESSION_ID}}\"}'"
    }
  }
}
```

Replace `{{WEBHOOK_URL}}` with your actual webhook URL.

### Method 2: Using a Shell Script Wrapper

Create a wrapper script that sends notifications:

#### `agentfy-notify.sh`

```bash
#!/bin/bash

WEBHOOK_URL="YOUR_WEBHOOK_URL_HERE"
SESSION_ID="${CLAUDE_SESSION_ID:-$(uuidgen)}"

send_event() {
    local event="$1"
    local message="${2:-}"

    curl -s -X POST "$WEBHOOK_URL" \
        -H "Content-Type: application/json" \
        -d "{
            \"event\": \"$event\",
            \"agent_id\": \"$SESSION_ID\",
            \"message\": \"$message\",
            \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"
        }" > /dev/null 2>&1
}

case "$1" in
    start)
        send_event "agent_started" "Session started"
        ;;
    permission)
        send_event "permission_required" "$2"
        ;;
    complete)
        send_event "task_completed" "$2"
        ;;
    error)
        send_event "error" "$2"
        ;;
    stop)
        send_event "agent_stopped" "Session ended"
        ;;
    heartbeat)
        send_event "heartbeat" "Agent is running"
        ;;
    *)
        echo "Usage: $0 {start|permission|complete|error|stop|heartbeat} [message]"
        exit 1
        ;;
esac
```

Make it executable:
```bash
chmod +x agentfy-notify.sh
```

Use it in your workflow:
```bash
./agentfy-notify.sh start
# ... Claude Code running ...
./agentfy-notify.sh complete "Feature implemented"
./agentfy-notify.sh stop
```

### Method 3: Inline Prompts

You can instruct Claude Code to send notifications by including this in your prompts:

```
Before starting any task, send a notification:
curl -X POST 'YOUR_WEBHOOK_URL' -H 'Content-Type: application/json' -d '{"event":"agent_started","agent_id":"SESSION_ID"}'

When you need permission, notify me:
curl -X POST 'YOUR_WEBHOOK_URL' -H 'Content-Type: application/json' -d '{"event":"permission_required","message":"DESCRIPTION"}'

When done, send completion:
curl -X POST 'YOUR_WEBHOOK_URL' -H 'Content-Type: application/json' -d '{"event":"task_completed"}'
```

## Event Types

| Event | Description | When to Send |
|-------|-------------|--------------|
| `agent_started` | Session begins | At the start of each Claude Code session |
| `status_change` | Status updated | When agent status changes |
| `permission_required` | Needs approval | When Claude needs permission for file edit, command, etc. |
| `task_completed` | Task finished | When a task or sub-task completes |
| `error` | Error occurred | When an error happens |
| `agent_stopped` | Session ends | When Claude Code session terminates |
| `heartbeat` | Still running | Periodic ping to indicate activity |

## Webhook Payload Format

```json
{
    "event": "permission_required",
    "agent_id": "unique-session-id",
    "status": "AWAITING_INPUT",
    "message": "Permission required: Edit src/app.ts",
    "name": "My Project Agent",
    "timestamp": "2025-01-24T12:00:00Z"
}
```

## Testing Your Setup

Test your webhook URL with curl:

```bash
curl -X POST 'YOUR_WEBHOOK_URL' \
    -H 'Content-Type: application/json' \
    -d '{
        "event": "agent_started",
        "agent_id": "test-123",
        "message": "Test notification"
    }'
```

You should receive a notification on your iPhone if everything is configured correctly.

## Troubleshooting

### Not receiving notifications?

1. **Check webhook URL**: Ensure you copied the complete URL from the app
2. **Check internet connection**: Both your computer and phone need internet access
3. **Check notification permissions**: Ensure Agentfy has notification permissions enabled
4. **Test the endpoint**: Use the curl command above to verify the webhook works

### Notifications delayed?

- Push notifications may have slight delays depending on network conditions
- Background app refresh should be enabled for Agentfy

### Invalid webhook token error?

- Your token may have been regenerated
- Open the Agentfy app and get a fresh webhook URL from Settings

## Support

For issues or feature requests, visit:
- GitHub: https://github.com/your-repo/agentfy
- Email: support@your-domain.com
