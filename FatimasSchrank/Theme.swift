import SwiftUI
import UIKit

// MARK: - Farben

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }

    /// Farbe mit eigener Variante für den dunklen Modus.
    static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1
            )
        })
    }
}

/// Farbwelt des Schranks, umschaltbar unter "Mehr".
struct CabinetStyle {
    let lacquer: [UInt32]       // oben, Mitte, unten
    let edge: UInt32
    let wall: [UInt32]          // Rückwand oben, Mitte, unten
    let rose: [UInt32]          // Rückwand an besonderen Tagen
    let door: [UInt32]          // Innenseite der Türen
    let velvet: [UInt32]        // Samt im Schmuckkästchen
    let text: UInt32            // Schrift auf dem Lack
    let textSecondary: UInt32
    let highlight: UInt32       // goldene Akzente auf dem Lack
    let isLight: Bool

    /// Wird nur über `Store.setTheme` und beim Laden gesetzt.
    static var current = CabinetStyle.burgundy

    static func of(_ theme: CabinetTheme) -> CabinetStyle {
        switch theme {
        case .burgundy: return .burgundy
        case .ivory: return .ivory
        case .midnight: return .midnight
        }
    }

    static let burgundy = CabinetStyle(
        lacquer: [0x5C1628, 0x4B1020, 0x2D0913], edge: 0x22060D,
        wall: [0x54403E, 0x2F2325, 0x1E1517], rose: [0x6E2A3A, 0x40161F, 0x24090F],
        door: [0x3A0D1A, 0x22060D], velvet: [0x7E2238, 0x4B1020],
        text: 0xF6EFE4, textSecondary: 0xB9AD9C, highlight: 0xECD3A0, isLight: false
    )

    static let midnight = CabinetStyle(
        lacquer: [0x22304D, 0x16213A, 0x0C1322], edge: 0x080D18,
        wall: [0x3A4256, 0x232A3B, 0x151A26], rose: [0x4A3348, 0x2E2033, 0x1A1220],
        door: [0x16213A, 0x0C1322], velvet: [0x2F3F63, 0x16213A],
        text: 0xF2EEE6, textSecondary: 0xA9B0BF, highlight: 0xE3CC98, isLight: false
    )

    static let ivory = CabinetStyle(
        lacquer: [0xFBF6EE, 0xEFE6D8, 0xDDD0BC], edge: 0xC9B89E,
        wall: [0xFFFBF4, 0xEDE3D4, 0xD6C8B2], rose: [0xFBE6E2, 0xEFCFC9, 0xD9AFA8],
        door: [0xF3EBDF, 0xDCCFBB], velvet: [0x8A2C44, 0x5A1426],
        text: 0x2A2118, textSecondary: 0x6F6455, highlight: 0x7A5F33, isLight: true
    )
}

enum Palette {
    private static var style: CabinetStyle { CabinetStyle.current }

    // Korpus
    static var oakTop: Color { Color(hex: style.lacquer[1]) }
    static var oakBottom: Color { Color(hex: style.lacquer[2]) }
    static var oakEdge: Color { Color(hex: style.edge) }
    static var lacquer: LinearGradient {
        LinearGradient(colors: style.lacquer.map { Color(hex: $0) }, startPoint: .top, endPoint: .bottom)
    }

    // Rückwand
    static var wallTop: Color { Color(hex: style.wall[0]) }
    static var wallMid: Color { Color(hex: style.wall[1]) }
    static var wallBottom: Color { Color(hex: style.wall[2]) }
    static var roseTop: Color { Color(hex: style.rose[0]) }
    static var roseMid: Color { Color(hex: style.rose[1]) }
    static var roseBottom: Color { Color(hex: style.rose[2]) }

    // Türen und Samt
    static var doorTop: Color { Color(hex: style.door[0]) }
    static var doorBottom: Color { Color(hex: style.door[1]) }
    static var velvetLight: Color { Color(hex: style.velvet[0]) }
    static var velvetDark: Color { Color(hex: style.velvet[1]) }

    /// Goldener Akzent, auf dem Lack gut lesbar.
    static var highlight: Color { Color(hex: style.highlight) }
    /// Schrift auf einer Fläche in `cream`.
    static var onCream: Color { Color(hex: style.isLight ? 0xFBF7EF : 0x1F1B17) }
    /// Helle oder dunkle Leisten, passend zum Lack.
    static var barScheme: ColorScheme { style.isLight ? .light : .dark }

    // Licht und Metall
    static let led = Color(hex: 0xFFF3D6)
    static let ledGlow = Color(hex: 0xFFE7B8)
    static let brassLight = Color(hex: 0xFBEEC9)
    static let brass = Color(hex: 0xC9A565)
    static let brassDark = Color(hex: 0x7D6131)

    // Text
    static var cream: Color { Color(hex: style.text) }              // Schrift auf dem Lack
    static var creamSecondary: Color { Color(hex: style.textSecondary) }
    static let creamFixed = Color(hex: 0xF6EFE4)                     // immer hell, für dunkle Überlagerungen
    static let creamFixedSecondary = Color(hex: 0xB9AD9C)
    static let ink = Color(hex: 0x1F1B17)          // auf Papier
    static let inkSecondary = Color(hex: 0x5E5446)
    static let bronze = Color(hex: 0x7A5F33)       // Akzent auf Hell (5,4:1)
    static let gold = Color(hex: 0xECD3A0)         // Akzent auf Dunkel

    // Flächen
    static let paper = Color(hex: 0xFBF7EF)
    static let sheet = Color.adaptive(light: 0xF6F1E8, dark: 0x1A0A0E)
    static let card = Color.adaptive(light: 0xFFFDF9, dark: 0x2A1519)
    static let accent = Color.adaptive(light: 0x7A5F33, dark: 0xECD3A0)
    static let rosePetal = Color(hex: 0xE8A7AE)

    static let brassGradient = LinearGradient(
        colors: [brassLight, brass, brassDark],
        startPoint: .top, endPoint: .bottom
    )
}

extension Font {
    static func serif(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        .system(style, design: .serif).weight(weight)
    }
}

// MARK: - Haptik

enum Haptic {
    static func soft() { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
    static func light() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func firm() { UIImpactFeedbackGenerator(style: .rigid).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
}

// MARK: - Holz, Licht, Messing, Glas

struct WoodBackground: View {
    var shade: Double = 0.3

    var body: some View {
        ZStack {
            // Weinroter Lack mit einem Hauch Maserung darunter.
            Rectangle()
                .fill(Palette.lacquer)
                .overlay {
                    Image("Wood")
                        .resizable()
                        .scaledToFill()
                        .opacity(0.12)
                }
                .clipped()
            LinearGradient(
                colors: [.black.opacity(shade * 0.2), .black.opacity(shade)],
                startPoint: .top, endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }
}

/// Die beleuchtete Rückwand des Schranks.
struct BackWall: View {
    var light: Double = 1
    var rose = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: rose ? [Palette.roseTop, Palette.roseMid, Palette.roseBottom]
                             : [Palette.wallTop, Palette.wallMid, Palette.wallBottom],
                startPoint: .top, endPoint: .bottom
            )
            RadialGradient(
                colors: [Palette.led.opacity(0.42), Palette.led.opacity(0.06), .clear],
                center: .top, startRadius: 0, endRadius: 460
            )
            LinearGradient(
                colors: [.black.opacity(0.38), .clear, .clear, .black.opacity(0.38)],
                startPoint: .leading, endPoint: .trailing
            )
            VStack(spacing: 0) {
                Rectangle()
                    .fill(Palette.led)
                    .frame(height: 2.5)
                    .shadow(color: Palette.ledGlow, radius: 9)
                    .shadow(color: Palette.ledGlow.opacity(0.6), radius: 20)
                Spacer(minLength: 0)
            }
            HStack(spacing: 0) {
                Rectangle().fill(Palette.led.opacity(0.9)).frame(width: 1.5)
                    .shadow(color: Palette.ledGlow, radius: 7)
                Spacer(minLength: 0)
                Rectangle().fill(Palette.led.opacity(0.9)).frame(width: 1.5)
                    .shadow(color: Palette.ledGlow, radius: 7)
            }
        }
        .brightness((light - 1) * 0.6)
    }
}

struct GlassShelf: View {
    var body: some View {
        VStack(spacing: 0) {
            Rectangle().fill(.white).frame(height: 1)
            Rectangle()
                .fill(LinearGradient(colors: [.white.opacity(0.9), Color(hex: 0xE9F1EE, opacity: 0.55), Color(hex: 0x9FB0AA, opacity: 0.5)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(height: 5)
            Rectangle().fill(Color(hex: 0x5D5347, opacity: 0.5)).frame(height: 1)
            LinearGradient(colors: [Palette.ledGlow.opacity(0.5), .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: 34)
        }
        .accessibilityHidden(true)
    }
}

struct BrassRod: View {
    var sparkle: Double = 0

    var body: some View {
        ZStack(alignment: .top) {
            Capsule().fill(Palette.brassGradient)
            Capsule().fill(.white.opacity(0.7)).frame(height: 1).padding(.horizontal, 6).padding(.top, 1)
            Capsule().fill(.white.opacity(sparkle))
        }
        .frame(height: 7)
        .shadow(color: .black.opacity(0.35), radius: 3, y: 4)
        .accessibilityHidden(true)
    }
}

/// Bügel mit Messinghaken.
struct Hanger: View {
    var width: CGFloat = 92

    var body: some View {
        ZStack {
            HangerBar()
                .stroke(Palette.brassGradient, style: StrokeStyle(lineWidth: 3, lineCap: .round))
            HangerHook()
                .stroke(Palette.brassGradient, style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
        }
        .frame(width: width, height: 32)
        .accessibilityHidden(true)
    }
}

struct HangerHook: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let cx = r.midX
        p.move(to: CGPoint(x: cx, y: r.minY + 17))
        p.addLine(to: CGPoint(x: cx, y: r.minY + 8))
        p.addQuadCurve(to: CGPoint(x: cx + 8, y: r.minY + 5), control: CGPoint(x: cx + 1, y: r.minY - 1))
        p.addQuadCurve(to: CGPoint(x: cx + 6, y: r.minY + 11), control: CGPoint(x: cx + 11, y: r.minY + 9))
        return p
    }
}

struct HangerBar: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let cx = r.midX
        p.move(to: CGPoint(x: r.minX + 3, y: r.maxY - 2))
        p.addQuadCurve(to: CGPoint(x: cx, y: r.minY + 17), control: CGPoint(x: cx - r.width * 0.22, y: r.minY + 19))
        p.addQuadCurve(to: CGPoint(x: r.maxX - 3, y: r.maxY - 2), control: CGPoint(x: cx + r.width * 0.22, y: r.minY + 19))
        return p
    }
}

/// Eine weit geöffnete Schranktür mit Spiegel auf der Innenseite.
struct CabinetDoor: View {
    enum Side { case leading, trailing }
    let side: Side

    var body: some View {
        ZStack {
            Rectangle()
                .fill(LinearGradient(colors: [Palette.doorTop, Palette.doorBottom], startPoint: .top, endPoint: .bottom))
            Rectangle()
                .strokeBorder(Palette.brass.opacity(0.55), lineWidth: 1)
            Rectangle()
                .fill(LinearGradient(
                    colors: [Color(hex: 0x7F7570), Color(hex: 0x3E3532), Color(hex: 0x8A807A), Color(hex: 0x2F2927)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .padding(.horizontal, 8)
                .padding(.vertical, 18)
                .overlay(
                    Rectangle()
                        .strokeBorder(Palette.brass, lineWidth: 1.5)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 18)
                )
        }
        .frame(width: 56)
        .frame(maxHeight: .infinity)
        .rotation3DEffect(
            .degrees(side == .leading ? -112 : 112),
            axis: (x: 0, y: 1, z: 0),
            anchor: side == .leading ? .leading : .trailing,
            perspective: 0.45
        )
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Papieretikett

struct PaperTag<Content: View>: View {
    var rotation: Double = -1.5
    var maxWidth: CGFloat = 320
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 10) {
            Circle()
                .strokeBorder(Palette.bronze, lineWidth: 1)
                .frame(width: 10, height: 10)
                .accessibilityHidden(true)
            content
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
        .frame(maxWidth: maxWidth)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Palette.paper)
                .shadow(color: .black.opacity(0.22), radius: 14, x: 4, y: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(Palette.bronze.opacity(0.45), lineWidth: 0.75)
        )
        .environment(\.colorScheme, .light)
        .rotationEffect(.degrees(rotation))
    }
}

// MARK: - Bedienelemente

struct GlassChip: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(selected ? .semibold : .regular))
                .foregroundStyle(selected ? Palette.onCream : Palette.cream)
                .lineLimit(1)
                .padding(.horizontal, 15)
                .frame(minHeight: 36)
                .background {
                    if selected {
                        Capsule().fill(Palette.cream)
                    } else {
                        Capsule().fill(.ultraThinMaterial)
                            .overlay(Capsule().strokeBorder(.white.opacity(0.18), lineWidth: 0.75))
                    }
                }
                .contentShape(Rectangle())
                .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct PrimaryCapsuleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(Palette.paper)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(Capsule().fill(Palette.ink))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 1), value: configuration.isPressed)
    }
}

// MARK: - Bilder der Kleidung

struct GarmentImage: View {
    @Environment(Store.self) private var store
    let garment: Garment
    var full = false
    @State private var image: UIImage?

    private var file: String { full ? garment.imageFile : garment.thumbFile }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Color.clear
            }
        }
        .accessibilityLabel(garment.name)
        .task(id: file) {
            guard !file.isEmpty else { return }
            if let cached = ImageCache.shared.get(file) {
                image = cached
                return
            }
            if let loaded = await ImageLoader.shared.load(store.imageURL(file), key: file) {
                image = loaded
            }
        }
    }
}

/// Ein gespeichertes Foto (zum Beispiel aus dem Tagebuch), im Hintergrund geladen.
struct StoredImage: View {
    @Environment(Store.self) private var store
    let file: String
    var contentMode: ContentMode = .fill
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                Rectangle().fill(Palette.card)
            }
        }
        .task(id: file) {
            guard !file.isEmpty else { return }
            if let cached = ImageCache.shared.get(file) {
                image = cached
                return
            }
            image = await ImageLoader.shared.load(store.imageURL(file), key: file)
        }
    }
}

struct ColorDots: View {
    let colors: [GarmentColor]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(colors) { c in
                Circle()
                    .fill(c.color)
                    .frame(width: 14, height: 14)
                    .overlay(Circle().strokeBorder(Palette.ink.opacity(0.25), lineWidth: 0.75))
                    .accessibilityLabel(c.title)
            }
        }
    }
}

struct ColorPickerRow: View {
    @Binding var selection: [GarmentColor]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(GarmentColor.allCases) { c in
                    let on = selection.contains(c)
                    Button {
                        if on { selection.removeAll { $0 == c } } else { selection.append(c) }
                        Haptic.light()
                    } label: {
                        Circle()
                            .fill(c.color)
                            .frame(width: 32, height: 32)
                            .overlay(Circle().strokeBorder(Color.primary.opacity(0.2), lineWidth: 0.75))
                            .overlay {
                                if on {
                                    Image(systemName: "checkmark")
                                        .font(.caption.bold())
                                        .foregroundStyle(c.isLight ? Color.black : Color.white)
                                }
                            }
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(c.title)
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
        }
    }
}

/// Collage aus bis zu vier Teilen auf Papier.
struct OutfitCollage: View {
    let garments: [Garment]

    var body: some View {
        let items = Array(garments.prefix(4))
        Grid(horizontalSpacing: 4, verticalSpacing: 4) {
            GridRow {
                cell(items, 0)
                cell(items, 1)
            }
            GridRow {
                cell(items, 2)
                cell(items, 3)
            }
        }
        .padding(8)
        .aspectRatio(1, contentMode: .fit)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.paper))
        .environment(\.colorScheme, .light)
    }

    @ViewBuilder
    private func cell(_ items: [Garment], _ index: Int) -> some View {
        if index < items.count {
            GarmentImage(garment: items[index])
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .shadow(color: .black.opacity(0.15), radius: 4, x: 2, y: 3)
        } else {
            Color.clear
        }
    }
}
