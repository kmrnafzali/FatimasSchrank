import SwiftUI

// MARK: - Kategorien und Farben

enum Category: String, Codable, CaseIterable, Identifiable {
    case dresses, outerwear, tops, bottoms, shoes, bags, accessories

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = Category(rawValue: raw) ?? .tops
    }

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dresses: return "Kleider"
        case .outerwear: return "Mäntel & Jacken"
        case .tops: return "Oberteile"
        case .bottoms: return "Hosen & Röcke"
        case .shoes: return "Schuhe"
        case .bags: return "Taschen"
        case .accessories: return "Accessoires"
        }
    }

    var singular: String {
        switch self {
        case .dresses: return "Kleid"
        case .outerwear: return "Jacke"
        case .tops: return "Oberteil"
        case .bottoms: return "Hose"
        case .shoes: return "Schuhe"
        case .bags: return "Tasche"
        case .accessories: return "Accessoire"
        }
    }

    var symbol: String {
        switch self {
        case .dresses: return "figure.dress.line.vertical.figure"
        case .outerwear: return "cloud.drizzle"
        case .tops: return "tshirt"
        case .bottoms: return "rectangle.portrait.split.2x1"
        case .shoes: return "shoeprints.fill"
        case .bags: return "handbag"
        case .accessories: return "sparkle"
        }
    }

    /// Endung für ein Farbadjektiv davor: das Kleid → "es", die Jacke → "e", die Schuhe → "e".
    var adjectiveEnding: String {
        switch self {
        case .dresses, .tops, .accessories: return "es"
        case .outerwear, .bottoms, .shoes, .bags: return "e"
        }
    }

    /// Hängt an der Stange (sonst steht es auf dem Glasboden).
    var hangs: Bool {
        switch self {
        case .shoes, .bags, .accessories: return false
        default: return true
        }
    }
}

enum GarmentColor: String, Codable, CaseIterable, Identifiable {
    case black, white, cream, grey, beige, camel, brown, red, bordeaux, pink, orange, yellow, green, blue, navy, purple, gold, silver

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = GarmentColor(rawValue: raw) ?? .black
    }

    var id: String { rawValue }

    var title: String {
        switch self {
        case .black: return "Schwarz"
        case .white: return "Weiß"
        case .cream: return "Creme"
        case .grey: return "Grau"
        case .beige: return "Beige"
        case .camel: return "Camel"
        case .brown: return "Braun"
        case .red: return "Rot"
        case .bordeaux: return "Bordeaux"
        case .pink: return "Rosé"
        case .orange: return "Orange"
        case .yellow: return "Gelb"
        case .green: return "Grün"
        case .blue: return "Blau"
        case .navy: return "Marine"
        case .purple: return "Lila"
        case .gold: return "Gold"
        case .silver: return "Silber"
        }
    }

    var hex: UInt32 {
        switch self {
        case .black: return 0x1A1A1A
        case .white: return 0xF8F8F6
        case .cream: return 0xF1E8D6
        case .grey: return 0x9A9A9E
        case .beige: return 0xDCC9A6
        case .camel: return 0xC19A6B
        case .brown: return 0x6B4A33
        case .red: return 0xC4262E
        case .bordeaux: return 0x6E1A2D
        case .pink: return 0xEDB5BC
        case .orange: return 0xE8853A
        case .yellow: return 0xF0D04C
        case .green: return 0x2F7D5F
        case .blue: return 0x3D6BC4
        case .navy: return 0x1F2D4D
        case .purple: return 0x7E5BA6
        case .gold: return 0xC9A565
        case .silver: return 0xC7C9CC
        }
    }

    var color: Color { Color(hex: hex) }

    /// Reihenfolge für die Regenbogen-Ordnung im Schrank.
    static let rainbow: [GarmentColor] = [
        .red, .bordeaux, .pink, .orange, .yellow, .gold, .camel, .beige, .brown,
        .green, .blue, .navy, .purple, .silver, .grey, .white, .cream, .black,
    ]

    /// Stamm für die Beugung ("schwarz" → "Schwarzes Kleid"). Nil, wenn die Farbe nicht gebeugt wird.
    var adjectiveStem: String? {
        switch self {
        case .black: return "schwarz"
        case .white: return "weiß"
        case .grey: return "grau"
        case .brown: return "braun"
        case .red: return "rot"
        case .yellow: return "gelb"
        case .green: return "grün"
        case .blue: return "blau"
        case .navy: return "marineblau"
        case .gold: return "golden"
        case .silver: return "silbern"
        default: return nil
        }
    }

    /// Vorschlag für den Namen, zum Beispiel "Schwarzes Kleid" oder "Jacke in Camel".
    static func suggestedName(for category: Category, colors: [GarmentColor]) -> String {
        guard let first = colors.first else { return category.singular }
        if let stem = first.adjectiveStem {
            let adjective = stem + category.adjectiveEnding
            let capitalized = adjective.prefix(1).uppercased() + String(adjective.dropFirst())
            return "\(capitalized) \(category.singular)"
        }
        return "\(category.singular) in \(first.title)"
    }

    /// Nächstliegende Farbe zu einem Bildpunkt (gewichteter RGB-Abstand).
    static func nearest(red r: Int, green g: Int, blue b: Int) -> GarmentColor {
        // Farblose Töne zuerst nach Helligkeit, sonst landet Dunkelgrau bei Braun.
        let spread = max(r, g, b) - min(r, g, b)
        if spread <= 28 {
            let light = (r + g + b) / 3
            if light < 55 { return .black }
            if light < 215 { return .grey }
            return .white
        }
        var best = GarmentColor.black
        var bestDistance = Int.max
        for c in allCases {
            let cr = Int((c.hex >> 16) & 0xFF), cg = Int((c.hex >> 8) & 0xFF), cb = Int(c.hex & 0xFF)
            let mean = (r + cr) / 2
            let dr = r - cr, dg = g - cg, db = b - cb
            // Klammern sind nötig: ">>" bindet in Swift stärker als "*".
            let redPart = ((512 + mean) * dr * dr) / 256
            let greenPart = 4 * dg * dg
            let bluePart = ((767 - mean) * db * db) / 256
            let distance = redPart + greenPart + bluePart
            if distance < bestDistance {
                bestDistance = distance
                best = c
            }
        }
        return best
    }

    var isLight: Bool {
        switch self {
        case .white, .cream, .beige, .yellow, .silver, .pink: return true
        default: return false
        }
    }
}

// MARK: - Datenmodell

struct Garment: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var category: Category
    var brand = ""
    var size = ""
    var colors: [GarmentColor] = []
    var memory = ""
    var note = ""
    var imageFile = ""
    var thumbFile = ""
    var added = Date()
    var isFavorite = false
    var isArchived = false
    /// Eigene Bereiche, zum Beispiel "Sport".
    var tags: [String] = []
    var seasons: [Season] = []
    var disposal = Disposal.keep
    /// Notiz für den Schneider.
    var alteration = ""
    var alterationDue: Date? = nil

    /// Platz in der Regenbogen-Ordnung, ohne Farbe ganz hinten.
    var rainbowRank: Int {
        guard let first = colors.first, let index = GarmentColor.rainbow.firstIndex(of: first) else { return 99 }
        return index
    }
}

enum Season: String, Codable, CaseIterable, Identifiable {
    case spring, summer, autumn, winter

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = Season(rawValue: raw) ?? .spring
    }

    var id: String { rawValue }

    var title: String {
        switch self {
        case .spring: return "Frühling"
        case .summer: return "Sommer"
        case .autumn: return "Herbst"
        case .winter: return "Winter"
        }
    }

    static func current(_ date: Date = Date()) -> Season {
        switch Calendar.german.component(.month, from: date) {
        case 3...5: return .spring
        case 6...8: return .summer
        case 9...11: return .autumn
        default: return .winter
        }
    }
}

enum Disposal: String, Codable, CaseIterable, Identifiable {
    case keep, sell, donate

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = Disposal(rawValue: raw) ?? .keep
    }

    var id: String { rawValue }

    var title: String {
        switch self {
        case .keep: return "Behalten"
        case .sell: return "Verkaufen"
        case .donate: return "Spenden"
        }
    }
}

struct Outfit: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var garmentIDs: [UUID]
    var created = Date()
}

struct PlanEntry: Identifiable, Codable, Hashable {
    var id = UUID()
    var day: String              // yyyy-MM-dd
    var outfitID: UUID?
    var garmentIDs: [UUID] = []  // für "Heute tragen" ohne Outfit
    var note = ""
}

enum PlaceMode: String, Codable, CaseIterable, Identifiable {
    case auto, wien, linz

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = PlaceMode(rawValue: raw) ?? .auto
    }

    var id: String { rawValue }

    var title: String {
        switch self {
        case .auto: return "Automatisch (Standort)"
        case .wien: return "Wien"
        case .linz: return "Linz"
        }
    }
}

struct Settings: Codable, Equatable {
    var welcomeSeen = false
    var doorsEnabled = true
    var motionEnabled = true
    var placeMode = PlaceMode.auto
    var readLetters: [String] = []
    var discovered: [String] = []
    var lastGoodNight = ""
    var milestonesShown: [Int] = []
    var customAreas: [String] = []
    var rainbowOrder = false
}

struct Wish: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var brand = ""
    var size = ""
    var color = ""
    var link = ""
    var note = ""
    var added = Date()
    var fulfilled = false
}

struct Trip: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var start: Date
    var end: Date
    /// Look je Tag (yyyy-MM-dd → Stücke).
    var plan: [String: [UUID]] = [:]
    /// Packliste.
    var garmentIDs: [UUID] = []
    var packed: [UUID] = []
}

/// Foto vom Tag im Tagebuch.
struct DayPhoto: Codable, Hashable {
    var full: String
    var thumb: String
}

struct Database: Codable {
    var garments: [Garment] = []
    var outfits: [Outfit] = []
    var plan: [PlanEntry] = []
    var dayNotes: [String: String] = [:]
    var settings = Settings()
    var wishes: [Wish] = []
    var sizes: [String: String] = [:]
    var trips: [Trip] = []
    var dayPhotos: [String: DayPhoto] = [:]
}

// MARK: - Nachsichtiges Lesen
// Fehlende oder unbekannte Felder führen nie zum Absturz, sie bekommen ihren Standardwert.

extension KeyedDecodingContainer {
    func value<T: Decodable>(_ key: Key, default fallback: T) -> T {
        (try? decodeIfPresent(T.self, forKey: key)) ?? fallback
    }
}

extension Garment {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(name: c.value(.name, default: "Stück"), category: c.value(.category, default: .tops))
        id = c.value(.id, default: UUID())
        brand = c.value(.brand, default: "")
        size = c.value(.size, default: "")
        colors = c.value(.colors, default: [])
        memory = c.value(.memory, default: "")
        note = c.value(.note, default: "")
        imageFile = c.value(.imageFile, default: "")
        thumbFile = c.value(.thumbFile, default: "")
        added = c.value(.added, default: Date())
        isFavorite = c.value(.isFavorite, default: false)
        isArchived = c.value(.isArchived, default: false)
        tags = c.value(.tags, default: [])
        seasons = c.value(.seasons, default: [])
        disposal = c.value(.disposal, default: .keep)
        alteration = c.value(.alteration, default: "")
        alterationDue = (try? c.decodeIfPresent(Date.self, forKey: .alterationDue)) ?? nil
    }
}

extension Outfit {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(name: c.value(.name, default: "Outfit"), garmentIDs: c.value(.garmentIDs, default: []))
        id = c.value(.id, default: UUID())
        created = c.value(.created, default: Date())
    }
}

extension PlanEntry {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(day: c.value(.day, default: Date().dayKey))
        id = c.value(.id, default: UUID())
        outfitID = (try? c.decodeIfPresent(UUID.self, forKey: .outfitID)) ?? nil
        garmentIDs = c.value(.garmentIDs, default: [])
        note = c.value(.note, default: "")
    }
}

extension Settings {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init()
        welcomeSeen = c.value(.welcomeSeen, default: false)
        doorsEnabled = c.value(.doorsEnabled, default: true)
        motionEnabled = c.value(.motionEnabled, default: true)
        placeMode = c.value(.placeMode, default: .auto)
        readLetters = c.value(.readLetters, default: [])
        discovered = c.value(.discovered, default: [])
        lastGoodNight = c.value(.lastGoodNight, default: "")
        milestonesShown = c.value(.milestonesShown, default: [])
        customAreas = c.value(.customAreas, default: [])
        rainbowOrder = c.value(.rainbowOrder, default: false)
    }
}

extension Database {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init()
        garments = c.value(.garments, default: [])
        outfits = c.value(.outfits, default: [])
        plan = c.value(.plan, default: [])
        dayNotes = c.value(.dayNotes, default: [:])
        settings = c.value(.settings, default: Settings())
        wishes = c.value(.wishes, default: [])
        sizes = c.value(.sizes, default: [:])
        trips = c.value(.trips, default: [])
        dayPhotos = c.value(.dayPhotos, default: [:])
    }
}

extension Wish {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(name: c.value(.name, default: "Wunsch"))
        id = c.value(.id, default: UUID())
        brand = c.value(.brand, default: "")
        size = c.value(.size, default: "")
        color = c.value(.color, default: "")
        link = c.value(.link, default: "")
        note = c.value(.note, default: "")
        added = c.value(.added, default: Date())
        fulfilled = c.value(.fulfilled, default: false)
    }
}

extension Trip {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(name: c.value(.name, default: "Reise"),
                  start: c.value(.start, default: Date()),
                  end: c.value(.end, default: Date()))
        id = c.value(.id, default: UUID())
        plan = c.value(.plan, default: [:])
        garmentIDs = c.value(.garmentIDs, default: [])
        packed = c.value(.packed, default: [])
    }
}

// MARK: - Datum

extension Date {
    var dayKey: String { Date.keyFormatter.string(from: self) }

    static func fromDayKey(_ key: String) -> Date? { keyFormatter.date(from: key) }

    private static let keyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        return f
    }()
}

extension Int {
    /// "1 Stück", "3 Stücke"
    var stuecke: String { self == 1 ? "1 Stück" : "\(self) Stücke" }
    /// "1 Outfit", "3 Outfits"
    var outfits: String { self == 1 ? "1 Outfit" : "\(self) Outfits" }
}

extension Locale {
    /// Die App spricht immer Deutsch, auch wenn das iPhone auf Englisch steht.
    static let german = Locale(identifier: "de_AT")
}

extension Date {
    /// Datum als deutscher Text, z. B. "Mittwoch, 11. November".
    func german(_ style: Date.FormatStyle) -> String {
        formatted(style.locale(.german))
    }
}

extension Calendar {
    static var german: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.locale = .german
        c.firstWeekday = 2
        return c
    }
}
