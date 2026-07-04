import SwiftUI

struct PostCardView: View {
    let post: PostDto
    var isDetail = false
    var onVote: (Int) -> Void
    var onPollVote: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(post.channel.nameJa)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                if post.isMine {
                    Text("自分")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Theme.pill)
                        .foregroundStyle(Theme.secondaryText)
                        .clipShape(Capsule())
                }
                Spacer()
                Text(TimeAgo.string(from: post.createdAt))
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
            }

            Text(post.text)
                .font(.system(size: isDetail ? 18 : 16.5))
                .foregroundStyle(Theme.text)
                .multilineTextAlignment(.leading)
                .lineSpacing(4)
                .lineLimit(isDetail ? nil : 10)
                .fixedSize(horizontal: false, vertical: true)

            if let imageUrl = post.imageUrl, let url = APIClient.shared.imageURL(for: imageUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        Color.clear
                    default:
                        Rectangle().fill(Theme.background).overlay(ProgressView())
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            if let poll = post.poll {
                PollView(poll: poll, onVote: onPollVote)
            }

            HStack(spacing: 6) {
                Image(systemName: "bubble.left")
                    .font(.subheadline)
                Text("\(post.commentCount)")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                VotePill(score: post.score, myVote: post.myVote, onVote: onVote)
            }
            .foregroundStyle(Theme.secondaryText)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}

// Horizontal chevron vote pill, Sidechat-style.
struct VotePill: View {
    let score: Int
    let myVote: Int
    var onVote: (Int) -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button { onVote(1) } label: {
                Image(systemName: "chevron.up")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(myVote == 1 ? Theme.upvote : Theme.secondaryText)
            }
            .buttonStyle(.plain)

            Text("\(score)")
                .font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundStyle(scoreColor)
                .frame(minWidth: 18)

            Button { onVote(-1) } label: {
                Image(systemName: "chevron.down")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(myVote == -1 ? Theme.downvote : Theme.secondaryText)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Theme.pill)
        .clipShape(Capsule())
    }

    private var scoreColor: Color {
        if myVote == 1 { return Theme.upvote }
        if myVote == -1 { return Theme.downvote }
        return Theme.text
    }
}

// Compact avatar used only where identity matters (comments, notifications).
struct AliasAvatar: View {
    let emoji: String
    var size: CGFloat = 30
    var colorKey: String = ""

    var body: some View {
        Text(emoji)
            .font(.system(size: size * 0.55))
            .frame(width: size, height: size)
            .background(Theme.avatarColor(for: colorKey.isEmpty ? emoji : colorKey))
            .clipShape(Circle())
    }
}

// Kept for call-site compatibility in the detail view.
struct VoteControl: View {
    let score: Int
    let myVote: Int
    var onVote: (Int) -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button { onVote(1) } label: {
                Image(systemName: "chevron.up")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(myVote == 1 ? Theme.upvote : Theme.secondaryText)
            }
            .buttonStyle(.plain)
            Text("\(score)")
                .font(.footnote.weight(.bold).monospacedDigit())
                .foregroundStyle(myVote == 1 ? Theme.upvote : (myVote == -1 ? Theme.downvote : Theme.secondaryText))
                .frame(minWidth: 14)
            Button { onVote(-1) } label: {
                Image(systemName: "chevron.down")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(myVote == -1 ? Theme.downvote : Theme.secondaryText)
            }
            .buttonStyle(.plain)
        }
    }
}

struct PollView: View {
    let poll: PollDto
    var onVote: (String) -> Void

    private var hasVoted: Bool { poll.myOptionId != nil }

    var body: some View {
        VStack(spacing: 8) {
            ForEach(poll.options) { option in
                Button {
                    onVote(option.id)
                } label: {
                    optionRow(option)
                }
                .buttonStyle(.plain)
            }
            Text("\(poll.totalVotes)票")
                .font(.caption)
                .foregroundStyle(Theme.secondaryText)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private func optionRow(_ option: PollOptionDto) -> some View {
        let fraction = poll.totalVotes > 0 ? Double(option.voteCount) / Double(poll.totalVotes) : 0
        let isMine = poll.myOptionId == option.id

        return ZStack(alignment: .leading) {
            GeometryReader { proxy in
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isMine ? Theme.accent.opacity(0.22) : Theme.pill)
                    .frame(width: hasVoted ? max(proxy.size.width * fraction, 4) : 0)
                    .animation(.easeOut(duration: 0.3), value: fraction)
            }
            HStack {
                Text(option.text)
                    .font(.footnote.weight(isMine ? .bold : .medium))
                    .foregroundStyle(Theme.text)
                Spacer()
                if hasVoted {
                    Text("\(Int((fraction * 100).rounded()))%")
                        .font(.footnote.weight(.semibold).monospacedDigit())
                        .foregroundStyle(isMine ? Theme.accent : Theme.secondaryText)
                }
                if isMine {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.footnote)
                        .foregroundStyle(Theme.accent)
                }
            }
            .padding(.horizontal, 12)
        }
        .frame(height: 40)
        .background(Theme.background.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isMine ? Theme.accent.opacity(0.5) : Theme.cardBorder, lineWidth: 1)
        )
    }
}
