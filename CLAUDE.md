# Agentfy Clone - Claude Code Agent Monitor

## Project Overview

This project replicates [Agentfy](https://www.getagentfy.com), an iOS application that monitors Claude Code agents in real-time. The app delivers notifications and status updates directly to users' iPhones, eliminating the need for constant terminal monitoring.

## Core Features to Implement

### 1. Live Activities & Lock Screen Integration
- Display agent status on iPhone lock screen
- Dynamic Island support for compact status view
- Real-time progress updates without unlocking device

### 2. Multi-Agent Dashboard
- Track unlimited Claude Code terminals
- Visual indicators for agent states: active, awaiting input, completed, error
- Clean, organized list view of all monitored agents

### 3. Push Notifications
- Instant alerts when agents require permission
- Task completion notifications
- Error alerts for failed operations

### 4. Terminal-Inspired UI
- Dark theme optimized for developers
- Monospace fonts where appropriate
- Clean, minimal interface design

## Architecture

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  Claude Code    │────▶│  Backend API    │────▶│   iOS App       │
│  (Hooks/Events) │     │  (Webhooks)     │     │  (SwiftUI)      │
└─────────────────┘     └─────────────────┘     └─────────────────┘
                              │
                              ▼
                        ┌─────────────────┐
                        │  Push Service   │
                        │  (APNS)         │
                        └─────────────────┘
```

## Tech Stack

### Backend
- **Runtime**: Node.js with TypeScript or Python FastAPI
- **Database**: PostgreSQL or SQLite for device/agent tracking
- **Push Notifications**: Apple Push Notification Service (APNS)
- **Hosting**: Railway, Fly.io, or similar

### iOS App
- **Framework**: SwiftUI (iOS 18.0+)
- **Live Activities**: ActivityKit
- **Notifications**: UserNotifications framework
- **Networking**: URLSession with async/await

### Claude Code Integration
- Webhook-based communication
- Custom hooks configuration
- Simple setup prompt for users

## Directory Structure

```
agentfy-clone/
├── backend/
│   ├── src/
│   │   ├── routes/
│   │   │   ├── webhook.ts      # Receive events from Claude Code
│   │   │   ├── devices.ts      # Device registration
│   │   │   └── agents.ts       # Agent management
│   │   ├── services/
│   │   │   ├── push.ts         # APNS integration
│   │   │   └── liveactivity.ts # Live Activity updates
│   │   ├── models/
│   │   │   ├── device.ts
│   │   │   └── agent.ts
│   │   └── index.ts
│   ├── package.json
│   └── tsconfig.json
├── ios/
│   └── Agentfy/
│       ├── App/
│       │   └── AgentfyApp.swift
│       ├── Views/
│       │   ├── DashboardView.swift
│       │   ├── AgentRowView.swift
│       │   └── OnboardingView.swift
│       ├── Models/
│       │   ├── Agent.swift
│       │   └── AgentStatus.swift
│       ├── Services/
│       │   ├── WebhookService.swift
│       │   └── NotificationService.swift
│       ├── LiveActivity/
│       │   ├── AgentActivityWidget.swift
│       │   └── AgentActivityAttributes.swift
│       └── Assets.xcassets/
├── claude-setup/
│   └── setup-prompt.md         # User setup instructions
├── PLAN.md
├── CLAUDE.md
└── README.md
```

## API Endpoints

### Backend API

```
POST /api/webhook              # Receive Claude Code events
POST /api/devices/register     # Register iOS device for push
DELETE /api/devices/:id        # Unregister device
GET /api/agents                # List all agents for a device
GET /api/agents/:id            # Get specific agent status
```

### Webhook Payload Format

```json
{
  "event": "status_change",
  "agent_id": "abc123",
  "device_token": "xyz789",
  "status": "awaiting_input",
  "message": "Permission required: file edit",
  "timestamp": "2025-01-24T12:00:00Z"
}
```

## Event Types

| Event | Description |
|-------|-------------|
| `agent_started` | New Claude Code session started |
| `status_change` | Agent status updated |
| `permission_required` | Agent needs user approval |
| `task_completed` | Task finished successfully |
| `error` | An error occurred |
| `agent_stopped` | Session ended |

## Development Commands

```bash
# Backend
cd backend
npm install
npm run dev

# iOS (requires Xcode)
cd ios/Agentfy
open Agentfy.xcodeproj
```

## Environment Variables

### Backend
```
PORT=3000
DATABASE_URL=postgresql://...
APNS_KEY_ID=your_key_id
APNS_TEAM_ID=your_team_id
APNS_KEY_PATH=./AuthKey.p8
APNS_BUNDLE_ID=com.yourapp.agentfy
```

## Key Implementation Notes

1. **Live Activities require iOS 18.0+** - Use ActivityKit framework
2. **APNS requires Apple Developer Account** - Need to configure push certificates
3. **Webhook URL must be unique per user** - Generate UUID-based URLs
4. **Rate limiting** - Implement to prevent abuse
5. **Secure communication** - Use HTTPS and validate webhook signatures

## Claude Code Hook Setup

Users will paste this setup prompt to configure Claude Code:

```
Configure a webhook to send status updates to: https://api.agentfy-clone.com/webhook/{user_token}

Send events for:
- Task start/completion
- Permission requests
- Errors
- Status changes
```

## Testing

- Backend: Jest/Vitest for unit tests
- iOS: XCTest for unit tests, XCUITest for UI tests
- Integration: Test webhook flow end-to-end

## References

- [ActivityKit Documentation](https://developer.apple.com/documentation/activitykit)
- [APNS Documentation](https://developer.apple.com/documentation/usernotifications)
- [Claude Code Hooks](https://docs.anthropic.com/claude-code/hooks)
