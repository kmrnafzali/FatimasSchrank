import SwiftUI
import Vision

/// Was auf einem Etikett gelesen wurde.
struct LabelInfo {
    var brand = ""
    var size = ""
    var material = ""
    var articleNumber = ""

    var isEmpty: Bool { brand.isEmpty && size.isEmpty && material.isEmpty && articleNumber.isEmpty }

    /// Kurzfassung für die Anzeige.
    var summary: String {
        [brand, size.isEmpty ? "" : "Größe \(size)", material, articleNumber.isEmpty ? "" : "Nr. \(articleNumber)"]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }
}

/// Liest Etiketten mit der Texterkennung von Apple, direkt auf dem Gerät.
enum LabelScanner {
    /// Bekannte Marken, kleingeschrieben und ohne Satzzeichen, dazu die Schreibweise zur Anzeige.
    private static let brands: [(String, String)] = [
        ("zara", "Zara"), ("mango", "Mango"), ("h&m", "H&M"), ("massimo dutti", "Massimo Dutti"),
        ("cos", "COS"), ("uniqlo", "Uniqlo"), ("nike", "Nike"), ("adidas", "Adidas"),
        ("levi's", "Levi's"), ("levis", "Levi's"), ("tommy hilfiger", "Tommy Hilfiger"),
        ("calvin klein", "Calvin Klein"), ("ralph lauren", "Ralph Lauren"), ("gucci", "Gucci"),
        ("prada", "Prada"), ("chanel", "Chanel"), ("dior", "Dior"), ("louis vuitton", "Louis Vuitton"),
        ("hugo boss", "Hugo Boss"), ("boss", "Boss"), ("esprit", "Esprit"), ("s oliver", "s.Oliver"),
        ("tom tailor", "Tom Tailor"), ("bershka", "Bershka"), ("pull&bear", "Pull&Bear"),
        ("stradivarius", "Stradivarius"), ("reserved", "Reserved"), ("c&a", "C&A"), ("primark", "Primark"),
        ("only", "Only"), ("vero moda", "Vero Moda"), ("vila", "Vila"), ("pieces", "Pieces"),
        ("gina tricot", "Gina Tricot"), ("weekday", "Weekday"), ("arket", "Arket"),
        ("other stories", "& Other Stories"), ("marc o polo", "Marc O'Polo"), ("lacoste", "Lacoste"),
        ("guess", "Guess"), ("diesel", "Diesel"), ("replay", "Replay"), ("superdry", "Superdry"),
        ("jack & jones", "Jack & Jones"), ("max mara", "Max Mara"), ("sandro", "Sandro"),
        ("maje", "Maje"), ("zalando", "Zalando"), ("asos", "ASOS"), ("shein", "Shein"),
        ("peek & cloppenburg", "Peek & Cloppenburg"), ("hallhuber", "Hallhuber"), ("comma", "comma,"),
        ("bogner", "Bogner"), ("strellson", "Strellson"), ("ralph", "Ralph Lauren"),
    ]

    private static let materialNames: [String: String] = [
        "cotton": "Baumwolle", "baumwolle": "Baumwolle", "coton": "Baumwolle", "algodon": "Baumwolle",
        "polyester": "Polyester", "viscose": "Viskose", "viskose": "Viskose", "wool": "Wolle", "wolle": "Wolle",
        "laine": "Wolle", "elastane": "Elastan", "elastan": "Elastan", "spandex": "Elastan", "elastano": "Elastan",
        "linen": "Leinen", "leinen": "Leinen", "silk": "Seide", "seide": "Seide", "polyamide": "Polyamid",
        "polyamid": "Polyamid", "nylon": "Nylon", "cashmere": "Kaschmir", "kaschmir": "Kaschmir",
        "acrylic": "Acryl", "acryl": "Acryl", "leather": "Leder", "leder": "Leder", "lyocell": "Lyocell",
        "modal": "Modal", "angora": "Angora", "mohair": "Mohair", "rayon": "Viskose", "tencel": "Tencel",
        "polyurethane": "Polyurethan", "polyurethan": "Polyurethan", "lurex": "Lurex", "metal": "Metall",
    ]

    /// Foto lesen. Gibt nil zurück, wenn nichts erkannt wurde.
    static func scan(_ image: UIImage) async -> LabelInfo? {
        let lines = await Task.detached(priority: .userInitiated) { () -> [String] in
            guard let cg = image.cgImage else { return [] }
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false
            request.recognitionLanguages = ["de-DE", "en-US"]
            let handler = VNImageRequestHandler(cgImage: cg, options: [:])
            guard (try? handler.perform([request])) != nil, let observations = request.results else { return [] }
            // Von oben nach unten lesen. Bei Vision liegt der Ursprung unten links.
            let sorted = observations.sorted { $0.boundingBox.midY > $1.boundingBox.midY }
            return sorted.compactMap { $0.topCandidates(1).first?.string }
        }.value
        guard !lines.isEmpty else { return nil }
        let info = parse(lines)
        return info.isEmpty ? nil : info
    }

    static func parse(_ lines: [String]) -> LabelInfo {
        var info = LabelInfo()
        info.brand = findBrand(lines)
        info.size = findSize(lines)
        info.material = findMaterial(lines)
        info.articleNumber = findArticle(lines)
        return info
    }

    // MARK: Einzelne Felder

    /// Wörter einer Zeile, kleingeschrieben, ohne Satzzeichen außer & und '.
    private static func normalized(_ text: String) -> String {
        var out = ""
        for scalar in text.lowercased().unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) || scalar == "&" || scalar == "'" {
                out.unicodeScalars.append(scalar)
            } else {
                out.append(" ")
            }
        }
        return out.split(separator: " ").joined(separator: " ")
    }

    private static func findBrand(_ lines: [String]) -> String {
        for line in lines {
            let padded = " " + normalized(line) + " "
            for (key, display) in brands where padded.contains(" " + normalized(key) + " ") {
                return display
            }
        }
        return ""
    }

    private static func firstMatch(_ pattern: String, in text: String, group: Int = 1) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range), match.numberOfRanges > group,
              let found = Range(match.range(at: group), in: text) else { return nil }
        return String(text[found])
    }

    private static func findSize(_ lines: [String]) -> String {
        // Zeilen wie "EUR 38", "Size M" oder "Größe: 36".
        let keyed = "(?i)\\b(?:eur|eu|de|gr|size|größe|grösse|taille|talla|taglia)\\s*[:.]?\\s*(xxxs|xxs|xs|s|m|l|xl|xxl|xxxl|[3-5][0-9])\\b"
        for line in lines {
            if let size = firstMatch(keyed, in: line) { return size.uppercased() }
        }
        // Zeilen, die nur aus einer Größe bestehen.
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if let size = firstMatch("^(XXXS|XXS|XS|S|M|L|XL|XXL|XXXL|[3-5][0-9])$", in: trimmed) { return size }
        }
        return ""
    }

    private static func findMaterial(_ lines: [String]) -> String {
        guard let regex = try? NSRegularExpression(pattern: "(\\d{1,3})\\s?%\\s?([A-Za-zÄÖÜäöüß]+)") else { return "" }
        var parts: [String] = []
        var seen = Set<String>()
        for line in lines {
            let range = NSRange(line.startIndex..., in: line)
            for match in regex.matches(in: line, range: range) {
                guard let percentRange = Range(match.range(at: 1), in: line),
                      let nameRange = Range(match.range(at: 2), in: line) else { continue }
                let percent = String(line[percentRange])
                let raw = String(line[nameRange]).lowercased()
                let name = materialNames[raw] ?? String(line[nameRange]).capitalized
                let part = "\(percent) % \(name)"
                if seen.insert(part).inserted { parts.append(part) }
            }
        }
        return parts.joined(separator: ", ")
    }

    private static func findArticle(_ lines: [String]) -> String {
        // Nach einem Stichwort: "Ref. 1234/567/800", "Art.-Nr. 12345", "Style 0123".
        let keyed = "(?i)\\b(?:ref|art|style|sku|model|modell|artikel|item)\\.?[-\\s]*(?:nr\\.?|no\\.?|#)?\\s*[:.]?\\s*([A-Z0-9][A-Z0-9/\\-\\.]{4,})"
        for line in lines {
            if let number = firstMatch(keyed, in: line) {
                return number.trimmingCharacters(in: CharacterSet(charactersIn: ".-/"))
            }
        }
        // Sonst die erste Zahl in der Form 1234/567/800 oder 12345-678.
        for line in lines {
            if let number = firstMatch("\\b(\\d{3,5}[/\\-]\\d{2,4}(?:[/\\-]\\d{2,4})?)\\b", in: line) { return number }
        }
        return ""
    }

    /// Suchadresse für Marke und Artikelnummer.
    static func searchURL(brand: String, article: String) -> URL? {
        let query = [brand, article]
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        guard !query.isEmpty,
              let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
        return URL(string: "https://www.google.com/search?q=" + encoded)
    }
}
