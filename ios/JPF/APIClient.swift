import Foundation

struct APIError: LocalizedError {
    let message: String
    let status: Int
    var errorDescription: String? { message }
}

private struct ServerError: Codable { let error: String }
private struct EmptyBody: Codable {}

final class APIClient {
    static let shared = APIClient()

    static let defaultBaseURL = "http://localhost:3000"

    var baseURL: URL {
        let raw = UserDefaults.standard.string(forKey: "api_base_url") ?? Self.defaultBaseURL
        return URL(string: raw) ?? URL(string: Self.defaultBaseURL)!
    }

    // In-memory cache backed by the Keychain — avoids a Keychain read per request.
    private lazy var cachedToken: String? = Keychain.load("token")

    var token: String? {
        get { cachedToken }
        set {
            cachedToken = newValue
            if let newValue { Keychain.save(newValue, for: "token") } else { Keychain.delete("token") }
        }
    }

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        let isoFractional = ISO8601DateFormatter()
        isoFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let iso = ISO8601DateFormatter()
        d.dateDecodingStrategy = .custom { decoder in
            let s = try decoder.singleValueContainer().decode(String.self)
            if let date = isoFractional.date(from: s) ?? iso.date(from: s) { return date }
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "bad date: \(s)"))
        }
        return d
    }()

    private func request<B: Encodable, T: Decodable>(
        _ method: String,
        _ path: String,
        body: B?
    ) async throws -> T {
        // URL(string:relativeTo:) keeps query strings intact (appendingPathComponent would escape "?").
        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw APIError(message: "URLが不正です", status: 0)
        }
        var req = URLRequest(url: url)
        req.httpMethod = method
        if let token { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONEncoder().encode(body)
        }
        let (data, response) = try await URLSession.shared.data(for: req)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            let message = (try? decoder.decode(ServerError.self, from: data))?.error ?? "通信エラーが発生しました"
            throw APIError(message: message, status: status)
        }
        return try decoder.decode(T.self, from: data)
    }

    private func get<T: Decodable>(_ path: String) async throws -> T {
        try await request("GET", path, body: EmptyBody?.none)
    }

    private func post<B: Encodable, T: Decodable>(_ path: String, _ body: B) async throws -> T {
        try await request("POST", path, body: body)
    }

    // MARK: - Auth

    func requestCode(email: String) async throws -> RequestCodeResponse {
        try await post("/api/v1/auth/request-code", ["email": email])
    }

    func verify(email: String, code: String) async throws -> AuthResponse {
        try await post("/api/v1/auth/verify", ["email": email, "code": code])
    }

    func me() async throws -> UserMe {
        try await get("/api/v1/me")
    }

    // MARK: - Feed & posts

    func channels() async throws -> [ChannelDto] {
        struct R: Codable { let channels: [ChannelDto] }
        let r: R = try await get("/api/v1/channels")
        return r.channels
    }

    func feed(sort: String, channel: String?, cursor: String?) async throws -> FeedResponse {
        var components = URLComponents()
        components.path = "/api/v1/feed"
        components.queryItems = [.init(name: "sort", value: sort)]
        if let cursor { components.queryItems?.append(.init(name: "cursor", value: cursor)) }
        if let channel { components.queryItems?.append(.init(name: "channel", value: channel)) }
        return try await get(components.string ?? "/api/v1/feed")
    }

    struct CreatePostBody: Codable {
        let channelSlug: String
        let text: String
        var anonymous: Bool = true
        var imageUrl: String?
        var poll: PollBody?
        struct PollBody: Codable { let options: [String] }
    }

    func createPost(_ body: CreatePostBody) async throws -> PostDto {
        struct R: Codable { let post: PostDto }
        let r: R = try await post("/api/v1/posts", body)
        return r.post
    }

    func postDetail(id: String) async throws -> PostDetailResponse {
        try await get("/api/v1/posts/\(id)")
    }

    func deletePost(id: String) async throws {
        struct R: Codable { let deleted: Bool }
        let _: R = try await request("DELETE", "/api/v1/posts/\(id)", body: EmptyBody?.none)
    }

    func votePost(id: String, value: Int) async throws -> VoteResponse {
        try await post("/api/v1/posts/\(id)/vote", ["value": value])
    }

    func voteComment(id: String, value: Int) async throws -> VoteResponse {
        try await post("/api/v1/comments/\(id)/vote", ["value": value])
    }

    func createComment(postId: String, text: String, parentId: String?, anonymous: Bool = true) async throws -> CommentDto {
        struct Body: Codable { let text: String; let parentId: String?; let anonymous: Bool }
        struct R: Codable { let comment: CommentDto }
        let r: R = try await post(
            "/api/v1/posts/\(postId)/comments",
            Body(text: text, parentId: parentId, anonymous: anonymous)
        )
        return r.comment
    }

    func setUsername(_ username: String) async throws -> UserMe {
        try await request("PATCH", "/api/v1/me", body: ["username": username])
    }

    // MARK: - Friends

    func friends() async throws -> FriendsResponse {
        try await get("/api/v1/friends")
    }

    func sendFriendRequest(username: String) async throws {
        struct R: Codable { let status: String }
        let _: R = try await post("/api/v1/friends/requests", ["username": username])
    }

    func respondFriendRequest(id: String, action: String) async throws {
        struct R: Codable { let status: String }
        let _: R = try await post("/api/v1/friends/requests/\(id)", ["action": action])
    }

    // MARK: - Chat

    func conversations() async throws -> [ConversationDto] {
        struct R: Codable { let conversations: [ConversationDto] }
        let r: R = try await get("/api/v1/conversations")
        return r.conversations
    }

    func openConversation(with userId: String) async throws -> (id: String, friend: FriendDto) {
        struct R: Codable { let id: String; let friend: FriendDto }
        let r: R = try await post("/api/v1/conversations", ["userId": userId])
        return (r.id, r.friend)
    }

    func messages(conversationId: String, cursor: String? = nil) async throws -> MessagesResponse {
        var path = "/api/v1/conversations/\(conversationId)/messages"
        if let cursor { path += "?cursor=\(cursor)" }
        return try await get(path)
    }

    func sendMessage(conversationId: String, text: String) async throws -> MessageDto {
        struct R: Codable { let message: MessageDto }
        let r: R = try await post("/api/v1/conversations/\(conversationId)/messages", ["text": text])
        return r.message
    }

    func votePoll(pollId: String, optionId: String) async throws -> PollDto {
        try await post("/api/v1/polls/\(pollId)/vote", ["optionId": optionId])
    }

    func myPosts() async throws -> [PostDto] {
        struct R: Codable { let posts: [PostDto] }
        let r: R = try await get("/api/v1/me/posts")
        return r.posts
    }

    // MARK: - Reports & notifications

    func report(targetType: String, targetId: String, reason: String) async throws {
        struct R: Codable { let reported: Bool }
        let _: R = try await post(
            "/api/v1/reports",
            ["targetType": targetType, "targetId": targetId, "reason": reason]
        )
    }

    func notifications() async throws -> NotificationsResponse {
        try await get("/api/v1/notifications")
    }

    func markNotificationsRead() async throws {
        struct R: Codable { let read: Bool }
        let _: R = try await post("/api/v1/notifications/read", EmptyBody())
    }

    // MARK: - Upload

    func uploadImage(_ data: Data, mimeType: String) async throws -> String {
        struct R: Codable { let imageUrl: String }
        let boundary = "jpf-\(UUID().uuidString)"
        var req = URLRequest(url: URL(string: "/api/v1/uploads", relativeTo: baseURL)!)
        req.httpMethod = "POST"
        if let token { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(Data("Content-Disposition: form-data; name=\"file\"; filename=\"image\"\r\n".utf8))
        body.append(Data("Content-Type: \(mimeType)\r\n\r\n".utf8))
        body.append(data)
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))
        req.httpBody = body

        let (respData, response) = try await URLSession.shared.data(for: req)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            let message = (try? decoder.decode(ServerError.self, from: respData))?.error ?? "アップロードに失敗しました"
            throw APIError(message: message, status: status)
        }
        return try decoder.decode(R.self, from: respData).imageUrl
    }

    func imageURL(for path: String) -> URL? {
        URL(string: path, relativeTo: baseURL)
    }
}
