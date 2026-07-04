import SwiftUI

// X monochrome palette: black surfaces, white actions (black text on white buttons).
// Red is reserved for errors/destructive, matching X.
enum Theme {
    static let background = Color.black                                      // #000000
    static let card = Color.black                                            // flat black — hairline borders do the separation
    static let cardBorder = Color(red: 0.184, green: 0.200, blue: 0.212)     // #2F3336
    static let accent = Color.white
    static let accentPink = Color.white                                      // badges/dots — monochrome
    static let secondaryText = Color(red: 0.443, green: 0.463, blue: 0.482)  // #71767B
    static let error = Color(red: 0.957, green: 0.129, blue: 0.180)          // #F4212E
    static let upvote = Color.white
    static let downvote = Color.white

    // Kept as a gradient type so call sites don't change; #EFF3F4 → #E7E9EA reads flat
    // like X's white primary buttons.
    static var gradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.937, green: 0.953, blue: 0.957),
                Color(red: 0.906, green: 0.914, blue: 0.918),
            ],
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
