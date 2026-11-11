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
    func addGarment(image: UIImage, category: Category, name: String) async -> Garment? {
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
        db = restored
        save()
    }
}
