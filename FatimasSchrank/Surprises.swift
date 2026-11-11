import SwiftUI

// MARK: - Schranktüren beim Start

struct DoorsView: View {
    @Environment(Store.self) private var store
    var autoOpen: Bool
    let onOpened: () -> Void

    @State private var angle: Double = 0
    @State private var flipped = false
    @State private var opening = false

    var body: some View {
        GeometryReader { geo in
            let half = geo.size.width / 2
            ZStack {
                HStack(spacing: 0) {
                    door(handleOnTrailing: true)
                        .frame(width: half)
                        .rotation3DEffect(.degrees(-angle), axis: (x: 0, y: 1, z: 0), anchor: .leading, perspective: 0.55)
                    door(handleOnTrailing: false)
                        .frame(width: half)
                        .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), anchor: .trailing, perspective: 0.55)
                }
                VStack(spacing: 18) {
                    Spacer()
                    monogram
                        .padding(.bottom, 40)
                    Text("Fatimas Schrank")
                        .font(.serif(.title))
                        .foregroundStyle(Palette.cream)
                    Text("Zum Öffnen tippen")
                        .font(.footnote)
                        .foregroundStyle(Palette.creamSecondary)
                    Spacer()
                    Spacer()
                }
                .opacity(angle > 2 ? 0 : 1)
            }
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture { open() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Schranktüren")
        .accessibilityHint("Doppeltippen, um den Schrank zu öffnen")
        .accessibilityAddTraits(.isButton)
        .task {
            guard autoOpen else { return }
            try? await Task.sleep(for: .seconds(3))
            if !flipped { open() }
        }
    }

    private var monogram: some View {
        ZStack {
            Ellipse()
                .fill(Palette.brassGradient)
                .frame(width: 96, height: 120)
                .shadow(color: .black.opacity(0.5), radius: 10, y: 8)
            Ellipse()
                .strokeBorder(Palette.brassDark, lineWidth: 1)
                .frame(width: 84, height: 108)
            if flipped {
                VStack(spacing: 4) {
                    Text(Liebesbriefe.monogramBack)
                        .font(.system(size: 22, weight: .semibold, design: .serif))
                    Text(Liebesbriefe.monogramDate)
                        .font(.system(size: 9, design: .serif))
                        .multilineTextAlignment(.center)
                        .frame(width: 70)
                }
                .foregroundStyle(Color(hex: 0x3A2618))
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
            } else {
                Text("F")
                    .font(.system(size: 54, weight: .regular, design: .serif))
                    .foregroundStyle(Color(hex: 0x3A2618))
            }
        }
        .rotation3DEffect(.degrees(flipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
        .onLongPressGesture(minimumDuration: 0.6) {
            Haptic.firm()
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) { flipped.toggle() }
            store.discover("monogramm")
        }
        .accessibilityHidden(true)
    }

    private func door(handleOnTrailing: Bool) -> some View {
        ZStack {
            // Das Holzbild liegt als Overlay, damit es die Türbreite nicht verändert.
            Palette.oakBottom
                .overlay {
                    Image("Wood")
                        .resizable()
                        .scaledToFill()
                }
                .clipped()
            LinearGradient(colors: [.black.opacity(0.05), .black.opacity(0.35)], startPoint: .top, endPoint: .bottom)
            RoundedRectangle(cornerRadius: 2)
                .strokeBorder(Color(hex: 0x5F4129).opacity(0.7), lineWidth: 1.5)
                .padding(18)
            HStack {
                if handleOnTrailing { Spacer() }
                Capsule()
                    .fill(Palette.brassGradient)
                    .frame(width: 5, height: 120)
                    .shadow(color: .black.opacity(0.4), radius: 3, x: 2, y: 3)
                    .padding(.horizontal, 10)
                if !handleOnTrailing { Spacer() }
            }
            HStack {
                if handleOnTrailing { Spacer() }
                Rectangle().fill(Color.black.opacity(0.55)).frame(width: 1.5)
                if !handleOnTrailing { Spacer() }
            }
        }
        .clipped()
    }

    private func open() {
        guard !opening else { return }
        opening = true
        Haptic.soft()
        withAnimation(.spring(response: 0.95, dampingFraction: 0.9)) { angle = 100 }
        Task {
            try? await Task.sleep(for: .milliseconds(650))
            onOpened()
        }
    }
}

// MARK: - Widmung

struct WelcomeView: View {
    @Environment(Store.self) private var store
    @State private var appeared = false

    var body: some View {
        ZStack {
            WoodBackground(shade: 0.45)
            VStack(spacing: 0) {
                Spacer()
                // Schnur
                Rectangle()
                    .fill(Palette.brass.opacity(0.8))
                    .frame(width: 1, height: appeared ? 120 : 40)
                PaperTag(rotation: appeared ? -2 : 6, maxWidth: 300) {
                    VStack(spacing: 14) {
                        Text("Für dich")
                            .font(.footnote.weight(.semibold))
                            .tracking(1.5)
                            .foregroundStyle(Palette.bronze)
                        Text("Fatimas Schrank")
                            .font(.serif(.title))
                            .foregroundStyle(Palette.ink)
                        Rectangle().fill(Palette.bronze).frame(width: 40, height: 0.75)
                        Text(Liebesbriefe.dedication)
                            .font(.serif(.body))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(Palette.inkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(Liebesbriefe.signature)
                            .font(.serif(.callout).italic())
                            .foregroundStyle(Palette.bronze)
                    }
                    .padding(.vertical, 6)
                }
                .padding(.horizontal, 32)
                Spacer()
                Button("Schrank öffnen") {
                    Haptic.soft()
                    store.db.settings.welcomeSeen = true
                    store.save()
                }
                .buttonStyle(CreamCapsuleStyle())
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 1.1, dampingFraction: 0.55)) { appeared = true }
            Haptic.soft()
        }
    }
}

struct CreamCapsuleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(Palette.ink)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(Capsule().fill(Palette.cream))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 1), value: configuration.isPressed)
    }
}

// MARK: - Blütenblätter an besonderen Tagen

struct PetalsView: View {
    let count = 16

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<count, id: \.self) { i in
                    Petal(index: i, size: geo.size)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct Petal: View {
    let index: Int
    let size: CGSize
    @State private var fallen = false

    var body: some View {
        let seed = Double(index)
        let startX = size.width * (0.08 + 0.84 * ((seed * 0.618).truncatingRemainder(dividingBy: 1)))
        let drift = CGFloat(sin(seed * 1.7) * 60)
        let duration = 3.6 + (seed.truncatingRemainder(dividingBy: 5)) * 0.35
        let delay = seed * 0.12
        Ellipse()
            .fill(LinearGradient(colors: [Color(hex: 0xF6C9CF), Palette.rosePetal], startPoint: .top, endPoint: .bottom))
            .frame(width: 11, height: 16)
            .rotationEffect(.degrees(fallen ? 260 + seed * 20 : seed * 30))
            .position(x: startX + (fallen ? drift : 0), y: fallen ? size.height + 40 : -30)
            .opacity(fallen ? 0.9 : 0)
            .onAppear {
                withAnimation(.easeIn(duration: duration).delay(delay)) { fallen = true }
            }
    }
}

// MARK: - Geheimfach mit Briefen

struct LettersView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var reading: LoveLetter?
    @State private var wiggle: String?

    private var letters: [LoveLetter] {
        Liebesbriefe.letters.sorted { $0.unlockDate > $1.unlockDate }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                WoodBackground(shade: 0.55)
                ScrollView {
                    VStack(spacing: 18) {
                        Text("Nur für dich")
                            .font(.serif(.largeTitle))
                            .foregroundStyle(Palette.cream)
                            .padding(.top, 8)
                        Text("Manche Briefe öffnen sich erst an besonderen Tagen.")
                            .font(.subheadline)
                            .foregroundStyle(Palette.creamSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.bottom, 8)
                        ForEach(letters) { letter in
                            envelope(letter)
                        }
                    }
                    .padding(20)
                }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
            .sheet(item: $reading) { letter in
                LetterReader(letter: letter)
            }
        }
        .onAppear { store.discover("geheimfach") }
    }

    private func envelope(_ letter: LoveLetter) -> some View {
        let open = letter.isOpen()
        let unread = open && !store.db.settings.readLetters.contains(letter.id)
        return Button {
            if open {
                Haptic.light()
                reading = letter
                if !store.db.settings.readLetters.contains(letter.id) {
                    store.db.settings.readLetters.append(letter.id)
                    store.save()
                }
            } else {
                Haptic.light()
                withAnimation(.spring(response: 0.2, dampingFraction: 0.3)) { wiggle = letter.id }
                Task {
                    try? await Task.sleep(for: .milliseconds(250))
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { wiggle = nil }
                }
            }
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 4).fill(open ? Palette.paper : Color(hex: 0xE7DCCB))
                        .frame(width: 58, height: 40)
                    EnvelopeFlap()
                        .stroke(Palette.bronze.opacity(0.6), lineWidth: 0.8)
                        .frame(width: 58, height: 40)
                    Circle()
                        .fill(open ? Palette.brassGradient : LinearGradient(colors: [Color(hex: 0x8C2F3F), Color(hex: 0x5E1A28)], startPoint: .top, endPoint: .bottom))
                        .frame(width: 14, height: 14)
                        .offset(y: 4)
                }
                .shadow(color: .black.opacity(0.3), radius: 4, y: 3)
                VStack(alignment: .leading, spacing: 4) {
                    Text(open ? letter.title : "Versiegelt")
                        .font(.serif(.headline))
                        .foregroundStyle(Palette.ink)
                    Text(open ? (unread ? "Neu" : "Gelesen") : "Öffnet sich am \(letter.unlockDate.german(.dateTime.day().month(.wide).year()))")
                        .font(.footnote)
                        .foregroundStyle(unread ? Palette.bronze : Palette.inkSecondary)
                }
                Spacer()
                if unread {
                    Circle().fill(Palette.brass).frame(width: 8, height: 8)
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Palette.paper.opacity(open ? 1 : 0.82)))
            .rotationEffect(.degrees(wiggle == letter.id ? 2 : 0))
        }
        .buttonStyle(.plain)
        .environment(\.colorScheme, .light)
        .accessibilityLabel(open ? "Brief: \(letter.title)" : "Versiegelter Brief")
    }
}

private struct EnvelopeFlap: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.midX, y: r.midY + 4))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        return p
    }
}

struct LetterReader: View {
    let letter: LoveLetter
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(letter.title)
                    .font(.serif(.title))
                    .foregroundStyle(Palette.ink)
                Text(letter.body)
                    .font(.serif(.body))
                    .foregroundStyle(Palette.ink)
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Palette.paper.ignoresSafeArea())
        .environment(\.colorScheme, .light)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Kleine Karten (Gute Nacht, Meilensteine, Titel, Geburtstag)

struct NoteCard: View {
    let eyebrow: String
    let text: String
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture(perform: onClose)
            VStack(spacing: 0) {
                Rectangle().fill(Palette.brass.opacity(0.8)).frame(width: 1, height: 60)
                PaperTag(rotation: -2.5, maxWidth: 300) {
                    VStack(spacing: 12) {
                        Text(eyebrow)
                            .font(.footnote.weight(.semibold))
                            .tracking(1.2)
                            .foregroundStyle(Palette.bronze)
                        Text(text)
                            .font(.serif(.title3))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(Liebesbriefe.signature)
                            .font(.serif(.footnote).italic())
                            .foregroundStyle(Palette.inkSecondary)
                    }
                }
                .onTapGesture(perform: onClose)
            }
            .padding(.horizontal, 36)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
        .accessibilityAddTraits(.isModal)
    }
}
