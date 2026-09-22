import XCTest

final class APIClientTests: XCTestCase {
    override func tearDown() {
        StubURLProtocol.handler = nil
        super.tearDown()
    }

    /// Prisma/Express serialise every `DateTime` with millisecond fractional
    /// seconds (`Date.prototype.toJSON()`'s own format) — this is the exact
    /// shape the real backend sends, byte for byte, not a simplified stand-in.
    func testDecodesTheRealBackendsMillisecondDateFormat() throws {
        let json = """
        {
          "sessionToken": "tok_abc123",
          "athlete": {
            "id": "athlete-1",
            "appleUserId": "001234.abcdef.5678",
            "birthDate": "2010-05-01T00:00:00.000Z",
            "createdAt": "2026-09-22T14:03:11.472Z"
          }
        }
        """
        let response = try APIClient.decodeAuthResponse(from: Data(json.utf8))

        XCTAssertEqual(response.sessionToken, "tok_abc123")
        XCTAssertEqual(response.athlete.id, "athlete-1")
        XCTAssertEqual(response.athlete.appleUserId, "001234.abcdef.5678")

        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        XCTAssertEqual(utc.dateComponents([.year, .month, .day], from: response.athlete.birthDate).year, 2010)
        XCTAssertEqual(utc.dateComponents([.year, .month, .day], from: response.athlete.birthDate).day, 1)
        XCTAssertEqual(utc.component(.second, from: response.athlete.createdAt), 11)
    }

    /// A future backend change that drops milliseconds should not break
    /// decoding either — both formats are tried explicitly.
    func testAlsoDecodesDatesWithoutFractionalSeconds() throws {
        let json = """
        {
          "sessionToken": "tok_xyz",
          "athlete": {
            "id": "athlete-2",
            "appleUserId": "sub-2",
            "birthDate": "2011-01-15T00:00:00Z",
            "createdAt": "2026-01-01T00:00:00Z"
          }
        }
        """
        XCTAssertNoThrow(try APIClient.decodeAuthResponse(from: Data(json.utf8)))
    }

    func testMalformedDateStringThrowsDecodingRatherThanCrashing() {
        let json = """
        {
          "sessionToken": "tok",
          "athlete": {
            "id": "athlete-3",
            "appleUserId": "sub-3",
            "birthDate": "not-a-date",
            "createdAt": "2026-01-01T00:00:00Z"
          }
        }
        """
        XCTAssertThrowsError(try APIClient.decodeAuthResponse(from: Data(json.utf8))) { error in
            guard case APIClient.APIError.decoding = error else {
                XCTFail("expected .decoding, got \(error)")
                return
            }
        }
    }

    func testSignInWithAppleWrapsATransportFailureRatherThanThrowingRaw() async throws {
        StubURLProtocol.handler = { _ in throw URLError(.notConnectedToInternet) }
        let client = APIClient(baseURL: URL(string: "https://example.invalid")!, session: StubURLProtocol.makeSession())

        do {
            _ = try await client.signInWithApple(identityToken: "token", rawNonce: "nonce", birthDate: nil)
            XCTFail("expected a transport error with no network")
        } catch APIClient.APIError.transport {
            // expected
        }
    }

    func testSignInWithAppleSurfacesTheServersErrorCodeOnAnHTTPFailure() async throws {
        StubURLProtocol.handler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 403, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"error":"under_minimum_age"}"#.utf8))
        }
        let client = APIClient(baseURL: URL(string: "https://example.invalid")!, session: StubURLProtocol.makeSession())

        do {
            _ = try await client.signInWithApple(identityToken: "token", rawNonce: nil, birthDate: .now)
            XCTFail("expected an http error")
        } catch APIClient.APIError.http(let status, let code) {
            XCTAssertEqual(status, 403)
            XCTAssertEqual(code, "under_minimum_age")
        }
    }
}
