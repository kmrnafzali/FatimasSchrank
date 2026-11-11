import SwiftUI
import PhotosUI

private struct RodOffsetKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

struct ClosetView: View {
    @Environment(Store.self) private var store
    @Environment(AppState.self) private var app

    @State private var category: Category = .dresses
    @State private var tilt: Double = 0
    @State private var lastOffset: CGFloat?
    @State private var settleTask: Task<Void, Never>?
    @State private var selected: Garment?
    @State private var editAfterAdd: Garment?
    @State private var showAll = false
    @State private var showCamera = false
    @State private var showPicker = false
    @State private var titleTaps = 0
    @State private var card: CardContent?
    @State private var emptyTaps = 0
    @State private var drawerPulled = false
    @State private var showPetals = false
    @State private var sheenIndex = -1
    @State private var sheenTick = 0

    struct CardContent: Equatable {
        let eyebrow: String
        let text: String
    }

    private var settings: Settings { store.db.settings }
    private var items: [Garment] { store.garments(in: category) }
    private var shelfItems: [Garment] {
        // An besonderen Tagen steht rechts eine Karte, dann ist Platz für zwei Stücke.
        Array((store.garments(in: .bags) + store.garments(in: .accessories)).prefix(special == nil ? 4 : 2))
    }
    private var special: SpecialDay? { SpecialDay.today() }
    private var hasUnreadLetter: Bool {
        Liebesbriefe.letters.contains { $0.isOpen() && !settings.readLetters.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                chips
                niche
                drawers
            }
            .background(WoodBackground())
            .overlay {
                if showPetals { PetalsView() }
            }
            .overlay {
                if let card {
                    NoteCard(eyebrow: card.eyebrow, text: card.text) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) { self.card = nil }
                    }
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showAll = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    .accessibilityLabel("Alle Stücke durchsuchen")
                    Menu {
                        Button {
                            showCamera = true
                        } label: {
                            Label("Foto aufnehmen", systemImage: "camera")
                        }
                        Button {
                            showPicker = true
                        } label: {
                            Label("Aus Fotos wählen", systemImage: "photo.on.rectangle")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Stück hinzufügen")
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
        }
        .toolbarColorScheme(.dark, for: .tabBar)
        .addGarmentFlow(category: category, showCamera: $showCamera, showPicker: $showPicker) { single in
            editAfterAdd = single
        }
        .sheet(item: $selected) { g in
            GarmentSheet(id: g.id)
        }
        .sheet(item: $editAfterAdd) { g in
            GarmentSheet(id: g.id, startEditing: true)
        }
        .sheet(isPresented: $showAll) {
            AllGarmentsView()
        }
        .sheet(isPresented: Binding(get: { app.showDrawer }, set: { app.showDrawer = $0 })) {
            LettersView()
        }
        .onChange(of: app.swayPulse) { _, _ in jiggle(strength: 5) }
        .onChange(of: app.shakePulse) { _, _ in
            Haptic.firm()
            jiggle(strength: 10)
            store.discover("schuetteln")
        }
        .onChange(of: app.milestone) { _, value in
            guard let value, let text = Liebesbriefe.milestones[value] else { return }
            withAnimation(.easeInOut(duration: 0.5)) { app.rodSparkle = true }
            Task {
                try? await Task.sleep(for: .milliseconds(600))
                withAnimation(.easeInOut(duration: 0.8)) { app.rodSparkle = false }
            }
            show(CardContent(eyebrow: "\(value) Stücke", text: text))
            app.milestone = nil
        }
        .task { await startUp() }
        .task(id: settings.motionEnabled) { await ambientSheen() }
    }

    // MARK: Kopf

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Fatimas Schrank")
                .font(.serif(.largeTitle))
                .foregroundStyle(Palette.cream)
                .onTapGesture {
                    titleTaps += 1
                    if titleTaps >= 7 {
                        titleTaps = 0
                        Haptic.success()
                        store.discover("titel")
                        show(CardContent(eyebrow: "Psst", text: Liebesbriefe.titleCard))
                    }
                }
                .accessibilityAddTraits(.isHeader)
            Text("\(store.activeGarments.count.stuecke) · \(store.db.outfits.count.outfits)")
                .font(.footnote)
                .foregroundStyle(Palette.creamSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
    }

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Category.allCases) { c in
                    GlassChip(title: c.title, selected: c == category) {
                        Haptic.light()
                        withAnimation(.spring(response: 0.35, dampingFraction: 1)) { category = c }
                        lastOffset = nil
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 6)
    }

    // MARK: Nische mit Licht, Fach und Stange

    private var niche: some View {
        ZStack(alignment: .top) {
            BackWall(light: app.light, rose: special != nil)
            VStack(spacing: 0) {
                shelf
                GlassShelf()
                if category.hangs {
                    rod
                } else {
                    standing
                }
                Spacer(minLength: 0)
            }
        }
        .clipShape(Rectangle())
        .overlay(alignment: .top) {
            Rectangle().fill(Palette.oakEdge).frame(height: 6)
        }
        .padding(.horizontal, 14)
        .frame(maxHeight: .infinity)
    }

    private var shelf: some View {
        HStack(alignment: .bottom, spacing: 14) {
            if shelfItems.isEmpty {
                Text("Taschen und Accessoires liegen hier oben.")
                    .font(.footnote)
                    .foregroundStyle(Palette.inkSecondary)
                    .frame(maxWidth: .infinity)
            } else {
                ForEach(shelfItems) { g in
                    GarmentImage(garment: g)
                        .frame(width: 66, height: 60, alignment: .bottom)
                        .shadow(color: .black.opacity(0.3), radius: 5, x: 4, y: 5)
                        .onTapGesture { open(g) }
                        .accessibilityAddTraits(.isButton)
                }
                Spacer(minLength: 0)
            }
            if let special {
                specialCard(special)
            }
        }
        .padding(.horizontal, 18)
        .frame(height: 78, alignment: .bottom)
        .padding(.top, 10)
    }

    private var rod: some View {
        ZStack(alignment: .top) {
            BrassRod(sparkle: app.rodSparkle ? 0.8 : 0)
                .padding(.top, 2)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 2) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, g in
                        hanging(g, index: index)
                    }
                    emptyHanger
                }
                .padding(.horizontal, 12)
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(key: RodOffsetKey.self, value: proxy.frame(in: .named("rod")).minX)
                    }
                )
            }
            .coordinateSpace(name: "rod")
            .onPreferenceChange(RodOffsetKey.self) { x in
                Task { @MainActor in handleScroll(x) }
            }
            if items.isEmpty {
                emptyRodHint
                    .padding(.top, 120)
            }
        }
        .padding(.top, 4)
    }

    private func hanging(_ g: Garment, index: Int) -> some View {
        VStack(spacing: -8) {
            Hanger(width: 92)
            ZStack {
                GarmentImage(garment: g)
                    .frame(width: 128, height: 270, alignment: .top)
                    .shadow(color: .black.opacity(0.38), radius: 10, x: 9, y: 14)
                if index == sheenIndex && app.ambient(settings) {
                    SilkSheen()
                        .id(sheenTick)
                        .mask(
                            GarmentImage(garment: g)
                                .frame(width: 128, height: 270, alignment: .top)
                        )
                        .allowsHitTesting(false)
                }
            }
        }
        .frame(width: 132)
        .rotationEffect(.degrees(tilt * (1 - Double(index % 3) * 0.12)), anchor: .top)
        .animation(.spring(response: 0.7, dampingFraction: 0.28).delay(Double(index % 6) * 0.03), value: tilt)
        .contentShape(Rectangle())
        .onTapGesture { open(g) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(g.name)
        .accessibilityAddTraits(.isButton)
    }

    private var emptyHanger: some View {
        VStack(spacing: 6) {
            Hanger(width: 92)
                .rotationEffect(.degrees(emptyTaps % 2 == 1 ? 9 : 0), anchor: .top)
                .animation(.spring(response: 0.45, dampingFraction: 0.25), value: emptyTaps)
            if emptyTaps >= 3 {
                PaperTag(rotation: 4, maxWidth: 130) {
                    Text(Liebesbriefe.emptyHanger)
                        .font(.serif(.footnote))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Palette.ink)
                }
                .transition(.scale(scale: 0.6, anchor: .top).combined(with: .opacity))
            }
        }
        .frame(width: 140, alignment: .top)
        .contentShape(Rectangle())
        .onTapGesture {
            Haptic.light()
            withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) { emptyTaps += 1 }
            if emptyTaps == 3 { store.discover("leerer-buegel") }
        }
        .accessibilityLabel("Leerer Bügel")
    }

    private var emptyRodHint: some View {
        VStack(spacing: 8) {
            Text("Hier ist noch Platz")
                .font(.serif(.title3))
                .foregroundStyle(Palette.ink)
            Text("Tippe oben auf Plus. Am besten legst du das Stück flach auf eine ruhige, helle Fläche, ohne Bügel.")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(Palette.inkSecondary)
        }
        .padding(.horizontal, 40)
        .allowsHitTesting(false)
    }

    private var standing: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 20)
            if items.isEmpty {
                emptyRodHint
                Spacer(minLength: 40)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .bottom, spacing: 18) {
                        ForEach(items) { g in
                            GarmentImage(garment: g)
                                .frame(width: 120, height: 150, alignment: .bottom)
                                .shadow(color: .black.opacity(0.35), radius: 8, x: 6, y: 8)
                                .onTapGesture { open(g) }
                                .accessibilityAddTraits(.isButton)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .frame(height: 170)
                GlassShelf()
                    .padding(.bottom, 10)
            }
        }
    }

    /// Kleine Karte, die an Geburtstag und Jahrestag auf dem Glasboden steht.
    private func specialCard(_ day: SpecialDay) -> some View {
        Button {
            Haptic.success()
            show(CardContent(eyebrow: day.cardTitle, text: day.card))
        } label: {
            VStack(spacing: 3) {
                Image(systemName: "heart.fill")
                    .font(.caption)
                    .foregroundStyle(Palette.rosePetal)
                Text(day.cardTitle)
                    .font(.serif(.caption))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Palette.paper)
                    .shadow(color: .black.opacity(0.3), radius: 5, x: 4, y: 5)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(Palette.bronze.opacity(0.45), lineWidth: 0.75)
            )
            .rotationEffect(.degrees(-3), anchor: .bottom)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Karte: \(day.cardTitle)")
    }

    // MARK: Schubladen

    private var drawers: some View {
        VStack(spacing: 2) {
            // Obere Schublade: alle Stücke im Überblick.
            drawerFront(dot: false)
                .frame(height: 46)
                .contentShape(Rectangle())
                .onTapGesture {
                    Haptic.soft()
                    showAll = true
                }
                .accessibilityLabel("Obere Schublade, alle Stücke")
                .accessibilityAddTraits(.isButton)
            drawerFront(dot: hasUnreadLetter)
                .frame(height: 46)
                .contentShape(Rectangle())
                .offset(y: drawerPulled ? 10 : 0)
                .onTapGesture { pullDrawer() }
                .accessibilityLabel(hasUnreadLetter ? "Unterste Schublade, etwas Neues liegt darin" : "Unterste Schublade")
                .accessibilityAddTraits(.isButton)
        }
        .padding(.horizontal, 14)
        .padding(.top, 2)
        .padding(.bottom, 8)
    }

    private func drawerFront(dot: Bool) -> some View {
        ZStack {
            // Das Holzbild liegt als Overlay, damit es die Schubladengröße nicht verändert.
            Rectangle()
                .fill(LinearGradient(colors: [Palette.oakTop, Palette.oakBottom], startPoint: .top, endPoint: .bottom))
                .overlay {
                    Image("Wood").resizable().scaledToFill().opacity(0.55)
                }
                .clipped()
            LinearGradient(colors: [.black.opacity(0.45), .clear], startPoint: .top, endPoint: .center)
            Capsule()
                .fill(Palette.brassGradient)
                .frame(width: 64, height: 5)
                .shadow(color: .black.opacity(0.4), radius: 2, y: 2)
            if dot {
                Circle()
                    .fill(Palette.gold)
                    .frame(width: 6, height: 6)
                    .shadow(color: Palette.gold, radius: 4)
                    .offset(x: 44)
            }
        }
        .clipped()
    }

    // MARK: Abläufe

    private func open(_ g: Garment) {
        Haptic.light()
        selected = g
    }

    private func show(_ content: CardContent) {
        withAnimation(.spring(response: 0.55, dampingFraction: 0.75)) { card = content }
    }

    private func pullDrawer() {
        Haptic.soft()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { drawerPulled = true }
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            app.showDrawer = true
            try? await Task.sleep(for: .milliseconds(400))
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { drawerPulled = false }
        }
    }

    private func handleScroll(_ x: CGFloat) {
        guard let previous = lastOffset else {
            lastOffset = x
            return
        }
        let dx = x - previous
        lastOffset = x
        guard abs(dx) > 0.5, app.motion(settings) else { return }
        tilt = max(-7, min(7, Double(-dx) * 0.35))
        settleTask?.cancel()
        settleTask = Task {
            try? await Task.sleep(for: .milliseconds(90))
            guard !Task.isCancelled else { return }
            tilt = 0
        }
    }

    private func jiggle(strength: Double) {
        guard app.motion(settings) else { return }
        tilt = strength
        settleTask?.cancel()
        settleTask = Task {
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            tilt = -strength * 0.5
            try? await Task.sleep(for: .milliseconds(140))
            guard !Task.isCancelled else { return }
            tilt = 0
        }
    }

    private func startUp() async {
        if let first = Category.allCases.first(where: { !store.garments(in: $0).isEmpty }),
           store.garments(in: category).isEmpty {
            category = first
        }
        if let open = app.argument("-open") {
            try? await Task.sleep(for: .milliseconds(600))
            switch open {
            case "garment": selected = store.garments(in: .dresses).first ?? store.activeGarments.first
            case "drawer": app.showDrawer = true
            case "all": showAll = true
            default: break
            }
        }
        // Überraschungen erst, wenn die Türen offen sind und die Widmung gelesen ist.
        while !Task.isCancelled && !(app.opened && settings.welcomeSeen) {
            try? await Task.sleep(for: .milliseconds(200))
        }
        guard !Task.isCancelled else { return }
        if special != nil, !app.petalsShown, app.motion(settings) {
            app.petalsShown = true
            try? await Task.sleep(for: .milliseconds(1200))
            showPetals = true
            try? await Task.sleep(for: .seconds(7))
            showPetals = false
        }
        if app.isNight, settings.lastGoodNight != app.nightKey, !app.isDemo {
            store.db.settings.lastGoodNight = app.nightKey
            store.save()
            let lines = Liebesbriefe.goodNight
            let day = Calendar.german.ordinality(of: .day, in: .era, for: Date()) ?? 0
            let pick = lines[day % lines.count]
            try? await Task.sleep(for: .milliseconds(900))
            show(CardContent(eyebrow: "Gute Nacht", text: pick))
        }
    }

    /// Etwa alle zehn Sekunden zieht ein Lichtstreifen über genau ein Teil.
    private func ambientSheen() async {
        var tick = 0
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(10))
            guard !items.isEmpty, app.ambient(settings) else { continue }
            sheenIndex = Int.random(in: 0..<min(items.count, 4))
            sheenTick += 1
            tick += 1
            // Selten ein leiser Luftzug, als ginge jemand vorbei.
            if tick % 4 == 0 { jiggle(strength: 1.6) }
        }
    }
}

/// Seidenglanz, der einmal über den Stoff zieht.
struct SilkSheen: View {
    @State private var x: CGFloat = -1

    var body: some View {
        GeometryReader { geo in
            LinearGradient(
                colors: [.white.opacity(0), .white.opacity(0.45), .white.opacity(0)],
                startPoint: .leading, endPoint: .trailing
            )
            .frame(width: geo.size.width * 0.45)
            .rotationEffect(.degrees(16))
            .offset(x: x * geo.size.width * 1.4)
            .frame(maxHeight: .infinity)
        }
        .blendMode(.screen)
        .onAppear {
            x = -1
            withAnimation(.easeInOut(duration: 1.6)) { x = 1 }
        }
    }
}

// MARK: - Alle Stücke als Raster

struct AllGarmentsView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var filter = 0
    @State private var selected: Garment?

    private var results: [Garment] {
        let q = search.trimmingCharacters(in: .whitespaces)
        return store.db.garments.filter { g in
            switch filter {
            case 1: if !g.isFavorite || g.isArchived { return false }
            case 2: if !g.isArchived { return false }
            default: if g.isArchived { return false }
            }
            if q.isEmpty { return true }
            return g.name.localizedCaseInsensitiveContains(q)
                || g.brand.localizedCaseInsensitiveContains(q)
                || g.memory.localizedCaseInsensitiveContains(q)
                || g.category.title.localizedCaseInsensitiveContains(q)
                || g.colors.contains { $0.title.localizedCaseInsensitiveContains(q) }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                Picker("Auswahl", selection: $filter) {
                    Text("Alle").tag(0)
                    Text("Favoriten").tag(1)
                    Text("Archiv").tag(2)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                if results.isEmpty {
                    ContentUnavailableView.search(text: search)
                        .padding(.top, 60)
                } else {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 18) {
                        ForEach(results) { g in
                            Button {
                                selected = g
                            } label: {
                                VStack(spacing: 8) {
                                    GarmentImage(garment: g)
                                        .frame(height: 170)
                                        .frame(maxWidth: .infinity)
                                        .padding(10)
                                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Palette.card))
                                        .overlay(alignment: .topTrailing) {
                                            if g.isFavorite {
                                                Image(systemName: "heart.fill")
                                                    .font(.caption)
                                                    .foregroundStyle(Palette.accent)
                                                    .padding(10)
                                            }
                                        }
                                    Text(g.name)
                                        .font(.serif(.subheadline))
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
            }
            .background(Palette.sheet.ignoresSafeArea())
            .navigationTitle("Alle Stücke")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: "Name, Marke, Farbe")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
            .sheet(item: $selected) { g in
                GarmentSheet(id: g.id)
            }
        }
    }
}
