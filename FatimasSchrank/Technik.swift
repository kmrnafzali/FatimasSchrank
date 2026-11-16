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

/// Eigenes Fenster über allem, auch über offenen Blättern und Fenstern der App.
@MainActor
final class LockWindow {
    static let shared = LockWindow()
    private var window: UIWindow?

    var isShowing: Bool { window != nil }

    func show(store: Store) {
        guard window == nil,
              let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first else { return }
        let w = UIWindow(windowScene: scene)
        w.windowLevel = .alert + 1
        let root = LockView { LockWindow.shared.hide() }
            .environment(store)
        let host = UIHostingController(rootView: AnyView(root))
        host.view.backgroundColor = .clear
        w.rootViewController = host
        // Nur einblenden, nicht zum Hauptfenster machen: sonst verliert die App danach die Tastatur.
        w.isHidden = false
        window = w
    }

    func hide() {
        guard let w = window else { return }
        UIView.animate(withDuration: 0.3, animations: {
            w.alpha = 0
        }, completion: { _ in
            w.isHidden = true
        })
        window = nil
    }
}

struct LockView: View {
    @Environment(Store.self) private var store
    let onUnlock: () -> Void
    @State private var failed = false
    @State private var autoTried = false

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
        // Face ID nur fragen, wenn die App im Vordergrund ist, und von selbst nur einmal.
        .task {
            // Beim Start ist die App einen Moment lang noch nicht aktiv: kurz warten.
            var waited = 0
            while UIApplication.shared.applicationState != .active && waited < 20 {
                try? await Task.sleep(for: .milliseconds(100))
                waited += 1
            }
            guard UIApplication.shared.applicationState == .active, !autoTried else { return }
            autoTried = true
            await unlock()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            guard !autoTried else { return }
            autoTried = true
            Task { await unlock() }
        }
    }

    private func unlock() async {
        failed = false
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
