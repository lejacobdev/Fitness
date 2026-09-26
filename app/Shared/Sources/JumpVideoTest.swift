#if os(iOS) && !APP_EXTENSION
import AVFoundation
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// The vertical jump, measured with the phone's camera: film the jump at
/// the camera's highest frame rate (240 fps on most iPhones), then step
/// frame by frame to the take-off and the landing. Flight time gives the
/// height (h = g·t²/8) — the method validated jump apps use.
struct JumpVideoTest: View {
    let onResult: (Double) -> Void

    @State private var filming = false
    @State private var pickedItem: PhotosPickerItem?
    @State private var videoURL: URL?
    @State private var loadingPick = false
    @State private var pickError: String?

    var body: some View {
        VStack(spacing: 12) {
            if let videoURL {
                JumpFrameMarker(url: videoURL, onResult: onResult) { self.videoURL = nil }
            } else {
                Button { filming = true } label: { Label("Film the jump", systemImage: "video.fill") }
                    .buttonStyle(.primary)
                PhotosPicker(selection: $pickedItem, matching: .videos, preferredItemEncoding: .current) {
                    Label(loadingPick ? "Opening…" : "Choose a video I already filmed", systemImage: "photo.on.rectangle")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppTheme.ink)
                        .frame(maxWidth: .infinity, minHeight: 58)
                        .background(AppTheme.fill, in: Capsule())
                }
                if let pickError {
                    Text(pickError)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.red)
                }
            }
        }
        .fullScreenCover(isPresented: $filming) {
            JumpCameraView { url in
                filming = false
                if let url { videoURL = url }
            }
        }
        .onChange(of: pickedItem) { _, item in
            guard let item else { return }
            loadingPick = true
            pickError = nil
            Task {
                if let movie = try? await item.loadTransferable(type: PickedMovie.self) {
                    videoURL = movie.url
                } else {
                    pickError = "That video couldn't be opened."
                }
                loadingPick = false
                pickedItem = nil
            }
        }
    }
}

/// A video from the photo library, copied somewhere the app can read it.
struct PickedMovie: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let copy = FileManager.default.temporaryDirectory.appending(path: "jump-\(UUID().uuidString).\(received.file.pathExtension)")
            try FileManager.default.copyItem(at: received.file, to: copy)
            return PickedMovie(url: copy)
        }
    }
}

// MARK: - Marking take-off and landing

struct JumpFrameMarker: View {
    let url: URL
    let onResult: (Double) -> Void
    let onRetake: () -> Void

    @State private var generator: AVAssetImageGenerator?
    @State private var duration: Double = 0
    @State private var frameRate: Double = 30
    @State private var time: Double = 0
    @State private var frame: CGImage?
    @State private var takeoff: Double?
    @State private var landing: Double?
    @State private var failed = false

    private var step: Double { 1 / max(frameRate, 1) }

    private var flightTime: Double? {
        guard let takeoff, let landing, landing > takeoff else { return nil }
        return landing - takeoff
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if failed {
                Text("This video couldn't be read. Try filming it again.")
                    .foregroundStyle(AppTheme.red)
                Button("Film again", action: onRetake).buttonStyle(.secondary)
            } else {
                Text(takeoff == nil
                     ? "Step to the last frame where the toes still touch the ground, then tap Take-off."
                     : "Now step to the first frame where a foot touches the ground again, then tap Landing.")
                    .font(.headline)
                    .foregroundStyle(AppTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                ZStack {
                    Color.black
                    if let frame {
                        Image(decorative: frame, scale: 1)
                            .resizable()
                            .scaledToFit()
                    } else {
                        ProgressView().tint(.white)
                    }
                }
                .frame(height: 360)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                Slider(value: $time, in: 0...max(duration, 0.01))
                    .tint(AppTheme.accent)
                HStack(spacing: 10) {
                    stepButton("-10", -10)
                    stepButton("-1", -1)
                    Text(String(format: "%.3f s", time))
                        .font(.subheadline.monospacedDigit().weight(.semibold))
                        .foregroundStyle(AppTheme.secondaryText)
                        .frame(maxWidth: .infinity)
                    stepButton("+1", 1)
                    stepButton("+10", 10)
                }
                if frameRate < 100 {
                    Text("This video is \(Int(frameRate.rounded())) frames per second, so the result can be a few cm off. Filming in the app uses the fastest frame rate your phone has.")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.secondaryText)
                }
                ButtonRow {
                    Button { takeoff = time } label: {
                        Label(takeoff.map { String(format: "Take-off %.3f", $0) } ?? "Take-off", systemImage: "arrow.up")
                    }
                    .buttonStyle(.secondary)
                    Button { landing = time } label: {
                        Label(landing.map { String(format: "Landing %.3f", $0) } ?? "Landing", systemImage: "arrow.down")
                    }
                    .buttonStyle(.secondary)
                    .disabled(takeoff == nil)
                }
                if let flightTime {
                    let height = BenchmarkMath.jumpHeightCentimeters(flightTime: flightTime)
                    if flightTime > 1.0 || flightTime < 0.15 {
                        Text("That's \(String(format: "%.2f", flightTime)) s in the air — check the frames. (A Slo-mo video from the Photos app plays slowed down; film in the app instead.)")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(AppTheme.red)
                    } else {
                        Button { onResult((height * 10).rounded() / 10) } label: {
                            Text("Save \(Int(height.rounded())) cm")
                        }
                        .buttonStyle(.primary)
                        // Guideline 1.4.1: say how it's worked out and that it's an estimate.
                        Text(String(format: "In the air for %.3f s. Estimated from flight time (height = g·t²/8) — good for tracking your own progress, not a lab measurement.", flightTime))
                            .font(.footnote)
                            .foregroundStyle(AppTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Button("Film again", action: onRetake)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.accent)
            }
        }
        .task { await load() }
        .onChange(of: time) { Task { await render() } }
    }

    private func stepButton(_ title: String, _ frames: Double) -> some View {
        Button {
            time = min(max(0, time + frames * step), duration)
        } label: {
            Text(title)
                .font(.headline.monospacedDigit())
                .foregroundStyle(AppTheme.ink)
                .frame(width: 52, height: 44)
                .background(AppTheme.fill, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func load() async {
        let asset = AVURLAsset(url: url)
        guard let seconds = try? await asset.load(.duration).seconds,
              let track = try? await asset.loadTracks(withMediaType: .video).first else {
            failed = true
            return
        }
        frameRate = Double((try? await track.load(.nominalFrameRate)) ?? 30)
        duration = seconds
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        generator.maximumSize = CGSize(width: 1080, height: 1080)
        self.generator = generator
        // Start in the middle: that's usually where the jump is.
        time = seconds / 2
        await render()
    }

    private func render() async {
        guard let generator else { return }
        let at = CMTime(seconds: time, preferredTimescale: 600)
        if let image = try? await generator.image(at: at).image {
            frame = image
        }
    }
}

// MARK: - Filming

/// Full screen: the camera at its fastest frame rate, and one big button.
struct JumpCameraView: View {
    let onDone: (URL?) -> Void

    @State private var camera = JumpCamera()
    @State private var ready = false
    @State private var denied = false
    @State private var recording = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if ready {
                CameraPreview(session: camera.session)
                    .ignoresSafeArea()
            }
            VStack {
                HStack {
                    Button("Cancel") {
                        camera.shutDown()
                        onDone(nil)
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding()
                    Spacer()
                    if ready {
                        Text("\(Int(camera.frameRate.rounded())) fps")
                            .font(.headline.monospacedDigit())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.black.opacity(0.5), in: Capsule())
                            .padding()
                    }
                }
                Spacer()
                if denied {
                    Text("Camera access is off. Turn it on in Settings → Athlete OS → Camera, or type your result in.")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding()
                } else {
                    Text(recording ? "Jump now — tap stop after landing." : "Phone low, side-on, feet in the picture. Tap record, then jump.")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(12)
                        .background(.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .padding(.horizontal)
                    Button {
                        if recording {
                            recording = false
                            Task {
                                let url = await camera.stop()
                                camera.shutDown()
                                onDone(url)
                            }
                        } else {
                            recording = true
                            camera.start()
                        }
                    } label: {
                        ZStack {
                            Circle().stroke(.white, lineWidth: 5).frame(width: 84, height: 84)
                            RoundedRectangle(cornerRadius: recording ? 8 : 36, style: .continuous)
                                .fill(AppTheme.red)
                                .frame(width: recording ? 36 : 70, height: recording ? 36 : 70)
                        }
                    }
                    .disabled(!ready)
                    .accessibilityLabel(recording ? "Stop filming" : "Start filming")
                    .padding(.bottom, 30)
                }
            }
        }
        .task {
            if await camera.configure() {
                ready = true
            } else {
                denied = true
            }
        }
    }
}

/// The capture session: back camera, fastest frame rate at 720p–1080p, no
/// sound (so no microphone permission is needed).
final class JumpCamera: NSObject, AVCaptureFileOutputRecordingDelegate, @unchecked Sendable {
    let session = AVCaptureSession()
    private let output = AVCaptureMovieFileOutput()
    private let queue = DispatchQueue(label: "athleteos.jumpcamera")
    private var finished: (@Sendable (URL?) -> Void)?
    private(set) var frameRate: Double = 30

    func configure() async -> Bool {
        guard await AVCaptureDevice.requestAccess(for: .video) else { return false }
        return await withCheckedContinuation { continuation in
            queue.async { continuation.resume(returning: self.setUp()) }
        }
    }

    private func setUp() -> Bool {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else { return false }
        session.beginConfiguration()
        session.sessionPreset = .inputPriority
        if session.canAddInput(input) { session.addInput(input) }
        if session.canAddOutput(output) { session.addOutput(output) }
        let candidates = device.formats.filter { format in
            let size = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            return size.height >= 720 && size.height <= 1080
        }
        func fastest(_ format: AVCaptureDevice.Format) -> Double {
            format.videoSupportedFrameRateRanges.map(\.maxFrameRate).max() ?? 0
        }
        if let best = candidates.max(by: { fastest($0) < fastest($1) }),
           let range = best.videoSupportedFrameRateRanges.max(by: { $0.maxFrameRate < $1.maxFrameRate }),
           (try? device.lockForConfiguration()) != nil {
            device.activeFormat = best
            device.activeVideoMinFrameDuration = range.minFrameDuration
            device.activeVideoMaxFrameDuration = range.minFrameDuration
            device.unlockForConfiguration()
            frameRate = range.maxFrameRate
        }
        session.commitConfiguration()
        session.startRunning()
        return true
    }

    func start() {
        queue.async {
            let url = FileManager.default.temporaryDirectory.appending(path: "jump-\(UUID().uuidString).mov")
            self.output.startRecording(to: url, recordingDelegate: self)
        }
    }

    /// Stops filming; the video's file once it's written.
    func stop() async -> URL? {
        await withCheckedContinuation { continuation in
            queue.async {
                self.finished = { url in continuation.resume(returning: url) }
                self.output.stopRecording()
            }
        }
    }

    func shutDown() {
        queue.async { if self.session.isRunning { self.session.stopRunning() } }
    }

    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL,
                    from connections: [AVCaptureConnection], error: (any Error)?) {
        let usable = FileManager.default.fileExists(atPath: outputFileURL.path)
        queue.async {
            let done = self.finished
            self.finished = nil
            done?(usable ? outputFileURL : nil)
        }
    }
}

/// The live camera picture.
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer {
            // layerClass guarantees the type.
            layer as! AVCaptureVideoPreviewLayer // swiftlint:disable:this force_cast
        }
    }
}
#endif
