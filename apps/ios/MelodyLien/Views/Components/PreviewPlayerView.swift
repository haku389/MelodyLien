import SwiftUI
import WebKit

// MARK: - YouTube 音声プレイヤー（隠し WKWebView）

/// YouTube IFrame Player API を WKWebView に載せ、サビ位置から自動再生する。
/// 映像は上の不透明レイヤーで隠し「音声だけ」の体験にする（設計書 §5.2/5.3）。
struct YouTubeAudioPlayer: UIViewRepresentable {
    let videoId: String
    let startSeconds: Int
    @Binding var stopSignal: Bool

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []   // 自動再生（音あり）を許可
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.isUserInteractionEnabled = false
        wv.scrollView.isScrollEnabled = false
        wv.backgroundColor = .black
        wv.isOpaque = true
        wv.loadHTMLString(Self.html(videoId: videoId, start: startSeconds),
                          baseURL: URL(string: "https://www.youtube.com"))
        return wv
    }

    func updateUIView(_ wv: WKWebView, context: Context) {
        if stopSignal {
            wv.evaluateJavaScript("window.stopPreview && window.stopPreview();", completionHandler: nil)
        }
    }

    private static func html(videoId: String, start: Int) -> String {
        """
        <!DOCTYPE html><html><head>
        <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
        <style>html,body{margin:0;padding:0;background:#000;overflow:hidden;}#player{width:100%;height:100%;}</style>
        </head><body>
        <div id="player"></div>
        <script src="https://www.youtube.com/iframe_api"></script>
        <script>
        var player;
        function onYouTubeIframeAPIReady(){
          player = new YT.Player('player', {
            videoId: '\(videoId)',
            playerVars: {autoplay:1, controls:0, rel:0, modestbranding:1, playsinline:1, fs:0, disablekb:1, start:\(start)},
            events: { 'onReady': function(e){ e.target.setVolume(100); e.target.playVideo(); } }
          });
        }
        window.stopPreview = function(){ if(player && player.pauseVideo){ player.pauseVideo(); } };
        </script></body></html>
        """
    }
}

// MARK: - 試聴モーダル

struct PreviewPlayerView: View {
    @EnvironmentObject var vm: AppViewModel
    let trackId: String

    @State private var secondsLeft = 30
    @State private var stopSignal = false
    @State private var finished = false
    @State private var waveAnimate = false

    private let total = 30
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var track: Track? { vm.track(for: trackId) }

    var body: some View {
        ZStack {
            // 非表示の音声プレイヤー（不透明な背景レイヤーで隠す＝音声のみ）
            if let t = track, let vid = t.youtubeVideoId {
                YouTubeAudioPlayer(videoId: vid, startSeconds: t.chorusStart ?? 0, stopSignal: $stopSignal)
                    .frame(width: 240, height: 135)
                    .allowsHitTesting(false)
            }
            LinearGradient(colors: [Color(hex: "1a1030"), Color(hex: "0f0a20")],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            content
        }
        .onReceive(timer) { _ in tick() }
        .onAppear { waveAnimate = true }
    }

    private var content: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button { end() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .heavy)).foregroundStyle(.white.opacity(0.7))
                        .frame(width: 36, height: 36)
                        .background(.white.opacity(0.1), in: Circle())
                }
            }
            .padding(.horizontal, 20).padding(.top, 16)

            Spacer()

            // 波形アニメーション（オーディオプレイヤー風）
            HStack(spacing: 5) {
                ForEach(0..<13, id: \.self) { i in
                    Capsule()
                        .fill(LinearGradient(colors: [Color(hex: "b79cff"), Color(hex: "8f6df4")],
                                             startPoint: .top, endPoint: .bottom))
                        .frame(width: 5, height: barHeight(i))
                        .animation(finished ? .default
                                   : .easeInOut(duration: 0.45).repeatForever().delay(Double(i) * 0.06),
                                   value: waveAnimate)
                }
            }
            .frame(height: 80)
            .opacity(finished ? 0.3 : 1)
            .padding(.bottom, 28)

            Text(track?.isUnlocked == true ? (track?.title ?? "—") : (track?.maskedLabel ?? "未解放メロディ"))
                .font(.system(size: 18, weight: .black)).foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Text(track?.displayArtist ?? "—")
                .font(.system(size: 12, weight: .heavy)).foregroundStyle(Color(hex: "a78bf8"))
                .padding(.top, 4)

            // カウントダウン
            Text(finished ? "完了" : "\(secondsLeft)")
                .font(.system(size: 40, weight: .black, design: .rounded)).foregroundStyle(.white)
                .padding(.top, 20)
            Text("秒").font(.system(size: 10, weight: .heavy)).foregroundStyle(.white.opacity(0.5))

            // プログレスバー
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.12))
                    Capsule()
                        .fill(LinearGradient(colors: [Color(hex: "8f6df4"), Color(hex: "ff7fa6")],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * CGFloat(secondsLeft) / CGFloat(total))
                        .animation(.linear(duration: 1), value: secondsLeft)
                }
            }
            .frame(height: 6)
            .padding(.horizontal, 40).padding(.top, 18)

            Text("本日あと \(vm.previewPlaysLeft(trackId: trackId)) 回試聴できます")
                .font(.system(size: 11, weight: .heavy)).foregroundStyle(.white.opacity(0.5))
                .padding(.top, 14)

            if finished {
                Text("試聴おわり。ヒントや確認で曲名を当てよう")
                    .font(.system(size: 11, weight: .heavy)).foregroundStyle(.white.opacity(0.55))
                    .padding(.top, 14)
            }

            Spacer()

            Button { end() } label: {
                Text(finished ? "閉じる" : "停止する")
                    .font(.system(size: 14, weight: .black)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 15)
                    .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.15)))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24).padding(.bottom, 28)
        }
    }

    private func barHeight(_ i: Int) -> CGFloat {
        if finished { return 10 }
        let base: [CGFloat] = [22, 44, 30, 60, 38, 70, 50, 70, 38, 60, 30, 44, 22]
        return waveAnimate ? base[i % base.count] : 12
    }

    private func tick() {
        guard !finished else { return }
        if secondsLeft > 0 { secondsLeft -= 1 }
        if secondsLeft <= 0 {
            finished = true
            stopSignal = true
        }
    }

    private func end() {
        stopSignal = true
        vm.endPreview()
    }
}
