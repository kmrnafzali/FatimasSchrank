import SwiftUI
import PhotosUI

private struct DayPick: Identifiable {
    let date: Date
    var id: String { date.dayKey }
}

struct CalendarView: View {
    @Environment(Store.self) private var store
    @Environment(AppState.self) private var app
    @Environment(LocationService.self) private var location
    @Environment(WeatherService.self) private var weather

    @State private var weekStart = Calendar.german.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
    @State private var addFor: DayPick?
    @State private var noteFor: DayPick?
    @State private var noteText = ""
    @State private var photoFor: DayPick?
    @State private var showPhotoPicker = false
    @State private var photoItem: PhotosPickerItem?

    private var days: [Date] {
        (0..<7).compactMap { Calendar.german.date(byAdding: .day, value: $0, to: weekStart) }
    }

    private var place: ResolvedPlace { location.resolve(store.db.settings.placeMode) }

    private var weekTitle: String {
        guard let last = days.last else { return "" }
        let f = Date.FormatStyle().day().month(.abbreviated)
        return "\(weekStart.german(f)) – \(last.german(f))"
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Button {
                            shiftWeek(-1)
                        } label: {
                            Image(systemName: "chevron.left").frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("Vorige Woche")
                        Spacer()
                        VStack(spacing: 2) {
                            Text(weekTitle).font(.serif(.headline))
                            Label(place.name, systemImage: store.db.settings.placeMode == .auto && location.latitude != nil ? "location.fill" : "mappin")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            shiftWeek(1)
                        } label: {
                            Image(systemName: "chevron.right").frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("Nächste Woche")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Palette.accent)
                }
                .listRowBackground(Color.clear)

                ForEach(days, id: \.self) { day in
                    Section {
                        dayRows(day)
                    } header: {
                        dayHeader(day)
                    }
                    .listRowBackground(rowBackground(day))
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.sheet.ignoresSafeArea())
            .navigationTitle("Kalender")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Heute") {
                        withAnimation { weekStart = Calendar.german.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date() }
                    }
                }
            }
            .sheet(item: $addFor) { pick in
                OutfitPickerSheet(date: pick.date)
            }
            .alert("Notiz zum Tag", isPresented: Binding(get: { noteFor != nil }, set: { if !$0 { noteFor = nil } })) {
                TextField("Zum Beispiel: Abendessen bei Mama", text: $noteText)
                Button("Sichern") {
                    if let pick = noteFor { store.setDayNote(pick.date, noteText) }
                    noteFor = nil
                }
                Button("Abbrechen", role: .cancel) { noteFor = nil }
            }
            .task(id: store.db.settings.placeMode) {
                if store.db.settings.placeMode == .auto && !app.isDemo {
                    location.request()
                }
                await weather.refresh(for: place)
            }
            .onChange(of: place) { _, newPlace in
                Task { await weather.refresh(for: newPlace) }
            }
            .photosPicker(isPresented: $showPhotoPicker, selection: $photoItem, matching: .images)
            .onChange(of: photoItem) { _, item in
                guard let item, let pick = photoFor else { return }
                photoItem = nil
                Task {
                    guard let data = try? await item.loadTransferable(type: Data.self),
                          let image = ImagePipeline.downsample(data: data, maxPixel: 1600) else { return }
                    if await store.setDayPhoto(pick.date, image: image) {
                        Haptic.success()
                    }
                }
            }
        }
    }

    private func shiftWeek(_ by: Int) {
        Haptic.light()
        withAnimation {
            weekStart = Calendar.german.date(byAdding: .weekOfYear, value: by, to: weekStart) ?? weekStart
        }
    }

    private func dayHeader(_ day: Date) -> some View {
        let isToday = Calendar.german.isDateInToday(day)
        return HStack(alignment: .firstTextBaseline) {
            Text(day.german(.dateTime.weekday(.wide).day().month(.wide)))
                .font(.serif(.subheadline, weight: isToday ? .semibold : .regular))
                .foregroundStyle(isToday ? Palette.accent : .secondary)
                .textCase(nil)
            if isToday {
                Text("Heute")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Palette.accent)
                    .textCase(nil)
            }
            if SpecialDay.today(day) != nil {
                Image(systemName: "heart.fill")
                    .font(.caption2)
                    .foregroundStyle(Palette.rosePetal)
            }
        }
    }

    @ViewBuilder
    private func dayRows(_ day: Date) -> some View {
        if let w = weather.days[day.dayKey] {
            HStack(spacing: 12) {
                Image(systemName: w.symbol)
                    .symbolRenderingMode(.multicolor)
                    .font(.title3)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(w.summary).font(.subheadline.weight(.medium)).monospacedDigit()
                    Text(w.tip).font(.footnote).foregroundStyle(.secondary)
                }
                Spacer()
                if w.rain > 0 {
                    Label("\(w.rain) %", systemImage: "drop")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            .accessibilityElement(children: .combine)
            .overlay(alignment: .trailing) {
                if w.isRainy && app.ambient(store.db.settings) {
                    RainDrops()
                        .frame(width: 34)
                        .offset(x: 14)
                }
            }
        }

        ForEach(store.entries(on: day)) { entry in
            HStack(spacing: 12) {
                OutfitCollage(garments: store.garments(for: entry))
                    .frame(width: 58, height: 58)
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.title(for: entry)).font(.serif(.body))
                    if !entry.note.isEmpty {
                        Text(entry.note).font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
            .swipeActions {
                Button("Entfernen", role: .destructive) { store.removePlan(entry.id) }
            }
        }

        let note = store.dayNote(day)
        if !note.isEmpty {
            Label(note, systemImage: "text.quote")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .onTapGesture {
                    noteText = note
                    noteFor = DayPick(date: day)
                }
        }

        if let photo = store.dayPhoto(day) {
            StoredImage(file: photo.thumb)
                .frame(height: 150)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .contextMenu {
                    Button("Foto entfernen", role: .destructive) {
                        store.removeDayPhoto(day)
                    }
                }
                .accessibilityLabel("Foto vom Tag")
        }

        HStack {
            Button {
                addFor = DayPick(date: day)
            } label: {
                Label("Outfit", systemImage: "plus")
            }
            .buttonStyle(.borderless)
            Spacer()
            Button {
                photoFor = DayPick(date: day)
                showPhotoPicker = true
            } label: {
                Label("Foto", systemImage: "camera")
            }
            .buttonStyle(.borderless)
            Spacer()
            Button {
                noteText = store.dayNote(day)
                noteFor = DayPick(date: day)
            } label: {
                Label("Notiz", systemImage: "square.and.pencil")
            }
            .buttonStyle(.borderless)
        }
        .font(.subheadline)
        .foregroundStyle(Palette.accent)
    }

    private func rowBackground(_ day: Date) -> some View {
        ZStack {
            Palette.card
            if let w = weather.days[day.dayKey] {
                w.mood
            }
        }
    }
}

/// Ein paar feine Tropfen an der Kante eines Regentags.
private struct RainDrops: View {
    @State private var fallen = false

    var body: some View {
        GeometryReader { geo in
            ForEach(0..<4, id: \.self) { i in
                Capsule()
                    .fill(Color(hex: 0x8FA6B8, opacity: 0.55))
                    .frame(width: 1.5, height: 8)
                    .position(x: 6 + CGFloat(i) * 8, y: fallen ? geo.size.height + 6 : -8)
                    .animation(
                        .easeIn(duration: 1.3).repeatCount(3, autoreverses: false).delay(Double(i) * 0.28),
                        value: fallen
                    )
            }
        }
        .clipped()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear { fallen = true }
    }
}

struct OutfitPickerSheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let date: Date

    var body: some View {
        NavigationStack {
            Group {
                if store.db.outfits.isEmpty {
                    ContentUnavailableView("Noch keine Outfits", systemImage: "sparkles",
                                           description: Text("Stell im Tab Outfits deinen ersten Look zusammen."))
                } else {
                    List(store.db.outfits) { outfit in
                        Button {
                            store.plan(outfit: outfit, on: date)
                            Haptic.success()
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                OutfitCollage(garments: store.garments(ids: outfit.garmentIDs))
                                    .frame(width: 58, height: 58)
                                Text(outfit.name).font(.serif(.body))
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                }
            }
            .navigationTitle(date.german(.dateTime.weekday(.wide).day().month(.wide)))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
