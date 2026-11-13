import SwiftUI
import UniformTypeIdentifiers

struct MoreView: View {
    @Environment(Store.self) private var store
    @Environment(AppState.self) private var app
    @Environment(LocationService.self) private var location

    @State private var backup: BackupFile?
    @State private var working = false
    @State private var importing = false
    @State private var pendingImport: URL?
    @State private var message: String?
    @State private var showWelcome = false

    var body: some View {
        @Bindable var store = store
        NavigationStack {
            Form {
                if let problem = store.loadProblem {
                    Section {
                        Label(problem, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    }
                }

                Section {
                    Picker("Ort", selection: $store.db.settings.placeMode) {
                        ForEach(PlaceMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    if store.db.settings.placeMode == .auto {
                        LabeledContent("Gerade", value: location.resolve(.auto).name)
                        if location.isDenied {
                            Button("Ortungsdienste in den Einstellungen erlauben") {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Wetter")
                } footer: {
                    Text("Ohne Standortfreigabe zeigt der Kalender das Wetter für Wien.")
                }

                Section("Bewegung") {
                    Toggle("Türen beim Öffnen", isOn: $store.db.settings.doorsEnabled)
                    Toggle("Bewegungen und Glanz", isOn: $store.db.settings.motionEnabled)
                }

                Section {
                    Button {
                        Task { await export() }
                    } label: {
                        HStack {
                            Label("Sicherung erstellen", systemImage: "square.and.arrow.up")
                            if working { Spacer(); ProgressView() }
                        }
                    }
                    .disabled(working)
                    Button {
                        importing = true
                    } label: {
                        Label("Sicherung einspielen", systemImage: "square.and.arrow.down")
                    }
                    .disabled(working)
                    LabeledContent("Belegter Speicher", value: ByteCountFormatter.string(fromByteCount: Int64(store.storageBytes()), countStyle: .file))
                    LabeledContent("Stücke", value: "\(store.db.garments.count)")
                } header: {
                    Text("Sicherung")
                } footer: {
                    Text("Alles bleibt nur auf diesem iPhone. Speichere ab und zu eine Sicherung, zum Beispiel in iCloud Drive.")
                }

                Section("Mein Schrank") {
                    NavigationLink {
                        WishlistView()
                    } label: {
                        Label("Wunschliste", systemImage: "gift")
                    }
                    NavigationLink {
                        SizesView()
                    } label: {
                        Label("Meine Größen", systemImage: "ruler")
                    }
                    NavigationLink {
                        DiaryView()
                    } label: {
                        Label("Tagebuch", systemImage: "photo.on.rectangle")
                    }
                    NavigationLink {
                        TripsView()
                    } label: {
                        Label("Reisen und Koffer", systemImage: "suitcase")
                    }
                    NavigationLink {
                        SortOutView()
                    } label: {
                        Label("Aussortieren und Schneiderei", systemImage: "scissors")
                    }
                    Toggle("Nach Farben sortieren", isOn: $store.db.settings.rainbowOrder)
                }

                Section {
                    Button {
                        app.showDrawer = true
                        app.tab = 0
                    } label: {
                        Label("Briefe", systemImage: "envelope")
                    }
                    Button {
                        showWelcome = true
                    } label: {
                        Label("Widmung ansehen", systemImage: "heart.text.square")
                    }
                } header: {
                    Text("Für dich")
                } footer: {
                    Text("\(store.db.settings.discovered.count) von 6 Geheimnissen entdeckt")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.sheet.ignoresSafeArea())
            .navigationTitle("Mehr")
            .onChange(of: store.db.settings) { _, _ in store.save() }
            .sheet(item: $backup) { file in
                ShareSheet(items: [file.url])
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.zip]) { result in
                if case .success(let url) = result { pendingImport = url }
            }
            .confirmationDialog("Sicherung einspielen?", isPresented: Binding(get: { pendingImport != nil }, set: { if !$0 { pendingImport = nil } }), titleVisibility: .visible) {
                Button("Ersetzen", role: .destructive) {
                    if let url = pendingImport { Task { await restore(url) } }
                    pendingImport = nil
                }
                Button("Abbrechen", role: .cancel) { pendingImport = nil }
            } message: {
                Text("Dein jetziger Schrank wird durch die Sicherung ersetzt.")
            }
            .alert("Hinweis", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("OK", role: .cancel) { message = nil }
            } message: {
                Text(message ?? "")
            }
            .fullScreenCover(isPresented: $showWelcome) {
                WelcomeAgain()
            }
        }
    }

    private func export() async {
        working = true
        defer { working = false }
        do {
            backup = BackupFile(url: try await store.makeBackup())
        } catch {
            message = "Die Sicherung konnte nicht erstellt werden."
        }
    }

    private func restore(_ url: URL) async {
        working = true
        defer { working = false }
        do {
            try await store.restoreBackup(from: url)
            Haptic.success()
            message = "Dein Schrank ist wiederhergestellt."
        } catch {
            message = "Diese Datei ist keine gültige Sicherung. Dein Schrank bleibt unverändert."
        }
    }
}

struct BackupFile: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

/// Die Widmung noch einmal, ohne den Zustand zu ändern.
private struct WelcomeAgain: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            WoodBackground(shade: 0.45)
            VStack(spacing: 0) {
                Spacer()
                Rectangle().fill(Palette.brass.opacity(0.8)).frame(width: 1, height: 100)
                PaperTag(rotation: -2, maxWidth: 300) {
                    VStack(spacing: 14) {
                        Text("Fatimas Schrank")
                            .font(.serif(.title))
                            .foregroundStyle(Palette.ink)
                        Text(Liebesbriefe.dedication)
                            .font(.serif(.body))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(Palette.inkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(Liebesbriefe.signature)
                            .font(.serif(.callout).italic())
                            .foregroundStyle(Palette.bronze)
                    }
                }
                .padding(.horizontal, 32)
                Spacer()
                Button("Schließen") { dismiss() }
                    .buttonStyle(CreamCapsuleStyle())
                    .padding(.horizontal, 32)
                    .padding(.bottom, 24)
            }
        }
    }
}
