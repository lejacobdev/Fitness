import SwiftUI
#if canImport(CoreImage) && canImport(UIKit)
import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit
#endif
#if os(iOS) && !APP_EXTENSION
import VisionKit
#endif

extension DeepLink: Identifiable {
    public var id: String { appURL.absoluteString }
}

#if canImport(CoreImage) && canImport(UIKit)
/// A QR code for a link: black on white, big enough to scan from a phone
/// held at arm's length (the iPhone Camera app opens the link straight away).
enum QRCode {
    static func image(for text: String, scale: CGFloat = 12) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: scale, y: scale)),
              let cgImage = CIContext().createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
#endif

/// Everything needed to pass a code on: the code itself, big; a QR code to
/// scan; and buttons to send the web link, the QR image or the direct app
/// link. Used for teams, leagues and shared workouts.
struct CodeShareView: View {
    let link: DeepLink
    /// "Join our team “Varsity”" — what the receiver reads with the link.
    let message: String
    @State private var copied: String?

    var body: some View {
        VStack(spacing: 18) {
            Text(link.code)
                .font(.system(size: 44, weight: .heavy, design: .monospaced))
                .tracking(4)
                .foregroundStyle(AppTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .accessibilityLabel("Code \(link.code.map(String.init).joined(separator: " "))")
            #if canImport(CoreImage) && canImport(UIKit)
            if let qr = QRCode.image(for: link.webURL.absoluteString) {
                Image(uiImage: qr)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 240)
                    .padding(14)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .accessibilityLabel("QR code for \(link.code)")
                Text("Scan with the iPhone Camera to open it in AthleteOS.")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.secondaryText)
                    .multilineTextAlignment(.center)
                #if os(iOS) && !APP_EXTENSION
                ShareLink(item: Image(uiImage: qr), preview: SharePreview("QR code \(link.code)", image: Image(uiImage: qr))) {
                    Label("Send the QR code", systemImage: "qrcode")
                }
                .buttonStyle(.secondary)
                #endif
            }
            #endif
            #if os(iOS) && !APP_EXTENSION
            ShareLink(item: link.webURL, subject: Text("AthleteOS"), message: Text("\(message) — code \(link.code)")) {
                Label("Send the link", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.primary)
            #endif
            #if os(iOS) && !APP_EXTENSION
            ButtonRow {
                copyButton("Copy code", value: link.code)
                copyButton("Copy app link", value: link.appURL.absoluteString)
            }
            #endif
            Text("The link opens the app on this screen, or a web page with the code if the app isn't installed. App link: \(link.appURL.absoluteString)")
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    #if os(iOS) && !APP_EXTENSION
    private func copyButton(_ title: String, value: String) -> some View {
        Button {
            UIPasteboard.general.string = value
            copied = title
        } label: {
            Label(copied == title ? "Copied" : title, systemImage: copied == title ? "checkmark" : "doc.on.doc")
        }
        .buttonStyle(.secondary)
    }
    #endif
}

/// `CodeShareView` in its own sheet, with a title.
struct CodeShareSheet: View {
    let title: String
    let subtitle: String
    let link: DeepLink
    let message: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    ScreenTitle(title, subtitle: subtitle)
                    CodeShareView(link: link, message: message)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .padding(.bottom, 24)
            }
            .appScreen()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.fontWeight(.semibold) }
            }
        }
    }
}

/// A code field that also takes a pasted link and, on iPhone, scans a QR code.
struct CodeField: View {
    let placeholder: String
    @Binding var text: String
    @State private var scanning = false

    var body: some View {
        HStack(spacing: 10) {
            TextField(placeholder, text: $text)
                .font(.title3.monospaced().weight(.semibold))
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.characters)
                #endif
                .padding(.horizontal, 16)
                .frame(minHeight: 54)
                .background(AppTheme.fill, in: RoundedRectangle(cornerRadius: AppTheme.controlCornerRadius, style: .continuous))
                .onChange(of: text) { _, new in
                    // A pasted link becomes its code.
                    if new.contains("://"), let code = DeepLink.code(fromInput: new) { text = code }
                }
            #if os(iOS) && !APP_EXTENSION
            if CodeScanner.isAvailable {
                Button { scanning = true } label: {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(AppTheme.onAccent)
                        .frame(width: 54, height: 54)
                        .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: AppTheme.controlCornerRadius, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Scan a QR code")
            }
            #endif
        }
        #if os(iOS) && !APP_EXTENSION
        .sheet(isPresented: $scanning) {
            CodeScanner { value in
                if let code = DeepLink.code(fromInput: value) { text = code }
                scanning = false
            }
            .ignoresSafeArea()
        }
        #endif
    }
}

#if os(iOS) && !APP_EXTENSION
/// The camera, looking for an AthleteOS QR code; reports the first one found.
struct CodeScanner: UIViewControllerRepresentable {
    let onFound: (String) -> Void

    @MainActor static var isAvailable: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.qr])],
            qualityLevel: .balanced, isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {
        if !scanner.isScanning { try? scanner.startScanning() }
    }

    func makeCoordinator() -> Coordinator { Coordinator(onFound: onFound) }

    @MainActor
    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onFound: (String) -> Void
        private var done = false

        init(onFound: @escaping (String) -> Void) { self.onFound = onFound }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            guard !done else { return }
            for item in addedItems {
                if case .barcode(let barcode) = item, let value = barcode.payloadStringValue, DeepLink.code(fromInput: value) != nil {
                    done = true
                    dataScanner.stopScanning()
                    onFound(value)
                    return
                }
            }
        }
    }
}
#endif
