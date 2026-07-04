import SwiftUI

struct PostCardView: View {
    let post: PostDto
    var isDetail = false
    var onVote: (Int) -> Void
    var onPollVote: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            Text(post.text)
                .font(isDetail ? .body : .subheadline)
                .foregroundStyle(Theme.text)
                .multilineTextAlignment(.leading)
                .lineLimit(isDetail ? nil : 8)
                .fixedSize(horizontal: false, vertical: true)

            if let imageUrl = post.imageUrl, let url = APIClient.shared.imageURL(for: imageUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        Color.clear
                    default:
                        Rectangle().fill(Theme.cardBorder.opacity(0.4)).overlay(ProgressView())
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            if let poll = post.poll {
                PollView(poll: poll, onVote: onPollVote)
            }

            footer
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private var header: some View {
        HStack(spacing: 10) {
            AliasAvatar(emoji: post.emoji)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(post.alias)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.text)
                    if post.isMine {
                        Text("あなた")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Theme.accent.opacity(0.2))
                            .foregroundStyle(Theme.accent)
                            .clipShape(Capsule())
                    }
                }
                Text("\(post.channel.emoji) \(post.channel.nameJa) ・ \(TimeAgo.string(from: post.createdAt))")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
            }
            Spacer()
        }
    }

    private var footer: some View {
        HStack(spacing: 20) {
            VoteControl(score: post.score, myVote: post.myVote, onVote: onVote)
            HStack(spacing: 5) {
                Image(systemName: "bubble.right")
                    .font(.footnote)
                Text("\(post.commentCount)")
                    .font(.footnote.weight(.medium))
            }
            .foregroundStyle(Theme.secondaryText)
            Spacer()
        }
    }
}

struct AliasAvatar: View {
    let emoji: String
    var size: CGFloat = 38

    var body: some View {
        Text(emoji)
            .font(.system(size: size * 0.55))
            .frame(width: size, height: size)
            .background(Theme.cardBorder.opacity(0.6))
            .clipShape(Circle())
    }
}

struct VoteControl: View {
    let score: Int
    let myVote: Int
    var onVote: (Int) -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button { onVote(1) } label: {
                Image(systemName: myVote == 1 ? "arrow.up.circle.fill" : "arrow.up.circle")
                    .font(.title3)
                    .foregroundStyle(myVote == 1 ? Theme.upvote : Theme.secondaryText)
            }
            .buttonStyle(.plain)

            Text("\(score)")
                .font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundStyle(scoreColor)
                .frame(minWidth: 24)

            Button { onVote(-1) } label: {
                Image(systemName: myVote == -1 ? "arrow.down.circle.fill" : "arrow.down.circle")
                    .font(.title3)
                    .foregroundStyle(myVote == -1 ? Theme.downvote : Theme.secondaryText)
            }
            .buttonStyle(.plain)
        }
    }

    private var scoreColor: Color {
        if myVote == 1 { return Theme.upvote }
        if myVote == -1 { return Theme.downvote }
        return Theme.text
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
                    .fill(isMine ? Theme.accent.opacity(0.35) : Theme.cardBorder.opacity(0.5))
                    .frame(width: hasVoted ? max(proxy.size.width * fraction, 4) : 0)
                    .animation(.easeOut(duration: 0.3), value: fraction)
            }
            HStack {
                Text(option.text)
                    .font(.footnote.weight(isMine ? .bold : .regular))
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
        .background(Theme.background.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isMine ? Theme.accent.opacity(0.6) : Theme.cardBorder, lineWidth: 1)
        )
    }
}
