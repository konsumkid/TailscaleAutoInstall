import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingClearConfirmation = false
    @State private var showingLogoutConfirmation = false
    @State private var copied = false

    var body: some View {
        NavigationStack {
            List {
                // Webhook Section
                Section {
                    if let webhookUrl = appState.webhookUrl {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Your Webhook URL")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text(webhookUrl)
                                .font(.system(.caption, design: .monospaced))
                                .lineLimit(2)
                        }
                        .padding(.vertical, 4)

                        Button {
                            UIPasteboard.general.string = webhookUrl
                            copied = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                copied = false
                            }
                        } label: {
                            Label(copied ? "Copied!" : "Copy Webhook URL", systemImage: copied ? "checkmark" : "doc.on.doc")
                        }
                        .tint(copied ? .green : .accent)
                    }
                } header: {
                    Text("Webhook")
                } footer: {
                    Text("Use this URL to configure your Claude Code hooks for real-time monitoring.")
                }

                // Agent Management
                Section("Agents") {
                    HStack {
                        Text("Total Agents")
                        Spacer()
                        Text("\(appState.agents.count)")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Active")
                        Spacer()
                        Text("\(appState.agents.filter { $0.status.isActive }.count)")
                            .foregroundStyle(.blue)
                    }

                    Button(role: .destructive) {
                        showingClearConfirmation = true
                    } label: {
                        Label("Clear All Agents", systemImage: "trash")
                    }
                    .disabled(appState.agents.isEmpty)
                }

                // Notifications
                Section("Notifications") {
                    NavigationLink {
                        NotificationSettingsView()
                    } label: {
                        Label("Notification Settings", systemImage: "bell.badge")
                    }
                }

                // About
                Section("About") {
                    LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    LabeledContent("Build", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")

                    Link(destination: URL(string: "https://github.com/your-repo/agentfy")!) {
                        Label("Source Code", systemImage: "chevron.left.forwardslash.chevron.right")
                    }

                    Link(destination: URL(string: "https://your-website.com/privacy")!) {
                        Label("Privacy Policy", systemImage: "hand.raised")
                    }
                }

                // Account
                Section {
                    Button(role: .destructive) {
                        showingLogoutConfirmation = true
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .navigationTitle("Settings")
            .confirmationDialog(
                "Clear All Agents",
                isPresented: $showingClearConfirmation,
                titleVisibility: .visible
            ) {
                Button("Clear All", role: .destructive) {
                    Task {
                        await appState.clearAllAgents()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will remove all agents from your dashboard. This action cannot be undone.")
            }
            .confirmationDialog(
                "Sign Out",
                isPresented: $showingLogoutConfirmation,
                titleVisibility: .visible
            ) {
                Button("Sign Out", role: .destructive) {
                    appState.logout()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You will need to set up the webhook again to receive notifications.")
            }
        }
    }
}

// MARK: - Notification Settings

struct NotificationSettingsView: View {
    @State private var notificationsEnabled = true
    @State private var permissionStatus: UNAuthorizationStatus = .notDetermined

    var body: some View {
        List {
            Section {
                HStack {
                    Text("Status")
                    Spacer()
                    Text(permissionStatusText)
                        .foregroundStyle(permissionStatusColor)
                }

                if permissionStatus == .denied {
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                }
            } header: {
                Text("Permission")
            } footer: {
                if permissionStatus == .denied {
                    Text("Notifications are disabled. Enable them in Settings to receive agent updates.")
                }
            }

            Section("Notification Types") {
                Toggle("Task Completed", isOn: .constant(true))
                Toggle("Permission Required", isOn: .constant(true))
                Toggle("Errors", isOn: .constant(true))
                Toggle("Agent Started", isOn: .constant(true))
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            permissionStatus = await NotificationService.shared.checkPermissionStatus()
        }
    }

    var permissionStatusText: String {
        switch permissionStatus {
        case .authorized: return "Enabled"
        case .denied: return "Disabled"
        case .notDetermined: return "Not Set"
        case .provisional: return "Provisional"
        case .ephemeral: return "Ephemeral"
        @unknown default: return "Unknown"
        }
    }

    var permissionStatusColor: Color {
        switch permissionStatus {
        case .authorized, .provisional, .ephemeral: return .green
        case .denied: return .red
        case .notDetermined: return .orange
        @unknown default: return .gray
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState())
        .preferredColorScheme(.dark)
}
