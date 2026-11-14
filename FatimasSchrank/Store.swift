import SwiftUI
import Observation
import ImageIO
import ZIPFoundation

/// Zwischenspeicher für geladene Bilder. NSCache ist threadsicher.
final class ImageCache: @unchecked Sendable {
    static let shared = ImageCache()
    private let cache = NSCache<NSString, UIImage>()

    init() { cache.countLimit = 400 }

    func get(_ key: String) -> UIImage? { cache.object(forKey: key as NSString) }
    func set(_ image: UIImage, _ key: String) { cache.setObject(image, forKey: key as NSString) }
    func remove(_ key: String) { cache.removeObject(forKey: key as NSString) }
    func removeAll() { cache.removeAllObjects() }
}

/// Lädt Bilder nacheinander auf einer eigenen Warteschlange.
/// So blockiert das Entpacken weder die Oberfläche noch die Fäden von Swift Concurrency,
/// und dieselbe Datei wird nie doppelt gleichzeitig entpackt.
final class ImageLoader: @unchecked Sendable {
    static let shared = ImageLoader()
    private let queue = DispatchQueue(label: "de.kmrn.fatimasschrank.bilder", qos: .userInitiated)

    func load(_ url: URL, key: String) async -> UIImage? {
        await withCheckedContinuation { (continuation: CheckedContinuation<UIImage?, Never>) in
            queue.async {
                if let cached = ImageCache.shared.get(key) {
                    continuation.resume(returning: cached)
                    return
                }
                let image = Self.decode(url)
                if let image { ImageCache.shared.set(image, key) }
                continuation.resume(returning: image)
            }
        }
    }

    /// Entpackt vollständig, damit beim Anzeigen nichts mehr nachgeladen wird.
    private static func decode(_ url: URL) -> UIImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 4096,
        ]
        guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
              let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return UIImage(contentsOfFile: url.path)
        }
        return UIImage(cgImage: cg)
    }
}

@MainActor
@Observable
final class Store {
    var db = Database()
    var loadProblem: String?
    let root: URL

    init() {
        root = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: imagesURL, withIntermediateDirectories: true)
        load()
    }

    // MARK: Ablage

    var imagesURL: URL { root.appendingPathComponent("Bilder", isDirectory: true) }
    private var dataURL: URL { root.appendingPathComponent("schrank.json") }

    func imageURL(_ file: String) -> URL { imagesURL.appendingPathComponent(file) }

    private func load() {
        let fm = FileManager.default
        guard fm.fileExists(atPath: dataURL.path) else { return }
        do {
            let data = try Data(contentsOf: dataURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            db = try decoder.decode(Database.self, from: data)
            CabinetStyle.current = .of(db.settings.theme)
        } catch {
            // Nichts überschreiben: die unlesbare Datei wird zur Seite gelegt.
            let stamp = Int(Date().timeIntervalSince1970)
            try? fm.moveItem(at: dataURL, to: root.appendingPathComponent("schrank-unlesbar-\(stamp).json"))
            loadProblem = "Deine gespeicherten Daten konnten nicht gelesen werden. Sie liegen gesichert in der Dateien-App."
        }
    }

    func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        do {
            let data = try encoder.encode(db)
            try data.write(to: dataURL, options: .atomic)
        } catch {
            print("Speichern fehlgeschlagen: \(error)")
        }
    }

    func storageBytes() -> Int {
        let keys: Set<URLResourceKey> = [.fileSizeKey]
        guard let files = try? FileManager.default.contentsOfDirectory(at: imagesURL, includingPropertiesForKeys: Array(keys)) else { return 0 }
        return files.reduce(0) { sum, url in
            sum + ((try? url.resourceValues(forKeys: keys).fileSize) ?? 0)
        }
    }

    // MARK: Kleidung

    var activeGarments: [Garment] { db.garments.filter { !$0.isArchived } }

    func garment(_ id: UUID) -> Garment? {
        db.garments.first { $0.id == id }
    }

    func garments(in category: Category) -> [Garment] {
        db.garments.filter { $0.category == category && !$0.isArchived }
    }

    func garments(ids: [UUID]) -> [Garment] {
        let order = Category.allCases
        return ids.compactMap { garment($0) }
            .sorted { (order.firstIndex(of: $0.category) ?? 0) < (order.firstIndex(of: $1.category) ?? 0) }
    }

    @discardableResult
    func addGarment(image: UIImage, category: Category, name: String, colors: [GarmentColor] = []) async -> Garment? {
        let id = UUID()
        let dir = imagesURL
        let files = await Task.detached(priority: .userInitiated) {
            ImagePipeline.write(image, base: id.uuidString, into: dir)
        }.value
        guard let files else { return nil }
        var g = Garment(name: name, category: category)
        g.id = id
        g.imageFile = files.full
        g.thumbFile = files.thumb
        g.colors = colors
        db.garments.insert(g, at: 0)
        save()
        return g
    }

    func update(_ garment: Garment) {
        guard let i = db.garments.firstIndex(where: { $0.id == garment.id }) else { return }
        db.garments[i] = garment
        save()
    }

    func deleteGarment(_ id: UUID) {
        guard let g = garment(id) else { return }
        let fm = FileManager.default
        for file in [g.imageFile, g.thumbFile] where !file.isEmpty {
            try? fm.removeItem(at: imageURL(file))
            ImageCache.shared.remove(file)
        }
        db.garments.removeAll { $0.id == id }
        for i in db.outfits.indices {
            db.outfits[i].garmentIDs.removeAll { $0 == id }
        }
        let empty = Set(db.outfits.filter { $0.garmentIDs.isEmpty }.map(\.id))
        db.outfits.removeAll { empty.contains($0.id) }
        for i in db.plan.indices {
            db.plan[i].garmentIDs.removeAll { $0 == id }
        }
        db.plan.removeAll { entry in
            if let oid = entry.outfitID { return empty.contains(oid) }
            return entry.garmentIDs.isEmpty
        }
        save()
    }

    func wornCount(_ g: Garment) -> Int {
        let today = Date().dayKey
        let outfitIDs = Set(db.outfits.filter { $0.garmentIDs.contains(g.id) }.map(\.id))
        return db.plan.filter { entry in
            guard entry.day <= today else { return false }
            if let oid = entry.outfitID, outfitIDs.contains(oid) { return true }
            return entry.garmentIDs.contains(g.id)
        }.count
    }

    // MARK: Outfits

    func outfit(_ id: UUID) -> Outfit? {
        db.outfits.first { $0.id == id }
    }

    func saveOutfit(_ outfit: Outfit) {
        if let i = db.outfits.firstIndex(where: { $0.id == outfit.id }) {
            db.outfits[i] = outfit
        } else {
            db.outfits.insert(outfit, at: 0)
        }
        save()
    }

    func deleteOutfit(_ id: UUID) {
        db.outfits.removeAll { $0.id == id }
        db.plan.removeAll { $0.outfitID == id }
        save()
    }

    // MARK: Kalender

    func entries(on date: Date) -> [PlanEntry] {
        let key = date.dayKey
        return db.plan.filter { $0.day == key }
    }

    func garments(for entry: PlanEntry) -> [Garment] {
        if let oid = entry.outfitID, let o = outfit(oid) { return garments(ids: o.garmentIDs) }
        return garments(ids: entry.garmentIDs)
    }

    func title(for entry: PlanEntry) -> String {
        if let oid = entry.outfitID, let o = outfit(oid) { return o.name }
        return garments(ids: entry.garmentIDs).first?.name ?? "Look"
    }

    func plan(outfit: Outfit, on date: Date) {
        db.plan.append(PlanEntry(day: date.dayKey, outfitID: outfit.id))
        save()
    }

    func wearToday(_ garment: Garment) {
        let key = Date().dayKey
        if let i = db.plan.firstIndex(where: { $0.day == key && $0.outfitID == nil }) {
            if !db.plan[i].garmentIDs.contains(garment.id) { db.plan[i].garmentIDs.append(garment.id) }
        } else {
            db.plan.append(PlanEntry(day: key, garmentIDs: [garment.id]))
        }
        save()
    }

    func removePlan(_ id: UUID) {
        db.plan.removeAll { $0.id == id }
        save()
    }

    func dayNote(_ date: Date) -> String { db.dayNotes[date.dayKey] ?? "" }

    func setDayNote(_ date: Date, _ text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        db.dayNotes[date.dayKey] = t.isEmpty ? nil : t
        save()
    }

    // MARK: Vorschläge

    func planGarments(_ ids: [UUID], on date: Date) {
        guard !ids.isEmpty else { return }
        db.plan.append(PlanEntry(day: date.dayKey, garmentIDs: ids))
        save()
    }

    /// Was in den `days` Tagen vor heute eingeplant war (heute selbst zählt nicht).
    func recentlyWorn(days: Int) -> Set<UUID> {
        guard let cutoff = Calendar.german.date(byAdding: .day, value: -days, to: Date()) else { return [] }
        let from = cutoff.dayKey
        let to = Date().dayKey
        var ids = Set<UUID>()
        for entry in db.plan where entry.day >= from && entry.day < to {
            for g in garments(for: entry) {
                ids.insert(g.id)
            }
        }
        return ids
    }

    func replacePlan(_ id: UUID, garmentIDs: [UUID]) {
        guard let i = db.plan.firstIndex(where: { $0.id == id }) else { return }
        db.plan[i].garmentIDs = garmentIDs
        db.plan[i].forecastTmax = nil
        db.plan[i].forecastRain = nil
        save()
    }

    struct ForecastChange {
        let entryID: UUID
        let title: String
        let day: String
        let weather: DayWeather
    }

    /// Merkt sich die Vorhersage zu geplanten Tagen und meldet, wo sie sich deutlich geändert hat.
    func stampForecasts(_ weather: [String: DayWeather]) -> [ForecastChange] {
        let today = Date().dayKey
        var changes: [ForecastChange] = []
        var dirty = false
        for i in db.plan.indices where db.plan[i].day >= today {
            let entry = db.plan[i]
            guard let w = weather[entry.day] else { continue }
            if let oldTmax = entry.forecastTmax, let oldRain = entry.forecastRain {
                let changed = (w.isRainy && !oldRain) || abs(w.tmax - oldTmax) >= 6
                if !changed { continue }
                changes.append(ForecastChange(entryID: entry.id, title: title(for: entry), day: entry.day, weather: w))
            }
            db.plan[i].forecastTmax = w.tmax
            db.plan[i].forecastRain = w.isRainy
            dirty = true
        }
        if dirty { save() }
        return changes
    }

    struct MonthSpending: Identifiable {
        let month: String   // yyyy-MM
        let total: Double
        let items: [Garment]
        var id: String { month }
    }

    /// Ausgaben je Monat, nach dem Tag, an dem das Stück in den Schrank kam.
    func spendingByMonth() -> [MonthSpending] {
        var groups: [String: [Garment]] = [:]
        for g in db.garments where (g.price ?? 0) > 0 {
            groups[String(g.added.dayKey.prefix(7)), default: []].append(g)
        }
        return groups.keys.sorted(by: >).map { key in
            let items = groups[key] ?? []
            let total = items.reduce(0.0) { $0 + ($1.price ?? 0) }
            return MonthSpending(month: key, total: total, items: items)
        }
    }

    /// Letzter Tag bis heute, an dem das Stück eingeplant war.
    func lastWornKey(_ g: Garment) -> String? {
        let today = Date().dayKey
        let outfitIDs = Set(db.outfits.filter { $0.garmentIDs.contains(g.id) }.map(\.id))
        return db.plan.filter { entry in
            guard entry.day <= today else { return false }
            if let oid = entry.outfitID, outfitIDs.contains(oid) { return true }
            return entry.garmentIDs.contains(g.id)
        }
        .map(\.day)
        .max()
    }

    /// Stücke, die schon länger im Schrank sind und seit `days` Tagen nicht getragen wurden.
    func forgottenGarments(days: Int) -> [Garment] {
        guard let cutoff = Calendar.german.date(byAdding: .day, value: -days, to: Date()) else { return [] }
        let key = cutoff.dayKey
        let found = activeGarments
            .filter { g in
                guard g.added < cutoff else { return false }
                guard let last = lastWornKey(g) else { return true }
                return last < key
            }
            .sorted { $0.added < $1.added }
        return Array(found.prefix(12))
    }

    // MARK: Ordnung

    /// Stücke, die für Vorschläge in Frage kommen: nicht archiviert, nicht zum Aussortieren vorgemerkt.
    var wearableGarments: [Garment] { activeGarments.filter { $0.disposal == .keep } }

    func garments(inArea area: String) -> [Garment] {
        db.garments.filter { !$0.isArchived && $0.tags.contains(area) }
    }

    /// Stücke, die seit `days` Tagen nicht im Kalender vorkamen.
    func rarelyWorn(days: Int) -> Set<UUID> {
        guard let cutoff = Calendar.german.date(byAdding: .day, value: -days, to: Date()) else { return [] }
        let key = cutoff.dayKey
        let ids = db.garments.filter { g in
            guard let last = lastWornKey(g) else { return true }
            return last < key
        }
        .map(\.id)
        return Set(ids)
    }

    var brands: [String] {
        let all = db.garments
            .map { $0.brand.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return Array(Set(all)).sorted()
    }

    @discardableResult
    func addArea(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty,
              !db.settings.customAreas.contains(trimmed),
              !Category.allCases.contains(where: { $0.title == trimmed }) else { return false }
        db.settings.customAreas.append(trimmed)
        save()
        return true
    }

    func removeArea(_ name: String) {
        db.settings.customAreas.removeAll { $0 == name }
        for i in db.garments.indices {
            db.garments[i].tags.removeAll { $0 == name }
        }
        save()
    }

    // MARK: Wünsche und Größen

    func saveWish(_ wish: Wish) {
        if let i = db.wishes.firstIndex(where: { $0.id == wish.id }) {
            db.wishes[i] = wish
        } else {
            db.wishes.insert(wish, at: 0)
        }
        save()
    }

    func deleteWish(_ id: UUID) {
        db.wishes.removeAll { $0.id == id }
        save()
    }

    func setSize(_ key: String, _ value: String) {
        db.sizes[key] = value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : value
        save()
    }

    // MARK: Reisen

    func trip(_ id: UUID) -> Trip? {
        db.trips.first { $0.id == id }
    }

    func saveTrip(_ trip: Trip) {
        if let i = db.trips.firstIndex(where: { $0.id == trip.id }) {
            db.trips[i] = trip
        } else {
            db.trips.insert(trip, at: 0)
        }
        save()
    }

    func deleteTrip(_ id: UUID) {
        db.trips.removeAll { $0.id == id }
        save()
    }

    func togglePacked(trip id: UUID, garment gid: UUID) {
        guard let i = db.trips.firstIndex(where: { $0.id == id }) else { return }
        if let j = db.trips[i].packed.firstIndex(of: gid) {
            db.trips[i].packed.remove(at: j)
        } else {
            db.trips[i].packed.append(gid)
        }
        save()
    }

    // MARK: Aussehen

    /// Farbe zuerst setzen, dann speichern: so zeichnet die App sofort in der neuen Farbe.
    func setTheme(_ theme: CabinetTheme) {
        CabinetStyle.current = .of(theme)
        db.settings.theme = theme
        save()
    }

    // MARK: Für euch beide

    func saveVoucher(_ voucher: Voucher) {
        if let i = db.vouchers.firstIndex(where: { $0.id == voucher.id }) {
            db.vouchers[i] = voucher
        } else {
            db.vouchers.append(voucher)
        }
        save()
    }

    func deleteVoucher(_ id: UUID) {
        db.vouchers.removeAll { $0.id == id }
        save()
    }

    func toggleKamranFavorite(_ id: UUID) {
        guard let i = db.garments.firstIndex(where: { $0.id == id }) else { return }
        db.garments[i].kamranFavorite.toggle()
        save()
    }

    @discardableResult
    func addCouplePhoto(_ image: UIImage) async -> Bool {
        let dir = imagesURL
        let base = "foto-\(UUID().uuidString.prefix(8))"
        let files = await Task.detached(priority: .userInitiated) {
            ImagePipeline.write(ImagePipeline.scaled(image, maxSide: 1600, opaque: true), base: base, into: dir)
        }.value
        guard let files else { return false }
        db.couplePhotos.insert(CouplePhoto(full: files.full, thumb: files.thumb), at: 0)
        save()
        return true
    }

    func updateCouplePhoto(_ photo: CouplePhoto) {
        guard let i = db.couplePhotos.firstIndex(where: { $0.id == photo.id }) else { return }
        db.couplePhotos[i] = photo
        save()
    }

    func deleteCouplePhoto(_ id: UUID) {
        guard let photo = db.couplePhotos.first(where: { $0.id == id }) else { return }
        for file in [photo.full, photo.thumb] {
            try? FileManager.default.removeItem(at: imageURL(file))
            ImageCache.shared.remove(file)
        }
        db.couplePhotos.removeAll { $0.id == id }
        save()
    }

    // MARK: Tagebuch

    func dayPhoto(_ date: Date) -> DayPhoto? {
        db.dayPhotos[date.dayKey]
    }

    @discardableResult
    func setDayPhoto(_ date: Date, image: UIImage) async -> Bool {
        let key = date.dayKey
        let dir = imagesURL
        let base = "tag-\(key)-\(UUID().uuidString.prefix(8))"
        let files = await Task.detached(priority: .userInitiated) {
            ImagePipeline.write(ImagePipeline.scaled(image, maxSide: 1600, opaque: true), base: base, into: dir)
        }.value
        guard let files else { return false }
        removeDayPhoto(date, persist: false)
        db.dayPhotos[key] = DayPhoto(full: files.full, thumb: files.thumb)
        save()
        return true
    }

    func removeDayPhoto(_ date: Date, persist: Bool = true) {
        guard let photo = db.dayPhotos[date.dayKey] else { return }
        for file in [photo.full, photo.thumb] {
            try? FileManager.default.removeItem(at: imageURL(file))
            ImageCache.shared.remove(file)
        }
        db.dayPhotos[date.dayKey] = nil
        if persist { save() }
    }

    // MARK: Überraschungen

    func discover(_ key: String) {
        guard !db.settings.discovered.contains(key) else { return }
        db.settings.discovered.append(key)
        save()
    }

    // MARK: Sicherung

    func makeBackup() async throws -> URL {
        save()
        let source = root
        return try await Task.detached(priority: .userInitiated) { () throws -> URL in
            let fm = FileManager.default
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            let dest = fm.temporaryDirectory.appendingPathComponent("Fatimas-Schrank-\(f.string(from: Date())).zip")
            try? fm.removeItem(at: dest)
            let staging = fm.temporaryDirectory.appendingPathComponent("sicherung-\(UUID().uuidString)", isDirectory: true)
            try fm.createDirectory(at: staging, withIntermediateDirectories: true)
            defer { try? fm.removeItem(at: staging) }
            try fm.copyItem(at: source.appendingPathComponent("schrank.json"), to: staging.appendingPathComponent("schrank.json"))
            let images = source.appendingPathComponent("Bilder", isDirectory: true)
            if fm.fileExists(atPath: images.path) {
                try fm.copyItem(at: images, to: staging.appendingPathComponent("Bilder", isDirectory: true))
            }
            try fm.zipItem(at: staging, to: dest, shouldKeepParent: false)
            return dest
        }.value
    }

    /// Einmal pro Woche eine Sicherung in "Dateien › Auf meinem iPhone › Schrank › Sicherungen".
    /// Sie wird mit dem iCloud-Backup des iPhones mitgesichert.
    func autoBackupIfDue() async {
        if let last = db.settings.lastAutoBackup, Date().timeIntervalSince(last) < 7 * 24 * 3600 { return }
        guard !db.garments.isEmpty else { return }
        do {
            let temp = try await makeBackup()
            let fm = FileManager.default
            let folder = root.appendingPathComponent("Sicherungen", isDirectory: true)
            try fm.createDirectory(at: folder, withIntermediateDirectories: true)
            let dest = folder.appendingPathComponent("Automatische Sicherung.zip")
            try? fm.removeItem(at: dest)
            try fm.moveItem(at: temp, to: dest)
            db.settings.lastAutoBackup = Date()
            save()
        } catch {
            // Beim nächsten Start wird es noch einmal versucht.
        }
    }

    func restoreBackup(from url: URL) async throws {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let target = root
        let restored = try await Task.detached(priority: .userInitiated) { () throws -> Database in
            let fm = FileManager.default
            let work = fm.temporaryDirectory.appendingPathComponent("wiederherstellen-\(UUID().uuidString)", isDirectory: true)
            try fm.createDirectory(at: work, withIntermediateDirectories: true)
            defer { try? fm.removeItem(at: work) }
            let zip = work.appendingPathComponent("sicherung.zip")
            try fm.copyItem(at: url, to: zip)
            let content = work.appendingPathComponent("inhalt", isDirectory: true)
            try fm.createDirectory(at: content, withIntermediateDirectories: true)
            try fm.unzipItem(at: zip, to: content)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let db = try decoder.decode(Database.self, from: Data(contentsOf: content.appendingPathComponent("schrank.json")))
            let newImages = content.appendingPathComponent("Bilder", isDirectory: true)
            let oldImages = target.appendingPathComponent("Bilder", isDirectory: true)
            if fm.fileExists(atPath: oldImages.path) { try fm.removeItem(at: oldImages) }
            if fm.fileExists(atPath: newImages.path) {
                try fm.moveItem(at: newImages, to: oldImages)
            } else {
                try fm.createDirectory(at: oldImages, withIntermediateDirectories: true)
            }
            return db
        }.value
        ImageCache.shared.removeAll()
        CabinetStyle.current = .of(restored.settings.theme)
        db = restored
        save()
    }
}
