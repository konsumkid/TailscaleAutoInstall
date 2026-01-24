import SwiftUI
import Combine

@MainActor
class AppState: ObservableObject {
    @Published var isOnboarded: Bool
    @Published var deviceId: String?
    @Published var webhookToken: String?
    @Published var webhookUrl: String?
    @Published var agents: [Agent] = []
    @Published var isLoading: Bool = false
    @Published var error: String?

    private var refreshTimer: Timer?
    private let userDefaults = UserDefaults.standard

    init() {
        self.isOnboarded = userDefaults.bool(forKey: "isOnboarded")
        self.deviceId = userDefaults.string(forKey: "deviceId")
        self.webhookToken = userDefaults.string(forKey: "webhookToken")
        self.webhookUrl = userDefaults.string(forKey: "webhookUrl")

        if isOnboarded {
            startAutoRefresh()
        }
    }

    func completeOnboarding(deviceId: String, webhookToken: String, webhookUrl: String) {
        self.deviceId = deviceId
        self.webhookToken = webhookToken
        self.webhookUrl = webhookUrl
        self.isOnboarded = true

        userDefaults.set(true, forKey: "isOnboarded")
        userDefaults.set(deviceId, forKey: "deviceId")
        userDefaults.set(webhookToken, forKey: "webhookToken")
        userDefaults.set(webhookUrl, forKey: "webhookUrl")

        startAutoRefresh()
    }

    func logout() {
        stopAutoRefresh()

        self.isOnboarded = false
        self.deviceId = nil
        self.webhookToken = nil
        self.webhookUrl = nil
        self.agents = []

        userDefaults.removeObject(forKey: "isOnboarded")
        userDefaults.removeObject(forKey: "deviceId")
        userDefaults.removeObject(forKey: "webhookToken")
        userDefaults.removeObject(forKey: "webhookUrl")
    }

    func refreshAgents() async {
        guard let webhookToken = webhookToken else { return }

        isLoading = true
        error = nil

        do {
            agents = try await APIService.shared.fetchAgents(webhookToken: webhookToken)
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func deleteAgent(_ agent: Agent) async {
        do {
            try await APIService.shared.deleteAgent(id: agent.id)
            agents.removeAll { $0.id == agent.id }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func clearAllAgents() async {
        guard let deviceId = deviceId else { return }

        do {
            try await APIService.shared.clearAllAgents(deviceId: deviceId)
            agents = []
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func startAutoRefresh() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refreshAgents()
            }
        }
    }

    private func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}
