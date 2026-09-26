#if os(iOS) && !APP_EXTENSION
import StoreKit
import SwiftUI

/// §4/§18's paywall. Everything App Review checks is on this one screen,
/// readable without buying anything: subscription length, price per period,
/// what's included, Restore Purchases, and links to the Terms and Privacy
/// Policy. And everything §4 says about selling to minors: no countdowns, no
/// urgency, the price stated plainly — every price is StoreKit's own, in the
/// athlete's currency — and a line that a parent may need to approve, with
/// Ask to Buy's waiting state shown as a real state, not a failure. The
/// introductory offer (new subscribers) is shown next to the regular price it
/// renews at, never on its own.
public struct PaywallView: View {
    let athlete: Athlete
    /// Which feature brought the athlete here, shown first in the list.
    let highlight: ProFeature?

    @Environment(\.dismiss) private var dismiss
    @State private var store = ProStore.shared
    @State private var selectedID = ProStore.yearlyID
    /// Products whose introductory offer this Apple ID can still use.
    @State private var introEligible: Set<String> = []
    @State private var pickedByHand = false

    public init(athlete: Athlete, highlight: ProFeature? = nil) {
        self.athlete = athlete
        self.highlight = highlight
    }

    private var features: [ProFeature] {
        // Only what really is Pro in the app — each has a gate.
        let all: [ProFeature] = [
            .workoutEditor, .myWorkouts, .shareWorkouts, .unlimitedLessons, .skillBlocks, .muscleWorkouts,
            .multipleSports, .fullSeasonCalendar, .detailedTracking, .exerciseProgress, .fullHistory,
            .videoJumpTest, .visualization, .moreCalendars, .coachWorkouts, .dataExport,
        ]
        guard let highlight, all.contains(highlight) else { return all }
        return [highlight] + all.filter { $0 != highlight }
    }

    private var selectedProduct: Product? {
        store.products.first { $0.id == selectedID }
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                CircleIconButton(systemImage: "xmark", accessibilityLabel: "Close") { dismiss() }
                Spacer()
                Button("Restore") { Task { await store.restore() } }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.secondaryText)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    // Prices first: what it costs is never below the fold.
                    planCards
                    statusBanner
                    featureList
                    freeForeverNote
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            .scrollIndicators(.hidden)

            footer
        }
        .appScreen()
        .task {
            // Fresh every time: a price or offer changed in App Store Connect
            // shows here without restarting the app.
            await store.loadProducts()
            await checkOffers()
        }
        .onChange(of: store.products.count) {
            Task { await checkOffers() }
        }
        .onChange(of: store.isPro) {
            if store.isPro { dismiss() }
        }
    }

    /// Which offers apply; with an offer on monthly, that plan starts selected.
    private func checkOffers() async {
        var eligible: Set<String> = []
        for product in store.products {
            if product.subscription?.introductoryOffer != nil, await product.subscription?.isEligibleForIntroOffer == true {
                eligible.insert(product.id)
            }
        }
        introEligible = eligible
        if !pickedByHand, eligible.contains(ProStore.monthlyID) { selectedID = ProStore.monthlyID }
    }

    private func offer(for product: Product) -> Product.SubscriptionOffer? {
        guard introEligible.contains(product.id) else { return nil }
        return product.subscription?.introductoryOffer
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "crown.fill")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(AppTheme.onAccent)
                .frame(width: 52, height: 52)
                .background(AppTheme.accent, in: Circle())
            Text("Train smarter with Pro")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(AppTheme.ink)
            Text("Everything in the free app, plus a plan that's completely yours, unlimited learning and the deep tools for a whole season.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
        }
    }

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(features, id: \.self) { feature in
                HStack(spacing: 12) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(AppTheme.onAccent)
                        .frame(width: 24, height: 24)
                        .background(AppTheme.accent, in: Circle())
                    Text(feature.proDescription)
                        .font(.subheadline.weight(feature == highlight ? .bold : .medium))
                        .foregroundStyle(AppTheme.ink)
                    Spacer(minLength: 0)
                }
            }
        }
        .cardStyle()
    }

    private var freeForeverNote: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "heart.fill")
                .foregroundStyle(AppTheme.brand)
            Text("Always free: the daily check-in, your plan and all three kinds of workout, logging, the Apple Watch app, fuelling, safety, Campus lessons every day, your sport's guide, leagues and teams.")
                .font(.footnote)
                .foregroundStyle(AppTheme.secondaryText)
        }
    }

    @ViewBuilder
    private var planCards: some View {
        if store.isLoadingProducts && store.products.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 120)
        } else if store.products.isEmpty && DemoData.isEnabled {
            // Screenshot runs have no StoreKit: show the real App Store prices.
            VStack(spacing: 12) {
                demoPlan("Yearly", "$24.99 per year · $2.08/month", badge: "Save 30%", selected: false)
                demoPlan("Monthly", "$0.99/month for your first 3 months, then $2.99/month", badge: "−67%", selected: true)
            }
        } else if store.products.isEmpty {
            VStack(spacing: 10) {
                Text("Prices aren't available right now. Check your connection, then try again.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
                Button("Try again") { Task { await store.loadProducts() } }
                    .buttonStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .cardStyle()
        } else {
            VStack(spacing: 12) {
                ForEach(store.products, id: \.id) { product in
                    planCard(product)
                }
            }
        }
    }

    private func demoPlan(_ title: String, _ price: String, badge: String?, selected: Bool) -> some View {
        HStack(spacing: 14) {
            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .foregroundStyle(selected ? AppTheme.accent : AppTheme.hairline)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(title).font(.headline).foregroundStyle(AppTheme.ink)
                    if let badge {
                        Text(badge)
                            .font(.caption2.bold())
                            .foregroundStyle(AppTheme.onAccent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(AppTheme.accent, in: Capsule())
                    }
                }
                Text(price).font(.subheadline).foregroundStyle(AppTheme.secondaryText)
            }
            Spacer()
        }
        .cardStyle(padding: 16)
        .overlay(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
            .stroke(selected ? AppTheme.accent : Color.clear, lineWidth: 2))
    }

    private func planCard(_ product: Product) -> some View {
        let isSelected = product.id == selectedID
        let isYearly = product.id == ProStore.yearlyID
        return Button {
            selectedID = product.id
            pickedByHand = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? AppTheme.accent : AppTheme.hairline)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(isYearly ? "Yearly" : "Monthly")
                            .font(.headline)
                            .foregroundStyle(AppTheme.ink)
                        if let offer = offer(for: product), let reduced = reductionText(offer, regular: product) {
                            Text(reduced)
                                .font(.caption2.bold())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(AppTheme.brand, in: Capsule())
                        } else if isYearly, let saving = savingText {
                            Text(saving)
                                .font(.caption2.bold())
                                .foregroundStyle(AppTheme.onAccent)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(AppTheme.accent, in: Capsule())
                        }
                    }
                    if let offer = offer(for: product) {
                        // The regular price, struck through, next to the offer — and what it renews at.
                        HStack(spacing: 6) {
                            Text(product.displayPrice)
                                .strikethrough()
                                .foregroundStyle(AppTheme.secondaryText)
                            Text(offer.displayPrice)
                                .font(.title3.bold())
                                .foregroundStyle(AppTheme.brand)
                            Text("/ \(unitWord(offer.period.unit, count: 1))")
                                .foregroundStyle(AppTheme.ink)
                        }
                        .font(.subheadline.weight(.semibold))
                        Text(offerTerms(offer, regular: product))
                            .font(.footnote)
                            .foregroundStyle(AppTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text(isYearly
                             ? "\(product.displayPrice) per year\(product.monthlyEquivalent.map { " · \($0)/month" } ?? "")"
                             : "\(product.displayPrice) per month")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(18)
            .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(isSelected ? AppTheme.accent : AppTheme.hairline, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(offer(for: product).map { "\(isYearly ? "Yearly" : "Monthly"), \(offerTerms($0, regular: product))" }
                            ?? (isYearly ? "Yearly, \(product.displayPrice) per year" : "Monthly, \(product.displayPrice) per month"))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// "€0.99/month for your first 3 months, then €2.99/month."
    private func offerTerms(_ offer: Product.SubscriptionOffer, regular: Product) -> String {
        let total = offer.periodCount * offer.period.value
        let span = "\(total) \(unitWord(offer.period.unit, count: total))"
        let renewal = "\(regular.displayPrice)/\(regular.subscription.map { unitWord($0.subscriptionPeriod.unit, count: 1) } ?? "month")"
        switch offer.paymentMode {
        case .freeTrial: return "Free for your first \(span), then \(renewal)."
        case .payUpFront: return "\(offer.displayPrice) for your first \(span), then \(renewal)."
        default: return "\(offer.displayPrice)/\(unitWord(offer.period.unit, count: 1)) for your first \(span), then \(renewal)."
        }
    }

    /// "−67%": how much lower the offer is than the regular price per period.
    private func reductionText(_ offer: Product.SubscriptionOffer, regular: Product) -> String? {
        if offer.paymentMode == .freeTrial { return "Free" }
        guard offer.paymentMode == .payAsYouGo, regular.price > 0,
              offer.period.unit == regular.subscription?.subscriptionPeriod.unit else { return nil }
        let percent = NSDecimalNumber(decimal: (1 - offer.price / regular.price) * 100).intValue
        return percent > 0 ? "−\(percent)%" : nil
    }

    private func unitWord(_ unit: Product.SubscriptionPeriod.Unit, count: Int) -> String {
        let word: String
        switch unit {
        case .day: word = "day"
        case .week: word = "week"
        case .month: word = "month"
        case .year: word = "year"
        @unknown default: word = "period"
        }
        return count == 1 ? word : word + "s"
    }

    /// "Save 44%" versus twelve months of the monthly plan.
    private var savingText: String? {
        guard let yearly = store.yearly, let monthly = store.monthly, monthly.price > 0 else { return nil }
        let twelveMonths = monthly.price * 12
        let saving = (twelveMonths - yearly.price) / twelveMonths * 100
        let percent = NSDecimalNumber(decimal: saving).intValue
        return percent > 0 ? "Save \(percent)%" : nil
    }

    @ViewBuilder
    private var statusBanner: some View {
        switch store.purchaseState {
        case .pending:
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "hourglass")
                    .font(.title3)
                    .foregroundStyle(AppTheme.amber)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Waiting for approval")
                        .font(.headline)
                        .foregroundStyle(AppTheme.ink)
                    Text("We've asked a parent or guardian to approve this. Pro unlocks automatically the moment they do — you can close this screen and keep training.")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }
            .cardStyle(padding: 16)
        case .failed(let message):
            Text(message)
                .font(.footnote)
                .foregroundStyle(AppTheme.red)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .purchased:
            Label("You're Pro. Thanks for supporting Athlete OS.", systemImage: "checkmark.seal.fill")
                .font(.headline)
                .foregroundStyle(AppTheme.green)
        case .idle, .purchasing:
            EmptyView()
        }
    }

    /// The selected plan's offer terms, stated in full above the button.
    private var footerTerms: String {
        guard let product = selectedProduct, let offer = offer(for: product) else { return "" }
        return offerTerms(offer, regular: product) + " "
    }

    private var footer: some View {
        VStack(spacing: 10) {
            Button {
                guard let product = selectedProduct else { return }
                Task { await store.purchase(product, athleteId: athlete.id) }
            } label: {
                if store.purchaseState == .purchasing {
                    ProgressView().tint(AppTheme.onAccent)
                } else {
                    Text(store.purchaseState == .pending ? "Waiting for approval"
                         : (selectedProduct.flatMap { offer(for: $0) }.map { "Start for \($0.displayPrice)" } ?? "Continue"))
                }
            }
            .buttonStyle(.primary)
            .disabled(selectedProduct == nil || store.purchaseState == .purchasing || store.purchaseState == .pending)

            Text(footerTerms + "Renews automatically until cancelled. Cancel anytime in Settings → Apple ID → Subscriptions. A parent may need to approve the purchase.")
                .font(.caption2)
                .foregroundStyle(AppTheme.secondaryText)
                .multilineTextAlignment(.center)

            HStack(spacing: 18) {
                Link("Terms of Use", destination: AppConfig.backendBaseURL.appending(path: "terms"))
                Link("Privacy Policy", destination: AppConfig.backendBaseURL.appending(path: "privacy"))
                Button("Restore Purchases") { Task { await store.restore() } }
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(AppTheme.ink)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(AppTheme.background)
    }
}

/// An inline upsell for a gated spot (Cal AI-style card, never an
/// interstitial — §4: "no interstitial paywall thrown up mid-session").
public struct ProUpsellCard: View {
    let athlete: Athlete
    let feature: ProFeature
    let message: String
    @State private var showingPaywall = false

    public init(athlete: Athlete, feature: ProFeature, message: String) {
        self.athlete = athlete
        self.feature = feature
        self.message = message
    }

    public var body: some View {
        Button {
            showingPaywall = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "crown.fill")
                    .foregroundStyle(AppTheme.onAccent)
                    .frame(width: 40, height: 40)
                    .background(AppTheme.accent, in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(feature.proDescription)
                        .font(.headline)
                        .foregroundStyle(AppTheme.ink)
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.secondaryText)
            }
            .cardStyle(padding: 16)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingPaywall) {
            PaywallView(athlete: athlete, highlight: feature)
        }
    }
}

/// Me tab row: shows Pro status, opens the paywall or Apple's manage screen,
/// and §18's non-blocking billing-retry banner.
public struct SubscriptionRow: View {
    let athlete: Athlete
    @State private var store = ProStore.shared
    @State private var showingPaywall = false
    @State private var showingManage = false

    public init(athlete: Athlete) {
        self.athlete = athlete
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                if store.isPro { showingManage = true } else { showingPaywall = true }
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(store.isPro ? AppTheme.amber : AppTheme.onAccent)
                        .frame(width: 34, height: 34)
                        .background(store.isPro ? AppTheme.amber.opacity(0.13) : AppTheme.ink,
                                    in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.isPro ? "Athlete OS Pro" : "Upgrade to Pro")
                            .font(.body)
                            .foregroundStyle(AppTheme.ink)
                        Text(statusLine)
                            .font(.caption)
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppTheme.secondaryText)
                }
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if store.isInBillingRetry {
                Label("There's a problem with your payment method. Pro stays on while Apple retries — update it in Settings.", systemImage: "exclamationmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(AppTheme.amber)
            }
            if store.purchaseState == .pending {
                Label("Waiting for a parent to approve your purchase.", systemImage: "hourglass")
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
        .paywallSheet(isPresented: $showingPaywall, athlete: athlete)
        .manageSubscriptionsSheet(isPresented: $showingManage)
    }

    private var statusLine: String {
        if store.isPro {
            if let until = store.serverProUntil {
                return "Active until \(until.formatted(date: .abbreviated, time: .omitted))"
            }
            return "Active"
        }
        return "Unlimited skill plans and muscle workouts, several sports, every progress chart"
    }
}

public extension View {
    /// Presents the paywall as a sheet — only ever in response to the
    /// athlete tapping something gated, never on its own.
    func paywallSheet(isPresented: Binding<Bool>, athlete: Athlete, highlight: ProFeature? = nil) -> some View {
        sheet(isPresented: isPresented) {
            PaywallView(athlete: athlete, highlight: highlight)
        }
    }
}
#endif
