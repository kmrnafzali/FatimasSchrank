import SwiftUI

/// Ein Stück, herausgenommen aus dem Schrank, mit Papieretikett.
struct GarmentSheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    let id: UUID
    var startEditing = false

    @State private var editing = false
    @State private var confirmDelete = false
    @State private var beats = 0
    @State private var lifted = false
    @State private var tagSwing: Double = 14
    @State private var wornToday = false

    var body: some View {
        NavigationStack {
            Group {
                if let g = store.garment(id) {
                    content(g)
                } else {
                    ContentUnavailableView("Nicht mehr im Schrank", systemImage: "hanger")
                }
            }
            .background(Palette.sheet.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { dismiss() }
                }
                if let g = store.garment(id) {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button {
                            var copy = g
                            copy.isFavorite.toggle()
                            store.update(copy)
                            Haptic.light()
                        } label: {
                            Image(systemName: g.isFavorite ? "heart.fill" : "heart")
                                .symbolEffect(.bounce, value: g.isFavorite)
                        }
                        .accessibilityLabel(g.isFavorite ? "Aus Favoriten entfernen" : "Zu Favoriten")
                        Menu {
                            Button {
                                editing = true
                            } label: {
                                Label("Bearbeiten", systemImage: "pencil")
                            }
                            Button {
                                var copy = g
                                copy.isArchived.toggle()
                                store.update(copy)
                            } label: {
                                Label(g.isArchived ? "Zurück in den Schrank" : "Archivieren", systemImage: "archivebox")
                            }
                            Button(role: .destructive) {
                                confirmDelete = true
                            } label: {
                                Label("Löschen", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                        }
                        .accessibilityLabel("Weitere Aktionen")
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $editing) {
                if let g = store.garment(id) {
                    GarmentEditor(original: g)
                }
            }
            .confirmationDialog("Dieses Stück löschen?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Löschen", role: .destructive) {
                    store.deleteGarment(id)
                    dismiss()
                }
                Button("Abbrechen", role: .cancel) {}
            } message: {
                Text("Es verschwindet auch aus allen Outfits und kann nicht wiederhergestellt werden.")
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .task {
            // Erst öffnen, wenn dieses Blatt fertig eingeblendet ist.
            guard startEditing else { return }
            try? await Task.sleep(for: .milliseconds(450))
            editing = true
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) { lifted = true }
            withAnimation(.spring(response: 0.9, dampingFraction: 0.22).delay(0.15)) { tagSwing = -2 }
        }
    }

    private func content(_ g: Garment) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                ZStack {
                    RadialGradient(colors: [Palette.led.opacity(0.55), .clear], center: .top, startRadius: 0, endRadius: 320)
                    GarmentImage(garment: g, full: true)
                        .frame(height: 380)
                        .shadow(color: .black.opacity(0.28), radius: 18, x: 10, y: 16)
                        .scaleEffect(lifted ? 1 : 0.9, anchor: .top)
                        .offset(y: lifted ? 0 : -30)
                        .padding(.top, 8)
                }
                .frame(height: 400)

                // Schnur und Etikett
                Rectangle()
                    .fill(Palette.bronze.opacity(0.6))
                    .frame(width: 1, height: 26)
                PaperTag(rotation: tagSwing) {
                    tagContent(g)
                }
                .padding(.horizontal, 40)

                Button {
                    store.wearToday(g)
                    Haptic.success()
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { wornToday = true }
                } label: {
                    Label(wornToday ? "Für heute eingetragen" : "Heute tragen", systemImage: wornToday ? "checkmark" : "sun.max")
                }
                .buttonStyle(PrimaryCapsuleStyle())
                .padding(.horizontal, 24)
                .padding(.top, 32)
                .padding(.bottom, 20)
                companions(g)
                    .padding(.bottom, 16)
                similarRow(g)
                    .padding(.bottom, 30)
            }
        }
    }

    /// Stücke derselben Art oder Farbe.
    private func similarRow(_ g: Garment) -> some View {
        pieceRow("Ähnliche Stücke", Stylist.similar(to: g, in: store.activeGarments))
    }

    /// Stücke aus anderen Kategorien, die farblich passen.
    private func companions(_ g: Garment) -> some View {
        pieceRow("Passt dazu", Stylist.companions(for: g, in: store.activeGarments))
    }

    @ViewBuilder
    private func pieceRow(_ title: String, _ matches: [Garment]) -> some View {
        if !matches.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.serif(.headline))
                    .padding(.horizontal, 24)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(matches) { m in
                            VStack(spacing: 6) {
                                GarmentImage(garment: m)
                                    .frame(width: 70, height: 88)
                                    .padding(6)
                                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Palette.card))
                                Text(m.name)
                                    .font(.caption)
                                    .lineLimit(1)
                                    .frame(width: 82)
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                    .padding(.horizontal, 24)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func tagContent(_ g: Garment) -> some View {
        VStack(spacing: 10) {
            Text(g.name)
                .font(.serif(.title2))
                .foregroundStyle(Palette.ink)
                .multilineTextAlignment(.center)
            let details = [g.brand, g.size.isEmpty ? "" : "Größe \(g.size)", g.category.singular]
                .filter { !$0.isEmpty }
                .joined(separator: " · ")
            Text(details)
                .font(.footnote)
                .foregroundStyle(Palette.inkSecondary)
                .multilineTextAlignment(.center)
            if !g.colors.isEmpty {
                ColorDots(colors: g.colors)
            }
            if !g.memory.isEmpty {
                Rectangle().fill(Palette.bronze.opacity(0.4)).frame(width: 30, height: 0.75)
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Button {
                        Haptic.firm()
                        beats += 1
                        Task {
                            try? await Task.sleep(for: .milliseconds(180))
                            Haptic.light()
                            beats += 1
                        }
                        store.discover("herzschlag")
                    } label: {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(Palette.rosePetal)
                            .symbolEffect(.bounce, value: beats)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Herz")
                    Text(g.memory)
                        .font(.serif(.callout).italic())
                        .foregroundStyle(Palette.ink)
                        .multilineTextAlignment(.leading)
                }
            }
            let worn = store.wornCount(g)
            Text(worn == 0 ? "Noch nicht getragen" : (worn == 1 ? "Einmal getragen" : "\(worn)-mal getragen"))
                .font(.footnote.weight(.medium))
                .foregroundStyle(Palette.bronze)
            if g.disposal != .keep {
                Label("Zum \(g.disposal.title) vorgemerkt", systemImage: "archivebox")
                    .font(.footnote)
                    .foregroundStyle(Palette.inkSecondary)
            }
            if !g.alteration.isEmpty {
                Label("Schneiderei: \(g.alteration)", systemImage: "scissors")
                    .font(.footnote)
                    .foregroundStyle(Palette.inkSecondary)
            }
            if !g.note.isEmpty {
                Text(g.note)
                    .font(.footnote)
                    .foregroundStyle(Palette.inkSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, 4)
    }
}

struct GarmentEditor: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var draft: Garment

    init(original: Garment) {
        _draft = State(initialValue: original)
    }

    private func seasonChip(_ s: Season) -> some View {
        let on = draft.seasons.contains(s)
        return Button {
            if on {
                draft.seasons.removeAll { $0 == s }
            } else {
                draft.seasons.append(s)
            }
        } label: {
            Text(s.title)
                .font(.footnote.weight(on ? .semibold : .regular))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(on ? Palette.accent.opacity(0.2) : Palette.card))
                .foregroundStyle(on ? Palette.accent : Color.primary)
        }
        .buttonStyle(.borderless)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private func areaBinding(_ name: String) -> Binding<Bool> {
        Binding(
            get: { draft.tags.contains(name) },
            set: { on in
                if on {
                    if !draft.tags.contains(name) { draft.tags.append(name) }
                } else {
                    draft.tags.removeAll { $0 == name }
                }
            }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $draft.name)
                    Picker("Kategorie", selection: $draft.category) {
                        ForEach(Category.allCases) { c in
                            Text(c.title).tag(c)
                        }
                    }
                    TextField("Marke", text: $draft.brand)
                    TextField("Größe", text: $draft.size)
                }
                Section("Farben") {
                    ColorPickerRow(selection: $draft.colors)
                }
                Section {
                    TextField("Getragen beim ersten Date …", text: $draft.memory, axis: .vertical)
                        .lineLimit(1...4)
                } header: {
                    Text("Erinnerung")
                } footer: {
                    Text("Eine Erinnerung bekommt ein kleines Herz auf dem Etikett.")
                }
                Section("Notiz") {
                    TextField("Pflege, Passform, Anlass …", text: $draft.note, axis: .vertical)
                        .lineLimit(1...5)
                }
                Section("Saison") {
                    HStack(spacing: 8) {
                        ForEach(Season.allCases) { s in
                            seasonChip(s)
                        }
                    }
                }
                if !store.db.settings.customAreas.isEmpty {
                    Section("Bereiche") {
                        ForEach(store.db.settings.customAreas, id: \.self) { name in
                            Toggle(name, isOn: areaBinding(name))
                        }
                    }
                }
                Section {
                    Toggle("Lieblingsstück", isOn: $draft.isFavorite)
                    Toggle("Archiviert", isOn: $draft.isArchived)
                    Picker("Aussortieren", selection: $draft.disposal) {
                        ForEach(Disposal.allCases) { d in
                            Text(d.title).tag(d)
                        }
                    }
                }
                Section {
                    TextField("Zum Beispiel: Saum kürzen", text: $draft.alteration)
                    Toggle("Erinnern", isOn: Binding(
                        get: { draft.alterationDue != nil },
                        set: { on in
                            draft.alterationDue = on ? (Calendar.german.date(byAdding: .day, value: 7, to: Date()) ?? Date()) : nil
                        }
                    ))
                    if let due = draft.alterationDue {
                        DatePicker("Am", selection: Binding(
                            get: { due },
                            set: { draft.alterationDue = $0 }
                        ), displayedComponents: [.date, .hourAndMinute])
                    }
                } header: {
                    Text("Schneiderei")
                } footer: {
                    Text("Mit Erinnerung bekommst du eine Mitteilung, wenn es Zeit für den Schneider ist.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.sheet.ignoresSafeArea())
            .navigationTitle("Bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") {
                        var g = draft
                        if g.name.trimmingCharacters(in: .whitespaces).isEmpty { g.name = g.category.singular }
                        store.update(g)
                        Reminders.updateAlteration(for: g)
                        Haptic.light()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}
