import UIKit
import Vision
import CoreImage
import ImageIO
import UniformTypeIdentifiers

/// Bilder laden, freistellen, verkleinern und platzsparend speichern.
/// Alle Funktionen sind synchron und werden abseits des Hauptfadens aufgerufen.
enum ImagePipeline {
    struct Prepared {
        let image: UIImage
        let isCutout: Bool
    }

    /// Lädt ein Foto speicherschonend direkt in kleiner Größe.
    static func downsample(data: Data, maxPixel: CGFloat) -> UIImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: cg)
    }

    static func scaled(_ image: UIImage, maxSide: CGFloat, opaque: Bool = false) -> UIImage {
        let size = image.size
        let longest = max(size.width, size.height)
        guard longest > 0 else { return image }
        let factor = min(1, maxSide / longest)
        let target = CGSize(width: max(1, (size.width * factor).rounded()),
                            height: max(1, (size.height * factor).rounded()))
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = opaque
        // Normale 8-Bit-Farben: klein zu speichern und sicher als HEIC kodierbar.
        format.preferredRange = .standard
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }

    /// Stellt das Hauptmotiv frei (Apple Vision, auf dem Gerät).
    static func cutout(_ image: UIImage) -> UIImage? {
        guard let cg = image.cgImage else { return nil }
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: cg, options: [:])
        do {
            try handler.perform([request])
            guard let result = request.results?.first, !result.allInstances.isEmpty else { return nil }
            // Kleine Nebenstücke (ein Stück Bettwäsche, ein Kissenzipfel) bleiben draußen.
            let keep = significantInstances(in: result.instanceMask, all: result.allInstances) ?? result.allInstances
            let buffer = try result.generateMaskedImage(
                ofInstances: keep,
                from: handler,
                croppedToInstancesExtent: true
            )
            let ci = CIImage(cvPixelBuffer: buffer)
            guard let out = CIContext().createCGImage(ci, from: ci.extent) else { return nil }
            return trimTransparent(UIImage(cgImage: out))
        } catch {
            return nil
        }
    }

    /// Behält die Teile, die mindestens 30 Prozent so groß sind wie das größte.
    private static func significantInstances(in mask: CVPixelBuffer, all: IndexSet) -> IndexSet? {
        CVPixelBufferLockBaseAddress(mask, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(mask, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(mask) else { return nil }
        let width = CVPixelBufferGetWidth(mask)
        let height = CVPixelBufferGetHeight(mask)
        let rowBytes = CVPixelBufferGetBytesPerRow(mask)
        var counts = [Int](repeating: 0, count: 256)
        for y in 0..<height {
            let row = base.advanced(by: y * rowBytes).assumingMemoryBound(to: UInt8.self)
            for x in 0..<width { counts[Int(row[x])] += 1 }
        }
        let candidates = all.filter { $0 < 256 }
        guard let largest = candidates.map({ counts[$0] }).max(), largest > 0 else { return nil }
        let kept = candidates.filter { counts[$0] * 10 >= largest * 3 }
        return kept.isEmpty ? nil : IndexSet(kept)
    }

    /// Schneidet den durchsichtigen Rand ab, damit das Stück genau am Bügel hängt.
    static func trimTransparent(_ image: UIImage) -> UIImage {
        guard let cg = image.cgImage else { return image }
        let w = cg.width
        let h = cg.height
        guard w > 0, h > 0 else { return image }
        var data = [UInt8](repeating: 0, count: w * h * 4)
        let box: (minX: Int, minY: Int, maxX: Int, maxY: Int)? = data.withUnsafeMutableBytes { buffer in
            guard let ctx = CGContext(
                data: buffer.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return nil }
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
            let bytes = buffer.bindMemory(to: UInt8.self)
            var minX = w, minY = h, maxX = -1, maxY = -1
            for y in 0..<h {
                for x in 0..<w where bytes[(y * w + x) * 4 + 3] > 12 {
                    if x < minX { minX = x }
                    if x > maxX { maxX = x }
                    if y < minY { minY = y }
                    maxY = y
                }
            }
            return maxX >= minX && maxY >= minY ? (minX, minY, maxX, maxY) : nil
        }
        guard let box else { return image }
        let rect = CGRect(x: box.minX, y: box.minY, width: box.maxX - box.minX + 1, height: box.maxY - box.minY + 1)
        guard let cropped = cg.cropping(to: rect) else { return image }
        return UIImage(cgImage: cropped)
    }

    static func prepare(_ image: UIImage) -> Prepared {
        let base = scaled(image, maxSide: 1600)
        if let cut = cutout(base) {
            return Prepared(image: scaled(cut, maxSide: 1200), isCutout: true)
        }
        return Prepared(image: scaled(base, maxSide: 1200, opaque: true), isCutout: false)
    }

    /// Schreibt Vollbild und Vorschau. Gibt die Dateinamen zurück.
    static func write(_ image: UIImage, base: String, into dir: URL) -> (full: String, thumb: String)? {
        let thumb = scaled(image, maxSide: 400)
        guard let full = encode(image), let small = encode(thumb) else { return nil }
        let fullName = "\(base).\(full.ext)"
        let thumbName = "\(base)_t.\(small.ext)"
        do {
            try full.data.write(to: dir.appendingPathComponent(fullName), options: .atomic)
            try small.data.write(to: dir.appendingPathComponent(thumbName), options: .atomic)
        } catch {
            return nil
        }
        return (fullName, thumbName)
    }

    /// HEIC, wenn die Transparenz dabei erhalten bleibt, sonst PNG.
    static func encode(_ image: UIImage) -> (data: Data, ext: String)? {
        #if targetEnvironment(simulator)
        // Der Simulator auf GitHub entpackt HEIC extrem langsam, dort reicht PNG.
        return image.pngData().map { ($0, "png") }
        #else
        guard let cg = image.cgImage else {
            return image.pngData().map { ($0, "png") }
        }
        let needsAlpha = hasAlpha(cg)
        if let heic = heic(cg), !needsAlpha || decodedHasAlpha(heic) {
            return (heic, "heic")
        }
        return image.pngData().map { ($0, "png") }
        #endif
    }

    private static func heic(_ cg: CGImage) -> Data? {
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data as CFMutableData, UTType.heic.identifier as CFString, 1, nil) else { return nil }
        let options = [kCGImageDestinationLossyCompressionQuality: 0.8] as CFDictionary
        CGImageDestinationAddImage(dest, cg, options)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return data as Data
    }

    private static func hasAlpha(_ cg: CGImage) -> Bool {
        switch cg.alphaInfo {
        case .none, .noneSkipFirst, .noneSkipLast: return false
        default: return true
        }
    }

    private static func decodedHasAlpha(_ data: Data) -> Bool {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cg = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return false }
        return hasAlpha(cg)
    }
}
