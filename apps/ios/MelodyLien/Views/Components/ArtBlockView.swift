import SwiftUI

// MARK: - カラーバリアント

extension Color {
    static let mlSunset = LinearGradient(colors: [Color(hex: "ff9a6c"), Color(hex: "ffca7a"), Color(hex: "6b468c")], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let mlViolet = LinearGradient(colors: [Color(hex: "c0adff"), Color(hex: "9271f0"), Color(hex: "4f3b82")], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let mlBerry  = LinearGradient(colors: [Color(hex: "ff8eb5"), Color(hex: "bb74ff"), Color(hex: "39436f")], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let mlMagic  = LinearGradient(colors: [Color(hex: "8ee7ff"), Color(hex: "80d8b5"), Color(hex: "365a70")], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let mlDefault = LinearGradient(colors: [Color(hex: "a892ff"), Color(hex: "ffb0bf"), Color(hex: "33465f")], startPoint: .topLeading, endPoint: .bottomTrailing)

    init(hex: String) {
        let scanner = Scanner(string: hex)
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        self.init(
            red:   Double((rgb >> 16) & 0xff) / 255,
            green: Double((rgb >> 8)  & 0xff) / 255,
            blue:  Double( rgb        & 0xff) / 255
        )
    }
}

func artGradient(for color: String) -> LinearGradient {
    switch color {
    case "sunset": return .mlSunset
    case "violet": return .mlViolet
    case "berry":  return .mlBerry
    case "magic":  return .mlMagic
    default:       return .mlDefault
    }
}

// MARK: - ArtBlockView

/// パズルアート表示。puzzle grid線を疑似的に重ねる
struct ArtBlockView: View {
    let color: String
    var cornerRadius: CGFloat = 18
    var thumbnailURL: URL? = nil

    var body: some View {
        ZStack {
            artGradient(for: color)
            // puzzle grid overlay
            GeometryReader { geo in
                Path { path in
                    let w = geo.size.width
                    let h = geo.size.height
                    let t1x = w * 0.33, t2x = w * 0.66
                    let t1y = h * 0.33, t2y = h * 0.66
                    path.move(to: CGPoint(x: t1x, y: 0)); path.addLine(to: CGPoint(x: t1x, y: h))
                    path.move(to: CGPoint(x: t2x, y: 0)); path.addLine(to: CGPoint(x: t2x, y: h))
                    path.move(to: CGPoint(x: 0, y: t1y)); path.addLine(to: CGPoint(x: w, y: t1y))
                    path.move(to: CGPoint(x: 0, y: t2y)); path.addLine(to: CGPoint(x: w, y: t2y))
                }
                .stroke(Color.white.opacity(0.46), lineWidth: 1)
            }
            if let url = thumbnailURL {
                AsyncImage(url: url) { img in
                    img.resizable().scaledToFill()
                } placeholder: { Color.clear }
                .clipped()
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .overlay(RoundedRectangle(cornerRadius: cornerRadius).stroke(Color.white.opacity(0.45), lineWidth: 1))
    }
}

// MARK: - PieceMeterView

struct PieceMeterView: View {
    let owned: Int
    let total: Int
    var compact: Bool = false

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 6) {
            Text("\(owned) / \(total)")
                .font(.system(size: compact ? 17 : 20, weight: .black))
            Text("ピース")
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(Color(hex: "817992"))
        }
    }
}

// MARK: - ProgressBarView

struct ProgressBarView: View {
    let value: Double   // 0.0 – 1.0

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color(hex: "eee6fb"))
                Capsule()
                    .fill(LinearGradient(colors: [Color(hex: "8f6df4"), Color(hex: "ff7fa6")],
                                        startPoint: .leading, endPoint: .trailing))
                    .frame(width: geo.size.width * min(max(value, 0), 1))
            }
        }
        .frame(height: 8)
    }
}
