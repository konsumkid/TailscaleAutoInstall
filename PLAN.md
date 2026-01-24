# Agentfy Clone - Implementation Plan

## Phase 1: Project Setup & Backend Foundation

### 1.1 Initialize Backend Project
- [ ] Create `backend/` directory structure
- [ ] Initialize Node.js project with TypeScript
- [ ] Install dependencies:
  - express/fastify (web framework)
  - @apple/app-store-server-library (APNS)
  - prisma (ORM)
  - zod (validation)
  - uuid (webhook URL generation)
- [ ] Configure TypeScript, ESLint, Prettier
- [ ] Set up environment variables handling

### 1.2 Database Schema Design
```prisma
model Device {
  id          String   @id @default(uuid())
  pushToken   String   @unique
  webhookToken String  @unique @default(uuid())
  createdAt   DateTime @default(now())
  updatedAt   DateTime @updatedAt
  agents      Agent[]
}

model Agent {
  id          String      @id @default(uuid())
  deviceId    String
  device      Device      @relation(fields: [deviceId], references: [id])
  name        String?
  status      AgentStatus @default(IDLE)
  lastMessage String?
  startedAt   DateTime    @default(now())
  updatedAt   DateTime    @updatedAt
}

enum AgentStatus {
  IDLE
  RUNNING
  AWAITING_INPUT
  COMPLETED
  ERROR
}
```

### 1.3 Core API Routes
- [ ] `POST /api/devices/register` - Register new device
- [ ] `DELETE /api/devices/:id` - Unregister device
- [ ] `POST /api/webhook/:token` - Receive Claude Code events
- [ ] `GET /api/health` - Health check endpoint

---

## Phase 2: Push Notification System

### 2.1 APNS Setup
- [ ] Obtain Apple Developer credentials
- [ ] Generate APNS authentication key (.p8 file)
- [ ] Configure APNS client in backend
- [ ] Create push notification service class

### 2.2 Notification Types
```typescript
interface PushPayload {
  aps: {
    alert: {
      title: string;
      body: string;
    };
    sound: string;
    badge?: number;
    "content-available"?: 1;
    "mutable-content"?: 1;
  };
  agentId: string;
  eventType: string;
}
```

### 2.3 Notification Templates
| Event | Title | Body |
|-------|-------|------|
| permission_required | "Permission Required" | "Agent needs approval: {action}" |
| task_completed | "Task Complete" | "Agent finished: {summary}" |
| error | "Agent Error" | "Error occurred: {message}" |
| agent_started | "Agent Started" | "New session: {name}" |

---

## Phase 3: iOS App Development

### 3.1 Project Setup
- [ ] Create new Xcode project (iOS 18.0+, SwiftUI)
- [ ] Configure App Bundle ID
- [ ] Enable Push Notifications capability
- [ ] Enable Live Activities capability
- [ ] Set up App Groups for shared data

### 3.2 Core Models
```swift
// Agent.swift
struct Agent: Identifiable, Codable {
    let id: String
    var name: String?
    var status: AgentStatus
    var lastMessage: String?
    var startedAt: Date
    var updatedAt: Date
}

enum AgentStatus: String, Codable {
    case idle = "IDLE"
    case running = "RUNNING"
    case awaitingInput = "AWAITING_INPUT"
    case completed = "COMPLETED"
    case error = "ERROR"

    var displayName: String {
        switch self {
        case .idle: return "Idle"
        case .running: return "Running"
        case .awaitingInput: return "Awaiting Input"
        case .completed: return "Completed"
        case .error: return "Error"
        }
    }

    var color: Color {
        switch self {
        case .idle: return .gray
        case .running: return .blue
        case .awaitingInput: return .orange
        case .completed: return .green
        case .error: return .red
        }
    }
}
```

### 3.3 Views to Implement

#### OnboardingView
- [ ] Welcome screen with app description
- [ ] Webhook URL display with copy button
- [ ] Setup instructions for Claude Code
- [ ] Push notification permission request

#### DashboardView
- [ ] List of all monitored agents
- [ ] Pull-to-refresh functionality
- [ ] Empty state when no agents
- [ ] Navigation to agent details

#### AgentRowView
- [ ] Agent name/ID display
- [ ] Status indicator (colored dot)
- [ ] Last message preview
- [ ] Time since last update

#### SettingsView
- [ ] Webhook URL management
- [ ] Notification preferences
- [ ] Clear all agents option
- [ ] About/Support links

### 3.4 Services

#### NetworkService
```swift
class NetworkService {
    static let shared = NetworkService()
    private let baseURL = "https://api.agentfy-clone.com"

    func registerDevice(pushToken: String) async throws -> Device
    func fetchAgents() async throws -> [Agent]
    func unregisterDevice() async throws
}
```

#### NotificationService
```swift
class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationService()

    func requestPermission() async -> Bool
    func registerForRemoteNotifications()
    func handleNotification(_ notification: UNNotification)
}
```

---

## Phase 4: Live Activities Implementation

### 4.1 Activity Attributes
```swift
// AgentActivityAttributes.swift
struct AgentActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var status: String
        var message: String
        var agentName: String
        var updatedAt: Date
    }

    var agentId: String
}
```

### 4.2 Live Activity Widget
- [ ] Create Widget Extension target
- [ ] Design Lock Screen layout
- [ ] Design Dynamic Island (compact/expanded)
- [ ] Implement activity start/update/end logic

### 4.3 Widget Views
```swift
// Lock Screen
struct AgentLockScreenView: View {
    let context: ActivityViewContext<AgentActivityAttributes>

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(context.state.agentName)
                    .font(.headline)
                Text(context.state.status)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            StatusIndicator(status: context.state.status)
        }
        .padding()
    }
}

// Dynamic Island (Expanded)
struct AgentExpandedView: View {
    let context: ActivityViewContext<AgentActivityAttributes>

    var body: some View {
        VStack {
            Text(context.state.agentName)
            Text(context.state.message)
                .font(.caption)
        }
    }
}
```

---

## Phase 5: Claude Code Integration

### 5.1 Hook Configuration
Create setup instructions for users:

```markdown
## Setup Claude Code Monitoring

1. Open the Agentfy app and copy your webhook URL
2. In Claude Code, add this hook configuration:

```json
{
  "hooks": {
    "on_task_start": {
      "command": "curl -X POST {WEBHOOK_URL} -H 'Content-Type: application/json' -d '{\"event\":\"agent_started\",\"agent_id\":\"$AGENT_ID\"}'"
    },
    "on_permission_request": {
      "command": "curl -X POST {WEBHOOK_URL} -H 'Content-Type: application/json' -d '{\"event\":\"permission_required\",\"agent_id\":\"$AGENT_ID\",\"message\":\"$MESSAGE\"}'"
    },
    "on_task_complete": {
      "command": "curl -X POST {WEBHOOK_URL} -H 'Content-Type: application/json' -d '{\"event\":\"task_completed\",\"agent_id\":\"$AGENT_ID\"}'"
    },
    "on_error": {
      "command": "curl -X POST {WEBHOOK_URL} -H 'Content-Type: application/json' -d '{\"event\":\"error\",\"agent_id\":\"$AGENT_ID\",\"message\":\"$ERROR\"}'"
    }
  }
}
```
```

### 5.2 Alternative: MCP Server
- [ ] Consider creating an MCP server for deeper integration
- [ ] Would allow bidirectional communication
- [ ] Could enable remote approval of permissions

---

## Phase 6: UI/UX Polish

### 6.1 Design System
- [ ] Define color palette (dark theme)
  - Background: #0D0D0D
  - Surface: #1A1A1A
  - Primary: #00D4AA (mint green)
  - Text Primary: #FFFFFF
  - Text Secondary: #888888
- [ ] Typography (SF Mono for code elements)
- [ ] Consistent spacing/padding
- [ ] Haptic feedback for interactions

### 6.2 Animations
- [ ] Smooth status transitions
- [ ] Pull-to-refresh animation
- [ ] Notification appearance
- [ ] Live Activity updates

### 6.3 Empty States
- [ ] No agents: "Start a Claude Code session to see it here"
- [ ] No connection: "Unable to connect to server"
- [ ] Error state: Retry button

---

## Phase 7: Testing & Quality

### 7.1 Backend Tests
- [ ] Unit tests for webhook processing
- [ ] Unit tests for push notification formatting
- [ ] Integration tests for API endpoints
- [ ] Load testing for concurrent webhooks

### 7.2 iOS Tests
- [ ] Unit tests for models
- [ ] Unit tests for services
- [ ] UI tests for main flows
- [ ] Live Activity testing (device required)

### 7.3 End-to-End Testing
- [ ] Full flow: Claude Code → Webhook → Push → App
- [ ] Test all event types
- [ ] Test notification appearance
- [ ] Test Live Activity updates

---

## Phase 8: Deployment

### 8.1 Backend Deployment
- [ ] Choose hosting (Railway/Fly.io/Render)
- [ ] Set up PostgreSQL database
- [ ] Configure environment variables
- [ ] Set up SSL certificate
- [ ] Configure monitoring/logging
- [ ] Set up CI/CD pipeline

### 8.2 iOS App Distribution
- [ ] Create App Store Connect listing
- [ ] Prepare screenshots and description
- [ ] Submit for TestFlight testing
- [ ] Address any review feedback
- [ ] Submit for App Store review

---

## Phase 9: Documentation & Launch

### 9.1 Documentation
- [ ] User guide for app setup
- [ ] Claude Code integration instructions
- [ ] FAQ section
- [ ] Troubleshooting guide

### 9.2 Launch Checklist
- [ ] Privacy policy page
- [ ] Terms of service
- [ ] Support email/contact
- [ ] Landing page (optional)

---

## Implementation Order Summary

1. **Backend Foundation** (Phase 1)
2. **Push Notifications** (Phase 2)
3. **iOS Core App** (Phase 3)
4. **Live Activities** (Phase 4)
5. **Claude Integration** (Phase 5)
6. **UI Polish** (Phase 6)
7. **Testing** (Phase 7)
8. **Deployment** (Phase 8)
9. **Documentation** (Phase 9)

---

## Resource Requirements

| Resource | Purpose | Cost |
|----------|---------|------|
| Apple Developer Account | App Store, APNS | $99/year |
| Backend Hosting | API server | ~$5-20/month |
| PostgreSQL | Database | ~$0-15/month |
| Domain Name | API URL | ~$12/year |

---

## Risk Mitigation

| Risk | Mitigation |
|------|------------|
| APNS complexity | Use proven libraries, thorough testing |
| iOS review rejection | Follow Apple guidelines strictly |
| Webhook reliability | Implement retry logic, error handling |
| Rate limiting | Implement throttling, queue system |
| Privacy concerns | Minimal data collection, clear policy |

---

## Future Enhancements (Post-MVP)

- [ ] macOS companion app
- [ ] Apple Watch app
- [ ] Multiple workspace support
- [ ] Custom notification sounds
- [ ] Agent analytics/history
- [ ] Shareable agent status links
- [ ] Dark/light theme toggle
- [ ] Siri Shortcuts integration
