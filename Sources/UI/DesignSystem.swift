#if canImport(UIKit)
import SwiftUI

// MARK: - Colour palette (ported from BMFinal — soft mint + pastel accents)

public extension Color {
    // Page & card backgrounds
    static let bmBg         = Color(hex: "#d8f5e8")
    static let bmBgCard     = Color.white
    static let bmBgSoft     = Color(hex: "#e8f8ef")
    static let bmBgMint     = Color(hex: "#c4eeda")
    // Borders
    static let bmBorder     = Color(hex: "#b8ddc8")
    static let bmBorderAct  = Color(hex: "#9bc8a8")
    // Text
    static let bmText1      = Color(hex: "#3a4a3e")
    static let bmText2      = Color(hex: "#6a8070")
    static let bmText3      = Color(hex: "#9ab8a2")
    // Brand green (leaf / CTA)
    static let bmGreen      = Color(hex: "#6aaa82")
    static let bmGreenLight = Color(hex: "#d8f5e8")
    static let bmGreenMid   = Color(hex: "#a8d8bc")
    // Title palette
    static let bmLilac      = Color(hex: "#b8a0d8")  // "BLOOMING"
    static let bmPeach      = Color(hex: "#f0a898")  // "MARVELLOUS"
    static let bmAmber      = Color(hex: "#e8b070")
    static let bmSky        = Color(hex: "#88c8e0")
    // Illustration
    static let bmFlowerPink  = Color(hex: "#f4b8b0")
    static let bmFlowerLilac = Color(hex: "#c0a0d8")
    static let bmPotTerra    = Color(hex: "#d4907a")
    static let bmLeafSage    = Color(hex: "#7aaa8a")
    // Status
    static let bmRed         = Color(hex: "#e07070")

    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var v: UInt64 = 0
        Scanner(string: h).scanHexInt64(&v)
        self.init(.sRGB,
                  red:   Double((v >> 16) & 0xFF) / 255,
                  green: Double((v >> 8)  & 0xFF) / 255,
                  blue:  Double( v        & 0xFF) / 255)
    }
}

// MARK: - BMCard modifier (rounded white card with green-tinted shadow)

public struct BMCard: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .padding(16)
            .background(Color.bmBgCard)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18)
                .stroke(Color.bmBorder, lineWidth: 2))
            .shadow(color: Color.bmGreen.opacity(0.10), radius: 6, y: 2)
    }
}

public extension View {
    func bmCard() -> some View { modifier(BMCard()) }
}

// MARK: - Sticker card modifier (white card with thick white outline + soft shadow)

public struct StickerCard: ViewModifier {
    let radius: CGFloat
    public init(radius: CGFloat = 18) { self.radius = radius }
    public func body(content: Content) -> some View {
        content
            .padding(.horizontal, 20).padding(.vertical, 12)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: radius))
            .overlay(RoundedRectangle(cornerRadius: radius)
                .stroke(Color.white, lineWidth: 5))
            .shadow(color: .black.opacity(0.10), radius: 12, y: 4)
    }
}

public extension View {
    func stickerCard(radius: CGFloat = 18) -> some View { modifier(StickerCard(radius: radius)) }
}

// MARK: - Pill button (rounded capsule in Nunito-Bold)

public struct PillButton: View {
    let label:    String
    let isActive: Bool
    let color:    Color
    let action:   () -> Void

    public init(_ label: String, isActive: Bool, color: Color = .bmGreen,
                action: @escaping () -> Void) {
        self.label = label
        self.isActive = isActive
        self.color = color
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(label)
                .font(.custom("Nunito-Bold", size: 13))
                .padding(.horizontal, 14).padding(.vertical, 7)
                .background(isActive ? color : Color.bmBgCard)
                .foregroundStyle(isActive ? .white : Color.bmText2)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(isActive ? color : Color.bmBorder, lineWidth: 2))
                .shadow(color: isActive ? color.opacity(0.3) : .clear, radius: 4, y: 1)
        }
        .animation(.easeInOut(duration: 0.15), value: isActive)
    }
}

// MARK: - Section label (uppercase Fredoka kerned label)

public struct SectionLabel: View {
    let icon: String?
    let title: String
    public init(_ title: String, icon: String? = nil) {
        self.title = title
        self.icon  = icon
    }
    public var body: some View {
        HStack(spacing: 4) {
            if let icon { Text(icon) }
            Text(title.uppercased())
                .font(.custom("Fredoka-SemiBold", size: 11))
                .foregroundStyle(Color.bmText2)
                .kerning(0.8)
        }
    }
}

// MARK: - Decorative shapes (used in the header / splash)

public struct FlowerShape: Shape {
    let petals: Int
    public init(petals: Int = 5) { self.petals = petals }
    public func path(in rect: CGRect) -> Path {
        let cx = rect.midX, cy = rect.midY
        let r  = min(rect.width, rect.height) / 2
        var p  = Path()
        for i in 0..<petals {
            let a  = (Double(i) / Double(petals)) * .pi * 2 - .pi / 2
            let bx = cx + cos(a) * r * 0.45, by = cy + sin(a) * r * 0.45
            let px = cx + cos(a) * r,        py = cy + sin(a) * r
            let c1x = cx + cos(a + 0.9) * r * 0.75, c1y = cy + sin(a + 0.9) * r * 0.75
            let c2x = cx + cos(a - 0.9) * r * 0.75, c2y = cy + sin(a - 0.9) * r * 0.75
            p.move(to: .init(x: bx, y: by))
            p.addCurve(to: .init(x: px, y: py),
                       control1: .init(x: c1x, y: c1y),
                       control2: .init(x: px, y: py))
            p.addCurve(to: .init(x: bx, y: by),
                       control1: .init(x: c2x, y: c2y),
                       control2: .init(x: bx, y: by))
        }
        return p
    }
}

public struct FlowerView: View {
    let size: CGFloat
    let petalColor: Color
    let centerColor: Color
    let petals: Int
    public init(size: CGFloat = 44,
                petalColor: Color = .bmFlowerPink,
                centerColor: Color = .bmLilac,
                petals: Int = 5) {
        self.size = size
        self.petalColor = petalColor
        self.centerColor = centerColor
        self.petals = petals
    }
    public var body: some View {
        ZStack {
            FlowerShape(petals: petals)
                .fill(petalColor.opacity(0.9))
                .frame(width: size, height: size)
            Circle().fill(centerColor)
                .frame(width: size * 0.28, height: size * 0.28)
            Circle().fill(Color.white.opacity(0.55))
                .frame(width: size * 0.13, height: size * 0.13)
        }
    }
}

public struct LeafView: View {
    let size: CGFloat
    let color: Color
    public init(size: CGFloat = 28, color: Color = .bmLeafSage) {
        self.size = size
        self.color = color
    }
    public var body: some View {
        ZStack {
            Ellipse().fill(color.opacity(0.85))
                .frame(width: size * 0.6, height: size)
            Rectangle()
                .fill(Color.white.opacity(0.35))
                .frame(width: 1.2, height: size * 0.75)
        }
    }
}
#endif
