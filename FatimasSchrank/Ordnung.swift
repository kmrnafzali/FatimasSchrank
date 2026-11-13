import SwiftUI
import UserNotifications

// MARK: - Suche in Alltagssprache

/// Versteht Suchen wie "rote Kleider" oder "schwarze Schuhe von Zara".
/// Funktioniert auch mit dem Mikrofon der Tastatur.
struct SearchQuery {
    var colors: Set<GarmentColor> = []
    var categories: Set<Category> = []
    var words: [String] = []

    private static let fillers: Set<String> = [
        "zeig", "zeige", "mir", "alle", "alles", "meine", "mein", "meinen", "die", "der", "das", "den", "dem",
        "mit", "und", "in", "im", "von", "aus", "kleidung", "stücke", "stück", "bitte", "ein", "eine", "einen",
    ]

    private static let colorStems: [(String, GarmentColor)] = [
        ("bordeaux", .bordeaux), ("weinrot", .bordeaux), ("dunkelblau", .navy), ("marine", .navy), ("navy", .navy),
        ("schwarz", .black), ("weiß", .white), ("weiss", .white), ("creme", .cream), ("grau", .grey),
        ("beige", .beige), ("camel", .camel), ("kamel", .camel), ("braun", .brown), ("rosa", .pink),
        ("rosé", .pink), ("rose", .pink), ("pink", .pink), ("rot", .red), ("orange", .orange), ("gelb", .yellow),
        ("grün", .green), ("gruen", .green), ("blau", .blue), ("lila", .purple), ("violett", .purple),
        ("gold", .gold), ("silber", .silver),
    ]

    private static let categoryStems: [(String, Category)] = [
        ("kleid", .dresses), ("mantel", .outerwear), ("mäntel", .outerwear), ("jacke", .outerwear),
        ("blazer", .outerwear), ("oberteil", .tops), ("bluse", .tops), ("shirt", .tops), ("pullover", .tops),
        ("pulli", .tops), ("top", .tops), ("hose", .bottoms), ("jeans", .bottoms), ("rock", .bottoms),
        ("röck", .bottoms), ("schuh", .shoes), ("pumps", .shoes), ("stiefel", .shoes), ("sneaker", .shoes),
        ("tasche", .bags), ("handtasche", .bags), ("schmuck", .accessories), ("kette", .accessories),
        ("uhr", .accessories), ("schal", .accessories), ("gürtel", .accessories), ("accessoire", .accessories),
    ]

    static func parse(_ text: String) -> SearchQuery {
        var query = SearchQuery()
        let words = text.lowercased()
            .split(whereSeparator: { !$0.isLetter })
            .map(String.init)
        for word in words where !fillers.contains(word) {
            if let match = colorStems.first(where: { word.hasPrefix($0.0) }) {
                query.colors.insert(match.1)
            } else if let match = categoryStems.first(where: { word.hasPrefix($0.0) }) {
                query.categories.insert(match.1)
            } else {
                query.words.append(word)
            }
        }
        return query
    }

    func matches(_ g: Garment) -> Bool {
        if !colors.isEmpty && colors.isDisjoint(with: g.colors) { return false }
        if !categories.isEmpty && !categories.contains(g.category) { return false }
        let texts = [g.name, g.brand, g.memory, g.note, g.category.title] + g.tags + g.colors.map(\.title)
        for word in words where !texts.contains(where: { $0.localizedCaseInsensitiveContains(word) }) {
            return false
        }
        return true
    }
}

// MARK: - Erinnerungen

enum Reminders {
    /// Plant die Erinnerung für den Schneider neu oder löscht sie.
    static func updateAlteration(for g: Garment) {
        let center = UNUserNotificationCenter.current()
        let id = "schneiderei-\(g.id.uuidString)"
        center.removePendingNotificationRequests(withIdentifiers: [id])
        guard let due = g.alterationDue, due > Date() else { return }
        let name = g.name
        let task = g.alteration
        let parts = Calendar.german.dateComponents([.year, .month, .day, .hour, .minute], from: due)
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "Ab zum Schneider"
            content.body = task.isEmpty ? "\(name) wartet auf den Schneider." : "\(name): \(task)"
            content.sound = .default
            let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
            center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
        }
    }
}

// MARK: - Schmuckkästchen

struct JewelryBoxView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var opened: Garment?

    private var pieces: [Garment] { store.garments(in: .accessories) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    Text("Schmuckkästchen")
                        .font(.serif(.largeTitle))
                        .foregroundStyle(Palette.cream)
                        .padding(.top, 8)
                    Text(pieces.isEmpty
                         ? "Noch leer. Schmuck, Uhren und Schals legst du in der Kategorie Accessoires an."
                         : pieces.count.stuecke)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Palette.creamSecondary)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                        ForEach(pieces) { g in
                            Button {
                                opened = g
                            } label: {
                                GarmentImage(garment: g)
                                    .padding(12)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 104)
                                    .background(compartment)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(g.name)
                        }
                        ForEach(0..<max(0, 9 - pieces.count), id: \.self) { _ in
                            compartment
                                .frame(height: 104)
                                .accessibilityHidden(true)
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color(hex: 0x2A0912))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Palette.brass.opacity(0.6), lineWidth: 1)
                    )
                }
                .padding()
            }
            .background(WoodBackground(shade: 0.5))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
            .sheet(item: $opened) { g in
                GarmentSheet(id: g.id)
            }
        }
    }

    /// Ein Fach mit Samteinlage.
    private var compartment: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(RadialGradient(colors: [Color(hex: 0x7E2238), Color(hex: 0x4B1020)], center: .top, startRadius: 2, endRadius: 120))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.4), lineWidth: 2)
            )
    }
}

// MARK: - Aussortieren und Schneiderei

struct SortOutView: View {
    @Environment(Store.self) private var store
    @State private var opened: Garment?

    var body: some View {
        let sell = store.activeGarments.filter { $0.disposal == .sell }
        let donate = store.activeGarments.filter { $0.disposal == .donate }
        let tailor = store.activeGarments.filter { !$0.alteration.isEmpty }
        List {
            if sell.isEmpty && donate.isEmpty && tailor.isEmpty {
                ContentUnavailableView(
                    "Alles bleibt",
                    systemImage: "archivebox",
                    description: Text("Im Bearbeiten-Fenster eines Stücks kannst du es zum Verkaufen oder Spenden vormerken oder eine Notiz für den Schneider anlegen.")
                )
                .listRowBackground(Color.clear)
            }
            disposalSection("Verkaufen", sell)
            disposalSection("Spenden", donate)
            if !tailor.isEmpty {
                Section("Schneiderei") {
                    ForEach(tailor) { g in
                        row(g, detail: alterationDetail(g))
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Palette.sheet.ignoresSafeArea())
        .navigationTitle("Aussortieren")
        .sheet(item: $opened) { g in
            GarmentSheet(id: g.id)
        }
    }

    private func alterationDetail(_ g: Garment) -> String {
        guard let due = g.alterationDue else { return g.alteration }
        return "\(g.alteration) · \(due.german(.dateTime.day().month(.abbreviated)))"
    }

    @ViewBuilder
    private func disposalSection(_ title: String, _ items: [Garment]) -> some View {
        if !items.isEmpty {
            Section {
                ForEach(items) { g in
                    row(g, detail: g.brand)
                        .swipeActions {
                            Button("Ist weg") {
                                var copy = g
                                copy.isArchived = true
                                store.update(copy)
                                Haptic.success()
                            }
                            .tint(Palette.accent)
                        }
                }
            } header: {
                Text(title)
            } footer: {
                Text("Nach links wischen, wenn das Stück weg ist. Es bleibt im Archiv.")
            }
        }
    }

    private func row(_ g: Garment, detail: String) -> some View {
        Button {
            opened = g
        } label: {
            HStack(spacing: 12) {
                GarmentImage(garment: g)
                    .frame(width: 44, height: 54)
                VStack(alignment: .leading, spacing: 2) {
                    Text(g.name)
                        .foregroundStyle(.primary)
                    if !detail.isEmpty {
                        Text(detail)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
