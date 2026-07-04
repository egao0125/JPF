import Foundation
import Observation

@Observable
@MainActor
final class SessionStore {
    var user: UserMe?
    var isBootstrapping = true

    private let api = APIClient.shared

    func bootstrap() async {
        defer { isBootstrapping = false }
        guard api.token != nil else { return }
        do {
            user = try await api.me()
        } catch let error as APIError where error.status == 401 || error.status == 403 {
            api.token = nil
        } catch {
            // Server unreachable — keep the token and let the user retry from the auth screen.
        }
    }

    func login(token: String, user verified: AuthResponse.VerifiedUser) async {
        api.token = token
        user = UserMe(
            id: verified.id,
            email: verified.email,
            karma: verified.karma,
            isModerator: verified.isModerator,
            postCount: nil,
            commentCount: nil,
            school: verified.school
        )
        // Refresh with full profile (post/comment counts).
        if let me = try? await api.me() { user = me }
    }

    func refresh() async {
        if let me = try? await api.me() { user = me }
    }

    func logout() {
        api.token = nil
        user = nil
    }
}
