import SwiftUI

enum Theme {
    static let background = Color(red: 0.059, green: 0.059, blue: 0.078) // #0F0F14
    static let card = Color(red: 0.102, green: 0.102, blue: 0.133) // #1A1A22
    static let cardBorder = Color(red: 0.173, green: 0.173, blue: 0.204) // #2C2C34
    static let accent = Color(red: 0.655, green: 0.545, blue: 0.980) // #A78BFA
    static let accentPink = Color(red: 0.957, green: 0.447, blue: 0.714) // #F472B6
    static let secondaryText = Color(red: 0.557, green: 0.557, blue: 0.576) // #8E8E93
    static let upvote = Color(red: 0.957, green: 0.447, blue: 0.714)
    static let downvote = Color(red: 0.42, green: 0.55, blue: 0.98)

    static var gradient: LinearGradient {
        LinearGradient(colors: [accent, accentPink], startPoint: .topLeading, endPoint: .bottomTrailing)
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
