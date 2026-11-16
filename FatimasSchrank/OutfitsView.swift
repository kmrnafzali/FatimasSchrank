import SwiftUI

struct OutfitsView: View {
    @Environment(Store.self) private var store
    @Environment(AppState.self) private var app
    @State private var showBuilder = false
    @State private var selected: Outfit?

    var body: some View {
        NavigationStack {
            ScrollView {
                TodaySection()
                if store.db.outfits.isEmpty {
                    ContentUnavailableView {
                        Label("Dein erstes Outfit wartet", systemImage: "sparkles")
                    } description: {
                        Text("Häng ein paar Stücke an den Kleiderständer und gib dem Look einen Namen.")
                    } actions: {
                        Button("Outfit zusammenstellen") { showBuilder = true }
                            .buttonStyle(.borderedProminent)
                    }
                    .padding(.top, 30)
                } else {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 22) {
                        ForEach(store.db.outfits) { outfit in
                            Button {
                                selected = outfit
                            } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    OutfitCollage(garments: store.garments(ids: outfit.garmentIDs))
                                        .shadow(color: .black.opacity(0.12), radius: 10, y: 6)
                                    Text(outfit.name)
                                        .font(.serif(.headline))
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                    Text(outfit.garmentIDs.count.stuecke)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(20)
                }
            }
            .background(Palette.sheet.ignoresSafeArea())
            .navigationTitle("Outfits")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showBuilder = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Neues Outfit")
                }
            }
            .sheet(isPresented: $showBuilder) {
                OutfitBuilder(existing: nil)
            }
            .sheet(item: $selected) { outfit in
                OutfitDetail(id: outfit.id)
            }
            .task(id: app.tab) {
                if app.tab == 1, app.argument("-open") == "builder", !showBuilder {
                    try? await Task.sleep(for: .milliseconds(600))
                    showBuilder = true
                }
            }
        }
    }
}

/// Oben im Outfits-Tab: Vorschlag für heute und Stücke, die lange nicht getragen wurden.
struct TodaySection: View {
    @Environment(Store.self) private var store
    @Environment(LocationService.self) private var location
    @Environment(WeatherService.self) private var weather
    @State private var shuffle = 0
    @State private var taken = false
    @State private var opened: Garment?
    @State private var occasion: Occasion?
    @State private var showThree = false
    @State private var threeSeed = 1
    @State private var shareImage: ShareImage?

    @Environment(AppState.self) private var app

    private var todayWeather: DayWeather? { weather.days[Date().dayKey] }

    private var look: Stylist.Look? {
        let day = Calendar.german.ordinality(of: .day, in: .era, for: Date()) ?? 0
        return Stylist.look(from: store.wearableGarments, weather: todayWeather, seed: day &* 31 &+ shuffle,
                            avoid: store.recentlyWorn(days: 3), occasion: occasion, ratings: store.ratings())
    }

    private var occasionPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                occasionChip(nil, title: "Jeder Anlass")
                ForEach(Occasion.allCases) { o in
                    occasionChip(o, title: o.title)
                }
            }
        }
    }

    private func occasionChip(_ o: Occasion?, title: String) -> some View {
        let on = occasion == o
        return Button {
            Haptic.light()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                occasion = o
                taken = false
            }
        } label: {
            Text(title)
                .font(.footnote.weight(on ? .semibold : .regular))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Capsule().fill(on ? Palette.accent.opacity(0.18) : Palette.card))
                .foregroundStyle(on ? Palette.accent : Color.primary)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    var body: some View {
        let forgotten = store.forgottenGarments(days: 60)
        VStack(alignment: .leading, spacing: 22) {
            if !store.wearableGarments.isEmpty {
                occasionPicker
            }
            if let look {
                card(look)
            } else if let occasion {
                Text("Für \(occasion.title) hast du noch keine Stücke markiert. Das geht im Bearbeiten-Fenster unter Anlässe.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if let hint = Stylist.missingHint(store.wearableGarments) {
                Label(hint, systemImage: "lightbulb")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.card))
            }
            if !forgotten.isEmpty {
                forgottenRow(forgotten)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .task {
            await weather.refresh(for: location.resolve(store.db.settings.placeMode))
        }
        // Für die automatischen Bildschirmfotos (Startparameter -open three).
        .task(id: app.tab) {
            guard app.tab == 1, app.argument("-open") == "three", !showThree else { return }
            try? await Task.sleep(for: .milliseconds(800))
            threeSeed = 4711
            showThree = true
        }
        .sheet(item: $opened) { g in
            GarmentSheet(id: g.id)
        }
        .sheet(isPresented: $showThree) {
            ThreeLooksSheet(seedBase: threeSeed)
        }
        .sheet(item: $shareImage) { item in
            ShareSheet(items: [item.image])
        }
        // Handy schütteln: drei Looks zur Auswahl, wenn der Outfits-Tab offen ist.
        .onChange(of: app.shakePulse) { _, _ in
            guard app.tab == 1, !store.wearableGarments.isEmpty else { return }
            threeSeed = Int.random(in: 1...999_999)
            showThree = true
        }
    }

    private func send(_ look: Stylist.Look) {
        Task {
            if let image = await OutfitShare.image(name: "Heute", garments: look.garments, store: store) {
                shareImage = ShareImage(image: image)
            }
        }
    }

    private func card(_ look: Stylist.Look) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Heute für dich")
                    .font(.footnote.weight(.semibold))
                    .tracking(1.2)
                    .foregroundStyle(Palette.highlight)
                Spacer()
                if let w = todayWeather {
                    Label(w.summary, systemImage: w.symbol)
                        .font(.footnote)
                        .foregroundStyle(Palette.creamSecondary)
                }
            }
            HStack(alignment: .top, spacing: 16) {
                OutfitCollage(garments: look.garments)
                    .frame(width: 120, height: 120)
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(look.garments) { g in
                        Text(g.name)
                            .font(.serif(.subheadline))
                            .foregroundStyle(Palette.cream)
                            .lineLimit(1)
                    }
                    Text(look.reason)
                        .font(.caption)
                        .foregroundStyle(Palette.creamSecondary)
                        .padding(.top, 4)
                }
            }
            HStack(spacing: 10) {
                Button {
                    Haptic.light()
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        shuffle += 1
                        taken = false
                    }
                } label: {
                    Label("Anderer Vorschlag", systemImage: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(.bordered)
                .tint(Palette.highlight)
                Button {
                    store.planGarments(look.garments.map(\.id), on: Date())
                    Haptic.success()
                    withAnimation { taken = true }
                } label: {
                    Label(taken ? "Eingetragen" : "Heute tragen", systemImage: taken ? "checkmark" : "sun.max")
                }
                .buttonStyle(.borderedProminent)
                .tint(Palette.highlight)
                .foregroundStyle(Palette.onCream)
                .disabled(taken)
            }
            .font(.subheadline)
            HStack(spacing: 18) {
                Button {
                    threeSeed = Int.random(in: 1...999_999)
                    showThree = true
                } label: {
                    Label("Drei Vorschläge", systemImage: "square.stack.3d.up")
                }
                Button {
                    send(look)
                } label: {
                    Label("An Kamran schicken", systemImage: "paperplane")
                }
            }
            .font(.footnote)
            .foregroundStyle(Palette.highlight)
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Palette.lacquer))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Palette.brass.opacity(0.5), lineWidth: 1))
    }

    private func forgottenRow(_ items: [Garment]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Lange nicht getragen")
                .font(.serif(.headline))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(items) { g in
                        Button {
                            opened = g
                        } label: {
                            GarmentImage(garment: g)
                                .frame(width: 70, height: 88)
                                .padding(6)
                                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Palette.card))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(g.name)
                    }
                }
            }
        }
    }
}

/// Drei verschiedene Looks zur Auswahl, zum Beispiel nach dem Schütteln.
struct ThreeLooksSheet: View {
    @Environment(Store.self) private var store
    @Environment(WeatherService.self) private var weather
    @Environment(\.dismiss) private var dismiss
    let seedBase: Int
    @State private var shareImage: ShareImage?

    private var looks: [Stylist.Look] {
        let ratings = store.ratings()
        var avoid = store.recentlyWorn(days: 3)
        var result: [Stylist.Look] = []
        for i in 0..<3 {
            guard let look = Stylist.look(from: store.wearableGarments, weather: weather.days[Date().dayKey],
                                          seed: seedBase &+ i &* 977, avoid: avoid, ratings: ratings) else { continue }
            result.append(look)
            avoid.formUnion(look.garments.map(\.id))
        }
        return result
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    ForEach(Array(looks.enumerated()), id: \.offset) { index, look in
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Vorschlag \(index + 1)")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Palette.bronze)
                            HStack(alignment: .top, spacing: 14) {
                                OutfitCollage(garments: look.garments)
                                    .frame(width: 110, height: 110)
                                VStack(alignment: .leading, spacing: 3) {
                                    ForEach(look.garments) { g in
                                        Text(g.name)
                                            .font(.serif(.subheadline))
                                            .lineLimit(1)
                                    }
                                }
                            }
                            HStack(spacing: 10) {
                                Button {
                                    store.planGarments(look.garments.map(\.id), on: Date())
                                    Haptic.success()
                                    dismiss()
                                } label: {
                                    Label("Heute tragen", systemImage: "sun.max")
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(Palette.accent)
                                Button {
                                    Task {
                                        if let image = await OutfitShare.image(name: "Vorschlag \(index + 1)", garments: look.garments, store: store) {
                                            shareImage = ShareImage(image: image)
                                        }
                                    }
                                } label: {
                                    Label("Schicken", systemImage: "paperplane")
                                }
                                .buttonStyle(.bordered)
                            }
                            .font(.subheadline)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Palette.card))
                    }
                    if looks.isEmpty {
                        Text("Leg zuerst ein paar Stücke in deinen Schrank.")
                            .foregroundStyle(.secondary)
                            .padding(.top, 40)
                    }
                }
                .padding(20)
            }
            .background(Palette.sheet.ignoresSafeArea())
            .navigationTitle("Drei Looks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
            .sheet(item: $shareImage) { item in
                ShareSheet(items: [item.image])
            }
        }
        .presentationDetents([.large])
    }
}

struct OutfitDetail: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let id: UUID
    @State private var date = Date()
    @State private var showPlan = false
    @State private var editing = false
    @State private var confirmDelete = false
    @State private var planned = false
    @State private var shareImage: ShareImage?

    var body: some View {
        NavigationStack {
            Group {
                if let outfit = store.outfit(id) {
                    ScrollView {
                        VStack(spacing: 24) {
                            MannequinStand(garments: store.garments(ids: outfit.garmentIDs))
                                .frame(height: 440)
                                .padding(.top, 10)
                            Text(outfit.name)
                                .font(.serif(.title))
                            VStack(spacing: 12) {
                                Button {
                                    showPlan = true
                                } label: {
                                    Label(planned ? "Eingeplant" : "Für einen Tag einplanen", systemImage: planned ? "checkmark" : "calendar.badge.plus")
                                }
                                .buttonStyle(PrimaryCapsuleStyle())
                                Button {
                                    Task {
                                        if let image = await OutfitShare.image(name: outfit.name, garments: store.garments(ids: outfit.garmentIDs), store: store) {
                                            shareImage = ShareImage(image: image)
                                        }
                                    }
                                } label: {
                                    Label("An Kamran schicken", systemImage: "paperplane")
                                }
                                .frame(minHeight: 44)
                                Button("Bearbeiten") { editing = true }
                                    .frame(minHeight: 44)
                            }
                            .padding(.horizontal, 24)
                        }
                        .padding(.bottom, 30)
                    }
                } else {
                    ContentUnavailableView("Outfit nicht gefunden", systemImage: "sparkles")
                }
            }
            .background(Palette.sheet.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) {
                        confirmDelete = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .accessibilityLabel("Outfit löschen")
                }
            }
            .sheet(isPresented: $showPlan) {
                NavigationStack {
                    DatePicker("Tag", selection: $date, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .padding()
                        .navigationTitle("Wann trägst du es?")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Abbrechen") { showPlan = false }
                            }
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Einplanen") {
                                    if let outfit = store.outfit(id) { store.plan(outfit: outfit, on: date) }
                                    Haptic.success()
                                    planned = true
                                    showPlan = false
                                }
                                .fontWeight(.semibold)
                            }
                        }
                }
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $editing) {
                if let outfit = store.outfit(id) { OutfitBuilder(existing: outfit) }
            }
            .sheet(item: $shareImage) { item in
                ShareSheet(items: [item.image])
            }
            .confirmationDialog("Outfit löschen?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Löschen", role: .destructive) {
                    store.deleteOutfit(id)
                    dismiss()
                }
                Button("Abbrechen", role: .cancel) {}
            } message: {
                Text("Die Kleidungsstücke bleiben im Schrank.")
            }
        }
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Kleiderständer

private enum Slot: CaseIterable {
    case upper, lower, outer, feet, bag, accessory

    static func of(_ c: Category) -> Slot {
        switch c {
        case .tops, .dresses: return .upper
        case .bottoms: return .lower
        case .outerwear: return .outer
        case .shoes: return .feet
        case .bags: return .bag
        case .accessories: return .accessory
        }
    }
}

/// "Stummer Diener": Messingständer, an dem das Outfit hängt.
struct MannequinStand: View {
    let garments: [Garment]

    private func first(_ slot: Slot) -> Garment? {
        garments.first { Slot.of($0.category) == slot }
    }

    var body: some View {
        let upper = first(.upper)
        let isDress = upper?.category == .dresses
        ZStack(alignment: .top) {
            // Ständer
            VStack(spacing: 0) {
                Hanger(width: 120)
                Rectangle().fill(Palette.brassGradient).frame(width: 4)
                Ellipse().fill(Palette.brassGradient).frame(width: 110, height: 14)
                    .shadow(color: .black.opacity(0.25), radius: 6, y: 4)
            }
            .padding(.top, 0)

            if let outer = first(.outer) {
                GarmentImage(garment: outer)
                    .frame(width: 150, height: 300, alignment: .top)
                    .offset(x: -62, y: 24)
                    .rotationEffect(.degrees(-4), anchor: .top)
                    .shadow(color: .black.opacity(0.25), radius: 10, x: 6, y: 10)
            }
            if let upper {
                GarmentImage(garment: upper)
                    .frame(width: 150, height: isDress ? 300 : 170, alignment: .top)
                    .offset(y: 24)
                    .shadow(color: .black.opacity(0.28), radius: 10, x: 6, y: 10)
            }
            if let lower = first(.lower), !isDress {
                GarmentImage(garment: lower)
                    .frame(width: 130, height: 190, alignment: .top)
                    .offset(y: upper == nil ? 40 : 178)
                    .shadow(color: .black.opacity(0.25), radius: 10, x: 6, y: 10)
            }
            if let bag = first(.bag) {
                GarmentImage(garment: bag)
                    .frame(width: 90, height: 90, alignment: .bottom)
                    .offset(x: 105, y: 230)
                    .shadow(color: .black.opacity(0.25), radius: 8, x: 4, y: 6)
            }
            if let acc = first(.accessory) {
                GarmentImage(garment: acc)
                    .frame(width: 56, height: 56)
                    .offset(x: 100, y: 70)
            }
            if let shoes = first(.feet) {
                GarmentImage(garment: shoes)
                    .frame(width: 100, height: 64, alignment: .bottom)
                    .offset(x: 40, y: 360)
                    .shadow(color: .black.opacity(0.25), radius: 6, x: 4, y: 4)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(garments.map(\.name).joined(separator: ", "))
    }
}

struct OutfitBuilder: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let existing: Outfit?
    @State private var name: String
    @State private var selection: [UUID]
    @State private var clicks = 0

    init(existing: Outfit?) {
        self.existing = existing
        _name = State(initialValue: existing?.name ?? "")
        _selection = State(initialValue: existing?.garmentIDs ?? [])
    }

    private var chosen: [Garment] { store.garments(ids: selection) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    MannequinStand(garments: chosen)
                        .frame(height: 440)
                        .animation(.spring(response: 0.45, dampingFraction: 0.72), value: selection)
                    TextField("Name des Outfits", text: $name)
                        .font(.serif(.title3))
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Palette.card))
                    if store.activeGarments.isEmpty {
                        Text("Leg zuerst ein paar Stücke in deinen Schrank.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(Category.allCases) { c in
                        let items = store.garments(in: c)
                        if !items.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(c.title)
                                    .font(.serif(.headline))
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 10) {
                                        ForEach(items) { g in
                                            pick(g)
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(Palette.sheet.ignoresSafeArea())
            .navigationTitle(existing == nil ? "Neues Outfit" : "Outfit bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .sensoryFeedback(.impact(weight: .medium), trigger: clicks)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") { save() }
                        .fontWeight(.semibold)
                        .disabled(selection.isEmpty)
                }
            }
        }
    }

    private func pick(_ g: Garment) -> some View {
        let on = selection.contains(g.id)
        return Button {
            toggle(g)
        } label: {
            GarmentImage(garment: g)
                .frame(width: 84, height: 104)
                .padding(6)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Palette.card))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Palette.accent, lineWidth: on ? 2.5 : 0)
                )
                .overlay(alignment: .topTrailing) {
                    if on {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Palette.accent)
                            .padding(5)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(g.name)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private func toggle(_ g: Garment) {
        if let i = selection.firstIndex(of: g.id) {
            selection.remove(at: i)
            return
        }
        let slot = Slot.of(g.category)
        if slot != .accessory {
            // Pro Platz nur ein Stück. Ein Kleid ersetzt Ober- und Unterteil.
            selection.removeAll { id in
                guard let other = store.garment(id) else { return true }
                let otherSlot = Slot.of(other.category)
                if otherSlot == slot { return true }
                if g.category == .dresses && otherSlot == .lower { return true }
                if slot == .lower && other.category == .dresses { return true }
                return false
            }
        }
        selection.append(g.id)
        clicks += 1
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        var outfit = existing ?? Outfit(name: "", garmentIDs: [])
        outfit.name = trimmed.isEmpty ? "Outfit \(store.db.outfits.count + (existing == nil ? 1 : 0))" : trimmed
        outfit.garmentIDs = selection
        store.saveOutfit(outfit)
        Haptic.success()
        dismiss()
    }
}
