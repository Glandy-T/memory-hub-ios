import SwiftUI
import UIKit

enum MHTheme {
    static let accent = Color(hex: "5C8CFF")
    static let cyan = Color(hex: "41C7BE")
    static let violet = Color(hex: "8F7CF6")
    static let coral = Color(hex: "FF6E67")
    static let warning = Color(hex: "FFC94A")

    static let pageBackground = Color(light: "F6F8FC", dark: "0B1423")
    static let raisedBackground = Color(light: "FFFFFF", dark: "132238")
    static let fieldBackground = Color(light: "EAF0F8", dark: "1C2D47")
    static let primaryText = Color(light: "152238", dark: "DCE7F7")
    static let secondaryText = Color(light: "66758B", dark: "8799B4")
    static let hairline = Color(light: "DCE4EE", dark: "22344D")

    static let pagePadding: CGFloat = 20
    static let cardRadius: CGFloat = 20
    static let controlRadius: CGFloat = 14
}

extension Color {
    init(light: String, dark: String) {
        self.init(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }

    init(hex: String) {
        self.init(uiColor: UIColor(hex: hex))
    }
}

extension UIColor {
    convenience init(hex: String) {
        let value = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var integer: UInt64 = 0
        Scanner(string: value).scanHexInt64(&integer)
        let red, green, blue, alpha: UInt64
        switch value.count {
        case 8:
            (red, green, blue, alpha) = (integer >> 24, integer >> 16 & 0xFF, integer >> 8 & 0xFF, integer & 0xFF)
        default:
            (red, green, blue, alpha) = (integer >> 16, integer >> 8 & 0xFF, integer & 0xFF, 0xFF)
        }
        self.init(
            red: CGFloat(red) / 255,
            green: CGFloat(green) / 255,
            blue: CGFloat(blue) / 255,
            alpha: CGFloat(alpha) / 255
        )
    }
}

struct PageBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(MHTheme.pageBackground.ignoresSafeArea())
            .foregroundStyle(MHTheme.primaryText)
    }
}

private struct MemoryHubGlassCard: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(MHTheme.raisedBackground.opacity(colorScheme == .light ? 0.64 : 0.42))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(MHTheme.hairline.opacity(0.8), lineWidth: 0.75)
                }
            }
    }
}

extension View {
    func memoryHubPage() -> some View { modifier(PageBackground()) }

    func memoryHubGlassCard(cornerRadius: CGFloat = MHTheme.cardRadius) -> some View {
        modifier(MemoryHubGlassCard(cornerRadius: cornerRadius))
    }
}
