import SwiftUI
import PhotosUI
import UserNotifications

// MARK: - Wetterwarnung

extension Reminders {
    /// Mitteilung, wenn sich das Wetter für einen geplanten Tag deutlich geändert hat.
    static func weatherChanged(_ change: Store.ForecastChange) {
        let center = UNUserNotificationCenter.current()
        let id = "wetter-\(change.entryID.uuidString)"
        let dayText = Date.fromDayKey(change.day)?.german(.dateTime.weekday(.wide)) ?? "dem geplanten Tag"
        let weatherText = change.weather.isRainy ? "regnerisch" : "anders als gedacht"
        let body = "Am \(dayText) wird es \(weatherText): \(change.weather.summary). Geplant ist: \(change.title)."
        // Am Morgen des Tages um 7 Uhr, sonst gleich.
        let morning = Date.fromDayKey(change.day).flatMap {
            Calendar.german.date(bySettingHour: 7, minute: 0, second: 0, of: $0)
        }
        let fireIn: TimeInterval = max(5, morning?.timeIntervalSinceNow ?? 5)
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "Das Wetter hat sich geändert"
            content.body = body
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: fireIn, repeats: false)
            center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
        }
    }
}

// MARK: - Reihe mit Stücken

struct PieceStrip: View {
    let title: String
    let garments: [Garment]

    var body: some View {
        if !garments.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.serif(.headline))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(garments) { g in
                            VStack(spacing: 6) {
                                GarmentImage(garment: g)
                                    .frame(width: 70, height: 88)
                                    .padding(6)
                                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Palette.card))
                                Text(g.name)
                                    .font(.caption)
                                    .lineLimit(1)
                                    .frame(width: 82)
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Budget

struct BudgetView: View {
    @Environment(Store.self) private var store

    static func euro(_ value: Double) -> String {
        value.formatted(.currency(code: "EUR").locale(.german))
    }

    static func monthTitle(_ key: String) -> String {
        Date.fromDayKey(key + "-01")?.german(.dateTime.month(.wide).year()) ?? key
    }

    var body: some View {
        let months = store.spendingByMonth()
        let thisMonth = String(Date().dayKey.prefix(7))
        let current = months.first { $0.month == thisMonth }?.total ?? 0
        List {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Diesen Monat")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text(Self.euro(current))
                        .font(.serif(.largeTitle))
                        .monospacedDigit()
                }
                .padding(.vertical, 6)
            } footer: {
                Text("Gezählt wird der Preis, den du beim Stück einträgst, im Monat, in dem es in den Schrank kam.")
            }
            ForEach(months) { month in
                Section {
                    ForEach(month.items) { g in
                        HStack(spacing: 12) {
                            GarmentImage(garment: g)
                                .frame(width: 40, height: 48)
                            Text(g.name)
                            Spacer()
                            Text(Self.euro(g.price ?? 0))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                } header: {
                    HStack {
                        Text(Self.monthTitle(month.month))
                        Spacer()
                        Text(Self.euro(month.total))
                            .monospacedDigit()
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Palette.sheet.ignoresSafeArea())
        .navigationTitle("Budget")
    }
}

// MARK: - Im Laden prüfen

struct ShopCheckView: View {
    @Environment(Store.self) private var store
    @State private var showCamera = false
    @State private var showPicker = false
    @State private var pickerItem: PhotosPickerItem?
    @State private var cameraImage: UIImage?
    @State private var working = false
    @State private var result: ImagePipeline.Prepared?
    @State private var status: String?

    private var probe: Garment? {
        guard let result else { return nil }
        var g = Garment(name: "", category: result.category ?? .tops)
        g.colors = result.colors
        return g
    }

    private var suggestedName: String {
        guard let result else { return "" }
        return GarmentColor.suggestedName(for: result.category ?? .tops, colors: result.colors)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if working {
                    ProgressView("Ich sehe es mir an")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                } else if let result, let probe {
                    Image(uiImage: result.image)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 240)
                        .frame(maxWidth: .infinity)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(suggestedName)
                            .font(.serif(.title2))
                        Text(result.category == nil
                             ? "Die Art konnte ich nicht sicher erkennen."
                             : "Erkannt als \(probe.category.singular).")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    let companions = Stylist.companions(for: probe, in: store.activeGarments)
                    let similar = Stylist.similar(to: probe, in: store.activeGarments)
                    if companions.isEmpty && similar.isEmpty {
                        Text("Dazu finde ich in deinem Schrank noch nichts Passendes.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    PieceStrip(title: "Passt zu deinen Stücken", garments: companions)
                    PieceStrip(title: "Ähnliches hast du schon", garments: similar)
                    if let status {
                        Label(status, systemImage: "checkmark")
                            .font(.footnote)
                            .foregroundStyle(Palette.accent)
                    }
                    Button("Auf die Wunschliste") {
                        store.saveWish(Wish(name: suggestedName))
                        Haptic.success()
                        status = "Steht auf deiner Wunschliste."
                    }
                    .buttonStyle(.bordered)
                    Button("Gekauft, in den Schrank legen") {
                        Task {
                            let added = await store.addGarment(image: result.image, category: probe.category,
                                                               name: suggestedName, colors: result.colors)
                            if added != nil {
                                Haptic.success()
                                status = "Liegt jetzt in deinem Schrank."
                            }
                        }
                    }
                    .buttonStyle(.bordered)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Passt das zu meinem Schrank?")
                            .font(.serif(.title2))
                        Text("Fotografiere ein Teil im Geschäft. Du siehst sofort, wozu es passt und ob du schon etwas Ähnliches hast.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 20)
                }
                HStack(spacing: 12) {
                    Button {
                        showCamera = true
                    } label: {
                        Label("Fotografieren", systemImage: "camera")
                    }
                    .buttonStyle(PrimaryCapsuleStyle())
                    Button {
                        showPicker = true
                    } label: {
                        Label("Aus Fotos", systemImage: "photo")
                            .frame(minHeight: 50)
                    }
                    .buttonStyle(.bordered)
                }
                .disabled(working)
            }
            .padding(20)
        }
        .background(Palette.sheet.ignoresSafeArea())
        .navigationTitle("Im Laden prüfen")
        .navigationBarTitleDisplayMode(.inline)
        .photosPicker(isPresented: $showPicker, selection: $pickerItem, matching: .images)
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            pickerItem = nil
            Task {
                guard let data = try? await item.loadTransferable(type: Data.self),
                      let image = ImagePipeline.downsample(data: data, maxPixel: 1600) else { return }
                await process(image)
            }
        }
        .fullScreenCover(isPresented: $showCamera, onDismiss: {
            if let image = cameraImage {
                cameraImage = nil
                Task { await process(image) }
            }
        }) {
            CameraPicker(onImage: { cameraImage = $0 }, onDone: { showCamera = false })
                .ignoresSafeArea()
        }
    }

    private func process(_ image: UIImage) async {
        working = true
        status = nil
        let prepared = await Task.detached(priority: .userInitiated) {
            ImagePipeline.prepare(image)
        }.value
        result = prepared
        working = false
    }
}
