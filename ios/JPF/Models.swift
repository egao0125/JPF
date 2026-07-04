import Foundation

struct SchoolDto: Codable, Hashable {
    let id: String
    let name: String
    let shortName: String?
}

struct UserMe: Codable, Hashable {
    let id: String
    let email: String
    var karma: Int
    let isModerator: Bool
    var postCount: Int?
    var commentCount: Int?
    let school: SchoolDto
}

struct ChannelDto: Codable, Hashable, Identifiable {
    let slug: String
    let nameJa: String
    let emoji: String
    var id: String { slug }
}

struct PollOptionDto: Codable, Hashable, Identifiable {
    let id: String
    let text: String
    var voteCount: Int
}

struct PollDto: Codable, Hashable {
    let id: String
    var totalVotes: Int
    var myOptionId: String?
    var options: [PollOptionDto]
}

struct PostDto: Codable, Hashable, Identifiable {
    let id: String
    let text: String
    let imageUrl: String?
    let alias: String
    let emoji: String
    let channel: ChannelDto
    var score: Int
    var myVote: Int
    var commentCount: Int
    let createdAt: Date
    let isMine: Bool
    var poll: PollDto?
}

struct CommentDto: Codable, Hashable, Identifiable {
    let id: String
    let parentId: String?
    let alias: String
    let emoji: String
    let isOp: Bool
    let text: String
    var score: Int
    var myVote: Int
    let createdAt: Date
    let isMine: Bool
    let isRemoved: Bool
}

struct NotificationDto: Codable, Hashable, Identifiable {
    let id: String
    let type: String
    let postId: String
    let commentId: String?
    let actorAlias: String
    let actorEmoji: String
    let preview: String
    let isRead: Bool
    let createdAt: Date

    var title: String {
        type == "reply_to_comment" ? "コメントに返信がありました" : "投稿にコメントがつきました"
    }
}

// MARK: - API payloads

struct AuthResponse: Codable {
    let token: String
    let user: VerifiedUser

    struct VerifiedUser: Codable {
        let id: String
        let email: String
        let karma: Int
        let isModerator: Bool
        let school: SchoolDto
    }
}

struct RequestCodeResponse: Codable {
    let sent: Bool
    let devCode: String?
}

struct FeedResponse: Codable {
    let posts: [PostDto]
    let nextCursor: Int?
}

struct PostDetailResponse: Codable {
    let post: PostDto
    let comments: [CommentDto]
}

struct VoteResponse: Codable {
    let score: Int
    let myVote: Int
}

struct NotificationsResponse: Codable {
    let unreadCount: Int
    let notifications: [NotificationDto]
}
