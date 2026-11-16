import SwiftUI

/// Ein Bild, das geteilt wird.
struct ShareImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

/// Die Karte, die als Bild verschickt wird. Feste Farben, damit sie immer gleich aussieht.
private struct ShareCard: View {
    let name: String
    let images: [UIImage]
    let names: [String]

    private var rows: [[Int]] {
        let indices = Array(images.indices)
        return stride(from: 0, to: indices.count, by: 3).map { start in
            Array(indices[start..<min(start + 3, indices.count)])
        }
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x5C1628), Color(hex: 0x2D0913)], startPoint: .top, endPoint: .bottom)
            VStack(spacing: 18) {
                Text("FATIMAS SCHRANK")
                    .font(.system(size: 13, weight: .semibold))
                    .tracking(3)
                    .foregroundStyle(Color(hex: 0xECD3A0))
                Text(name)
                    .font(.system(size: 34, weight: .regular, design: .serif))
                    .foregroundStyle(Color(hex: 0xF6EFE4))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                VStack(spacing: 10) {
                    ForEach(rows, id: \.self) { row in
                        HStack(spacing: 10) {
                            ForEach(row, id: \.self) { index in
                                VStack(spacing: 6) {
                                    Image(uiImage: images[index])
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 140, height: 150)
                                    Text(index < names.count ? names[index] : "")
                                        .font(.system(size: 12, design: .serif))
                                        .foregroundStyle(Color(hex: 0x5E5446))
                                        .lineLimit(1)
                                }
                                .padding(10)
                                .frame(width: 160)
                                .background(RoundedRectangle(cornerRadius: 12).fill(Color(hex: 0xFBF7EF)))
                            }
                        }
                    }
                }
                Spacer(minLength: 0)
                Text("Was meinst du, Kamran?")
                    .font(.system(size: 17, design: .serif).italic())
                    .foregroundStyle(Color(hex: 0xECD3A0))
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 30)
        }
        .frame(width: 540, height: 675)
    }
}

enum OutfitShare {
    /// Zeichnet den Look als Bild. Die Vorschaubilder werden vorher geladen, damit nichts fehlt.
    @MainActor
    static func image(name: String, garments: [Garment], store: Store) async -> UIImage? {
        let chosen = Array(garments.prefix(6))
        var images: [UIImage] = []
        var names: [String] = []
        for g in chosen {
            if let image = await ImageLoader.shared.load(store.imageURL(g.thumbFile), key: g.thumbFile) {
                images.append(image)
                names.append(g.name)
            }
        }
        guard !images.isEmpty else { return nil }
        let renderer = ImageRenderer(content: ShareCard(name: name, images: images, names: names))
        renderer.scale = 2
        return renderer.uiImage
    }
}
