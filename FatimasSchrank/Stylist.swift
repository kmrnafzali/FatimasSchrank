import Foundation

/// Gleichbleibender Zufall: derselbe Startwert ergibt denselben Vorschlag.
struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64

    init(seed: Int) {
        state = UInt64(bitPattern: Int64(seed))
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// Stellt Looks aus dem Schrank zusammen, passend zum Wetter und zu den Farben.
enum Stylist {
    struct Look {
        var garments: [Garment]
        var reason: String
    }

    /// Farben, die zu allem passen.
    static let neutrals: Set<GarmentColor> = [.black, .white, .cream, .grey, .beige, .camel, .navy, .brown, .gold, .silver]

    /// Bunte Paare, die gut zusammen aussehen.
    static let pairs: Set<Set<GarmentColor>> = [
        [.bordeaux, .pink], [.green, .pink], [.blue, .pink], [.red, .blue],
        [.purple, .pink], [.green, .blue], [.yellow, .blue], [.orange, .blue],
    ]

    /// Passen zwei Stücke farblich zusammen?
    static func matches(_ a: [GarmentColor], _ b: [GarmentColor]) -> Bool {
        if a.isEmpty || b.isEmpty { return true }
        let colorfulA = Set(a).subtracting(neutrals)
        let colorfulB = Set(b).subtracting(neutrals)
        if colorfulA.isEmpty || colorfulB.isEmpty { return true }
        if !colorfulA.isDisjoint(with: colorfulB) { return true }
        for x in colorfulA {
            for y in colorfulB where pairs.contains([x, y]) {
                return true
            }
        }
        return false
    }

    /// Ein ganzer Look: Kleid oder Oberteil mit Hose, dazu Schuhe, Tasche und bei Kälte oder Regen ein Mantel.
    static func look(from all: [Garment], weather: DayWeather?, seed: Int) -> Look? {
        let items = all.filter { !$0.isArchived }
        var rng = SplitMix64(seed: seed)
        func pool(_ c: Category) -> [Garment] { items.filter { $0.category == c } }

        let cold = (weather?.tmax ?? 15) < 15 || (weather?.isRainy ?? false)
        let dresses = pool(.dresses)
        let tops = pool(.tops)
        let bottoms = pool(.bottoms)

        var result: [Garment] = []
        let useDress = !dresses.isEmpty && (tops.isEmpty || bottoms.isEmpty || rng.next() % 2 == 0)
        if useDress, let dress = dresses.randomElement(using: &rng) {
            result = [dress]
        } else if let top = tops.randomElement(using: &rng) {
            let fitting = bottoms.filter { matches($0.colors, top.colors) }
            if let bottom = (fitting.isEmpty ? bottoms : fitting).randomElement(using: &rng) {
                result = [top, bottom]
            } else {
                result = [top]
            }
        } else if let bottom = bottoms.randomElement(using: &rng) {
            result = [bottom]
        }
        guard !result.isEmpty else { return nil }

        let baseColors = result.flatMap(\.colors)
        func pick(_ c: Category) -> Garment? {
            let candidates = pool(c)
            let fitting = candidates.filter { matches($0.colors, baseColors) }
            return (fitting.isEmpty ? candidates : fitting).randomElement(using: &rng)
        }
        if cold, let coat = pick(.outerwear) { result.append(coat) }
        if let shoes = pick(.shoes) { result.append(shoes) }
        if let bag = pick(.bags) { result.append(bag) }
        if rng.next() % 3 == 0, let accessory = pick(.accessories) { result.append(accessory) }

        let reason: String
        if let weather {
            reason = "\(weather.summary) · \(weather.tip)"
        } else {
            reason = "Passend zu deinen Farben"
        }
        return Look(garments: result, reason: reason)
    }

    /// Stücke aus anderen Kategorien, die farblich zu diesem passen.
    static func companions(for g: Garment, in all: [Garment]) -> [Garment] {
        let clash: Set<Category>
        switch g.category {
        case .dresses: clash = [.dresses, .tops, .bottoms]
        case .tops, .bottoms: clash = [g.category, .dresses]
        default: clash = [g.category]
        }
        let order = Category.allCases
        let found = all
            .filter { $0.id != g.id && !$0.isArchived && !clash.contains($0.category) && matches($0.colors, g.colors) }
            .sorted { (order.firstIndex(of: $0.category) ?? 0) < (order.firstIndex(of: $1.category) ?? 0) }
        return Array(found.prefix(12))
    }

    // MARK: Reisen

    /// Alle Tage einer Reise, höchstens 31.
    static func days(from start: Date, to end: Date) -> [Date] {
        let cal = Calendar.german
        var result: [Date] = []
        var day = cal.startOfDay(for: start)
        let last = cal.startOfDay(for: end)
        while day <= last && result.count < 31 {
            result.append(day)
            guard let next = cal.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return result
    }

    /// Plant für jeden Reisetag einen Look und macht daraus die Packliste.
    static func fill(_ trip: Trip, garments: [Garment], weather: [String: DayWeather], variant: Int = 0) -> Trip {
        var t = trip
        t.plan = [:]
        var all: [UUID] = []
        var base = variant &* 104_729
        for scalar in trip.id.uuidString.unicodeScalars {
            base = base &+ Int(scalar.value)
        }
        for (i, day) in days(from: trip.start, to: trip.end).enumerated() {
            guard let daily = Stylist.look(from: garments, weather: weather[day.dayKey], seed: base &+ i &* 7_919) else { continue }
            let ids = daily.garments.map(\.id)
            t.plan[day.dayKey] = ids
            for id in ids where !all.contains(id) {
                all.append(id)
            }
        }
        t.garmentIDs = all
        t.packed = t.packed.filter { all.contains($0) }
        return t
    }
}
