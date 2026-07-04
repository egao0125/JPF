import SwiftUI

// X default (light) palette: white surfaces, black text, black primary buttons.
// Red is reserved for errors/destructive, matching X.
enum Theme {
    static let background = Color.white
    static let card = Color.white                                            // hairline borders do the separation
    static let cardBorder = Color(red: 0.812, green: 0.851, blue: 0.871)     // #CFD9DE
    static let text = Color(red: 0.059, green: 0.078, blue: 0.098)           // #0F1419
    static let accent = Color(red: 0.059, green: 0.078, blue: 0.098)         // #0F1419 — black actions
    static let accentPink = Color(red: 0.059, green: 0.078, blue: 0.098)     // badges/dots — monochrome
    static let secondaryText = Color(red: 0.325, green: 0.392, blue: 0.443)  // #536471
    static let error = Color(red: 0.957, green: 0.129, blue: 0.180)          // #F4212E
    static let upvote = Color(red: 0.059, green: 0.078, blue: 0.098)
    static let downvote = Color(red: 0.059, green: 0.078, blue: 0.098)

    // Kept as a gradient type so call sites don't change; #0F1419 → #272C30 reads flat
    // like X's black primary buttons.
    static var gradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.059, green: 0.078, blue: 0.098),
                Color(red: 0.153, green: 0.173, blue: 0.188),
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
