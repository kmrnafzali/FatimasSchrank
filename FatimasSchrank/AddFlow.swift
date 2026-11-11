import SwiftUI
import PhotosUI
import UIKit

extension View {
    /// Kamera, Fotoauswahl und die Aufnahme-Animation.
    func addGarmentFlow(category: Category,
                        showCamera: Binding<Bool>,
                        showPicker: Binding<Bool>,
                        onSingleAdded: @escaping (Garment) -> Void) -> some View {
        modifier(AddGarmentFlow(category: category, showCamera: showCamera, showPicker: showPicker, onSingleAdded: onSingleAdded))
    }
}

private enum ImportSource {
    case item(PhotosPickerItem)
    case image(UIImage)
}

private struct AddGarmentFlow: ViewModifier {
    @Environment(Store.self) private var store
    @Environment(AppState.self) private var app

    let category: Category
    @Binding var showCamera: Bool
    @Binding var showPicker: Bool
    let onSingleAdded: (Garment) -> Void

    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var cameraImage: UIImage?
    @State private var running = false
    @State private var total = 0
    @State private var done = 0
    @State private var current: UIImage?
    @State private var currentDetail: String?
    @State private var revealID = 0
    @State private var failures = 0
    @State private var message: String?

    func body(content: Content) -> some View {
        content
            .photosPicker(isPresented: $showPicker, selection: $pickerItems, maxSelectionCount: 30, matching: .images)
            .onChange(of: pickerItems) { _, items in
                guard !items.isEmpty else { return }
                let sources = items.map { ImportSource.item($0) }
                pickerItems = []
                Task { await run(sources) }
            }
            .fullScreenCover(isPresented: $showCamera, onDismiss: {
                if let image = cameraImage {
                    cameraImage = nil
                    Task { await run([.image(image)]) }
                }
            }) {
                CameraPicker(onImage: { cameraImage = $0 }, onDone: { showCamera = false })
                    .ignoresSafeArea()
            }
            .overlay {
                if running {
                    ImportOverlay(total: total, done: done, image: current, detail: currentDetail, revealID: revealID)
                        .transition(.opacity)
                }
            }
            .alert("Hinweis", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("OK", role: .cancel) { message = nil }
            } message: {
                Text(message ?? "")
            }
    }

    private func run(_ sources: [ImportSource]) async {
        guard !running else { return }
        let before = store.activeGarments.count
        withAnimation(.easeOut(duration: 0.25)) {
            running = true
            total = sources.count
            done = 0
            current = nil
            failures = 0
        }
        var lastAdded: Garment?
        var cutoutFailed = 0
        for source in sources {
            guard let photo = await load(source) else {
                failures += 1
                continue
            }
            let prepared = await Task.detached(priority: .userInitiated) {
                ImagePipeline.prepare(photo)
            }.value
            if !prepared.isCutout { cutoutFailed += 1 }
            // Erkannte Kategorie hat Vorrang, sonst die gerade gewählte.
            let detected = prepared.category ?? category
            let name = GarmentColor.suggestedName(for: detected, colors: prepared.colors)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                current = prepared.image
                currentDetail = name
                revealID += 1
            }
            Haptic.light()
            let started = Date()
            if let g = await store.addGarment(image: prepared.image, category: detected, name: name, colors: prepared.colors) {
                lastAdded = g
            } else {
                failures += 1
            }
            // Die Aufnahme soll man kurz sehen können, bei vielen Fotos etwas kürzer.
            let hold = sources.count == 1 ? 1.3 : 0.8
            let elapsed = Date().timeIntervalSince(started)
            if elapsed < hold {
                try? await Task.sleep(for: .milliseconds(Int((hold - elapsed) * 1000)))
            }
            Haptic.firm()
            withAnimation(.spring(response: 0.45, dampingFraction: 0.9)) { done += 1 }
        }
        withAnimation(.easeOut(duration: 0.3)) {
            running = false
            current = nil
            currentDetail = nil
        }
        app.swayPulse += 1

        let after = store.activeGarments.count
        for mark in [100, 250, 500, 1000] where before < mark && after >= mark && !store.db.settings.milestonesShown.contains(mark) {
            store.db.settings.milestonesShown.append(mark)
            store.save()
            app.milestone = mark
        }

        if failures > 0 {
            message = failures == 1 ? "Ein Foto konnte nicht geladen werden." : "\(failures) Fotos konnten nicht geladen werden."
        } else if cutoutFailed > 0 && sources.count == 1 {
            message = "Der Hintergrund ließ sich bei diesem Foto nicht entfernen. Flach auf einer ruhigen, hellen Fläche und ohne Bügel klappt es am besten."
        }
        if sources.count == 1, let lastAdded {
            try? await Task.sleep(for: .milliseconds(350))
            onSingleAdded(lastAdded)
        }
    }

    private func load(_ source: ImportSource) async -> UIImage? {
        switch source {
        case .image(let image):
            return await Task.detached(priority: .userInitiated) {
                ImagePipeline.scaled(image, maxSide: 1600)
            }.value
        case .item(let item):
            guard let data = try? await item.loadTransferable(type: Data.self) else { return nil }
            return await Task.detached(priority: .userInitiated) {
                ImagePipeline.downsample(data: data, maxPixel: 1600)
            }.value
        }
    }
}

/// Das frisch freigestellte Stück: goldene Kontur, Lichtstreifen, dann schwebt es in den Schrank.
private struct ImportOverlay: View {
    let total: Int
    let done: Int
    let image: UIImage?
    let detail: String?
    let revealID: Int

    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(spacing: 28) {
                Spacer()
                ZStack {
                    if let image {
                        CutoutReveal(image: image)
                            .id(revealID)
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.92).combined(with: .opacity),
                                removal: .scale(scale: 0.35, anchor: .top).combined(with: .offset(y: -260)).combined(with: .opacity)
                            ))
                    } else {
                        ProgressView()
                            .controlSize(.large)
                            .tint(Palette.cream)
                    }
                }
                .frame(height: 380)
                VStack(spacing: 6) {
                    Text(image == nil ? "Wird vorbereitet" : "Kommt in deinen Schrank")
                        .font(.serif(.title3))
                        .foregroundStyle(Palette.cream)
                    if image != nil, let detail {
                        Text("Erkannt: \(detail)")
                            .font(.footnote)
                            .foregroundStyle(Palette.gold)
                            .transition(.opacity)
                    }
                    if total > 1 {
                        Text("\(min(done + 1, total)) von \(total)")
                            .font(.footnote)
                            .monospacedDigit()
                            .foregroundStyle(Palette.creamSecondary)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 40)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Stück wird hinzugefügt")
    }
}

private struct CutoutReveal: View {
    let image: UIImage
    @State private var glow = 0.0
    @State private var sweep: CGFloat = -1

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .shadow(color: Palette.gold.opacity(glow), radius: 2)
            .shadow(color: Palette.gold.opacity(glow * 0.6), radius: 10)
            .overlay {
                GeometryReader { geo in
                    LinearGradient(colors: [.white.opacity(0), .white.opacity(0.55), .white.opacity(0)],
                                   startPoint: .leading, endPoint: .trailing)
                        .frame(width: geo.size.width * 0.4)
                        .rotationEffect(.degrees(18))
                        .offset(x: sweep * geo.size.width * 1.3)
                        .frame(maxHeight: .infinity)
                }
                .mask(Image(uiImage: image).resizable().scaledToFit())
                .blendMode(.screen)
            }
            .onAppear {
                withAnimation(.easeOut(duration: 0.5)) { glow = 1 }
                withAnimation(.easeInOut(duration: 1.0).delay(0.15)) { sweep = 1 }
                withAnimation(.easeIn(duration: 0.5).delay(0.9)) { glow = 0.3 }
            }
    }
}

// MARK: - Kamera

struct CameraPicker: UIViewControllerRepresentable {
    var onImage: (UIImage) -> Void
    var onDone: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker

        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImage(image)
            }
            parent.onDone()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onDone()
        }
    }
}
