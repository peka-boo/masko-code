import SwiftUI

enum Constants {
    private static let serverPortKey = "serverPort"

    // Web links (opened in browser)
    #if DEBUG
    static let maskoBaseURL = "http://localhost:3000"
    #else
    static let maskoBaseURL = "https://masko.ai"
    #endif
    static let githubRepoURL = "https://github.com/RousselPaul/masko-code"

    // Local hook server
    static let legacyDefaultServerPort: UInt16 = 49152
    static let defaultServerPort: UInt16 = 45832
    static var serverPort: UInt16 {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: serverPortKey) != nil else {
            return defaultServerPort
        }

        let stored = defaults.integer(forKey: serverPortKey)
        if stored == Int(legacyDefaultServerPort) {
            defaults.set(Int(defaultServerPort), forKey: serverPortKey)
            return defaultServerPort
        }
        return stored > 0 ? UInt16(stored) : defaultServerPort
    }
    static func setServerPort(_ port: UInt16) {
        UserDefaults.standard.set(Int(port), forKey: serverPortKey)
    }

    // Brand colors — Electric Violet dark theme
    static let orangePrimary = Color(red: 139/255, green: 92/255, blue: 246/255)      // #8B5CF6
    static let orangeHover = Color(red: 167/255, green: 139/255, blue: 250/255)       // #A78BFA
    static let orangeShadow = Color(red: 109/255, green: 40/255, blue: 217/255)       // #6D28D9
    static let textPrimary = Color(red: 230/255, green: 237/255, blue: 243/255)       // #e6edf3
    static let textMuted = Color(red: 125/255, green: 133/255, blue: 144/255)         // #7d8590
    static let darkBackground = Color(red: 10/255, green: 10/255, blue: 15/255)       // #0a0a0f
    static let lightBackground = darkBackground                                        // alias for compatibility
    static let surfaceWhite = Color(red: 18/255, green: 18/255, blue: 26/255)         // #12121a
    static let surfaceDark = Color(red: 10/255, green: 10/255, blue: 15/255)          // #0a0a0f
    static let surfaceElevated = Color(red: 26/255, green: 26/255, blue: 36/255)      // #1a1a24
    static let border = Color.white.opacity(0.08)                                      // subtle border
    static let borderHover = Color.white.opacity(0.14)

    // Interactive state colors
    static let chip = Color(red: 139/255, green: 92/255, blue: 246/255).opacity(0.08)             // violet hover bg
    static let stage = Color.white.opacity(0.03)                                                   // subtle hover
    static let orangePrimaryLight = Color(red: 139/255, green: 92/255, blue: 246/255).opacity(0.12) // active item bg
    static let orangePrimarySubtle = Color(red: 139/255, green: 92/255, blue: 246/255).opacity(0.08) // selected row bg
    static let destructiveRed = Color(red: 248/255, green: 81/255, blue: 73/255)                   // #f85149

    // MARK: - Typography (Apple HIG system fonts)

    /// System font — headings, buttons, display text
    static func heading(size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    /// System font — body text, labels, metadata
    static func body(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    // Named text styles following SF Pro sizing
    static let fontTitle = Font.title2           // 17pt — section headers
    static let fontHeadline = Font.headline       // 13pt semibold — card titles
    static let fontBody = Font.body              // 13pt regular
    static let fontCallout = Font.callout        // 12pt — secondary info
    static let fontSubheadline = Font.subheadline // 11pt — badges, labels
    static let fontFootnote = Font.footnote      // 10pt — timestamps, captions

    // MARK: - Layout (macOS HIG corner radii)

    static let cornerRadius: CGFloat = 10       // cards, groups
    static let cornerRadiusSmall: CGFloat = 6   // buttons, small cards
    static let cornerRadiusTiny: CGFloat = 4    // badges, chips

    // MARK: - Spacing (Apple 8pt grid)

    static let spacingTight: CGFloat = 8        // between tightly related items
    static let spacingNormal: CGFloat = 12      // standard item spacing
    static let spacingLoose: CGFloat = 16       // relaxed spacing
    static let spacingSection: CGFloat = 24     // section separators
    static let contentPaddingH: CGFloat = 20    // horizontal content padding
    static let contentPaddingV: CGFloat = 16    // vertical content padding

    // MARK: - Shadows (subtle, macOS style)

    /// Default card shadow
    static let cardShadowColor = Color.black.opacity(0.25)
    static let cardShadowRadius: CGFloat = 1
    static let cardShadowY: CGFloat = 0.5

    /// Hover card shadow
    static let cardHoverShadowColor = Color.black.opacity(0.35)
    static let cardHoverShadowRadius: CGFloat = 4
    static let cardHoverShadowY: CGFloat = 2

    // MARK: - Gradients

    /// Feature card violet tint gradient
    static let featureCardGradient = LinearGradient(
        colors: [
            Color(red: 139/255, green: 92/255, blue: 246/255).opacity(0.10),
            Color(red: 167/255, green: 139/255, blue: 250/255).opacity(0.05)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
