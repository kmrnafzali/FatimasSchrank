import SwiftUI
import PhotosUI

// MARK: - Monogramm

struct MonogramPlate: Shape {
    let kind: MonogramKind

    static func size(_ kind: MonogramKind) -> CGSize {
        kind == .circle ? CGSize(width: 112, height: 112) : CGSize(width: 96, height: 120)
    }

    func path(in r: CGRect) -> Path {
        switch kind {
        case .oval:
            return Ellipse().path(in: r)
        case .circle:
            let s = min(r.width, r.height)
            return Circle().path(in: CGRect(x: r.midX - s / 2, y: r.midY - s / 2, width: s, height: s))
        case .shield:
            let w = r.width
            let h = r.height
            var p = Path()
            p.move(to: CGPoint(x: r.minX + w * 0.12, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX - w * 0.12, y: r.minY))
            p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY + h * 0.12), control: CGPoint(x: r.maxX, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.minY + h * 0.5))
            p.addQuadCurve(to: CGPoint(x: r.midX, y: r.maxY), control: CGPoint(x: r.maxX, y: r.minY + h * 0.85))
            p.addQuadCurve(to: CGPoint(x: r.minX, y: r.minY + h * 0.5), control: CGPoint(x: r.minX, y: r.minY + h * 0.85))
            p.addLine(to: CGPoint(x: r.minX, y: r.minY + h * 0.12))
            p.addQuadCurve(to: CGPoint(x: r.minX + w * 0.12, y: r.minY), control: CGPoint(x: r.minX, y: r.minY))
            p.closeSubpath()
            return p
        }
    }
}

/// Das Messingschild mit Buchstaben, wie an der Schranktür.
struct MonogramBadge: View {
    let text: String
    let kind: MonogramKind

    static func fontSize(for text: String) -> CGFloat {
        switch text.count {
        case 0, 1: return 54
        case 2: return 40
        default: return 30
        }
    }

    var body: some View {
        let size = MonogramPlate.size(kind)
        ZStack {
            MonogramPlate(kind: kind)
                .fill(Palette.brassGradient)
                .frame(width: size.width, height: size.height)
                .shadow(color: .black.opacity(0.4), radius: 8, y: 6)
            MonogramPlate(kind: kind)
                .stroke(Palette.brassDark, lineWidth: 1)
                .frame(width: size.width - 12, height: size.height - 12)
            Text(text)
                .font(.system(size: Self.fontSize(for: text), weight: .regular, design: .serif))
                .foregroundStyle(Color(hex: 0x3A2618))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(width: size.width * 0.8)
        }
        .accessibilityLabel("Monogramm \(text)")
    }
}

// MARK: - Aussehen

private struct IconChoice: Identifiable {
    let name: String?
    let title: String
    let preview: String
    var id: String { preview }
}

struct AppearanceView: View {
    @Environment(Store.self) private var store
    @State private var currentIcon: String?
    @State private var iconProblem: String?

    private let icons = [
        IconChoice(name: nil, title: "Monogramm", preview: "IconPreviewA"),
        IconChoice(name: "AppIcon-Tueren", title: "Türen", preview: "IconPreviewB"),
        IconChoice(name: "AppIcon-Buegel", title: "Bügel", preview: "IconPreviewC"),
        IconChoice(name: "AppIcon-Elfenbein", title: "Elfenbein", preview: "IconPreviewD"),
    ]

    var body: some View {
        @Bindable var store = store
        Form {
            Section("Farbe des Schranks") {
                Picker("Farbe", selection: Binding(get: { store.db.settings.theme }, set: { store.setTheme($0) })) {
                    ForEach(CabinetTheme.allCases) { theme in
                        Text(theme.title).tag(theme)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }

            Section {
                HStack {
                    Spacer()
                    MonogramBadge(text: store.db.settings.monogram, kind: store.db.settings.monogramShape)
                        .padding(.vertical, 10)
                    Spacer()
                }
                .listRowBackground(Palette.lacquer)
                TextField("Buchstaben", text: Binding(
                    get: { store.db.settings.monogram },
                    set: { store.db.settings.monogram = String($0.prefix(3)) }
                ))
                .textInputAutocapitalization(.characters)
                Picker("Form", selection: $store.db.settings.monogramShape) {
                    ForEach(MonogramKind.allCases) { kind in
                        Text(kind.title).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
                TextField("Rückseite, zum Beispiel F + K", text: $store.db.settings.monogramBack)
            } header: {
                Text("Monogramm an der Tür")
            } footer: {
                Text("Bis zu drei Buchstaben. Die Rückseite erscheint, wenn man das Schild lange drückt.")
            }

            Section {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                    ForEach(icons) { icon in
                        Button {
                            choose(icon)
                        } label: {
                            VStack(spacing: 6) {
                                Image(icon.preview)
                                    .resizable()
                                    .scaledToFit()
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .strokeBorder(Palette.accent, lineWidth: currentIcon == icon.name ? 2.5 : 0)
                                    )
                                Text(icon.title)
                                    .font(.caption2)
                                    .foregroundStyle(.primary)
                            }
                        }
                        .buttonStyle(.borderless)
                        .accessibilityAddTraits(currentIcon == icon.name ? .isSelected : [])
                    }
                }
                .padding(.vertical, 6)
            } header: {
                Text("App-Symbol")
            } footer: {
                Text(iconProblem ?? "iOS fragt beim Wechsel einmal kurz nach.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Palette.sheet.ignoresSafeArea())
        .navigationTitle("Aussehen")
        .onAppear { currentIcon = UIApplication.shared.alternateIconName }
        .onDisappear { store.save() }
    }

    private func choose(_ icon: IconChoice) {
        guard UIApplication.shared.supportsAlternateIcons else {
            iconProblem = "Dieses Gerät erlaubt keinen Wechsel des Symbols."
            return
        }
        UIApplication.shared.setAlternateIconName(icon.name) { error in
            Task { @MainActor in
                if error == nil {
                    currentIcon = icon.name
                    iconProblem = nil
                    Haptic.success()
                } else {
                    iconProblem = "Das Symbol ließ sich gerade nicht wechseln."
                }
            }
        }
    }
}

// MARK: - Eure Fotos

struct CouplePhotosView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var picks: [PhotosPickerItem] = []
    @State private var showPicker = false
    @State private var opened: CouplePhoto?
    @State private var working = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    Text("Wir zwei")
                        .font(.serif(.largeTitle))
                        .foregroundStyle(Palette.cream)
                        .padding(.top, 8)
                    if store.db.couplePhotos.isEmpty {
                        Text("Hier liegen eure gemeinsamen Fotos. Tippe oben auf Plus, um welche hineinzulegen.")
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(Palette.creamSecondary)
                            .padding(.horizontal, 20)
                    }
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 14) {
                        ForEach(Array(store.db.couplePhotos.enumerated()), id: \.element.id) { index, photo in
                            Button {
                                opened = photo
                            } label: {
                                StoredImage(file: photo.thumb)
                                    .frame(height: 190)
                                    .frame(maxWidth: .infinity)
                                    .clipShape(Rectangle())
                                    .padding(8)
                                    .padding(.bottom, 18)
                                    .background(Palette.paper)
                                    .shadow(color: .black.opacity(0.35), radius: 8, x: 3, y: 6)
                                    .rotationEffect(.degrees(index % 2 == 0 ? -2 : 2))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(photo.caption.isEmpty ? "Foto" : photo.caption)
                        }
                    }
                    .padding(.horizontal)
                    if working {
                        ProgressView()
                            .tint(Palette.cream)
                    }
                }
                .padding(.bottom, 30)
            }
            .background(WoodBackground(shade: 0.5))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showPicker = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Fotos hinzufügen")
                }
            }
            .toolbarColorScheme(Palette.barScheme, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
            .photosPicker(isPresented: $showPicker, selection: $picks, maxSelectionCount: 20, matching: .images)
            .onChange(of: picks) { _, items in
                guard !items.isEmpty else { return }
                picks = []
                Task { await add(items) }
            }
            .sheet(item: $opened) { photo in
                CouplePhotoPage(id: photo.id)
            }
        }
    }

    private func add(_ items: [PhotosPickerItem]) async {
        working = true
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = ImagePipeline.downsample(data: data, maxPixel: 1600) else { continue }
            await store.addCouplePhoto(image)
        }
        working = false
        Haptic.success()
    }
}

private struct CouplePhotoPage: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let id: UUID
    @State private var confirmDelete = false

    var body: some View {
        NavigationStack {
            ScrollView {
                if let photo = store.db.couplePhotos.first(where: { $0.id == id }) {
                    VStack(spacing: 16) {
                        StoredImage(file: photo.full, contentMode: .fit)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        TextField("Was war das für ein Tag?", text: Binding(
                            get: { photo.caption },
                            set: { text in
                                var copy = photo
                                copy.caption = text
                                store.updateCouplePhoto(copy)
                            }
                        ), axis: .vertical)
                        .font(.serif(.body))
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Palette.card))
                    }
                    .padding()
                }
            }
            .background(Palette.sheet.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .destructive) {
                        confirmDelete = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .accessibilityLabel("Foto löschen")
                }
            }
            .confirmationDialog("Dieses Foto löschen?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Löschen", role: .destructive) {
                    store.deleteCouplePhoto(id)
                    dismiss()
                }
                Button("Abbrechen", role: .cancel) {}
            }
        }
    }
}

// MARK: - Kamrans Bereich

struct KamranView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var editing: Voucher?

    var body: some View {
        @Bindable var store = store
        NavigationStack {
            Form {
                Section {
                    Text("Hier richtest du Überraschungen ein. Fatima sieht davon nur, was du freigibst.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section {
                    ForEach(store.db.vouchers) { voucher in
                        Button {
                            editing = voucher
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(voucher.title)
                                    .foregroundStyle(.primary)
                                Text("Öffnet sich am \(voucher.unlock.german(.dateTime.day().month(.wide).year()))")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete { offsets in
                        let ids = offsets.map { store.db.vouchers[$0].id }
                        for id in ids { store.deleteVoucher(id) }
                    }
                    Button {
                        editing = Voucher(title: "")
                    } label: {
                        Label("Gutschein hinzufügen", systemImage: "plus")
                    }
                } header: {
                    Text("Gutscheine")
                } footer: {
                    Text("Ein Gutschein liegt versiegelt im Geheimfach und öffnet sich am gewählten Tag.")
                }
                Section {
                    NavigationLink {
                        KamranFavoritesView()
                    } label: {
                        Label("Deine Lieblinge an ihr", systemImage: "heart")
                    }
                } footer: {
                    Text("Diese Stücke bekommen auf dem Etikett den Hinweis \"Kamrans Liebling\".")
                }
                Section {
                    TextField("Mindestens 4 Ziffern", text: $store.db.settings.kamranCode)
                        .keyboardType(.numberPad)
                } header: {
                    Text("Code für diesen Bereich")
                } footer: {
                    Text("Erreichbar unter Mehr: ganz unten zwei Sekunden auf die Versionszeile drücken. Nimm kein Datum, das Fatima erraten könnte.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.sheet.ignoresSafeArea())
            .navigationTitle("Für Kamran")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") {
                        store.save()
                        dismiss()
                    }
                    // Ohne gültigen Code könnte jeder den Bereich neu einrichten.
                    .disabled(store.db.settings.kamranCode.count < 4)
                }
            }
            .interactiveDismissDisabled(store.db.settings.kamranCode.count < 4)
            .sheet(item: $editing) { voucher in
                VoucherEditor(original: voucher)
            }
        }
    }
}

private struct VoucherEditor: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var draft: Voucher

    init(original: Voucher) {
        _draft = State(initialValue: original)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Titel, zum Beispiel Wellnesstag", text: $draft.title)
                    TextField("Was sie bekommt, ein Code oder ein paar Worte", text: $draft.text, axis: .vertical)
                        .lineLimit(3...8)
                }
                Section {
                    DatePicker("Öffnet sich am", selection: $draft.unlock, displayedComponents: .date)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.sheet.ignoresSafeArea())
            .navigationTitle("Gutschein")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") {
                        var voucher = draft
                        if voucher.title.trimmingCharacters(in: .whitespaces).isEmpty { voucher.title = "Überraschung" }
                        store.saveVoucher(voucher)
                        Haptic.success()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

private struct KamranFavoritesView: View {
    @Environment(Store.self) private var store

    var body: some View {
        List {
            if store.activeGarments.isEmpty {
                Text("Noch keine Stücke im Schrank.")
                    .foregroundStyle(.secondary)
            }
            ForEach(store.activeGarments) { g in
                Button {
                    store.toggleKamranFavorite(g.id)
                    Haptic.light()
                } label: {
                    HStack(spacing: 12) {
                        GarmentImage(garment: g)
                            .frame(width: 40, height: 48)
                        Text(g.name)
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: g.kamranFavorite ? "heart.fill" : "heart")
                            .foregroundStyle(Palette.accent)
                    }
                }
                .accessibilityAddTraits(g.kamranFavorite ? .isSelected : [])
            }
        }
        .scrollContentBackground(.hidden)
        .background(Palette.sheet.ignoresSafeArea())
        .navigationTitle("Deine Lieblinge")
    }
}
