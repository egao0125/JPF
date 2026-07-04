import SwiftUI

// Sidechat-style palette: light gray canvas, white cards, one vivid blue.
enum Theme {
    static let background = Color(red: 0.949, green: 0.953, blue: 0.965)   // #F2F3F6
    static let card = Color.white
    static let cardBorder = Color(red: 0.898, green: 0.906, blue: 0.922)   // #E5E7EB — hairlines only where needed
    static let text = Color(red: 0.090, green: 0.102, blue: 0.125)         // #171A20
    static let accent = Color(red: 0.239, green: 0.427, blue: 0.961)       // #3D6DF5
    static let accentPink = Color(red: 0.239, green: 0.427, blue: 0.961)   // legacy alias — accent
    static let secondaryText = Color(red: 0.549, green: 0.573, blue: 0.604) // #8C929A
    static let error = Color(red: 0.937, green: 0.267, blue: 0.267)        // #EF4444
    static let upvote = Color(red: 0.239, green: 0.427, blue: 0.961)       // blue
    static let downvote = Color(red: 0.937, green: 0.353, blue: 0.239)     // #EF5A3D
    static let pill = Color(red: 0.949, green: 0.953, blue: 0.965)         // vote pill / control fills

    // Flat brand blue; kept as a gradient type so button call sites don't change.
    static var gradient: LinearGradient {
        LinearGradient(
            colors: [accent, Color(red: 0.196, green: 0.365, blue: 0.878)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // Stable pastel for comment avatars, derived from the alias.
    static let avatarPalette: [Color] = [
        Color(red: 0.85, green: 0.91, blue: 1.0),   // pale blue
        Color(red: 1.0, green: 0.88, blue: 0.90),   // pale pink
        Color(red: 1.0, green: 0.93, blue: 0.82),   // pale orange
        Color(red: 0.87, green: 0.96, blue: 0.87),  // pale green
        Color(red: 0.93, green: 0.89, blue: 1.0),   // pale purple
        Color(red: 0.84, green: 0.96, blue: 0.95),  // pale teal
    ]

    static func avatarColor(for key: String) -> Color {
        var hash = 0
        for scalar in key.unicodeScalars { hash = (hash &* 31 &+ Int(scalar.value)) }
        return avatarPalette[abs(hash) % avatarPalette.count]
    }
}

extension View {
    func cardStyle() -> some View {
        self
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: .black.opacity(0.05), radius: 10, y: 3)
    }
}

enum TimeAgo {
    private static let formatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.unitsStyle = .abbreviated
        return f
    }()

    static func string(from date: Date) -> String {
        let seconds = -date.timeIntervalSinceNow
        if seconds < 60 { return "たった今" }
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
