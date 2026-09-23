import AuthenticationServices
import CryptoKit
import SwiftUI

/// §23: "Sign in with Apple is the only login. No email, no password, no
/// other provider." Uses AuthenticationServices' own SwiftUI button rather
/// than the UIKit delegate pattern — fewer moving parts, and it is Apple's
/// own framework either way (no third-party dependency, §0).
public enum SignInNonce {
    /// A fresh cryptographically random nonce for one sign-in attempt. Sent
    /// to Apple hashed (`sha256`); the RAW value goes to our own backend,
    /// which re-hashes and compares (appleIdentity.js's `sha256Hex` —
    /// replay-proofing a token from a different session cannot match).
    public static func generate() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return bytes.map { String(format: "%02x", $0) }.joined()
    }

    public static func sha256(_ raw: String) -> String {
        SHA256.hash(data: Data(raw.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

public enum SignInWithAppleError: Error, Sendable {
    case noIdentityToken
}

/// Emits the identity token and the RAW nonce (not the hashed one Apple saw)
/// on success — both of which `APIClient.signInWithApple` needs, since the
/// backend re-derives the hash itself rather than trusting a client-supplied
/// hash.
public struct AppleSignInButton: View {
    private let onSuccess: (_ identityToken: String, _ rawNonce: String) -> Void
    private let onFailure: (Error) -> Void
    @State private var currentNonce = SignInNonce.generate()
    @Environment(\.colorScheme) private var colorScheme

    public init(
        onSuccess: @escaping (_ identityToken: String, _ rawNonce: String) -> Void,
        onFailure: @escaping (Error) -> Void
    ) {
        self.onSuccess = onSuccess
        self.onFailure = onFailure
    }

    public var body: some View {
        SignInWithAppleButton(.signIn) { request in
            // §3: store only the `sub`. Requesting no scopes at all means
            // there is no email or name to even consider dropping later.
            request.requestedScopes = []
            request.nonce = SignInNonce.sha256(currentNonce)
        } onCompletion: { result in
            switch result {
            case .success(let authorization):
                guard
                    let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                    let tokenData = credential.identityToken,
                    let token = String(data: tokenData, encoding: .utf8)
                else {
                    onFailure(SignInWithAppleError.noIdentityToken)
                    return
                }
                onSuccess(token, currentNonce)
            case .failure(let error):
                onFailure(error)
            }
            // A fresh nonce for the next attempt, whether this one succeeded
            // or not — a nonce is single-use by design.
            currentNonce = SignInNonce.generate()
        }
        // Matches the app's own primary button: black on the light canvas,
        // white on the dark one.
        .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
    }
}
