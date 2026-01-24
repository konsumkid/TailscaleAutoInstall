import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(Int)
    case decodingError
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid server response"
        case .serverError(let code):
            return "Server error: \(code)"
        case .decodingError:
            return "Failed to decode response"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

actor APIService {
    static let shared = APIService()

    private let baseURL: String
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    private init() {
        // Default to localhost for development
        // In production, this should be your deployed backend URL
        self.baseURL = ProcessInfo.processInfo.environment["API_BASE_URL"]
            ?? "https://agentfy-api.example.com"

        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601

        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
    }

    // MARK: - Device Registration

    func registerDevice(pushToken: String) async -> DeviceRegistrationResponse? {
        let url = "\(baseURL)/api/devices/register"

        let body: [String: Any] = [
            "pushToken": pushToken,
            "platform": "ios",
            "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        ]

        do {
            let response: DeviceRegistrationResponse = try await post(url: url, body: body)

            // Save to UserDefaults
            await MainActor.run {
                UserDefaults.standard.set(response.id, forKey: "deviceId")
                UserDefaults.standard.set(response.webhookToken, forKey: "webhookToken")
                UserDefaults.standard.set(response.webhookUrl, forKey: "webhookUrl")
            }

            return response
        } catch {
            print("Failed to register device: \(error)")
            return nil
        }
    }

    // MARK: - Agents

    func fetchAgents(webhookToken: String) async throws -> [Agent] {
        let url = "\(baseURL)/api/agents/by-token/\(webhookToken)"
        let response: AgentsResponse = try await get(url: url)
        return response.agents
    }

    func deleteAgent(id: String) async throws {
        let url = "\(baseURL)/api/agents/\(id)"
        let _: DeleteResponse = try await delete(url: url)
    }

    func clearAllAgents(deviceId: String) async throws {
        let url = "\(baseURL)/api/agents/by-device/\(deviceId)/all"
        let _: ClearResponse = try await delete(url: url)
    }

    // MARK: - HTTP Methods

    private func get<T: Decodable>(url: String) async throws -> T {
        guard let url = URL(string: url) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        return try await perform(request: request)
    }

    private func post<T: Decodable>(url: String, body: [String: Any]) async throws -> T {
        guard let url = URL(string: url) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        return try await perform(request: request)
    }

    private func delete<T: Decodable>(url: String) async throws -> T {
        guard let url = URL(string: url) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        return try await perform(request: request)
    }

    private func perform<T: Decodable>(request: URLRequest) async throws -> T {
        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                throw APIError.serverError(httpResponse.statusCode)
            }

            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                print("Decoding error: \(error)")
                throw APIError.decodingError
            }
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error)
        }
    }
}
