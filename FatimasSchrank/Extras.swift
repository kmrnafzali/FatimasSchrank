import SwiftUI

// MARK: - Wunschliste

struct WishlistView: View {
    @Environment(Store.self) private var store
    @State private var editing: Wish?

    var body: some View {
        let open = store.db.wishes.filter { !$0.fulfilled }
        let done = store.db.wishes.filter { $0.fulfilled }
        List {
            if store.db.wishes.isEmpty {
                ContentUnavailableView(
                    "Noch keine Wünsche",
                    systemImage: "gift",
                    description: Text("Halte fest, was dir gefällt. Vielleicht liest jemand mit.")
                )
                .listRowBackground(Color.clear)
            }
            if !open.isEmpty {
                Section("Wünsche") {
                    ForEach(open) { wish in row(wish) }
                        .onDelete { offsets in
                            for i in offsets { store.deleteWish(open[i].id) }
                        }
                }
            }
            if !done.isEmpty {
                Section("Erfüllt") {
                    ForEach(done) { wish in row(wish) }
                        .onDelete { offsets in
                            for i in offsets { store.deleteWish(done[i].id) }
                        }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Palette.sheet.ignoresSafeArea())
        .navigationTitle("Wunschliste")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editing = Wish(name: "")
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Wunsch hinzufügen")
            }
        }
        .sheet(item: $editing) { wish in
            WishEditor(original: wish)
        }
    }

    private func row(_ wish: Wish) -> some View {
        let details = [wish.brand, wish.size.isEmpty ? "" : "Größe \(wish.size)", wish.color]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
        return Button {
            editing = wish
        } label: {
            HStack(spacing: 12) {
                Image(systemName: wish.fulfilled ? "checkmark.seal.fill" : "gift")
                    .foregroundStyle(Palette.accent)
                    .frame(width: 26)
                VStack(alignment: .leading, spacing: 2) {
                    Text(wish.name)
                        .font(.serif(.body))
                        .foregroundStyle(.primary)
                        .strikethrough(wish.fulfilled)
                    if !details.isEmpty {
                        Text(details)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

struct WishEditor: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var draft: Wish

    init(original: Wish) {
        _draft = State(initialValue: original)
    }

    private var linkURL: URL? {
        guard let url = URL(string: draft.link.trimmingCharacters(in: .whitespaces)),
              let scheme = url.scheme, scheme.hasPrefix("http") else { return nil }
        return url
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Was wünschst du dir?", text: $draft.name)
                    TextField("Marke", text: $draft.brand)
                    TextField("Größe", text: $draft.size)
                    TextField("Farbe", text: $draft.color)
                }
                Section {
                    TextField("Link (optional)", text: $draft.link)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    if let url = linkURL {
                        Link("Im Browser öffnen", destination: url)
                    }
                }
                Section("Notiz") {
                    TextField("Wo gesehen, wofür, warum", text: $draft.note, axis: .vertical)
                        .lineLimit(1...4)
                }
                Section {
                    Toggle("Erfüllt", isOn: $draft.fulfilled)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.sheet.ignoresSafeArea())
            .navigationTitle(draft.name.isEmpty ? "Neuer Wunsch" : "Wunsch")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") {
                        var wish = draft
                        if wish.name.trimmingCharacters(in: .whitespaces).isEmpty { wish.name = "Wunsch" }
                        store.saveWish(wish)
                        Haptic.success()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Größen

struct SizesView: View {
    @Environment(Store.self) private var store

    static let keys = ["Oberteile", "Kleider", "Hosen und Jeans", "Röcke", "Mäntel und Jacken", "Schuhe", "Ringe", "BH"]

    var body: some View {
        Form {
            Section {
                ForEach(Self.keys, id: \.self) { key in
                    HStack {
                        Text(key)
                        Spacer()
                        TextField("–", text: binding(key))
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 140)
                    }
                }
            } footer: {
                Text("Praktisch für Geschenke und fürs Online-Shoppen.")
            }
            Section("Marken und Besonderheiten") {
                TextField("Zum Beispiel: bei Zara eher M", text: binding("Notizen"), axis: .vertical)
                    .lineLimit(2...6)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Palette.sheet.ignoresSafeArea())
        .navigationTitle("Meine Größen")
    }

    private func binding(_ key: String) -> Binding<String> {
        Binding(
            get: { store.db.sizes[key] ?? "" },
            set: { store.setSize(key, $0) }
        )
    }
}

// MARK: - Tagebuch

private struct DayKey: Identifiable {
    let id: String
}

struct DiaryView: View {
    @Environment(Store.self) private var store
    @State private var showing: DayKey?

    private var keys: [String] { store.db.dayPhotos.keys.sorted(by: >) }

    static func title(_ key: String) -> String {
        Date.fromDayKey(key)?.german(.dateTime.day().month(.wide).year()) ?? key
    }

    var body: some View {
        ScrollView {
            if keys.isEmpty {
                ContentUnavailableView(
                    "Dein Tagebuch ist noch leer",
                    systemImage: "photo.on.rectangle",
                    description: Text("Im Kalender kannst du zu jedem Tag ein Foto von deinem Look ablegen.")
                )
                .padding(.top, 60)
            } else {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 16) {
                    ForEach(keys, id: \.self) { key in
                        if let photo = store.db.dayPhotos[key] {
                            Button {
                                showing = DayKey(id: key)
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    StoredImage(file: photo.thumb)
                                        .frame(height: 200)
                                        .frame(maxWidth: .infinity)
                                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    Text(Self.title(key))
                                        .font(.serif(.subheadline))
                                        .foregroundStyle(.primary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding()
            }
        }
        .background(Palette.sheet.ignoresSafeArea())
        .navigationTitle("Tagebuch")
        .sheet(item: $showing) { day in
            DiaryPage(key: day.id)
        }
    }
}

private struct DiaryPage: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let key: String

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let photo = store.db.dayPhotos[key] {
                        StoredImage(file: photo.full, contentMode: .fit)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    if let date = Date.fromDayKey(key) {
                        ForEach(store.entries(on: date)) { entry in
                            Label(store.title(for: entry), systemImage: "sparkles")
                                .font(.serif(.body))
                        }
                        let note = store.dayNote(date)
                        if !note.isEmpty {
                            Label(note, systemImage: "text.quote")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
            }
            .background(Palette.sheet.ignoresSafeArea())
            .navigationTitle(DiaryView.title(key))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Reisen und Koffer

struct TripsView: View {
    @Environment(Store.self) private var store
    @State private var creating = false

    var body: some View {
        List {
            if store.db.trips.isEmpty {
                ContentUnavailableView(
                    "Noch keine Reise",
                    systemImage: "suitcase",
                    description: Text("Wähle die Tage, und dein Schrank stellt Outfits und eine Packliste zusammen.")
                )
                .listRowBackground(Color.clear)
            }
            ForEach(store.db.trips) { trip in
                NavigationLink {
                    TripDetail(id: trip.id)
                } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(trip.name)
                            .font(.serif(.headline))
                        Text("\(TripDetail.range(trip)) · \(trip.packed.count) von \(trip.garmentIDs.count) eingepackt")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onDelete { offsets in
                let ids = offsets.map { store.db.trips[$0].id }
                for id in ids { store.deleteTrip(id) }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Palette.sheet.ignoresSafeArea())
        .navigationTitle("Reisen")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    creating = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Reise planen")
            }
        }
        .sheet(isPresented: $creating) {
            TripEditor()
        }
    }
}

struct TripEditor: View {
    @Environment(Store.self) private var store
    @Environment(WeatherService.self) private var weather
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var start = Date()
    @State private var end = Calendar.german.date(byAdding: .day, value: 2, to: Date()) ?? Date()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Wohin geht es?", text: $name)
                    DatePicker("Von", selection: $start, displayedComponents: .date)
                    DatePicker("Bis", selection: $end, in: start..., displayedComponents: .date)
                } footer: {
                    Text("Für jeden Tag gibt es einen Look. Daraus entsteht deine Packliste.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.sheet.ignoresSafeArea())
            .navigationTitle("Neue Reise")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: start) { _, newStart in
                if end < newStart { end = newStart }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Zusammenstellen") { create() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func create() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let trip = Trip(name: trimmed.isEmpty ? "Reise" : trimmed, start: start, end: max(end, start))
        store.saveTrip(Stylist.fill(trip, garments: store.activeGarments, weather: weather.days))
        Haptic.success()
        dismiss()
    }
}

struct TripDetail: View {
    @Environment(Store.self) private var store
    @Environment(WeatherService.self) private var weather
    let id: UUID

    static func range(_ trip: Trip) -> String {
        let style = Date.FormatStyle().day().month(.abbreviated)
        return "\(trip.start.german(style)) – \(trip.end.german(style))"
    }

    var body: some View {
        Group {
            if let trip = store.trip(id) {
                content(trip)
            } else {
                ContentUnavailableView("Reise nicht gefunden", systemImage: "suitcase")
            }
        }
        .background(Palette.sheet.ignoresSafeArea())
    }

    private func content(_ trip: Trip) -> some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(Self.range(trip))
                        .font(.serif(.headline))
                    ProgressView(value: Double(trip.packed.count), total: Double(max(trip.garmentIDs.count, 1)))
                        .tint(Palette.accent)
                    Text("\(trip.packed.count) von \(trip.garmentIDs.count) eingepackt")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
            if trip.garmentIDs.isEmpty {
                Section {
                    Text("Leg zuerst ein paar Stücke in deinen Schrank, dann stelle ich die Reise neu zusammen.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else {
                Section("Packliste") {
                    ForEach(store.garments(ids: trip.garmentIDs)) { g in
                        Button {
                            store.togglePacked(trip: trip.id, garment: g.id)
                            Haptic.light()
                        } label: {
                            HStack(spacing: 12) {
                                GarmentImage(garment: g)
                                    .frame(width: 40, height: 48)
                                Text(g.name)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: trip.packed.contains(g.id) ? "checkmark.circle.fill" : "circle")
                                    .font(.title3)
                                    .foregroundStyle(Palette.accent)
                            }
                        }
                        .accessibilityAddTraits(trip.packed.contains(g.id) ? .isSelected : [])
                    }
                }
            }
            ForEach(Stylist.days(from: trip.start, to: trip.end), id: \.self) { day in
                if let ids = trip.plan[day.dayKey], !ids.isEmpty {
                    let pieces = store.garments(ids: ids)
                    Section(day.german(.dateTime.weekday(.wide).day().month(.wide))) {
                        HStack(spacing: 12) {
                            OutfitCollage(garments: pieces)
                                .frame(width: 64, height: 64)
                            Text(pieces.map(\.name).joined(separator: ", "))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .navigationTitle(trip.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    let variant = Int.random(in: 1...999_999)
                    store.saveTrip(Stylist.fill(trip, garments: store.activeGarments, weather: weather.days, variant: variant))
                    Haptic.light()
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                }
                .accessibilityLabel("Neu zusammenstellen")
            }
        }
    }
}
