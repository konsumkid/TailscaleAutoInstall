import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedAgent: Agent?
    @State private var showingAgentDetail = false

    var body: some View {
        NavigationStack {
            Group {
                if appState.agents.isEmpty && !appState.isLoading {
                    EmptyAgentsView()
                } else {
                    AgentListView(
                        agents: appState.agents,
                        onDelete: deleteAgent,
                        onSelect: { agent in
                            selectedAgent = agent
                            showingAgentDetail = true
                        }
                    )
                }
            }
            .navigationTitle("Agents")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if appState.isLoading {
                        ProgressView()
                    } else {
                        Button {
                            Task {
                                await appState.refreshAgents()
                            }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
            }
            .refreshable {
                await appState.refreshAgents()
            }
            .sheet(isPresented: $showingAgentDetail) {
                if let agent = selectedAgent {
                    AgentDetailView(agent: agent)
                }
            }
        }
        .task {
            await appState.refreshAgents()
        }
    }

    private func deleteAgent(_ agent: Agent) {
        Task {
            await appState.deleteAgent(agent)
        }
    }
}

// MARK: - Empty State

struct EmptyAgentsView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "terminal")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                Text("No Agents")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Start a Claude Code session to see it here. Make sure you've configured the webhook.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.background)
    }
}

// MARK: - Agent List

struct AgentListView: View {
    let agents: [Agent]
    let onDelete: (Agent) -> Void
    let onSelect: (Agent) -> Void

    var groupedAgents: [AgentGroup] {
        let active = agents.filter { $0.status.isActive }
        let completed = agents.filter { $0.status == .completed }
        let errors = agents.filter { $0.status == .error }
        let idle = agents.filter { $0.status == .idle }

        var groups: [AgentGroup] = []

        if !active.isEmpty {
            groups.append(AgentGroup(title: "Active", agents: active))
        }
        if !errors.isEmpty {
            groups.append(AgentGroup(title: "Errors", agents: errors))
        }
        if !completed.isEmpty {
            groups.append(AgentGroup(title: "Completed", agents: completed))
        }
        if !idle.isEmpty {
            groups.append(AgentGroup(title: "Idle", agents: idle))
        }

        return groups
    }

    var body: some View {
        List {
            ForEach(groupedAgents, id: \.title) { group in
                Section(group.title) {
                    ForEach(group.agents) { agent in
                        AgentRowView(agent: agent)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onSelect(agent)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    onDelete(agent)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

struct AgentGroup {
    let title: String
    let agents: [Agent]
}

// MARK: - Agent Row

struct AgentRowView: View {
    let agent: Agent

    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            Image(systemName: agent.status.icon)
                .font(.title3)
                .foregroundStyle(agent.status.color)
                .frame(width: 32)

            // Agent info
            VStack(alignment: .leading, spacing: 4) {
                Text(agent.displayName)
                    .font(.headline)
                    .lineLimit(1)

                if let message = agent.lastMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Time and status
            VStack(alignment: .trailing, spacing: 4) {
                Text(agent.status.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(agent.status.color)

                Text(agent.timeAgo)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Agent Detail

struct AgentDetailView: View {
    @Environment(\.dismiss) var dismiss
    let agent: Agent

    var body: some View {
        NavigationStack {
            List {
                Section("Status") {
                    HStack {
                        Image(systemName: agent.status.icon)
                            .foregroundStyle(agent.status.color)
                        Text(agent.status.displayName)
                            .foregroundStyle(agent.status.color)
                    }
                }

                Section("Information") {
                    LabeledContent("ID", value: agent.id.prefix(8).description)
                    LabeledContent("Started", value: agent.startedAt.formatted())
                    LabeledContent("Updated", value: agent.updatedAt.formatted())

                    if let externalId = agent.externalId {
                        LabeledContent("External ID", value: externalId.prefix(8).description)
                    }
                }

                if let message = agent.lastMessage {
                    Section("Last Message") {
                        Text(message)
                            .font(.system(.body, design: .monospaced))
                    }
                }

                if let event = agent.lastEvent {
                    Section("Last Event") {
                        Text(event)
                            .font(.system(.body, design: .monospaced))
                    }
                }
            }
            .navigationTitle(agent.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    DashboardView()
        .environmentObject(AppState())
        .preferredColorScheme(.dark)
}
