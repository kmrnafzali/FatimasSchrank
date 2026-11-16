import SwiftUI
import AppIntents

// MARK: - Siri und Kurzbefehle

struct TodayOutfitIntent: AppIntent {
    static var title: LocalizedStringResource = "Was ziehe ich heute an?"
    static var description = IntentDescription("Schlägt einen Look aus deinem Schrank vor, passend zum Wetter.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = Store()
        let weather = WeatherService()
        let place: ResolvedPlace = store.db.settings.placeMode == .linz ? .linz : .wien
        await weather.refresh(for: place)
        let today = weather.days[Date().dayKey]
        let day = Calendar.german.ordinality(of: .day, in: .era, for: Date()) ?? 0
        guard let look = Stylist.look(from: store.wearableGarments, weather: today, seed: day &* 31,
                                      avoid: store.recentlyWorn(days: 3)) else {
            return .result(dialog: "Dein Schrank ist noch leer. Leg zuerst ein paar Stücke hinein.")
        }
        let names = ListFormatter.localizedString(byJoining: look.garments.map(\.name))
        let weatherText = today.map { "Heute \($0.summary), \($0.tip.lowercased()). " } ?? ""
        let answer = "\(weatherText)Wie wäre es mit \(names)?"
        return .result(dialog: "\(answer)")
    }
}

struct SchrankShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: TodayOutfitIntent(),
            phrases: [
                "Was ziehe ich heute an mit \(.applicationName)",
                "\(.applicationName) Outfit für heute",
            ],
            shortTitle: "Outfit für heute",
            systemImageName: "hanger"
        )
    }
}
