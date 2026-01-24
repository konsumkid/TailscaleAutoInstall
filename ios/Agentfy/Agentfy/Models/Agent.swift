import Foundation
import SwiftUI

struct Agent: Identifiable, Codable, Equatable {
    let id: String
    let deviceId: String
    var externalId: String?
    var name: String?
    var status: AgentStatus
    var lastMessage: String?
    var lastEvent: String?
    let startedAt: Date
    var updatedAt: Date

    var displayName: String {
        name ?? "Agent \(id.prefix(8))"
    }

    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: updatedAt, relativeTo: Date())
    }
}

enum AgentStatus: String, Codable, CaseIterable {
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

    var icon: String {
        switch self {
        case .idle: return "moon.fill"
        case .running: return "play.fill"
        case .awaitingInput: return "hand.raised.fill"
        case .completed: return "checkmark.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        }
    }

    var isActive: Bool {
        switch self {
        case .running, .awaitingInput:
            return true
        default:
            return false
        }
    }
}

// MARK: - API Response Models

struct AgentsResponse: Codable {
    let agents: [Agent]
    let count: Int
}

struct DeviceRegistrationResponse: Codable {
    let id: String
    let webhookToken: String
    let webhookUrl: String
    let message: String
}

struct DeleteResponse: Codable {
    let message: String
}

struct ClearResponse: Codable {
    let message: String
    let deletedCount: Int
}
