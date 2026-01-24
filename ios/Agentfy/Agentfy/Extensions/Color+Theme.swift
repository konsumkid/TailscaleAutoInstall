import SwiftUI

extension Color {
    // MARK: - Background Colors
    static let background = Color(hex: "0D0D0D")
    static let surface = Color(hex: "1A1A1A")
    static let surfaceElevated = Color(hex: "252525")

    // MARK: - Accent Colors
    static let accent = Color(hex: "00D4AA")
    static let accentDark = Color(hex: "00A88A")

    // MARK: - Status Colors
    static let statusRunning = Color.blue
    static let statusAwaiting = Color.orange
    static let statusCompleted = Color.green
    static let statusError = Color.red
    static let statusIdle = Color.gray

    // MARK: - Text Colors
    static let textPrimary = Color.white
    static let textSecondary = Color(hex: "888888")
    static let textTertiary = Color(hex: "555555")

    // MARK: - Initializer
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - View Modifiers

extension View {
    func cardStyle() -> some View {
        self
            .padding()
            .background(Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    func accentBorder() -> some View {
        self
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.accent.opacity(0.3), lineWidth: 1)
            )
    }
}
