import ActivityKit
import Foundation

struct AgentActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var status: String
        var statusColor: String // Hex color
        var message: String
        var agentName: String
        var updatedAt: Date

        init(
            status: String,
            statusColor: String = "00D4AA",
            message: String,
            agentName: String,
            updatedAt: Date = Date()
        ) {
            self.status = status
            self.statusColor = statusColor
            self.message = message
            self.agentName = agentName
            self.updatedAt = updatedAt
        }
    }

    var agentId: String
    var agentExternalId: String?
}

// MARK: - Live Activity Manager

@MainActor
class LiveActivityManager: ObservableObject {
    static let shared = LiveActivityManager()

    @Published var activeActivities: [String: Activity<AgentActivityAttributes>] = [:]

    private init() {}

    func startActivity(for agent: Agent) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("Live Activities not enabled")
            return
        }

        // End existing activity for this agent if exists
        if let existingActivity = activeActivities[agent.id] {
            Task {
                await existingActivity.end(dismissalPolicy: .immediate)
            }
        }

        let attributes = AgentActivityAttributes(
            agentId: agent.id,
            agentExternalId: agent.externalId
        )

        let contentState = AgentActivityAttributes.ContentState(
            status: agent.status.displayName,
            statusColor: agent.status.hexColor,
            message: agent.lastMessage ?? "Agent is running...",
            agentName: agent.displayName,
            updatedAt: agent.updatedAt
        )

        do {
            let activity = try Activity<AgentActivityAttributes>.request(
                attributes: attributes,
                content: .init(state: contentState, staleDate: nil),
                pushType: .token
            )

            activeActivities[agent.id] = activity
            print("Started Live Activity for agent: \(agent.id)")

            // Handle push token for remote updates
            Task {
                for await pushToken in activity.pushTokenUpdates {
                    let tokenString = pushToken.map { String(format: "%02x", $0) }.joined()
                    print("Live Activity push token: \(tokenString)")
                    // Send token to backend for remote updates
                }
            }
        } catch {
            print("Failed to start Live Activity: \(error)")
        }
    }

    func updateActivity(for agent: Agent) {
        guard let activity = activeActivities[agent.id] else {
            // Start new activity if not exists
            startActivity(for: agent)
            return
        }

        let contentState = AgentActivityAttributes.ContentState(
            status: agent.status.displayName,
            statusColor: agent.status.hexColor,
            message: agent.lastMessage ?? "Agent is running...",
            agentName: agent.displayName,
            updatedAt: agent.updatedAt
        )

        Task {
            await activity.update(using: contentState)
        }
    }

    func endActivity(for agentId: String) {
        guard let activity = activeActivities[agentId] else { return }

        Task {
            await activity.end(dismissalPolicy: .default)
            activeActivities.removeValue(forKey: agentId)
        }
    }

    func endAllActivities() {
        for (agentId, activity) in activeActivities {
            Task {
                await activity.end(dismissalPolicy: .immediate)
            }
            activeActivities.removeValue(forKey: agentId)
        }
    }
}

// MARK: - AgentStatus Extension

extension AgentStatus {
    var hexColor: String {
        switch self {
        case .idle: return "888888"
        case .running: return "007AFF"
        case .awaitingInput: return "FF9500"
        case .completed: return "34C759"
        case .error: return "FF3B30"
        }
    }
}
