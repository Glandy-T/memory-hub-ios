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

                        GeometryReader { geometry in
                            let width = geometry.size.width
                            let height = geometry.size.height

                            Ellipse()
                                .fill(MHTheme.violet.opacity(0.12))
                                .frame(width: width * 0.75, height: height * 0.23)
                                .blur(radius: 64)
                                .offset(x: width * 0.48, y: -height * 0.06)

                            Ellipse()
                                .fill(MHTheme.cyan.opacity(0.08))
                                .frame(width: width * 0.68, height: height * 0.24)
                                .blur(radius: 72)
                                .offset(x: -width * 0.32, y: height * 0.38)

                            Ellipse()
                                .fill(MHTheme.accent.opacity(0.08))
                                .frame(width: width * 0.76, height: height * 0.24)
                                .blur(radius: 78)
                                .offset(x: width * 0.20, y: height * 0.70)
                        }

                        Image("LightPigmentBackground")
                            .resizable()
                            .scaledToFill()
                            .saturation(0)
                            .contrast(1.08)
                            .opacity(0.04)
                            .blendMode(.screen)
                    }
                }
                .ignoresSafeArea()
                .accessibilityHidden(true)
            }
            .foregroundStyle(MHTheme.primaryText)
    }
}

enum MemoryHubGlassStyle: Equatable {
    case compact
    case standard
    case hero

    func tintOpacity(for colorScheme: ColorScheme) -> Double {
        switch (self, colorScheme) {
        case (.compact, .dark): 0.06
        case (.standard, .dark): 0.045
        case (.hero, .dark): 0.02
        case (.compact, .light): 0.028
        case (.standard, .light): 0.02
        case (.hero, .light): 0.01
        default: 0.02
        }
    }

    func materialOpacity(for colorScheme: ColorScheme) -> Double {
        switch (self, colorScheme) {
        case (.compact, .dark): 0.66
        case (.standard, .dark): 0.62
        case (.hero, .dark): 0.55
        case (.compact, .light): 0.88
        case (.standard, .light): 0.86
        case (.hero, .light): 0.80
        default: 0.74
        }
    }

    func highlightOpacity(for colorScheme: ColorScheme) -> Double {
        switch (self, colorScheme) {
        case (.compact, .dark): 0.12
        case (.standard, .dark): 0.09
        case (.hero, .dark): 0.07
        case (.compact, .light): 0.12
        case (.standard, .light): 0.10
        case (.hero, .light): 0.075
        default: 0.09
        }
    }

    func borderOpacity(for colorScheme: ColorScheme) -> Double {
        switch (self, colorScheme) {
        case (.compact, .dark): 0.26
        case (.standard, .dark): 0.22
        case (.hero, .dark): 0.18
        case (.compact, .light): 0.56
        case (.standard, .light): 0.50
        case (.hero, .light): 0.42
        default: 0.3
        }
    }

    func shadowOpacity(for colorScheme: ColorScheme) -> Double {
        switch (self, colorScheme) {
        case (.compact, .dark): 0.14
        case (.standard, .dark): 0.12
        case (.hero, .dark): 0.10
        case (.compact, .light): 0.045
        case (.standard, .light): 0.04
        case (.hero, .light): 0.035
        default: 0.06
        }
    }
}

private struct MemoryHubGlassCard: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    let cornerRadius: CGFloat
    let style: MemoryHubGlassStyle

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .opacity(style.materialOpacity(for: colorScheme))
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(
                                colorScheme == .dark
                                    ? Color(hex: "304763").opacity(style.tintOpacity(for: colorScheme))
                                    : Color.white.opacity(style.tintOpacity(for: colorScheme))
                            )
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(style.highlightOpacity(for: colorScheme)),
                                        Color.clear,
                                        Color.white.opacity(style.highlightOpacity(for: colorScheme) * 0.24)
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
                                    Color.white.opacity(style.borderOpacity(for: colorScheme)),
                                    MHTheme.hairline.opacity(0.18),
                                    Color.white.opacity(style.borderOpacity(for: colorScheme) * 0.22)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
                .shadow(
                    color: Color.black.opacity(style.shadowOpacity(for: colorScheme)),
                    radius: style == .hero ? 9 : 5,
                    y: style == .hero ? 6 : 3
                )
            }
    }
}

extension View {
    func memoryHubPage() -> some View { modifier(PageBackground()) }

    func memoryHubGlassCard(
        cornerRadius: CGFloat = MHTheme.cardRadius,
        style: MemoryHubGlassStyle = .standard
    ) -> some View {
        modifier(MemoryHubGlassCard(cornerRadius: cornerRadius, style: style))
    }
}
