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

enum Palette {
    // Korpus
    static let oakTop = Color(hex: 0x4B1020)
    static let oakBottom = Color(hex: 0x2D0913)
    static let oakEdge = Color(hex: 0x22060D)
    static let lacquer = LinearGradient(
        colors: [Color(hex: 0x5C1628), Color(hex: 0x4B1020), Color(hex: 0x2D0913)],
        startPoint: .top, endPoint: .bottom
    )

    // Rückwand
    static let wallTop = Color(hex: 0x54403E)
    static let wallMid = Color(hex: 0x2F2325)
    static let wallBottom = Color(hex: 0x1E1517)
    static let roseTop = Color(hex: 0x6E2A3A)
    static let roseMid = Color(hex: 0x40161F)
    static let roseBottom = Color(hex: 0x24090F)

    // Licht und Metall
    static let led = Color(hex: 0xFFF3D6)
    static let ledGlow = Color(hex: 0xFFE7B8)
    static let brassLight = Color(hex: 0xFBEEC9)
    static let brass = Color(hex: 0xC9A565)
    static let brassDark = Color(hex: 0x7D6131)

    // Text
    static let cream = Color(hex: 0xF6EFE4)        // auf dunklem Holz
    static let creamSecondary = Color(hex: 0xB9AD9C)
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
                .fill(LinearGradient(colors: [Color(hex: 0x3A0D1A), Color(hex: 0x22060D)], startPoint: .top, endPoint: .bottom))
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
                .foregroundStyle(selected ? Palette.ink : Palette.cream)
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
