import SwiftUI

// MARK: - カラーバリアント

extension LinearGradient {
    static let mlSunset  = LinearGradient(colors: [Color(hex: "ff9a6c"), Color(hex: "ffca7a"), Color(hex: "6b468c")], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let mlViolet  = LinearGradient(colors: [Color(hex: "c0adff"), Color(hex: "9271f0"), Color(hex: "4f3b82")], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let mlBerry   = LinearGradient(colors: [Color(hex: "ff8eb5"), Color(hex: "bb74ff"), Color(hex: "39436f")], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let mlMagic   = LinearGradient(colors: [Color(hex: "8ee7ff"), Color(hex: "80d8b5"), Color(hex: "365a70")], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let mlDefault = LinearGradient(colors: [Color(hex: "a892ff"), Color(hex: "ffb0bf"), Color(hex: "33465f")], startPoint: .topLeading, endPoint: .bottomTrailing)
}

extension Color {
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

/// 曲アート（正方形〜任意比率）。サムネイルがあれば中央を切り抜いて表示し、
/// 未解放（mosaic）の場合はネタバレ防止でぼかし（モザイク）をかける。
/// サムネイルが無い架空曲はグラデーション＋擬似パズルグリッドで表示する。
struct ArtBlockView: View {
    let color: String
    var cornerRadius: CGFloat = 18
    var thumbnailURL: URL? = nil
    var mosaic: Bool = false

    /// Track から直接生成する便利イニシャライザ。
    /// 解放済み＝鮮明 / 未解放＝モザイクを自動で出し分ける。
    init(color: String, cornerRadius: CGFloat = 18, thumbnailURL: URL? = nil, mosaic: Bool = false) {
        self.color = color
        self.cornerRadius = cornerRadius
        self.thumbnailURL = thumbnailURL
        self.mosaic = mosaic
    }

    init(track: Track, cornerRadius: CGFloat = 18) {
        self.init(color: track.color,
                  cornerRadius: cornerRadius,
                  thumbnailURL: track.thumbnailURL,
                  mosaic: !track.isUnlocked)
    }

    var body: some View {
        ZStack {
            artGradient(for: color)
            // puzzle grid overlay（サムネイルが無いときの雰囲気づけ）
            if thumbnailURL == nil {
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
            }
            if let url = thumbnailURL {
                CachedThumbnail(url: url)
                    .blur(radius: mosaic ? 10 : 0)
                    .scaleEffect(mosaic ? 1.15 : 1)   // ぼかしの縁が透けないよう少し拡大
            }
            if mosaic {
                Color.black.opacity(0.06)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .overlay(RoundedRectangle(cornerRadius: cornerRadius).stroke(Color.white.opacity(0.45), lineWidth: 1))
    }
}

// MARK: - PuzzlePiecesView

/// 設計書準拠の 6×4＝24ピースのパズル表示。
/// 所持ピースだけサムネイルを見せ、未所持は lockedピース（淡い紫）で隠す。
/// - revealAll: フル表示（全ピースを見せる）
/// - blur: モザイク（未解放曲のフル表示などで使用）
struct PuzzlePiecesView: View {
    let thumbnailURL: URL?
    let ownedPieces: [Int]
    var color: String = "violet"
    var cornerRadius: CGFloat = 16
    var revealAll: Bool = false
    var blur: Bool = false

    private let cols = 6
    private let rows = 4
    private let gap: CGFloat = 2

    private func isVisible(_ n: Int) -> Bool { revealAll || ownedPieces.contains(n) }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                // ベース：未所持ロックピース（淡い紫グレー）
                pieceGrid(w: w, h: h) { _ in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(hex: "E3DAF5"))
                        .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color(hex: "D3C7EE"), lineWidth: 0.5))
                }
                // サムネイル（所持ピースのみマスク表示）
                Group {
                    if let url = thumbnailURL {
                        CachedThumbnail(url: url)
                    } else {
                        artGradient(for: color)
                    }
                }
                .frame(width: w, height: h)
                .blur(radius: blur ? 16 : 0)
                .mask(
                    pieceGrid(w: w, h: h) { n in
                        Rectangle().fill(isVisible(n) ? Color.white : Color.clear)
                    }
                )
            }
            .frame(width: w, height: h)
        }
        .aspectRatio(16.0 / 9.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .overlay(RoundedRectangle(cornerRadius: cornerRadius).stroke(Color(hex: "E0D8F7")))
    }

    @ViewBuilder
    private func pieceGrid<Cell: View>(w: CGFloat, h: CGFloat, @ViewBuilder cell: @escaping (Int) -> Cell) -> some View {
        VStack(spacing: gap) {
            ForEach(0..<rows, id: \.self) { r in
                HStack(spacing: gap) {
                    ForEach(0..<cols, id: \.self) { c in
                        cell(r * cols + c + 1)
                    }
                }
            }
        }
        .frame(width: w, height: h)
    }
}

// MARK: - CachedThumbnail

/// SwiftUI標準の AsyncImage は再描画のたびにロードをやり直し、
/// 読み込み中はプレースホルダ（=下のグラデーション）に戻ってしまう。
/// NSCache + @State で一度読み込んだ画像を保持し、再描画でも消えないようにする。
final class ThumbnailCache {
    static let shared = NSCache<NSURL, UIImage>()
}

/// QUIC スタール対策＋タイムアウト付きの専用セッション。
/// シミュレータで img.youtube への HTTP/3 接続がハングする事象を回避する。
private let thumbnailSession: URLSession = {
    let cfg = URLSessionConfiguration.default
    cfg.timeoutIntervalForRequest = 12
    cfg.timeoutIntervalForResource = 20
    cfg.waitsForConnectivity = true
    cfg.requestCachePolicy = .returnCacheDataElseLoad
    return URLSession(configuration: cfg)
}()

struct CachedThumbnail: View {
    let url: URL
    @State private var image: UIImage?

    var body: some View {
        // Color.clear を基準にすることで、コンテナの形（正方形/16:9）に必ず追従させる。
        // 画像を overlay にすると画像自身がレイアウトサイズを決めなくなり、
        // scaledToFill でその枠を埋めて中央クロップされる（正方形なら 1:1 クロップ）。
        Color.clear
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                }
            }
            .clipped()
            .onAppear {
                if image == nil,
                   let cached = ThumbnailCache.shared.object(forKey: url as NSURL) {
                    image = cached
                }
            }
            .task(id: url) { await load() }
    }

    private func load() async {
        // ビューが別URLで再利用されたとき、前の画像が残らないよう必ず更新する
        if let cached = ThumbnailCache.shared.object(forKey: url as NSURL) {
            image = cached
            return
        }
        image = nil   // 取得中は前トラックの画像を消す（取り違え防止）

        // 同梱画像（file URL）はディスクから直接読む。ネットワーク不要・即時。
        if url.isFileURL {
            guard let data = try? Data(contentsOf: url),
                  let ui = UIImage(data: data) else { return }
            ThumbnailCache.shared.setObject(ui, forKey: url as NSURL)
            image = ui
            return
        }

        guard let (data, _) = try? await thumbnailSession.data(from: url),
              let ui = UIImage(data: data) else { return }
        ThumbnailCache.shared.setObject(ui, forKey: url as NSURL)
        image = ui
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
