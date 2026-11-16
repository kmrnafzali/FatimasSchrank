import SwiftUI
import AVFoundation

// MARK: - Kamera

/// Verbindung zwischen der SwiftUI-Oberfläche und dem Kamerabild.
final class CameraHandle {
    weak var controller: CameraViewController?

    func capture() {
        controller?.capture()
    }
}

final class CameraViewController: UIViewController, AVCapturePhotoCaptureDelegate {
    var onPhoto: ((Data) -> Void)?
    var onFailure: ((String) -> Void)?

    private let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private var preview: AVCaptureVideoPreviewLayer?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configure()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        self.configure()
                    } else {
                        self.onFailure?("Die Kamera ist nicht erlaubt. Du kannst das in den Einstellungen ändern.")
                    }
                }
            }
        default:
            onFailure?("Die Kamera ist nicht erlaubt. Du kannst das in den Einstellungen ändern.")
        }
    }

    private func configure() {
        session.beginConfiguration()
        session.sessionPreset = .photo
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input), session.canAddOutput(output) else {
            session.commitConfiguration()
            onFailure?("Auf diesem Gerät gibt es keine Kamera.")
            return
        }
        session.addInput(input)
        session.addOutput(output)
        session.commitConfiguration()

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        view.layer.addSublayer(layer)
        preview = layer

        let running = session
        DispatchQueue.global(qos: .userInitiated).async {
            running.startRunning()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        preview?.frame = view.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        let running = session
        DispatchQueue.global(qos: .userInitiated).async {
            if running.isRunning { running.stopRunning() }
        }
    }

    func capture() {
        guard session.isRunning else { return }
        if let connection = output.connection(with: .video), connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
        }
        output.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil, let data = photo.fileDataRepresentation() else { return }
        DispatchQueue.main.async {
            self.onPhoto?(data)
        }
    }
}

struct CameraFeed: UIViewControllerRepresentable {
    let handle: CameraHandle
    let onPhoto: (Data) -> Void
    let onFailure: (String) -> Void

    func makeUIViewController(context: Context) -> CameraViewController {
        let controller = CameraViewController()
        controller.onPhoto = onPhoto
        controller.onFailure = onFailure
        handle.controller = controller
        return controller
    }

    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {}
}

// MARK: - Schnellaufnahme

/// Die Kamera bleibt offen. Jedes Stück wird im Hintergrund freigestellt, erkannt und abgelegt.
struct QuickCaptureView: View {
    @Environment(Store.self) private var store
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss

    let category: Category

    @State private var handle = CameraHandle()
    @State private var saved = 0
    @State private var pending = 0
    @State private var lastName: String?
    @State private var problem: String?
    @State private var flash = false

    var body: some View {
        ZStack {
            CameraFeed(handle: handle, onPhoto: { data in
                flashShutter()
                Haptic.firm()
                pending += 1
                Task { await process(data) }
            }, onFailure: { text in
                problem = text
            })
            .ignoresSafeArea()

            Color.white
                .opacity(flash ? 0.6 : 0)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack {
                HStack {
                    Button("Fertig") { dismiss() }
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .frame(minHeight: 44)
                        .background(Capsule().fill(.black.opacity(0.5)))
                    Spacer()
                    Text(countText)
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 36)
                        .background(Capsule().fill(.black.opacity(0.5)))
                        .accessibilityLabel(countText)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                Spacer()

                if let problem {
                    Text(problem)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                        .padding(16)
                        .background(RoundedRectangle(cornerRadius: 14).fill(.black.opacity(0.6)))
                        .padding(.horizontal, 30)
                } else if let lastName {
                    Text("Gespeichert: \(lastName)")
                        .font(.footnote)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(.black.opacity(0.5)))
                        .transition(.opacity)
                } else {
                    Text("Lege das Stück flach auf eine helle Fläche und tippe auf den Auslöser.")
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 30)
                }

                Button {
                    handle.capture()
                } label: {
                    ZStack {
                        Circle().strokeBorder(.white, lineWidth: 4).frame(width: 78, height: 78)
                        Circle().fill(.white).frame(width: 62, height: 62)
                    }
                }
                .padding(.vertical, 24)
                .accessibilityLabel("Foto aufnehmen")
                .disabled(problem != nil)
            }
        }
        .background(Color.black)
        .statusBarHidden()
    }

    private var countText: String {
        if pending > 0 {
            return "\(saved) gespeichert, \(pending) in Arbeit"
        }
        return saved == 1 ? "1 Stück gespeichert" : "\(saved) Stücke gespeichert"
    }

    private func flashShutter() {
        withAnimation(.easeOut(duration: 0.08)) { flash = true }
        Task {
            try? await Task.sleep(for: .milliseconds(120))
            withAnimation(.easeIn(duration: 0.2)) { flash = false }
        }
    }

    private func process(_ data: Data) async {
        let photo = await Task.detached(priority: .userInitiated) {
            ImagePipeline.downsample(data: data, maxPixel: 1600)
        }.value
        guard let photo else {
            pending -= 1
            return
        }
        let prepared = await Task.detached(priority: .userInitiated) {
            ImagePipeline.prepare(photo)
        }.value
        let detected = prepared.category ?? category
        let name = GarmentColor.suggestedName(for: detected, colors: prepared.colors)
        let before = store.activeGarments.count
        if await store.addGarment(image: prepared.image, category: detected, name: name, colors: prepared.colors) != nil {
            saved += 1
            withAnimation { lastName = name }
            Haptic.success()
            let after = store.activeGarments.count
            for mark in [100, 250, 500, 1000] where before < mark && after >= mark && !store.db.settings.milestonesShown.contains(mark) {
                store.db.settings.milestonesShown.append(mark)
                store.save()
                app.milestone = mark
            }
        }
        pending -= 1
    }
}
