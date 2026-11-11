import SwiftUI
import Observation

@main
struct FatimasSchrankApp: App {
    @State private var store = Store()
    @State private var app = AppState()
    @State private var location = LocationService()
    @State private var weather = WeatherService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.locale, .german)
                .environment(store)
                .environment(app)
                .environment(location)
                .environment(weather)
        }
    }
}

/// Zustand, der nur während der Laufzeit gilt.
@MainActor
@Observable
final class AppState {
    var tab = 0
    var light: Double = 1
    var swayPulse = 0
    var shakePulse = 0
    var rodSparkle = false
    var milestone: Int?
    var showDrawer = false
    var petalsShown = false
    var opened = false

    let arguments = ProcessInfo.processInfo.arguments

    var isDemo: Bool { arguments.contains("-demo") }

    func argument(_ name: String) -> String? {
        guard let i = arguments.firstIndex(of: name), i + 1 < arguments.count else { return nil }
        return arguments[i + 1]
    }

    /// Bewegung ist erlaubt, wenn sie eingeschaltet ist und das System sie nicht reduziert.
    func motion(_ settings: Settings) -> Bool {
        settings.motionEnabled && !UIAccessibility.isReduceMotionEnabled
    }

    /// Ruhige Dauerbewegungen (Glanz, Luftzug) zusätzlich nicht im Stromsparmodus.
    func ambient(_ settings: Settings) -> Bool {
        motion(settings) && !ProcessInfo.processInfo.isLowPowerModeEnabled
    }

    var isNight: Bool {
        let hour = Calendar.german.component(.hour, from: Date())
        return hour >= 23 || hour < 5
    }

    /// Schlüssel für "diese Nacht" (nach Mitternacht zählt noch der Vortag).
    var nightKey: String {
        let now = Date()
        let hour = Calendar.german.component(.hour, from: now)
        let day = hour < 5 ? Calendar.german.date(byAdding: .day, value: -1, to: now) ?? now : now
        return day.dayKey
    }
}

extension Notification.Name {
    static let deviceShaken = Notification.Name("deviceShaken")
}

extension UIWindow {
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            NotificationCenter.default.post(name: .deviceShaken, object: nil)
        }
        super.motionEnded(motion, with: event)
    }
}

struct RootView: View {
    @Environment(Store.self) private var store
    @Environment(AppState.self) private var app
    @State private var doorsVisible = false
    @State private var started = false

    var body: some View {
        @Bindable var app = app
        TabView(selection: $app.tab) {
            ClosetView()
                .tabItem { Label("Schrank", systemImage: "hanger") }
                .tag(0)
            OutfitsView()
                .tabItem { Label("Outfits", systemImage: "sparkles") }
                .tag(1)
            CalendarView()
                .tabItem { Label("Kalender", systemImage: "calendar") }
                .tag(2)
            MoreView()
                .tabItem { Label("Mehr", systemImage: "heart") }
                .tag(3)
        }
        .tint(Palette.accent)
        .overlay {
            if doorsVisible {
                DoorsView(autoOpen: app.argument("-screen") != "doors") {
                    withAnimation(.easeOut(duration: 0.35)) { doorsVisible = false }
                    lightUp()
                }
                .transition(.opacity)
            }
        }
        .fullScreenCover(isPresented: Binding(
            get: { started && !doorsVisible && !store.db.settings.welcomeSeen },
            set: { _ in }
        )) {
            WelcomeView()
                .environment(store)
        }
        .onReceive(NotificationCenter.default.publisher(for: .deviceShaken)) { _ in
            app.shakePulse += 1
        }
        .task {
            guard !started else { return }
            if app.isDemo {
                await Demo.prepare(store: store, app: app)
            }
            if let tab = app.argument("-tab"), let n = Int(tab) { app.tab = n }
            let wantsDoors = store.db.settings.doorsEnabled
                && !UIAccessibility.isReduceMotionEnabled
                && !app.arguments.contains("-noDoors")
            doorsVisible = wantsDoors
            if !wantsDoors { lightUp() }
            started = true
        }
    }

    private func lightUp() {
        app.opened = true
        let target: Double = app.isNight ? 0.72 : 1
        if app.motion(store.db.settings) {
            app.light = 0.25
            withAnimation(.easeOut(duration: 0.9)) { app.light = target }
            app.swayPulse += 1
        } else {
            app.light = target
        }
    }
}
