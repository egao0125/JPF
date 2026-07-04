import SwiftUI

// X (Twitter) "Lights out" palette.
enum Theme {
    static let background = Color.black                                      // #000000
    static let card = Color.black                                            // flat black — hairline borders do the separation
    static let cardBorder = Color(red: 0.184, green: 0.200, blue: 0.212)     // #2F3336
    static let accent = Color(red: 0.114, green: 0.608, blue: 0.941)         // #1D9BF0 X blue
    static let accentPink = Color(red: 0.976, green: 0.094, blue: 0.502)     // #F91880 like-pink
    static let secondaryText = Color(red: 0.443, green: 0.463, blue: 0.482)  // #71767B
    static let error = Color(red: 0.957, green: 0.129, blue: 0.180)          // #F4212E
    static let upvote = Color(red: 0.114, green: 0.608, blue: 0.941)         // X blue
    static let downvote = Color(red: 0.957, green: 0.129, blue: 0.180)       // #F4212E

    // Kept as a gradient type so call sites don't change; #1D9BF0 → #1A8CD8 reads flat like X buttons.
    static var gradient: LinearGradient {
        LinearGradient(
            colors: [accent, Color(red: 0.102, green: 0.549, blue: 0.847)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

extension View {
    func cardStyle() -> some View {
        self
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Theme.cardBorder, lineWidth: 1)
            )
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
