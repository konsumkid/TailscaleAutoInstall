import WidgetKit
import SwiftUI
import ActivityKit

// MARK: - Live Activity Widget

struct AgentfyWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AgentActivityAttributes.self) { context in
            // Lock Screen / Banner View
            LockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded View
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color(hex: context.state.statusColor))
                            .frame(width: 10, height: 10)
                        Text(context.state.status)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.updatedAt, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.agentName)
                        .font(.headline)
                        .lineLimit(1)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .padding(.horizontal)
                }
            } compactLeading: {
                // Compact Leading
                Circle()
                    .fill(Color(hex: context.state.statusColor))
                    .frame(width: 12, height: 12)
            } compactTrailing: {
                // Compact Trailing
                Text(context.state.status)
                    .font(.caption2)
                    .fontWeight(.medium)
            } minimal: {
                // Minimal
                Circle()
                    .fill(Color(hex: context.state.statusColor))
                    .frame(width: 10, height: 10)
            }
        }
    }
}

// MARK: - Lock Screen View

struct LockScreenView: View {
    let context: ActivityViewContext<AgentActivityAttributes>

    var body: some View {
        HStack(spacing: 16) {
            // Status indicator
            VStack {
                Circle()
                    .fill(Color(hex: context.state.statusColor))
                    .frame(width: 12, height: 12)
            }
            .frame(width: 24)

            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(context.state.agentName)
                        .font(.headline)
                        .lineLimit(1)

                    Spacer()

                    Text(context.state.status)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(Color(hex: context.state.statusColor))
                }

                Text(context.state.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            // Time
            VStack(alignment: .trailing) {
                Text(context.state.updatedAt, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color.black.opacity(0.8))
    }
}

// MARK: - Color Extension for Widget

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 3:
            (r, g, b) = ((int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (1, 1, 1)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: 1
        )
    }
}

// MARK: - Preview

#Preview("Live Activity", as: .content, using: AgentActivityAttributes(agentId: "123")) {
    AgentfyWidgetLiveActivity()
} contentStates: {
    AgentActivityAttributes.ContentState(
        status: "Running",
        statusColor: "007AFF",
        message: "Implementing new feature...",
        agentName: "Agent abc12345"
    )
    AgentActivityAttributes.ContentState(
        status: "Awaiting Input",
        statusColor: "FF9500",
        message: "Permission required: edit file.ts",
        agentName: "Agent abc12345"
    )
}
