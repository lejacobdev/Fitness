#if os(iOS) && !APP_EXTENSION
import Foundation
import Observation
import StoreKit

/// §18's client half. StoreKit 2 only; the server (App Store Server
/// Notifications V2) is the authority on `proUntil` and this class never
/// writes it anywhere but the local mirror of what the server said.
///
/// - `Transaction.updates` is listened to from launch and never cancelled —
///   an Ask to Buy approval usually lands while the app is closed or
///   backgrounded, and missing it is the most likely subscription bug in an
///   app for minors.
/// - `transaction.finish()` is called only after the entitlement is recorded.
/// - A pending purchase (Ask to Buy) is a real, visible state.
@MainActor
@Observable
public final class ProStore {
    public static let shared = ProStore()

    public static let monthlyID = "com.studentathlete.app.pro.monthly"
    public static let yearlyID = "com.studentathlete.app.pro.yearly"
    public static let productIDs = [yearlyID, monthlyID]

    public enum PurchaseState: Equatable {
        case idle
        case purchasing
        /// Ask to Buy: waiting for a parent. Unlocks via `Transaction.updates`.
        case pending
        case purchased
        case failed(String)
    }

    public private(set) var products: [Product] = []
    public private(set) var isLoadingProducts = false
    public private(set) var productLoadFailed = false
    public private(set) var purchaseState: PurchaseState = .idle
    /// A verified, unexpired, unrevoked transaction for one of our products.
    public private(set) var hasActiveSubscription = false
    /// The server's word (`GET /athlete/me`).
    public private(set) var serverProUntil: Date?
    /// True while StoreKit reports billing retry / grace period, for §18's
    /// non-blocking banner.
    public private(set) var isInBillingRetry = false

    @ObservationIgnored private var updatesTask: Task<Void, Never>?
    @ObservationIgnored private var started = false

    public var isPro: Bool {
        ProGate.isPro(proUntil: serverProUntil, hasActiveSubscription: hasActiveSubscription)
    }

    public var yearly: Product? { products.first { $0.id == Self.yearlyID } }
    public var monthly: Product? { products.first { $0.id == Self.monthlyID } }

    private init() {}

    /// Call once at launch (idempotent).
    public func start(athlete: Athlete) {
        serverProUntil = athlete.proUntil
        guard !started else { return }
        started = true
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                await self?.handle(update)
            }
        }
        Task {
            await loadProducts()
            await refreshEntitlements()
            await refreshFromServer(athlete: athlete)
        }
    }

    public func loadProducts() async {
        isLoadingProducts = true
        productLoadFailed = false
        defer { isLoadingProducts = false }
        do {
            let loaded = try await Product.products(for: Self.productIDs)
            products = loaded.sorted {
                (Self.productIDs.firstIndex(of: $0.id) ?? .max) < (Self.productIDs.firstIndex(of: $1.id) ?? .max)
            }
            productLoadFailed = loaded.isEmpty
        } catch {
            productLoadFailed = true
        }
    }

    public func purchase(_ product: Product, athleteId: String) async {
        purchaseState = .purchasing
        var options: Set<Product.PurchaseOption> = []
        // appAccountToken ties the transaction to this athlete server-side.
        if let token = UUID(uuidString: athleteId) {
            options.insert(.appAccountToken(token))
        }
        do {
            let result = try await product.purchase(options: options)
            switch result {
            case .success(let verification):
                await handle(verification)
                purchaseState = hasActiveSubscription ? .purchased : .idle
            case .pending:
                purchaseState = .pending
            case .userCancelled:
                purchaseState = .idle
            @unknown default:
                purchaseState = .idle
            }
        } catch {
            purchaseState = .failed("The purchase didn't go through. Nothing was charged — please try again.")
        }
    }

    /// §4: "A working Restore Purchases button is mandatory."
    public func restore() async {
        purchaseState = .idle
        do {
            try await AppStore.sync()
        } catch StoreKitError.userCancelled {
            return
        } catch {
            purchaseState = .failed("Couldn't reach the App Store to restore. Check your connection and try again.")
            return
        }
        await refreshEntitlements()
        purchaseState = hasActiveSubscription
            ? .purchased
            : .failed("Nothing to restore — this Apple ID has no active Pro subscription.")
    }

    public func refreshEntitlements() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  Self.productIDs.contains(transaction.productID),
                  transaction.revocationDate == nil
            else { continue }
            if let expires = transaction.expirationDate, expires < .now { continue }
            active = true
        }
        hasActiveSubscription = active
        await refreshBillingRetryState()
    }

    /// Pulls the authoritative entitlement from the server and mirrors it
    /// locally so offline launches still know.
    public func refreshFromServer(athlete: Athlete) async {
        guard let token = try? KeychainTokenStore().read() else { return }
        var request = URLRequest(url: AppConfig.backendBaseURL.appending(path: "athlete/me"))
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        guard
            let (data, response) = try? await URLSession.shared.data(for: request),
            (response as? HTTPURLResponse)?.statusCode == 200,
            let body = try? JSONDecoder().decode(MeResponse.self, from: data)
        else { return }
        let proUntil = body.athlete.proUntil.flatMap(Self.parseDate)
        serverProUntil = proUntil
        athlete.proUntil = proUntil
    }

    private func handle(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result else { return }
        await refreshEntitlements()
        if hasActiveSubscription, purchaseState == .pending {
            purchaseState = .purchased
        }
        await transaction.finish()
    }

    private func refreshBillingRetryState() async {
        guard let product = yearly ?? monthly, let statuses = try? await product.subscription?.status else {
            isInBillingRetry = false
            return
        }
        isInBillingRetry = statuses.contains { $0.state == .inBillingRetryPeriod || $0.state == .inGracePeriod }
    }

    private struct MeResponse: Decodable {
        struct Body: Decodable { let proUntil: String? }
        let athlete: Body
    }

    private static func parseDate(_ string: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: string) ?? ISO8601DateFormatter().date(from: string)
    }
}

public extension Product {
    /// "€3.33/month" for the yearly card.
    var monthlyEquivalent: String? {
        guard let period = subscription?.subscriptionPeriod, period.unit == .year else { return nil }
        let monthly = price / Decimal(12 * period.value)
        return monthly.formatted(priceFormatStyle)
    }
}
#endif
