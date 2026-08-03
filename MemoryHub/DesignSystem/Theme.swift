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
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    MHTheme.pageBackground

                    if colorScheme == .light {
                        Image("LightPigmentBackground")
                            .resizable()
                            .scaledToFill()
                            .opacity(0.46)
                    } else {
                        Color(hex: "111925")

                        RadialGradient(
                            colors: [MHTheme.violet.opacity(0.16), Color.clear],
                            center: .topTrailing,
                            startRadius: 0,
                            endRadius: 340
                        )

                        RadialGradient(
                            colors: [MHTheme.cyan.opacity(0.075), Color.clear],
                            center: UnitPoint(x: 0, y: 0.54),
                            startRadius: 0,
                            endRadius: 310
                        )

                        RadialGradient(
                            colors: [MHTheme.accent.opacity(0.09), Color.clear],
                            center: UnitPoint(x: 0.72, y: 1.04),
                            startRadius: 0,
                            endRadius: 330
                        )
                    }
                }
                .ignoresSafeArea()
                .accessibilityHidden(true)
            }
            .foregroundStyle(MHTheme.primaryText)
    }
}

private struct MemoryHubGlassCard: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(
                                colorScheme == .dark
                                    ? Color(hex: "304763").opacity(0.22)
                                    : Color.white.opacity(0.035)
                            )
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(colorScheme == .light ? 0.1 : 0.035),
                                        Color.clear,
                                        Color.white.opacity(colorScheme == .light ? 0.025 : 0.015)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(colorScheme == .light ? 0.58 : 0.18),
                                    MHTheme.hairline.opacity(0.24),
                                    Color.white.opacity(colorScheme == .light ? 0.12 : 0.06)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
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
