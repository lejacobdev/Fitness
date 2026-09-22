import Foundation

/// §3's backend has no public host attached yet — `backend/` runs in Docker
/// Compose locally and in CI, but nothing has deployed it to a real domain.
/// Every network call routes through this one constant so that deployment is
/// a one-line change here, not a hunt through every call site.
public enum AppConfig {
    public static let backendBaseURL = URL(string: "https://api.studentathlete.app")!
}
