import CryptoKit
import XCTest

/// §21: "Offline behaviour: with the network stubbed dead, launch ... and
/// confirm nothing is lost on reconnect." M5/M8 haven't landed yet (there is
/// no session or check-in to log against), so this is M4's own slice of that
/// same guarantee: a pack downloaded on a previous, connected launch stays
/// fully readable with the network stubbed dead on a later one, and a failed
/// download — offline, or a corrupted response — never corrupts what was
/// already there.
final class PackDownloaderTests: XCTestCase {
    override func tearDown() {
        StubURLProtocol.handler = nil
        super.tearDown()
    }

    private func makeClient() -> APIClient {
        APIClient(baseURL: URL(string: "https://example.invalid")!, session: StubURLProtocol.makeSession())
    }

    private func makeEmptyDirectory() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appending(path: "pack-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func testPreviouslyDownloadedPacksStayAvailableWithNoNetwork() throws {
        let dir = try makeEmptyDirectory()
        try Data("already downloaded".utf8).write(to: dir.appending(path: "core-v1.json"))
        StubURLProtocol.handler = { _ in throw URLError(.notConnectedToInternet) }

        let downloader = PackDownloader(client: makeClient(), packsDirectory: dir)

        XCTAssertEqual(downloader.locallyAvailablePackFiles(), ["core-v1.json"])
    }

    func testDownloadFailsClosedWithNoNetworkAndLeavesExistingFilesIntact() async throws {
        let dir = try makeEmptyDirectory()
        let existingFile = dir.appending(path: "core-v1.json")
        try Data("already downloaded".utf8).write(to: existingFile)
        StubURLProtocol.handler = { _ in throw URLError(.notConnectedToInternet) }

        let downloader = PackDownloader(client: makeClient(), packsDirectory: dir)
        let manifest = PackManifest(generatedAt: "2026-01-01T00:00:00Z", packs: [
            PackManifestEntry(slug: "core", version: 2, file: "core-v2.json", sizeBytes: 10, checksum: "deadbeef"),
        ])

        do {
            _ = try await downloader.download(slug: "core", manifest: manifest)
            XCTFail("expected a transport error with no network")
        } catch APIClient.APIError.transport {
            // expected
        }

        XCTAssertEqual(downloader.locallyAvailablePackFiles(), ["core-v1.json"])
        XCTAssertEqual(try Data(contentsOf: existingFile), Data("already downloaded".utf8))
    }

    func testChecksumMismatchIsRejectedAndNeverWrittenToDisk() async throws {
        let dir = try makeEmptyDirectory()
        let payload = Data("pack contents".utf8)
        StubURLProtocol.handler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, payload)
        }

        let downloader = PackDownloader(client: makeClient(), packsDirectory: dir)
        let manifest = PackManifest(generatedAt: "2026-01-01T00:00:00Z", packs: [
            PackManifestEntry(slug: "core", version: 1, file: "core-v1.json", sizeBytes: payload.count, checksum: "not-the-real-checksum"),
        ])

        do {
            _ = try await downloader.download(slug: "core", manifest: manifest)
            XCTFail("expected a checksum mismatch")
        } catch PackDownloadError.checksumMismatch(let slug, let expected, let actual) {
            XCTAssertEqual(slug, "core")
            XCTAssertEqual(expected, "not-the-real-checksum")
            XCTAssertEqual(actual, SHA256.hash(data: payload).map { String(format: "%02x", $0) }.joined())
        }

        XCTAssertTrue(downloader.locallyAvailablePackFiles().isEmpty)
    }

    func testAMatchingChecksumIsWrittenAndBecomesLocallyAvailable() async throws {
        let dir = try makeEmptyDirectory()
        let payload = Data("pack contents".utf8)
        let checksum = SHA256.hash(data: payload).map { String(format: "%02x", $0) }.joined()
        StubURLProtocol.handler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, payload)
        }

        let downloader = PackDownloader(client: makeClient(), packsDirectory: dir)
        let manifest = PackManifest(generatedAt: "2026-01-01T00:00:00Z", packs: [
            PackManifestEntry(slug: "core", version: 1, file: "core-v1.json", sizeBytes: payload.count, checksum: checksum),
        ])

        let destination = try await downloader.download(slug: "core", manifest: manifest)

        XCTAssertEqual(try Data(contentsOf: destination), payload)
        XCTAssertEqual(downloader.locallyAvailablePackFiles(), ["core-v1.json"])
    }
}
