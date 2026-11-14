import SwiftUI
import LocalAuthentication
import AppIntents

// MARK: - Face ID

enum Unlocker {
    /// Fragt nach Face ID, Touch ID oder dem Gerätecode.
    /// Ist auf dem Gerät gar kein Code eingerichtet, sperrt die App niemanden aus.
    @MainActor
    static func authenticate() async -> Bool {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else { return true }
        do {
            return try await context.evaluatePolicy(.deviceOwnerAuthentication,
                                                    localizedReason: "Damit nur du deinen Schrank öffnest.")
        } catch {
            return false
        }
    }
}

struct LockView: View {
    @Environment(Store.self) private var store
    let onUnlock: () -> Void
    @State private var failed = false

    var body: some View {
        ZStack {
            WoodBackground(shade: 0.5)
            VStack(spacing: 22) {
                MonogramBadge(text: store.db.settings.monogram, kind: store.db.settings.monogramShape)
                Text("Fatimas Schrank")
                    .font(.serif(.title))
                    .foregroundStyle(Palette.cream)
                Button {
                    Task { await unlock() }
                } label: {
                    Label("Entsperren", systemImage: "faceid")
                }
                .buttonStyle(CreamCapsuleStyle())
                .frame(maxWidth: 260)
                if failed {
                    Text("Das hat nicht geklappt. Versuch es noch einmal.")
                        .font(.footnote)
                        .foregroundStyle(Palette.creamSecondary)
                }
            }
            .padding(32)
        }
        .task { await unlock() }
    }

    private func unlock() async {
        if await Unlocker.authenticate() {
            onUnlock()
        } else {
            failed = true
        }
    }
}

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
