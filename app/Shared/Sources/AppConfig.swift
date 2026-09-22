import Foundation

/// §3's backend has no public host attached yet — `backend/` runs in Docker
/// Compose locally and in CI, but nothing has deployed it to a real domain.
/// Every network call routes through this one constant so that deployment is
/// a one-line change here, not a hunt through every call site.
public enum AppConfig {
    public static let backendBaseURL = URL(string: "https://api.studentathlete.app")!

    /// Where downloaded content packs live on disk — Application Support,
    /// not Caches, since §4's "a free user always has at least one sport
    /// downloaded and fully usable offline" means the system must never be
    /// free to purge this to reclaim space. One shared computation so
    /// RootView, OnboardingView and anything reading the catalogue (§9's
    /// CatalogueLoader) can never disagree about where packs are.
    public static func packsDirectory(fileManager: FileManager = .default) -> URL {
        let base = (try? fileManager.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )) ?? fileManager.temporaryDirectory
        return base.appending(path: "packs")
    }
}
