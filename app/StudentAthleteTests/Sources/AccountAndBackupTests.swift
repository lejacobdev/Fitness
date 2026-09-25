import SwiftData
import XCTest

/// Backup across phones (CloudSync), log out / delete account (LocalWipe)
/// and deleting plans.
@MainActor
final class AccountAndBackupTests: XCTestCase {
    override func tearDown() {
        StubURLProtocol.handler = nil
        for key in ["cloud.meta", "cloud.lastRowPull", "plans.deletedSkillPlanDates", "plans.variant"] {
            UserDefaults.standard.removeObject(forKey: key)
        }
        super.tearDown()
    }

    /// An empty UserDefaults suite of its own, so tests never touch real settings.
    private func freshSuite(_ name: String) -> UserDefaults {
        let suite = UserDefaults(suiteName: "AccountAndBackupTests.\(name)")!
        suite.removePersistentDomain(forName: "AccountAndBackupTests.\(name)")
        return suite
    }

    private func makeContext() throws -> ModelContext {
        ModelContext(try AthleteStore.makeContainer(inMemory: true))
    }

    private func makeClient() -> APIClient {
        APIClient(baseURL: URL(string: "https://example.invalid")!, session: StubURLProtocol.makeSession())
    }

    nonisolated private static func ok(_ request: URLRequest, _ json: String) -> (HTTPURLResponse, Data) {
        (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data(json.utf8))
    }

    /// URLProtocol hands the body over as a stream.
    nonisolated private static func body(of request: URLRequest) -> [String: Any] {
        var data = request.httpBody ?? Data()
        if data.isEmpty, let stream = request.httpBodyStream {
            stream.open()
            var buffer = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable {
                let read = stream.read(&buffer, maxLength: buffer.count)
                if read <= 0 { break }
                data.append(buffer, count: read)
            }
            stream.close()
        }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
    }

    /// Records what was pushed, thread-safely (the stub runs off the main actor).
    private final class PushLog: @unchecked Sendable {
        private let lock = NSLock()
        private var _keys: [Set<String>] = []
        var keys: [Set<String>] { lock.lock(); defer { lock.unlock() }; return _keys }
        func record(_ keys: Set<String>) { lock.lock(); _keys.append(keys); lock.unlock() }
    }

    /// A server holding one backed-up sport; PUT echoes back what was sent.
    private func stubServer(sportsUpdatedAt: String, log: PushLog) {
        StubURLProtocol.handler = { request in
            if request.httpMethod == "PUT" {
                let states = (Self.body(of: request)["states"] as? [String: Any]) ?? [:]
                log.record(Set(states.keys))
                let data = try JSONSerialization.data(withJSONObject: ["states": states])
                return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
            }
            return Self.ok(request, """
            {"states": {"sports": {"updatedAt": "\(sportsUpdatedAt)", "value": [
              {"id": "sport-1", "sportSlug": "soccer", "positionSlug": "midfielder", "formatSlug": null,
               "seasonStart": 1788220800, "seasonEnd": 1798761600, "isPrimary": true}
            ]}}}
            """)
        }
    }

    // MARK: - CloudSync

    func testANewPhoneTakesTheBackupAndUploadsWhatTheServerLacks() async throws {
        UserDefaults.standard.removeObject(forKey: "cloud.meta")
        let context = try makeContext()
        let athlete = Athlete(appleUserId: "sub-new-phone", birthDate: Date(timeIntervalSince1970: 1_262_304_000))
        context.insert(athlete)
        let log = PushLog()
        stubServer(sportsUpdatedAt: "2026-09-20T10:00:00.000Z", log: log)

        let reached = await CloudSync.sync(athlete: athlete, context: context, apiClient: makeClient(), tokenStore: InMemoryTokenStore(token: "tok"))

        XCTAssertTrue(reached)
        XCTAssertEqual(athlete.sports.map(\.sportSlug), ["soccer"], "the backed-up sport came back")
        XCTAssertEqual(athlete.sports.first?.positionSlug, "midfielder")
        let pushed = try XCTUnwrap(log.keys.first)
        XCTAssertTrue(pushed.contains("profile"), "what the server didn't have goes up")
        XCTAssertFalse(pushed.contains("sports"), "the server's copy won, so it isn't pushed back")
    }

    func testAChangeMadeOnThisPhoneIsPushedAndBeatsAnOlderServerCopy() async throws {
        UserDefaults.standard.removeObject(forKey: "cloud.meta")
        let context = try makeContext()
        let athlete = Athlete(appleUserId: "sub-edit", birthDate: .now)
        context.insert(athlete)
        let log = PushLog()
        stubServer(sportsUpdatedAt: "2026-01-01T00:00:00.000Z", log: log)
        let client = makeClient()
        let tokens = InMemoryTokenStore(token: "tok")
        _ = await CloudSync.sync(athlete: athlete, context: context, apiClient: client, tokenStore: tokens)

        // The athlete moves their season here; the server still has January's copy.
        let sport = try XCTUnwrap(athlete.sports.first)
        sport.seasonEnd = sport.seasonEnd.addingTimeInterval(86_400 * 7)
        _ = await CloudSync.sync(athlete: athlete, context: context, apiClient: client, tokenStore: tokens)

        XCTAssertTrue(log.keys.last?.contains("sports") ?? false, "the local edit is pushed")
    }

    func testWithoutASignInNothingIsSent() async throws {
        let context = try makeContext()
        let athlete = Athlete(appleUserId: "sub-offline", birthDate: .now)
        context.insert(athlete)
        StubURLProtocol.handler = { _ in XCTFail("no token, no network"); throw URLError(.badURL) }
        let reached = await CloudSync.sync(athlete: athlete, context: context, apiClient: makeClient(), tokenStore: InMemoryTokenStore(token: nil))
        XCTAssertFalse(reached)
    }

    func testSettingsSurviveTheRoundTripWithTheirTypes() throws {
        let suite = freshSuite("roundTrip")
        suite.set(30, forKey: "campus.xp")
        suite.set("lesson-a,lesson-b", forKey: "campus.learned")
        suite.set(true, forKey: "campus.soundOn")
        suite.set([2, 4, 6], forKey: "schedule.practiceWeekdays")
        suite.set(Data([1, 2, 3]), forKey: "schedule.blob")
        suite.set("not mine", forKey: "someoneElsesKey")

        let campus = CloudSync.exportSettings(group: "campus", suite)
        XCTAssertEqual(Set(campus.keys), ["campus.xp", "campus.learned", "campus.soundOn"])
        XCTAssertNil(CloudSync.exportSettings(group: "app", suite)["someoneElsesKey"])

        // Through JSON, as the server stores it, into a fresh phone.
        let json = try JSONEncoder().encode(CloudSync.exportSettings(group: "schedule", suite).merging(campus) { a, _ in a })
        let decoded = try JSONDecoder().decode([String: CloudSync.SettingValue].self, from: json)
        let fresh = freshSuite("roundTrip.fresh")
        CloudSync.applySettings(decoded, group: "campus", to: fresh)
        CloudSync.applySettings(decoded, group: "schedule", to: fresh)

        XCTAssertEqual(fresh.integer(forKey: "campus.xp"), 30)
        XCTAssertEqual(fresh.string(forKey: "campus.learned"), "lesson-a,lesson-b")
        XCTAssertTrue(fresh.bool(forKey: "campus.soundOn"))
        XCTAssertEqual(fresh.array(forKey: "schedule.practiceWeekdays") as? [Int], [2, 4, 6])
        XCTAssertEqual(fresh.data(forKey: "schedule.blob"), Data([1, 2, 3]))
    }

    func testSettingsGroupsKeepUnrelatedKeysOut() {
        XCTAssertEqual(CloudSync.settingGroup(of: "campus.xp"), "campus")
        XCTAssertEqual(CloudSync.settingGroup(of: "dayStatus.v1"), "app")
        XCTAssertNil(CloudSync.settingGroup(of: "cloud.meta"), "sync bookkeeping never syncs itself")
        XCTAssertNil(CloudSync.settingGroup(of: "healthPermissionAsked"), "per-device permission prompts stay per device")
        XCTAssertLessThanOrEqual(CloudSync.documentKeys.count, 50, "the server takes at most 50 documents per write")
    }

    func testRestoringRowsAddsMissingWorkoutsAndCheckInsOnce() async throws {
        let context = try makeContext()
        let athlete = Athlete(appleUserId: "sub-rows", birthDate: .now)
        context.insert(athlete)
        StubURLProtocol.handler = { request in
            if request.url!.path.hasSuffix("checkins") {
                return Self.ok(request, """
                {"checkIns": [{"clientId": "c1", "date": "2026-09-20", "sleepQuality": 4, "sleepHours": 8.5, "soreness": 2,
                  "sorenessAreas": [], "energy": 4, "stress": 2, "readinessBand": "GREEN", "readinessZ": 0.4}]}
                """)
            }
            return Self.ok(request, """
            {"sessions": [{"clientId": "s1", "startedAt": "2026-09-20T16:00:00.000Z", "endedAt": null, "sessionRPE": 7,
              "minutes": 45, "source": "PHONE", "healthKitWorkoutId": null, "notes": null,
              "sets": [{"clientId": "x1", "itemSlug": "split-squat", "setIndex": 0, "reps": 8, "weightKg": null,
                        "seconds": null, "distanceM": null, "contacts": null, "side": null}]}]}
            """)
        }
        let client = makeClient()
        let tokens = InMemoryTokenStore(token: "tok")
        UserDefaults.standard.removeObject(forKey: "cloud.lastRowPull")

        await CloudSync.restoreRows(athlete: athlete, context: context, apiClient: client, full: true, tokenStore: tokens)
        await CloudSync.restoreRows(athlete: athlete, context: context, apiClient: client, full: true, tokenStore: tokens)

        XCTAssertEqual(athlete.checkIns.count, 1)
        XCTAssertEqual(athlete.checkIns.first?.readinessBand, .green)
        XCTAssertNotNil(athlete.checkIns.first?.syncedAt, "restored rows are never pushed back up")
        XCTAssertEqual(athlete.sessions.count, 1)
        XCTAssertEqual(athlete.sessions.first?.sets.first?.itemSlug, "split-squat")
        XCTAssertNotNil(athlete.sessions.first?.syncedAt)
    }

    // MARK: - Log out / delete

    func testTheWipeLeavesNothingBehind() throws {
        let suite = freshSuite("wipe")
        let context = try makeContext()
        let athlete = Athlete(appleUserId: "sub-wipe", birthDate: .now)
        context.insert(athlete)
        context.insert(AthleteSport(sportSlug: "soccer", seasonStart: .now, seasonEnd: .now, athlete: athlete))
        context.insert(CheckIn(date: .now, sleepQuality: 3, soreness: 2, energy: 3, stress: 2, athlete: athlete))
        let session = Session(startedAt: .now, source: .phone, athlete: athlete)
        context.insert(session)
        context.insert(SetLog(itemSlug: "push-up", setIndex: 0, reps: 10, session: session))
        context.insert(SkillBlock(sportSlug: "soccer", skillSlug: "passing", targetDate: .now, seed: "s", athlete: athlete))
        try context.save()
        suite.set(120, forKey: "campus.xp")
        let tokens = InMemoryTokenStore(token: "tok")

        LocalWipe.wipeData(context: context, tokenStore: tokens, defaults: suite)

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Athlete>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<AthleteSport>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<CheckIn>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Session>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<SetLog>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<SkillBlock>()), 0)
        XCTAssertNil(try tokens.read())
        XCTAssertNil(suite.object(forKey: "campus.xp"))
    }

    func testDeletingTheAccountSendsTheDeleteAndReportsFailure() async throws {
        let client = makeClient()
        StubURLProtocol.handler = { request in
            XCTAssertEqual(request.httpMethod, "DELETE")
            XCTAssertEqual(request.url?.path, "/athlete/me")
            return (HTTPURLResponse(url: request.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!, Data())
        }
        try await client.deleteAccount(sessionToken: "tok")

        StubURLProtocol.handler = { _ in throw URLError(.notConnectedToInternet) }
        do {
            try await client.deleteAccount(sessionToken: "tok")
            XCTFail("offline must not look like a deleted account")
        } catch {}
    }

    // MARK: - Deleting plans

    func testDeletingASkillPlanStillCountsTowardsTheMonthlyFreePlans() throws {
        let context = try makeContext()
        let athlete = Athlete(appleUserId: "sub-plans", birthDate: .now)
        context.insert(athlete)
        let store = SkillBlockStore(modelContext: context)
        let block = try store.save(athlete: athlete, sportSlug: "soccer", skillSlug: "passing", targetDate: .now, seed: "seed")
        XCTAssertEqual(athlete.skillBlocks.count, 1)

        try store.delete(block)

        XCTAssertEqual(athlete.skillBlocks.count, 0)
        XCTAssertEqual(SkillBlockStore.quotaDates(for: athlete).count, 1)
    }

    func testANewWeeklyPlanChangesTheSeedAndCanGoBack() {
        PlanVariant.backToOriginal()
        XCTAssertEqual(PlanVariant.seed("a-1"), "a-1")
        PlanVariant.buildNew()
        XCTAssertEqual(PlanVariant.seed("a-1"), "a-1-v1")
        PlanVariant.buildNew()
        XCTAssertEqual(PlanVariant.seed("a-1"), "a-1-v2")
        PlanVariant.backToOriginal()
        XCTAssertEqual(PlanVariant.seed("a-1"), "a-1")
    }
}
