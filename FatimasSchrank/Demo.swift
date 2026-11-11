import SwiftUI

// Beispielinhalt nur für die automatischen Bildschirmfotos (Startparameter -demo).
// Im normalen Betrieb läuft nichts davon, der Schrank startet leer.

private struct DrawnShape: Shape {
    let box: CGSize
    let build: @Sendable (inout Path, (CGFloat, CGFloat) -> CGPoint) -> Void

    func path(in r: CGRect) -> Path {
        var p = Path()
        let sx = r.width / box.width
        let sy = r.height / box.height
        let w = box.width
        build(&p) { x, y in
            CGPoint(x: r.minX + (x + w / 2) * sx, y: r.minY + (y + 5) * sy)
        }
        return p
    }
}

private func fabric(_ colors: [UInt32]) -> LinearGradient {
    LinearGradient(colors: colors.map { Color(hex: $0) }, startPoint: .leading, endPoint: .trailing)
}

private let longBox = CGSize(width: 124, height: 316)
private let shortBox = CGSize(width: 124, height: 210)

private let coatPath = DrawnShape(box: longBox) { p, m in
    p.move(to: m(-11, -3))
    p.addCurve(to: m(-44, 16), control1: m(-24, 2), control2: m(-38, 7))
    p.addCurve(to: m(-40, 122), control1: m(-46, 60), control2: m(-42, 100))
    p.addCurve(to: m(-52, 300), control1: m(-46, 180), control2: m(-50, 240))
    p.addLine(to: m(52, 300))
    p.addCurve(to: m(40, 122), control1: m(50, 240), control2: m(46, 180))
    p.addCurve(to: m(44, 16), control1: m(42, 100), control2: m(46, 60))
    p.addCurve(to: m(11, -3), control1: m(38, 7), control2: m(24, 2))
    p.addLine(to: m(0, 20))
    p.closeSubpath()
}

private let dressPath = DrawnShape(box: longBox) { p, m in
    p.move(to: m(-15, 0))
    p.addLine(to: m(-20, 30))
    p.addCurve(to: m(20, 30), control1: m(-10, 44), control2: m(10, 44))
    p.addLine(to: m(15, 0))
    p.addLine(to: m(17, 0))
    p.addLine(to: m(23, 30))
    p.addCurve(to: m(34, 170), control1: m(25, 78), control2: m(27, 110))
    p.addCurve(to: m(52, 296), control1: m(42, 226), control2: m(48, 268))
    p.addCurve(to: m(-52, 296), control1: m(24, 310), control2: m(-24, 310))
    p.addCurve(to: m(-34, 170), control1: m(-48, 268), control2: m(-42, 226))
    p.addCurve(to: m(-23, 30), control1: m(-27, 110), control2: m(-25, 78))
    p.addLine(to: m(-17, 0))
    p.closeSubpath()
}

private let jacketPath = DrawnShape(box: shortBox) { p, m in
    p.move(to: m(-10, -3))
    p.addCurve(to: m(-42, 16), control1: m(-23, 2), control2: m(-36, 7))
    p.addCurve(to: m(-36, 112), control1: m(-44, 60), control2: m(-38, 96))
    p.addCurve(to: m(-44, 190), control1: m(-40, 140), control2: m(-43, 166))
    p.addLine(to: m(-3, 194))
    p.addLine(to: m(0, 152))
    p.addLine(to: m(3, 194))
    p.addLine(to: m(44, 190))
    p.addCurve(to: m(36, 112), control1: m(43, 166), control2: m(40, 140))
    p.addCurve(to: m(42, 16), control1: m(38, 96), control2: m(44, 60))
    p.addCurve(to: m(10, -3), control1: m(36, 7), control2: m(23, 2))
    p.addLine(to: m(0, 70))
    p.closeSubpath()
}

private let blousePath = DrawnShape(box: shortBox) { p, m in
    p.move(to: m(-9, -3))
    p.addCurve(to: m(-38, 16), control1: m(-21, 2), control2: m(-32, 7))
    p.addLine(to: m(-54, 130))
    p.addLine(to: m(-40, 134))
    p.addLine(to: m(-40, 150))
    p.addCurve(to: m(40, 150), control1: m(-20, 158), control2: m(20, 158))
    p.addLine(to: m(40, 134))
    p.addLine(to: m(54, 130))
    p.addLine(to: m(38, 16))
    p.addCurve(to: m(9, -3), control1: m(32, 7), control2: m(21, 2))
    p.addCurve(to: m(-9, -3), control1: m(4, 10), control2: m(-4, 10))
    p.closeSubpath()
}

private let trousersPath = DrawnShape(box: longBox) { p, m in
    p.move(to: m(-30, 0))
    p.addLine(to: m(30, 0))
    p.addLine(to: m(38, 300))
    p.addLine(to: m(8, 300))
    p.addLine(to: m(0, 90))
    p.addLine(to: m(-8, 300))
    p.addLine(to: m(-38, 300))
    p.closeSubpath()
}

private struct BagArt: View {
    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0.5, to: 1)
                .stroke(Palette.brassGradient, lineWidth: 5)
                .frame(width: 120, height: 120)
                .offset(y: -30)
            RoundedRectangle(cornerRadius: 18)
                .fill(LinearGradient(colors: [Color(hex: 0x4A4541), Color(hex: 0x1D1B1A), Color(hex: 0x0D0C0C)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 210, height: 150)
                .offset(y: 50)
            RoundedRectangle(cornerRadius: 3)
                .fill(Palette.brassGradient)
                .frame(width: 34, height: 24)
                .offset(y: 40)
        }
    }
}

private struct ShoeArt: View {
    var body: some View {
        DrawnShape(box: CGSize(width: 240, height: 130)) { p, m in
            p.move(to: m(-110, 0))
            p.addCurve(to: m(-40, 70), control1: m(-96, 0), control2: m(-76, 54))
            p.addCurve(to: m(110, 112), control1: m(4, 86), control2: m(92, 88))
            p.addCurve(to: m(100, 120), control1: m(114, 118), control2: m(108, 120))
            p.addLine(to: m(-30, 120))
            p.addCurve(to: m(-96, 80), control1: m(-52, 104), control2: m(-76, 88))
            p.addLine(to: m(-100, 120))
            p.addLine(to: m(-112, 120))
            p.closeSubpath()
        }
        .fill(LinearGradient(colors: [Color(hex: 0xA01F33), Color(hex: 0x5A0F1D)], startPoint: .top, endPoint: .bottom))
    }
}

private struct Sample {
    let name: String
    let category: Category
    let size: CGSize
    let view: AnyView
    var brand = ""
    var colors: [GarmentColor] = []
    var memory = ""
    var favorite = false
}

@MainActor
enum Demo {
    private static var samples: [Sample] {
        let long = CGSize(width: 372, height: 948)
        let short = CGSize(width: 372, height: 630)
        return [
            Sample(name: "Seidenkleid", category: .dresses, size: long,
                   view: AnyView(dressPath.fill(fabric([0x470D19, 0xA53049, 0x6A1627, 0xC9566F, 0x791A2D, 0x3F0D17]))),
                   brand: "Atelier", colors: [.bordeaux], memory: "Getragen beim ersten Date", favorite: true),
            Sample(name: "Abendkleid", category: .dresses, size: long,
                   view: AnyView(dressPath.fill(fabric([0x0C0C0E, 0x3B3B42, 0x141418, 0x4A4A52, 0x101014]))), colors: [.black]),
            Sample(name: "Cocktailkleid", category: .dresses, size: long,
                   view: AnyView(dressPath.fill(fabric([0x082E25, 0x2F9478, 0x125041, 0x40AB8D, 0x072A22]))), colors: [.green]),
            Sample(name: "Kamelmantel", category: .outerwear, size: long,
                   view: AnyView(coatPath.fill(fabric([0x8F683A, 0xD3A970, 0xB98B53, 0x7F5B31]))), brand: "Atelier", colors: [.camel]),
            Sample(name: "Blazer", category: .outerwear, size: short,
                   view: AnyView(jacketPath.fill(fabric([0xC9BFAD, 0xFBF7EE, 0xE8DFCF, 0xB9AD9A]))), colors: [.cream]),
            Sample(name: "Schluppenbluse", category: .tops, size: short,
                   view: AnyView(blousePath.fill(fabric([0x082E25, 0x2F9478, 0x125041, 0x40AB8D, 0x072A22]))), colors: [.green]),
            Sample(name: "Kaschmirpullover", category: .tops, size: short,
                   view: AnyView(blousePath.fill(fabric([0xB98F88, 0xEBC7C0, 0xD7ABA4, 0xA67D76]))), colors: [.pink], favorite: true),
            Sample(name: "Bundfaltenhose", category: .bottoms, size: long,
                   view: AnyView(trousersPath.fill(fabric([0x3D4048, 0x7A7E89, 0x555963, 0x33363D]))), colors: [.grey]),
            Sample(name: "Ledertasche", category: .bags, size: CGSize(width: 240, height: 240),
                   view: AnyView(BagArt()), colors: [.black]),
            Sample(name: "Pumps", category: .shoes, size: CGSize(width: 300, height: 170),
                   view: AnyView(ShoeArt()), colors: [.red]),
        ]
    }

    static func prepare(store: Store, app: AppState) async {
        store.db.settings.welcomeSeen = app.argument("-open") != "welcome"
        store.db.settings.placeMode = .wien
        guard store.db.garments.isEmpty else {
            store.save()
            return
        }
        for sample in samples.reversed() {
            let renderer = ImageRenderer(content: sample.view.frame(width: sample.size.width, height: sample.size.height))
            renderer.scale = 1
            renderer.isOpaque = false
            guard let image = renderer.uiImage,
                  var g = await store.addGarment(image: image, category: sample.category, name: sample.name) else { continue }
            g.brand = sample.brand
            g.colors = sample.colors
            g.memory = sample.memory
            g.isFavorite = sample.favorite
            store.update(g)
        }
        func id(_ name: String) -> UUID? { store.db.garments.first { $0.name == name }?.id }
        let looks: [(String, [String])] = [
            ("Erstes Date", ["Seidenkleid", "Kamelmantel", "Pumps", "Ledertasche"]),
            ("Büro am Montag", ["Schluppenbluse", "Bundfaltenhose", "Blazer", "Ledertasche"]),
            ("Sonntag", ["Kaschmirpullover", "Bundfaltenhose", "Pumps"]),
        ]
        for look in looks {
            store.saveOutfit(Outfit(name: look.0, garmentIDs: look.1.compactMap { id($0) }))
        }
        let today = Date()
        if let first = store.db.outfits.last {
            store.plan(outfit: first, on: today)
        }
        if let second = store.db.outfits.first,
           let tomorrow = Calendar.german.date(byAdding: .day, value: 1, to: today) {
            store.plan(outfit: second, on: tomorrow)
        }
        store.setDayNote(today, "Abendessen in der Innenstadt")
        store.save()
    }
}
