# Agentfy Clone - Claude Code Agent Monitor

A complete clone of [Agentfy](https://www.getagentfy.com) - an iOS application that monitors Claude Code agents in real-time with push notifications and Live Activities.

## Overview

Agentfy Clone allows developers to monitor their Claude Code sessions from their iPhone, receiving instant notifications when agents need input, complete tasks, or encounter errors.

![Agentfy Screenshot](https://via.placeholder.com/800x400?text=Agentfy+Clone)

## Features

- **Push Notifications** - Get instant alerts when agents need permission or complete tasks
- **Live Activities** - Track agent status on your Lock Screen and Dynamic Island
- **Multi-Agent Dashboard** - Monitor unlimited Claude Code sessions
- **Terminal-Inspired UI** - Dark theme designed for developers
- **Real-time Updates** - Webhook-based communication for instant status changes

## Project Structure

```
.
├── backend/                 # Node.js/TypeScript API server
│   ├── src/
│   │   ├── routes/         # API endpoints
│   │   ├── services/       # Push notifications, etc.
│   │   ├── middleware/     # Error handling, logging
│   │   └── utils/          # Prisma client, validators
│   ├── prisma/             # Database schema
│   └── package.json
├── ios/                     # SwiftUI iOS app
│   └── Agentfy/
│       ├── Agentfy/
│       │   ├── App/        # App entry point, state
│       │   ├── Views/      # SwiftUI views
│       │   ├── Models/     # Data models
│       │   ├── Services/   # API, notifications
│       │   ├── LiveActivity/
│       │   └── Extensions/
│       └── AgentfyWidget/  # Live Activity widget
├── claude-setup/           # Claude Code integration
├── CLAUDE.md               # Project documentation
└── PLAN.md                 # Implementation plan
```

## Quick Start

### Backend (Replit)

1. Open the project in Replit
2. Click "Run" - the backend will start automatically
3. Your API will be available at `https://your-repl.replit.app`

### Backend (Local)

```bash
cd backend
npm install
npx prisma db push
npm run dev
```

### iOS App

1. Open `ios/Agentfy/Agentfy.xcodeproj` in Xcode
2. Set your Team ID in Signing & Capabilities
3. Update the bundle identifier
4. Build and run on your device

## Configuration

### Backend Environment Variables

```bash
# .env
PORT=3000
DATABASE_URL="file:./dev.db"
APNS_KEY_ID=your_key_id
APNS_TEAM_ID=your_team_id
APNS_BUNDLE_ID=com.yourcompany.agentfy
APNS_KEY_PATH=./certs/AuthKey.p8
```

### Claude Code Integration

See [claude-setup/README.md](claude-setup/README.md) for detailed instructions.

Quick setup:
1. Get your webhook URL from the app
2. Configure Claude Code hooks to send events to your webhook
3. Start monitoring!

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/devices/register` | Register device for push |
| POST | `/api/webhook/:token` | Receive Claude Code events |
| GET | `/api/agents/by-token/:token` | Get agents for device |
| DELETE | `/api/agents/:id` | Delete an agent |
| GET | `/api/health` | Health check |

## Webhook Events

```json
{
  "event": "permission_required",
  "agent_id": "session-123",
  "message": "Edit file: src/app.ts",
  "timestamp": "2025-01-24T12:00:00Z"
}
```

Event types: `agent_started`, `status_change`, `permission_required`, `task_completed`, `error`, `agent_stopped`

## Tech Stack

### Backend
- Node.js + TypeScript
- Express
- Prisma (SQLite/PostgreSQL)
- APNS for push notifications

### iOS
- SwiftUI
- ActivityKit (Live Activities)
- UserNotifications
- iOS 18.0+

## Requirements

- Node.js 18+
- iOS 18.0+
- Apple Developer Account (for APNS)
- Xcode 15+

## Development

```bash
# Backend development
cd backend
npm run dev

# Run tests
npm test

# Database studio
npx prisma studio
```

## Deployment

### Backend (Replit)
The project is pre-configured for Replit. Just import and run.

### Backend (Other platforms)
```bash
cd backend
npm run build
npm start
```

### iOS
Submit through Xcode to App Store Connect.

## Contributing

Contributions are welcome! Please read the [PLAN.md](PLAN.md) for the roadmap.

## License

MIT License - see [LICENSE](LICENSE) for details.

## Acknowledgments

- [Agentfy](https://www.getagentfy.com) - The original inspiration
- [Anthropic](https://anthropic.com) - Claude Code
- [Apple](https://developer.apple.com) - ActivityKit & APNS

---

## Legacy: Tailscale Proxmox Setup

This repo also contains a script for setting up Tailscale on Proxmox. See [setup_tailscale_proxmox.sh](setup_tailscale_proxmox.sh).
