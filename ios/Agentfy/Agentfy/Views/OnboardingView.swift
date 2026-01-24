import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @State private var currentStep = 0
    @State private var isLoading = false
    @State private var generatedWebhookUrl: String?
    @State private var deviceId: String?
    @State private var webhookToken: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress indicator
                HStack(spacing: 8) {
                    ForEach(0..<3) { index in
                        Capsule()
                            .fill(index <= currentStep ? Color.accent : Color.gray.opacity(0.3))
                            .frame(height: 4)
                    }
                }
                .padding(.horizontal)
                .padding(.top)

                TabView(selection: $currentStep) {
                    WelcomeStep()
                        .tag(0)

                    SetupStep(
                        isLoading: $isLoading,
                        webhookUrl: $generatedWebhookUrl,
                        deviceId: $deviceId,
                        webhookToken: $webhookToken
                    )
                    .tag(1)

                    InstructionsStep(webhookUrl: generatedWebhookUrl ?? "")
                        .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Navigation buttons
                HStack {
                    if currentStep > 0 {
                        Button("Back") {
                            withAnimation {
                                currentStep -= 1
                            }
                        }
                        .buttonStyle(.bordered)
                    }

                    Spacer()

                    if currentStep < 2 {
                        Button("Continue") {
                            handleContinue()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(currentStep == 1 && generatedWebhookUrl == nil)
                    } else {
                        Button("Get Started") {
                            completeOnboarding()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
            }
            .background(Color.background)
        }
    }

    private func handleContinue() {
        if currentStep == 0 {
            withAnimation {
                currentStep = 1
            }
            requestNotificationPermission()
        } else {
            withAnimation {
                currentStep += 1
            }
        }
    }

    private func requestNotificationPermission() {
        isLoading = true

        Task {
            let granted = await NotificationService.shared.requestPermission()

            if granted {
                // Generate mock webhook for demo purposes
                // In production, this would be returned by the API after device registration
                let mockToken = UUID().uuidString.lowercased()
                await MainActor.run {
                    self.webhookToken = mockToken
                    self.deviceId = UUID().uuidString
                    self.generatedWebhookUrl = "https://your-api.com/api/webhook/\(mockToken)"
                    self.isLoading = false
                }
            } else {
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }

    private func completeOnboarding() {
        guard let deviceId = deviceId,
              let webhookToken = webhookToken,
              let webhookUrl = generatedWebhookUrl else { return }

        appState.completeOnboarding(
            deviceId: deviceId,
            webhookToken: webhookToken,
            webhookUrl: webhookUrl
        )
    }
}

// MARK: - Welcome Step

struct WelcomeStep: View {
    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "terminal.fill")
                .font(.system(size: 80))
                .foregroundStyle(Color.accent)

            VStack(spacing: 16) {
                Text("Welcome to Agentfy")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Monitor your Claude Code agents in real-time with notifications and Live Activities.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            VStack(alignment: .leading, spacing: 20) {
                FeatureRow(
                    icon: "bell.badge.fill",
                    title: "Push Notifications",
                    description: "Get alerts when agents need input"
                )

                FeatureRow(
                    icon: "rectangle.stack.fill",
                    title: "Live Activities",
                    description: "Track progress on your Lock Screen"
                )

                FeatureRow(
                    icon: "square.grid.2x2.fill",
                    title: "Multi-Agent Dashboard",
                    description: "Monitor all your agents in one place"
                )
            }
            .padding(.horizontal, 32)

            Spacer()
        }
        .padding()
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(Color.accent)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Setup Step

struct SetupStep: View {
    @Binding var isLoading: Bool
    @Binding var webhookUrl: String?
    @Binding var deviceId: String?
    @Binding var webhookToken: String?

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            if isLoading {
                ProgressView()
                    .scaleEffect(1.5)

                Text("Setting up your device...")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            } else if let url = webhookUrl {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.green)

                VStack(spacing: 16) {
                    Text("Device Registered!")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Your webhook URL is ready:")
                        .foregroundStyle(.secondary)

                    WebhookUrlCard(url: url)
                }
            } else {
                Image(systemName: "bell.slash.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.orange)

                VStack(spacing: 16) {
                    Text("Notifications Required")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Please enable notifications to receive agent updates.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }

            Spacer()
        }
        .padding()
    }
}

struct WebhookUrlCard: View {
    let url: String
    @State private var copied = false

    var body: some View {
        VStack(spacing: 12) {
            Text(url)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            Button {
                UIPasteboard.general.string = url
                copied = true

                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    copied = false
                }
            } label: {
                Label(copied ? "Copied!" : "Copy URL", systemImage: copied ? "checkmark" : "doc.on.doc")
            }
            .buttonStyle(.bordered)
            .tint(copied ? .green : .accent)
        }
        .padding()
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Instructions Step

struct InstructionsStep: View {
    let webhookUrl: String

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(Color.accent)

                Text("Setup Claude Code")
                    .font(.title2)
                    .fontWeight(.bold)

                VStack(alignment: .leading, spacing: 24) {
                    InstructionRow(
                        number: "1",
                        title: "Open Claude Code",
                        description: "Launch Claude Code in your terminal"
                    )

                    InstructionRow(
                        number: "2",
                        title: "Configure Hooks",
                        description: "Add the webhook configuration to your hooks settings"
                    )

                    InstructionRow(
                        number: "3",
                        title: "Start Monitoring",
                        description: "Your agents will now appear in the dashboard"
                    )
                }
                .padding(.horizontal)

                // Code example
                VStack(alignment: .leading, spacing: 8) {
                    Text("Hook Configuration:")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    CodeBlock(code: """
                    // Add to your Claude Code hooks
                    {
                      "webhook_url": "\(webhookUrl)"
                    }
                    """)
                }
                .padding(.horizontal)
            }
            .padding()
        }
    }
}

struct InstructionRow: View {
    let number: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Text(number)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(Color.accent)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct CodeBlock: View {
    let code: String
    @State private var copied = false

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            Button {
                UIPasteboard.general.string = code
                copied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    copied = false
                }
            } label: {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(.caption)
            }
            .foregroundStyle(copied ? .green : .secondary)

            Text(code)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AppState())
        .preferredColorScheme(.dark)
}
