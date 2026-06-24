# MelodyLien 実装記録

このファイルは、MelodyLienで実装した内容を毎回記録するためのログです。

## 現在の実装状態サマリー（2026-06-17 時点）

### アーキテクチャ

```text
Webプロトタイプ（apps/web/）: 静的SPA・ES Modules・LocalStorage永続化・port 5174
Go API（main.go + api/）: 曲検索・カタログ提供・port 3001
Supabase（MelodyLien / ap-northeast-1）: PostgreSQL（RLS・9テーブル）+ Auth
```

### 実装済み機能一覧

| 分類 | 機能 | 状態 |
|---|---|---|
| コア | 8画面（ホーム/メロディ/ピース選択/未解放/パズル/コレクション/ランキング/マイページ） | ✅ |
| コア | 24ピースパズル（6×4実画像・所持グリッド・モザイク⇄ピース切替） | ✅ |
| コア | 初期ピース1〜7枚ランダム（三角分布） | ✅ |
| コア | メロディコイン（新規+1 / 完成後重複+3） | ✅ |
| コア | 伏せ字・広告ヒント段階解放・YouTube確認フロー | ✅ |
| コア | パズル完成演出（パーティクル・曲名自動解放）【A-1】 | ✅ |
| すれちがい | 出会い5件・順番制フロー（進捗ドット・ロック・自動前進）【A-2】 | ✅ |
| すれちがい | 同一ユーザークールタイム6時間（バナー表示） | ✅ |
| すれちがい | ピース取得後のフレンド申請（追加/スキップ） | ✅ |
| 試聴 | YouTube 30秒試聴（音声のみ・サビ位置・波形UI） | ✅ |
| 試聴 | 試聴回数制限 1曲1日3回（残回数表示・日付リセット）【A-3】 | ✅ |
| バックエンド | Supabase プロジェクト・スキーマ・シード・RLS【B-1】 | ✅ |
| バックエンド | Go API の Supabase カタログ連携・`/api/search` | ✅ |
| 認証 | ログイン画面（メール/Google/Apple/LINE/ゲスト）【B-2】 | ✅ |
| 認証 | ゲスト機能制限（フレンド・ランキング不可＋登録導線） | ✅ |
| 認証 | Google/Apple OAuth・LINE OIDC・匿名認証の有効化 | ⏳ ダッシュボード設定待ち |
| バックエンド | ピース・コレクションのSupabase同期（ログイン時マージ＋都度反映）【B-3】 | ✅ |
| その他 | 音楽検索（Go API + ローカルフォールバック） | ✅ |
| マイページ | フレンド一覧・フレンド詳細画面（音楽でつながった履歴）【C-1】 | ✅ |
| ホーム | デイリーミッション（ピース5個獲得でコイン+10）【C-2】 | ✅ |
| コレクション | アーティストタブの実計算化（全アーティスト・完成数連動）【C-3】 | ✅ |
| コレクション | 称号タブ（8種・達成条件・進捗バー・獲得演出）【C-3】 | ✅ |
| すれちがい | フレンド交換回数の実イベント連動（再交換で+1・Supabase同期）【C-4】 | ✅ |
| ドキュメント | SwiftUI / Jetpack Compose 移植対応表（docs/native-porting-map.md）【C-5】 | ✅ |
| すれちがい | クールタイム明け（6時間経過）の出会いが再度受信可になる日次リフレッシュ【D-1】 | ✅ |
| マイページ/コレクション | 推し曲設定（解放済みの曲から最大3曲・トグル）【D-2】 | ✅ |
| コレクション | 称号獲得時のトースト・獲得演出オーバーレイ【E-1】 | ✅ |
| コア | 経験値・レベルアップ（新規ピース+5 / 完成+50・レベルバー連動）【E-2】 | ✅ |
| ランキング | 自分の順位の実データ算出（所持ピース数・友達タブはフレンド連動）【E-3】 | ✅ |
| コア | パズル完成報酬コインの実付与（rewardCoins 100枚）【F-1】 | ✅ |
| マイページ | プレミアムプラン（模擬加入・広告スキップ・推し曲5曲・エリアランキング）【F-2】 | ✅ |
| ホーム | 今日のメロディプレイリスト画面（ヒーローパネルから遷移）【F-3】 | ✅ |
| マイページ | ショップ（ヒントチケット・ランダムピース・アバター装飾の購入/装備）【G-1】 | ✅ |
| マイページ | 通知設定画面（即時/まとめ通知・時間帯・項目別トグルの永続化）【G-2】 | ✅ |
| マイページ | 音楽サービス連携の模擬実装（Spotify/Apple Music/YouTube Music）【G-3】 | ✅ |
| マイページ | バックグラウンド検知の設定画面（ON/OFF・スキャン頻度・夜間停止）【H-1】 | ✅ |
| コレクション | 称号の常設リワード（獲得時にコイン/EXPボーナス・演出/タブに報酬表示）【H-2】 | ✅ |
| すれちがい | 推し曲のすれちがい連動（交換時に自分の推し曲を相手へ配達・回数記録）【H-3】 | ✅ |
| ホーム | 通知バナーと通知設定の連動（即時通知OFFで🔕バナー・まとめ通知表示に切替）【I-1】 | ✅ |
| コレクション | アーティスト詳細ページ（アーティストタブの「詳細 ›」から曲パズル一覧へ遷移）【I-2】 | ✅ |

---

## 2026-06-04

- 仕様書を読み、主要体験を「近距離で届いたメロディの確認」「5枠からのピース選択」「未解放曲の伏せ字・試聴・広告ヒント」「曲パズル進行」「アーティストパズル」「今日のメロディプレイリスト」として整理。
- 依存関係なしで動作する静的SPAを新規作成。
- `index.html` に主要6画面と広告確認モーダルの土台を追加。
- `src/styles.css` に仕様書のカラーパレット、角丸、柔らかい影、ぷっくりしたカード・ボタン・下部タブのUIを実装。
- `src/app.js` に画面遷移、ピース候補選択、未解放曲への遷移、広告確認モーダル、ヒント段階の更新を実装。
- `assets/` にメロディコイン、パズルピース、ヒントチケット、マスコット、パズルカバー、背景装飾、アーティスト画像のSVG素材を追加。
- ブラウザ検証で見つかった日本語ラベル・数値・ミッションカード見出しの折り返しとページ全体スクロールバーをCSSで調整。

### 本実装フェーズ1

- `index.html` を ES Modules 前提に変更。
- `src/data.js` を追加し、ユーザー、楽曲、アーティスト、近距離交換候補、今日のメロディプレイリストのシードデータを分離。
- `src/store.js` を追加し、画面状態、選択中トラック、所持ピース、ヒント段階、YouTube確認リンク表示状態、解放済み曲、あとで聴くをLocalStorageへ永続化。
- `src/app.js` を再構成し、画面描画とイベント接続をストア駆動に変更。
- ピース候補選択時に所持ピースを追加し、未解放曲は未解放画面、解放済み曲はパズル画面へ遷移するように実装。
- 「答えを見る」は広告確認後にYouTube確認導線を表示し、「確認する」で曲名・アーティスト名を解放する段階フローに変更。
- 曲パズル画面の所持ピース数と進行バーをストアの所持ピースから算出するように変更。
- `package.json` を追加し、`npm run check` と `npm run test:store` で構文チェックとストア永続化テストを実行できるようにした。
- Browserでホーム、ピース選択、未解放曲、広告確認、YouTube確認相当の解放、パズル画面までの主要フローを確認。

### 本実装フェーズ2

- 参考UIに合わせて各画面のHTML構造・CSSを全面改修。
  - ホーム：「近距離交換をはじめる」ボタン、通知バッジ、レベルバー、コレクション実計算
  - ピース選択：横スクロールカード列、選択状態ハイライト、固定「このピースを選ぶ」ボタン
  - 未解放メロディ：★マスク表示、🎫チケットアイコン付きヒントボタン、「あとで確認」
  - 広告モーダル：マスコット配置、「※広告視聴後はキャンセルできません」注釈
  - アーティスト：アーティストパズル進行バッジ、3状態ステータスバッジ、NEWバッジ
  - 曲パズル：パズルSVGアセット使用、空ピースのグレー表示
- UIのハードコード値をすべて実状態から計算するように修正。
  - コレクション統計（曲パズル完成数、アーティスト数、プレイリスト数）をstoreから算出
  - `collectionSummary` を `seedData` から削除
  - 今日のメロディのピース進行をプレイリスト先頭曲の `collectedPieces` から算出
  - アーティスト画面「あと○曲」を `totalTrackPuzzles - completedTrackPuzzles` で計算
- `server/` ディレクトリにNode.js APIサーバーを新規作成（`npm run api` で起動 / port 3001）。
  - `server/schema.sql`：PostgreSQLテーブル定義（users / artists / tracks / collected_pieces / encounters など12テーブル）
  - `server/db/client.js`：インメモリストア（開発用）＋クエリヘルパー関数群
  - `server/db/seed.js`：初期データ定義
  - `server/routes/tracks.js`：GET /api/tracks, GET /api/tracks/:id, POST unlock/pieces/hint
  - `server/routes/users.js`：GET /api/me, /collection, /mission, POST listen-later
  - `server/routes/encounters.js`：GET /api/encounters/today, POST select
  - `server/routes/playlist.js`：GET /api/playlist/daily
  - `server/middleware/cors.js`：CORS・JSONレスポンスヘルパー
  - `server/index.js`：ルーティングテーブルとHTTPサーバー起動

### UI再作成フェーズ

- Goインストール確認として `go version` を実行し、`go1.26.4 darwin/arm64` を確認。
- UI崩れの原因になっていた画面テンプレートとCSSを0ベースで再作成。
- `src/app.js` を全面整理し、インラインスタイルを排除して、状態管理・データ定義を維持したまま表示レイヤーを差し替え。
- `src/styles.css` を全面差し替えし、モバイル優先の安定したカード、ヘッダー、下部タブ、候補カード、パズル、モーダル、トーストへ再定義。
- ホーム画面を「ユーザー状態」「今日のメロディ」「コレクション」「ミッション」「最近追加した曲」の縦積み構成へ変更。
- ピース選択画面を横スクロール候補カード + 画面下部の確定ボタンに整理。
- 未解放曲、曲パズル、アーティスト、プレイリスト画面も同じUI基準で再構成。
- `npm run check` と `npm run test:store` を実行し、構文チェックとストア永続化テストが通ることを確認。
- Browserでホーム、ピース候補選択、候補確定、パズル、アーティスト画面のDOM状態とテキスト溢れを確認。

### UIフォント・変数化修正

- UI全体のフォントサイズを縮小。
  - body: 12px
  - ホームユーザー名・画面タイトル: 15px
  - メインのピース数表示: 20px
  - ボタン: 12px
- `status: "あと3ピース"` のような派生表示値を `src/data.js` から削除。
- `6 / 9`、`3 / 5`、完成までの残りピース、プレイリスト曲の状態表示を `state.collectedPieces`、`pieceCount`、`mission.current`、`mission.target` から算出する形に変更。
- `app.js` に残っていた日本語UI文言を `src/data.js` の `UI_TEXT` へ移動。
- プレイリストサブタイトルと出会いサマリーを `dailyPlaylist.encounterId` と `encounters[].summary` から生成するように変更。
- `rg` で `app.js` 内の日本語直書き、固定進行値、`status` 参照が残っていないことを確認。
- `npm run check` と `npm run test:store` を実行し、構文チェックとストア永続化テストが通ることを確認。

### 仕様変更反映

- **未解放メロディのマスク仕様変更**
  - アーティスト名は常に表示するよう変更（旧: アーティスト名も伏せ字）
  - 曲名の伏せ字を `○` から `?`（文字数に合わせた個数）に変更
  - `masks` → `titleMasks`（タイトルのみ）にデータ構造を変更
  - `maskForTrack` を `${artistName} / ${titleMask}` 形式に更新
  - ホームの「最近追加した曲」でも未解放曲のアーティスト名を表示するよう修正

- **ピース候補選択画面のタイマー削除**
  - 残り時間（`00:45` 等）の表示を削除
  - `encounter.expiresInSeconds` の参照を除去

- **メロディコイン取得ルール追加**
  - ピース新規獲得時: +1枚
  - パズル全揃い後の重複ピース取得時: +3枚
  - `state.coins` をストア管理に追加（LocalStorage 永続化）
  - ホームのコイン表示を `seedData.user.coins` → `state.coins` に変更

- **開発サーバー改善 (`apps/web/serve.py`)**
  - ESModule のキャッシュ問題を解決するため全JSファイルのインポート文にタイムスタンプを動的付与
  - HTML・JS すべてに `Cache-Control: no-store` を付与

- **仕様書（Obsidianmd）更新**
  - 開発計画書 §10: アーティスト名公開・`?`マスク・ヒント段階の例を更新
  - 開発計画書 §8.2: メロディコイン取得ルール表を追加
  - UI設計書 §5.2: 残り時間削除・コイン表示仕様を更新

### モザイク調整・YouTube 30秒試聴機能（音声専用・サビ位置再生）

- **モザイク強度を緩和** — `filter:blur(22px) brightness(0.55)` → `blur(12px) brightness(0.78)` に変更。全体の輪郭が薄く感じ取れる程度に調整。

- **YouTube IFrame 30秒試聴（音声専用・サビ位置から再生）**
  - `apps/web/src/data.js`: 全8曲（実YouTube IDあり）に `chorusStart`（サビ開始秒数）を追加。
    - Pretender:57s / Lemon:68s / 夜に駆ける:52s / 唱:44s / 怪獣の花唄:38s / Anytime Anywhere:58s / ブルーベリー・ナイツ:55s / ハルジオン:62s
  - `index.html`: 試聴モーダル `#preview-modal` を音声プレイヤーUIに再設計。
    - `#preview-player` をモーダル外の `position:fixed; left:-9999px` に移動し、映像を非表示のまま音声だけ再生。
    - 13本のバーが異なるタイミングで上下する CSS 波形アニメーション（`@keyframes wave-bar`）を表示。
    - 再生完了・停止時は `.stopped` クラスで波形をフラット化。
    - ダーク背景 `#1a1030` のオーディオプレイヤー風デザイン。
  - `apps/web/src/app.js`: `openPreview(trackId)` を更新。
    - `YT.Player` に `playerVars: { autoplay:1, controls:0, start: track.chorusStart }` を渡してサビから自動再生。
    - `display:none` ではなくオフスクリーン配置で再生継続を保証。
    - 30秒カウントダウン完了後に `pauseVideo()`、未解放曲はヒントLv1自動付与。
  - 架空曲（`youtubeVideoId` が `"official-"` 始まり）はアラートで試聴不可を通知。
  - メロディカルーセルの曲名下に「▶ 少し聴く」ボタンを追加。未解放メロディ画面にも設置済み。

次の候補:

- 音楽検索・公式MV判定・正規パズル画像DBのAPIモックを追加する。
- 近距離交換イベントと通知制限のドメインロジックを追加する。
- Go API / PostgreSQL スキーマ / 管理画面の最小構成を追加する。
- SwiftUI / Jetpack Compose へ移植する場合の画面コンポーネント対応表を作成する。

## 2026-06-09

### フロー確認・UI改修・パズル画像生成

**実装対象ディレクトリ**: `apps/web/src/`（開発サーバーが配信する実ファイル）
※ルートの `src/` は古い並行コピーのため対象外。

- **ピース候補確定→ピース選択フローの動作確認**
  - メロディ画面（カルーセル）→「このパズルにする」→ ピース選択画面（6×4 = 24ピースグリッド）→ ピース取得 → 未解放メロディ画面 の一連フローを通し確認。
  - `SELECT_PUZZLE` → `activeScreen: "piece-select"` → `SELECT_PIECE` → `activeScreen: mystery/puzzle` の遷移が正常動作していることを確認。
  - 「パズルを選び直す」ボタンでカルーセルへ戻る動作も確認。
  - ピース取得時のトースト（`メロディコイン ×1`）表示も確認。

- **背景装飾の削除**
  - `apps/web/src/styles.css`: `body` の `radial-gradient` 装飾を削除し、`background: #f8f4fc` に変更。
  - `apps/web/src/styles.css`: `.app-shell` の `url("../assets/bg-doodles.svg")` 背景パターン（格子模様アイコン）を削除。
  - `apps/web/src/styles.css`: `.art-block::after` の格子状ハイライトオーバーレイを削除。

- **プレースホルダーのグリーンバック化**
  - `apps/web/src/styles.css`: `.art-block` および `.art-block.sunset/violet/berry/magic` のカラーグラデーションを `background: #3ecf6b`（グリーンバック）に統一。
  - `apps/web/src/styles.css`: `.avatar` の `background` をグリーンバックに変更。
  - 意図：実画像が差し込まれていない箇所が一目でわかるようにする。本番画像が入った箇所（Pretenderなど）は上書きされるため影響なし。

- **未実装曲のパズル画像生成（グリーンバック仮画像）**
  - `puzzle_test/generate_puzzle.py` を使い、9曲分のグリーンバックサムネイル（1200×672px）からピース24枚を生成。
  - 生成対象：`track_sunset_drive` / `track_lemon` / `track_yoru` / `track_show` / `track_kaiju` / `track_anytime` / `track_blueberry` / `track_magic_hour` / `track_halzion`
  - 各曲の出力先：`apps/web/assets/puzzles/{track_id}/piece_01.png ~ piece_24.png` および `preview.png`

- **`PUZZLE_ASSETS` を全曲対応に更新**
  - `apps/web/src/data.js`: `PUZZLE_ASSETS.tracks` に全9曲を追加。
  - コメントで `✓ 本番画像`（Pretender）と `★ greenback`（仮画像）を区別。
  - これにより、ピース選択グリッドで所持ピースがグリーン画像、未所持ピースが暗い lockedピースとして正しく表示される。

### 本番YouTubeサムネイル差し替え

- YouTube画像CDN（`https://img.youtube.com/vi/{videoId}/maxresdefault.jpg`）からAPIキー不要でサムネイルを取得。
- `generate_puzzle.py`（`puzzle_test/.venv` 環境）でサムネイルを24ピース＋preview.pngに分割。
- 差し替え対象8曲（実YouTube IDあり）:

| トラックID | 曲名 | アーティスト | YouTube ID |
|---|---|---|---|
| track_pretender | Pretender | Official髭男dism | TQ8WlA2GXbk |
| track_lemon | Lemon | 米津玄師 | SX_ViT4Ra7k |
| track_yoru | 夜に駆ける | YOASOBI | x8VYWazR5mE |
| track_show | Show | King Gnu | pgXpM4l_MwI |
| track_kaiju | 怪獣の花唄 | Vaundy | UM9XNpgrqVk |
| track_anytime | Anytime | ATARASHII GAKKO! | r105CzDvoo0 |
| track_blueberry | ブルーベリー・ナイツ | マカロニえんぴつ | Euf1-3WRino |
| track_halzion | ハルジオン | YOASOBI | kzdJkT4kp-A |

- ハルジオン: `maxresdefault` が存在せず11KB（小サイズ）のため `hqdefault.jpg` を使用。
- 架空曲2曲（`track_sunset_drive` / `track_magic_hour`）はグリーンバック仮画像のまま維持。
- `apps/web/src/data.js`: `seedData.tracks` の `youtubeVideoId` と `thumbnailUrl` を全曲分更新。
  - `track_blueberry` のタイトルも `"ブルーベリー"` → `"ブルーベリー・ナイツ"` に修正。
  - 架空曲の `thumbnailUrl` を `ASSETS.cover` → `./assets/puzzles/{track_id}/preview.png` に統一。

### 音楽検索・Go API 最小構成

- **Go API コンパイルエラー修正**
  - `backend/api/go.mod` の module 名が `melodylien` なのに import が `melodylien/api/handler` になっていた。
  - `main.go` / `handler/handler.go` / `store/store.go` の import を `melodylien/handler` 等に修正。
  - `go build ./...` が通ることを確認。

- **シードデータ更新（`backend/api/store/store.go`）**
  - 全曲の `PieceCount` を 9 → 24 に修正（6×4 グリッドと一致）。
  - `track_pretender`（Official髭男dism）を追加。計10曲。
  - `track_blueberry` タイトルを `"ブルーベリー"` → `"ブルーベリー・ナイツ"` に修正。
  - `track_show` artistID → `artist_kingu_gnu`（King Gnu）、`track_anytime` artistID → `artist_atarashii`（ATARASHII GAKKO!）に修正。
  - `artist_kingu_gnu` / `artist_atarashii` を Artists に追加（計10アーティスト）。

- **音楽検索エンドポイント追加（`GET /api/search?q=...`）**
  - `store.SearchTracks(q)`: タイトル・アーティスト名に対してキーワード検索、最大20件返却。
  - `handler.searchTracks`: `/api/search` ルートを追加。
  - レスポンス: `{ query, results: [{trackId, title, artistName, color, youtubeId}] }`

- **SPA への API 統合（`apps/web/src/`）**
  - `apps/web/src/api.js` を新規作成（3秒タイムアウト付き fetch ラッパー）。
  - `apps/web/src/app.js`: コレクション画面に検索バーUI追加。250ms デバウンスで API 検索、未起動時はローカルフォールバック。結果に「Go API / ローカル」取得元ラベル表示。
  - `apps/web/src/styles.css`: 検索バー・ドロップダウン・バッジのスタイルを追加。

### クールタイム・モザイク切り替え・UI改善

- **同一ユーザーとのクールタイム 6時間**
  - `data.js`: encounter に `fromUserId`, `fromUserName` を追加。`initialAppState()` に `encounterCooldowns: {}` を追加。
  - `store.js`: `SELECT_PIECE` 時に `encounterCooldowns[encounterId] = Date.now()` を記録。LocalStorage に永続化。
  - `app.js`: `cooldownRemaining()` / `formatCooldown()` ヘルパーを追加。メロディ画面ヘッダー下にクールタイムバナー（⏳ ユーザー名・残り時間）を表示。

- **カルーセルモザイク↔ピース確認 切り替え**
  - `data.js`: `initialAppState()` に `carouselViewMode: "pieces"` を追加。
  - `store.js`: `TOGGLE_CAROUSEL_VIEW` アクション追加。`CAROUSEL_NEXT/PREV` でビューモードを "pieces" にリセット。
  - `app.js`: カード左上に切り替えボタン（「🎵 フル表示」/「🧩 ピース確認」）を追加。モザイクモードは `filter: blur(12px) brightness(0.78)` で全体をぼかした表示（後に調整済み）。

- **未所持ピースの背景改善**
  - `puzzleGridMini()`: 未所持セルを `opacity:.35` の真っ暗から `background:#3a3060` + `outline:1px solid rgba(255,255,255,.18)` + `opacity:0.55` に変更。セル間のギャップ色も紫系 `rgba(80,60,140,.5)` に変更し、枠が視覚的に見えるように改善。

### カルーセル表示変更・初期ピース数ランダム化（仕様変更）

- **メロディ画面カルーセル：サムネイル全体表示 → 所持状況パズルグリッドへ変更**
  - `apps/web/src/app.js`: `puzzleGridMini(state, trackId)` ヘルパーを追加。
  - カルーセルのメインカード内をサムネイル `<img>` から 6×4 ピースグリッドに差し替え。
  - 所持ピース: 実ピース画像 + 緑オーバーレイ表示。
  - 未所持ピース: locked ピース画像、opacity 0.35 で暗く表示。
  - カード右下に `n / 24` の所持数バッジを常時表示。
  - ユーザーが出会ったパズルについて「自分が何枚持っているか」を直感的に把握できる仕様へ変更。

- **初期ピース数：0枚固定 → 1〜7枚ランダム（三角分布）**（仕様変更）
  - `apps/web/src/data.js`: `initialAppState()` の `collectedPieces` を変更。
  - `ownedPieces: []` のトラックに三角分布で 1〜7 枚を生成。
  - 式: `count = clamp(round(1 + 3 * (rand() + rand())), 1, 7)` → 期待値 4、最頻値 ≈ 4。
  - `ownedPieces` が設定済みのトラック（プロトタイプサンプル）はそのまま維持。

### A-1: パズル完成演出

- `data.js`: `initialAppState()` に `puzzleCompleteTrackId: null` を追加。
- `store.js`: `SELECT_PIECE` で `justCompleted` 判定（初めて全ピース揃った）。完成時は曲名を自動解放（`unlockedTrackIds` へ追加）し `puzzleCompleteTrackId` をセット。`DISMISS_PUZZLE_COMPLETE` アクション追加。
- `index.html`: `<div id="puzzle-complete-root">` を追加。
- `app.js`: `renderPuzzleComplete(state)` — フルスクリーンオーバーレイ（z-index 300〜302）。ダーク背景 + 28個のパーティクル（CSS `@keyframes pcParticle`）+ バウンス入場カード（`pcIn`）。完成画像・🎉 パズル完成！・曲名・アーティスト・ピース数/コインバッジ・「コレクションで見る」「閉じる」ボタン。

### A-2: 複数すれちがい + 順番制フロー + フレンド機能

- **出会いデータ 5件**（`data.js`）: 田中ゆき(大学)・佐藤けんじ(渋谷駅)・鈴木あや(カフェ)・山田たろう(図書館)・中村みか(コンビニ)。`encounterOrder` 配列で順序を定義。
- **順番制フロー**: 出会いは1人ずつ順番に確認する（自由切り替え不可）。
  - メロディ画面上部に進捗バー（n / 5 件目・ドットインジケーター: 緑=済 / 紫=今ここ / 薄=未確認）。
  - 「今日の出会い」リスト: 確認済み=✓済バッジ、現在=「→ 今ここ」、未来=🔒順番待ち（タップ不可・薄表示）。
  - `store.js`: `SELECT_PIECE` 後に `nextUnvisitedEncounter()` で次の未確認出会いへ自動前進。
  - mystery/puzzle 画面下部に「n人目の出会いへ ›」ボタン（`nextEncounterButton()`）。全確認済みなら「🎉 今日の出会いを全て確認しました」。
- **フレンド機能**（開発計画書「フレンド機能・音楽共有」§準拠・近距離交換後のフレンド申請導線）:
  - `data.js`: `friends: []`, `pendingFriendAdd: null` を初期状態に追加。
  - `store.js`: `ADD_FRIEND` / `DISMISS_FRIEND_PROMPT` アクション。ピース取得時に相手が未フレンドなら `pendingFriendAdd` をセット。
  - `app.js`: `friendPromptCard()` — ピース取得後の画面に「○○さんとメロディでつながりました／フレンドに追加・スキップ」カードを表示。フレンドには 🎵 マーク。
  - ホーム画面の「今日n件のメロディ」はクールタイム未消化の出会い数を動的にカウント。

### A-3: 試聴回数制限（1曲1日3回）

- `data.js`: `previewPlays: {}` を初期状態に追加（`{ [trackId]: { date, count } }`、日付単位でリセット）。
- `store.js`: `RECORD_PREVIEW_PLAY` アクション（日付が変わればカウント1から）。`SHOW_TOAST` アクション追加。LocalStorage に永続化。
- `app.js`: `PREVIEW_DAILY_LIMIT = 3`、`previewPlaysLeft(state, trackId)` ヘルパー。
  - `openPreview()` 冒頭で残回数チェック → 0ならトースト「本日の試聴回数を使い切りました（1日3回まで）」を表示して再生しない。再生時に `RECORD_PREVIEW_PLAY` を dispatch。
  - カルーセルの試聴ボタン: 「▶ 少し聴く（あと n 回）」/ 使い切り時はグレー無効ボタン。
  - 試聴モーダル内に「本日あと n 回試聴できます」表示（`#preview-plays-left`）。
  - 未解放メロディ画面: 再生FABを減光 + 「（試聴 本日あとn回）」表示。

### B-1: Supabase 新規プロジェクト + Go API 接続

- **Supabaseプロジェクト**: `MelodyLien`（ref: `wngtvdgzzlkajtbwsurc` / ap-northeast-1 東京 / 無料プラン）
  - URL: `https://wngtvdgzzlkajtbwsurc.supabase.co`
  - publishable key: `sb_publishable_oR41TcNHu-G9La0JHrnmWg_P8SfRts5`（anon・公開前提）
- **スキーマ**（migration: `initial_schema`）: `artists` / `tracks` / `profiles` / `collected_pieces` / `unlocked_tracks` / `encounters` / `encounter_candidates` / `encounter_cooldowns` / `friendships`
  - 全テーブル RLS 有効。マスタ（artists/tracks/encounters/candidates）は全員 select 可、ユーザーデータは `auth.uid()` 本人のみ。
  - `handle_new_user()` トリガー: サインアップ時に `profiles` 行を自動作成（`is_anonymous` → `is_guest`）。PostgREST からの EXECUTE は revoke 済み。
- **シード**: プロトタイプ `data.js` と同一の8アーティスト・10曲（chorusStart含む）・出会い5件・候補17件。
- **Go API**（`api/store/supabase.go` 新規）:
  - 起動時に PostgREST（`/rest/v1/artists`, `/rest/v1/tracks`）からカタログ取得しインメモリストアを置き換え。
  - 失敗時は埋め込みシードで継続（フォールバック）。env: `SUPABASE_URL` / `SUPABASE_ANON_KEY`（デフォルト値あり）。
  - `/api/search?q=` エンドポイントを handler に追加（フロント `api.js` が期待する `{results: [{trackId,title,artistName,color,youtubeId}]}` 形式）。
  - 動作確認: `q=yoasobi` → 夜に駆ける + ハルジオン（YouTube ID 付き）が Supabase カタログから返る。

### B-2: 認証最小構成（Supabase Auth）

- **`apps/web/src/supabase.js`**（新規）: `@supabase/supabase-js@2` を esm.sh CDN から import。
  - `getAuthUser()` / `signUpEmail()` / `signInEmail()` / `signInOAuth()` / `signInGuest()` / `signOut()` / `onAuthChange()`。
  - ゲスト: `signInAnonymously()` 失敗時（匿名認証無効時）は「ローカルゲスト」へフォールバック（`melodylien.localGuest` フラグ・端末内のみ）。
- **ログイン画面**（`#auth-root` フルスクリーンオーバーレイ・z-index 400）:
  - ✉️ メール（ログイン/新規登録フォーム）・Google・Apple・LINE・ゲストの5導線。
  - メール新規登録 → 確認メール送信を通知。OAuth 未設定時はエラーメッセージで案内。
  - LINE はカスタム OIDC 連携前提（プロトタイプでは未設定通知）。
- **state**: `authUser`（undefined=確認中 / null=未ログイン / object）。`SET_AUTH` アクション。非永続（セッションは supabase-js が管理）。
- **ゲスト機能制限**（仕様: フレンド / ランキング参加 / 共有 / 課金 / 引き継ぎ）:
  - フレンド申請カード → 「🔒 ゲストでは利用できません + 登録する」に差し替え。
  - ランキング画面に「ゲストは参加できません（閲覧のみ）」バナー。
  - マイページに「アカウント」セクション（プロバイダ表示・アカウント登録・ログアウト）。
- **検証済み**: signup API でユーザー作成 → `profiles` 行がトリガーで自動作成されることを確認。

**Supabase ダッシュボードでの残作業**（コードからは設定不可）:

- Authentication → Sign In / Up → 「Allow anonymous sign-ins」を有効化（ゲストのサーバー同期用）
- Google / Apple OAuth プロバイダの設定（クライアントID等）
- LINE ログイン（カスタム OIDC）の設定
- Leaked password protection の有効化（推奨）

### B-3: ピース・コレクションの Supabase 同期

ゲスト制限の「アカウント登録するとデータが引き継げる」を実際に機能させるための同期実装。ゲスト（匿名認証・ローカルゲスト）は対象外、ローカルのみで完結。

- **`apps/web/src/sync.js`**（新規）:
  - `fetchRemote(userId)`: `collected_pieces` / `unlocked_tracks` / `friendships` / `encounter_cooldowns` / `profiles.coins` を取得し、ローカル state と同じ形（`collectedPieces` / `unlockedTrackIds` / `friends` / `encounterCooldowns` / `coins`）に整形。
  - `mergeStates(local, remote)`: 和集合でマージ。ピース・解放曲・フレンド（`friend_name`一致で重複排除）は和集合、クールタイムは新しい方のタイムスタンプ、コインは `Math.max`。
  - `pushRemote(userId, merged)`: マージ結果を各テーブルへ `upsert`（`onConflict` は各テーブルの複合PK: `user_id,track_id,piece_number` 等）。
  - `syncOnLogin(userId, store)`: ログイン時にリモート取得 → マージ → `MERGE_REMOTE_STATE` を dispatch → リモートへ書き戻し。失敗してもローカル動作は継続（`console.error` のみ）。
  - `syncAfterAction(userId, prevState, nextState, action)`: ログイン中の操作を都度リモートへ反映。
    - `SELECT_PIECE`: 取得ピース・新規解放曲・コイン差分・出会いクールタイムを upsert/update。
    - `ADD_FRIEND`: フレンド行を upsert（`friend_user_id` は出会いNPCのIDがUUID形式でないため `null`、`friend_name` で一致管理）。
    - `UNLOCK_TRACK`: 解放曲を upsert。
- **`apps/web/src/store.js`**: `MERGE_REMOTE_STATE` アクションを追加。マージ後の `encounterCooldowns` から `nextUnvisitedEncounter()` で `activeEncounterId` を再計算（別端末ログイン時も出会いの順番を正しく再開）。
- **`apps/web/src/app.js`**:
  - `refreshAuth()`: 非ゲストユーザーで `user.id` が前回と異なる場合のみ `syncOnLogin()` を実行（`syncedUserId` で重複防止）。
  - 追加の `store.subscribe`: 直前状態を保持し、dispatch のたびに `syncAfterAction()` を呼び出す。
- **検証済み**（テストアカウント作成 → 削除済み）:
  - 初回ログイン: ローカル133ピース・7解放曲・1フレンド・コイン2 → Supabaseへ同期完了。
  - ログイン中のピース取得・フレンド追加 → 即座に該当テーブルへ反映。
  - 別端末想定（LocalStorageクリア後に再ログイン）: リモートのデータ＋新規ローカル分がマージされ、`activeEncounterId` も正しい続きの出会いに復元。

次の候補:

- フレンド一覧・フレンド詳細画面（マイページ内・音楽でつながった履歴表示）
- デイリーミッションの実装（ホームの「0 / 5」を実機能化）
- アーティストパズル・称号タブの実装
- SwiftUI / Jetpack Compose への移植対応表を作成する。

## 2026-06-11

### C-1: フレンド一覧・フレンド詳細画面

マイページから「音楽でつながった履歴」を見られるようにする画面。`friends` 配列（`userId`/`userName`/`addedAt`/`exchangeCount`）と B-3 で同期した Supabase `friendships` テーブルを表示するだけで完結。

- **`apps/web/index.html`**: `friends-screen` / `friend-detail-screen` の `<section>` を追加。
- **`apps/web/src/store.js`**: `OPEN_FRIEND` アクション追加（`selectedFriendUserId` をセットして `friend-detail` へ遷移）。`saveState()` に `selectedFriendUserId` を追加。
- **`apps/web/src/app.js`**:
  - `npcEncounterForUserId(userId)`: `userId` から `seedData.encounters` を逆引き（出会った場所・関連曲を特定するため）。
  - `formatDate(timestamp)`: `YYYY/MM/DD` 形式の日付文字列を生成。
  - `renderMypage`: 「アカウント」と「推し曲設定」の間に「フレンド」セクションを追加（フレンド数 + 「フレンド一覧を見る」ボタン → `friends` 画面へ）。
  - `renderFriends(state)`: フレンド一覧。0人の場合は空状態メッセージ（`.notice-panel` 流用）。1人以上は `addedAt` 降順で `.track-list`/`.track-row` を流用した行（アイコン・名前・追加日・出会った場所・交換回数）。各行に `data-open-friend="${userId}"`。
  - `renderFriendDetail(state)`: フレンド詳細。ヘッダー（`.home-header`/`.avatar`/`.home-user`）、`.stat-grid`（フレンド歴・交換回数・出会った場所）、出会ったNPCの `encounter.candidates` から `.song-grid`（音楽でつながった曲・未解放曲はマスク表示）。
  - クリックハンドラに `[data-open-friend]` → `OPEN_FRIEND` dispatch を追加。
- 検証: LocalStorage に `friends` を1件投入 → マイページ「フレンド 1人」表示 → 一覧で田中ゆきの行（大学・交換1回・追加日）表示 → 詳細で フレンド歴4日／交換回数1回／出会った場所「大学」と、出会ったNPC（encounter_today_001）の5曲（Pretenderは解放済みのため曲名表示、他4曲は「未解放メロディ」表示）を確認。

### C-2: デイリーミッションの実装

ホームの「0 / 5」表示を実機能化。「ピースを5個獲得」を条件に進捗管理し、達成時にメロディコイン+10を付与。

- **`apps/web/src/data.js`**:
  - `todayKey()`（`YYYY-MM-DD`）を `formatNumber` の直後にエクスポート追加（`store.js`/`app.js` 共通の日付キー判定に使用、`app.js` 内のローカル定義は削除）。
  - `seedData.mission` を `{ label: "デイリー", current: 0, target: 5 }` → `{ label: "デイリー", target: 5, rewardCoins: 10 }` に変更。
  - `initialAppState()` に `dailyMission: { date: todayKey(), progress: 0, claimed: false }` と `selectedFriendUserId: null` を追加。
- **`apps/web/src/store.js`**:
  - `getDailyMissionProgress(state)`: 日付が変わっていれば `{date, progress:0, claimed:false}` にリセットして返す。
  - `SELECT_PIECE`: 新規ピース獲得時に `dailyMission.progress` を+1（上限5）。`progress >= target` かつ未達成なら `claimed:true` + コイン+10、トーストに `🎉 デイリーミッション達成！メロディコイン +10` を追記（複数行）。
  - `saveState()` に `dailyMission` を追加。
- **`apps/web/src/styles.css`**: `.toast` を複数行メッセージ対応（`white-space:pre-line; text-align:center`）に変更。
- **`apps/web/src/app.js`**: `renderHome` でミッションパネルに実進捗（`n / 5`・進行バー・説明文）を表示。達成時は「🎉 達成済み！メロディコイン +10 を獲得しました」、未達成時は「あとnピース獲得で達成」のような案内を表示。
- 検証: ピースを5個（新規）獲得 → `dailyMission` が `{progress:5, claimed:true}` に更新 → コインが規定通り加算（新規ピース+1×5 + 達成ボーナス+10 = +15）→ 複数行トースト表示 → ホームのミッションパネルが「5/5・🎉 達成済み！メロディコイン +10 を獲得しました」表示に切り替わることを確認。コンソールエラーなし。

次の候補:

- アーティストパズル・称号タブの実装
- フレンドの「交換回数」を実際の交換イベント発生時にインクリメントする（現状は `ADD_FRIEND` 時に固定で1）
- SwiftUI / Jetpack Compose への移植対応表を作成する。

### C-3: アーティストパズル・称号タブの実機能化

コレクション画面の「アーティスト」タブはシード固定値（YOASOBI 1組のみ・12/18固定）、「称号」タブはプレースホルダーのみだったのを実データ連動に変更。

- **`apps/web/src/data.js`**:
  - `seedData.artists`（YOASOBI 1件・`completedTrackPuzzles` 等の固定値）を削除。
  - `seedData.titles` を追加: 称号8種の定義（`id`/`icon`/`name`/`description`/`type`/`target`）。
    - type: `puzzles`（完成曲数: 1曲/3曲/全曲）・`artists`（全曲完成アーティスト1組）・`friends`（フレンド1人/3人）・`unlocks`（曲名解放5曲）・`mission`（デイリーミッション達成）。`target: "all"` は全曲数を表す。
- **`apps/web/src/app.js`**:
  - `artistGroups(state)`: `seedData.tracks` を `artistId` でグループ化し、完成曲数を `collectedPieces` から実計算（アーティストマスタ不要に）。
  - `titleProgress(state, title)`: 称号の `current` / `target` / `unlocked` を state から算出。
  - `computeCollection`: ホームの「アーティスト n / m」を `artistGroups` ベースの実計算に変更（0/1 固定 → 実アーティスト8組）。
  - アーティストタブ: 全アーティストをカード表示し、完成数・進捗バーを実計算値で描画。
  - 称号タブ: 「n / 8 獲得」ヘッダー + 称号カードリスト。獲得済みは紫グラデ枠 + 「獲得済み」、未獲得はグレースケールアイコン + 進捗バー + `current / target` 表示。
  - 検索ローカルフォールバック: `seedData.artists` 参照（YOASOBI 以外 `""` になっていた）を `track.artistName` 直接参照に修正。
- 検証: アーティストタブに8組全員が実進捗（髭男 0/2・Niziu 0/1 等）で表示。称号タブは現在の state（フレンド1人・解放7曲・ミッション達成済み）で「3 / 8 獲得」（はじめてのフレンド・名曲ハンター・今日のがんばり屋）が正しく解放表示されることを確認。

### C-4: フレンド交換回数の実イベント連動

- **`apps/web/src/store.js`**: `SELECT_PIECE` で出会い相手が既フレンドの場合、該当フレンドの `exchangeCount` を+1（未フレンドなら従来通り `pendingFriendAdd` をセット）。
- **`apps/web/src/sync.js`**: `syncAfterAction` の `SELECT_PIECE` ブランチに、`exchangeCount` が増えたフレンドの `friendships.exchange_count` をリモート更新する処理を追加。
- 検証: 既フレンド（田中ゆき）の出会いクールタイムを解除して再交換 → `exchangeCount` が 1→2 にインクリメントされることを確認。コンソールエラーなし。

### C-5: SwiftUI / Jetpack Compose 移植対応表

- **`docs/native-porting-map.md`**（新規）: Webプロトタイプの構造ごとに SwiftUI / Jetpack Compose での実現方法を対応表化。
  - アーキテクチャ（store.js → @Observable/TCA・ViewModel+StateFlow、LocalStorage → UserDefaults/DataStore）
  - 画面対応（10画面 + 下部ナビ → TabView/NavigationStack・Scaffold/Navigation Compose）
  - コンポーネント・演出（モーダル・トースト・パーティクル・モザイク・波形アニメーション等）
  - 状態・ロジック（アクション単位の移植注意点。reduce 純粋関数はほぼ機械的に移植可能）
  - 外部連携（YouTube プレイヤー規約注意・supabase-swift/kt・すれちがい通信は MultipeerConnectivity / Nearby Connections）
  - 移植優先順位の目安（データ層 → コア画面 → 同期 → 演出 → すれちがい本実装）

### C-6: npm scripts の現行コード対象化・旧並行コピー削除

`npm run check` / `test:store` がルートの古い `src/` 並行コピー（v1キー・旧アクション体系 `SELECT_CANDIDATE` 等）を検証していて、現行コード（`apps/web/src/`）のテストになっていなかった問題を修正。

- **`package.json`**:
  - `serve`: `python3 -m http.server 5173`（ルートの旧 index.html を配信）→ `python3 apps/web/serve.py`（現行の開発サーバー・port 5174）に変更。
  - `check`: 対象を `apps/web/src/` の全JS（app/data/store/sync/supabase/api）に変更。
  - `test:store`: インラインの `-e` スクリプト → `node scripts/test-store.mjs` に変更。
- **`scripts/test-store.mjs`**（新規）: 現行の store.js（v2キー・`SELECT_PUZZLE`/`SELECT_PIECE` 体系）に対するテスト。
  - ピース取得 → ピース・コイン+1・デイリーミッション進捗・クールタイムの永続化を検証。
  - 重複ピース取得でミッション進捗が増えないことを検証。
  - `ADD_FRIEND` → 既フレンドとの再交換で `exchangeCount` が 1→2 になること（C-4）を検証。
  - `UNLOCK_TRACK` の永続化を検証。
- **削除**: ルートの `src/`（4ファイル）と `index.html`（旧6画面レイアウト）。どこからも参照されていないことを確認済み（git管理下のため復元可能）。

### D-1: すれちがい出会いの6時間リフレッシュ実装

`nextUnvisitedEncounter()` が `!cooldowns[id]`（未訪問か）しか見ておらず、5件全てにクールタイムが付くと「次の出会い」が永久に出現しない（コアループが停止する）問題を修正。

- **`apps/web/src/data.js`**: `COOLDOWN_MS = 6 * 60 * 60 * 1000`（6時間）と `OSHI_LIMIT = 3` を先頭付近にエクスポート追加（`app.js` 内に重複していた `COOLDOWN_MS` 定義を一本化）。
- **`apps/web/src/store.js`**:
  - `isAvailable(cooldowns, id)`: 未訪問 または `Date.now() - cooldowns[id] >= COOLDOWN_MS` で `true`。
  - `nextUnvisitedEncounter()` を `nextAvailableEncounter(cooldowns)` に置き換え。`seedData.encounterOrder` から `isAvailable` を満たす最初の id を返す（無ければ `null`）。
  - `SELECT_PIECE` / `MERGE_REMOTE_STATE` の自動前進ロジックを `nextAvailableEncounter` 呼び出しに変更。
- **`apps/web/src/app.js`**:
  - ローカル `COOLDOWN_MS` 定義を削除し `data.js` からインポート。
  - `nextEncounterButton(state)`: 「クールタイム明け」も次の出会いとして検出するよう書き換え。全件クールタイム中の場合は「🎉 今日の出会いを全て確認しました／次の出会いまであと ◯時間◯分」を表示。
  - 「今日の出会い一覧」: `clickable = !isLocked`（未来の未訪問のみロック）に変更。クールタイム中の済み出会いは「済 · あと◯時間◯分」バッジ、クールタイム明けは「受信可」バッジ（`var(--mint)` ・太字）で表示し、タップで `SWITCH_ENCOUNTER` 可能に。
- **`scripts/test-store.mjs`**: 独立ストアで encounter_today_001 を消化 → encounter_today_002 へ自動前進 → `encounter_today_001` のクールタイムをLocalStorage上で6時間以上前に書き換え（期限切れをシミュレート）→ ストア再生成 → encounter_today_002 を消化すると `activeEncounterId` が `encounter_today_001` に戻る（再受信可能）ことを検証。
- 検証: `npm run test:store` で上記アサーションが通ることを確認。ブラウザでも encounter_today_001 を消化（→ today_002 へ自動前進）→ クールタイムを手動で期限切れに書き換えてリロード → メロディ画面で「1人目（田中ゆき）」が「受信可」（mint・太字）でクリック可能、「2人目（佐藤けんじ）」が「→ 今ここ」、3〜5人目は「🔒 順番待ち」のままであることをスクリーンショットで確認。

### D-2: 推し曲設定の実装

マイページ「推し曲設定（0/3曲）」とコレクション>推し曲タブが、いずれも見た目だけのプレースホルダーで未機能だったのを実装。

- **`apps/web/src/data.js`**: `OSHI_LIMIT = 3`（D-1と合わせて追加）。`initialAppState()` に `oshiTrackIds: []` を追加。
- **`apps/web/src/store.js`**:
  - `saveState()` に `oshiTrackIds` を追加（LocalStorageのみで完結。`previewPlays`/`dailyMission` と同様にSupabase同期対象外）。
  - `TOGGLE_OSHI_TRACK` アクション: 既に推し曲なら解除。上限（`OSHI_LIMIT`=3）到達時は追加せずトースト「推し曲は3曲まで設定できます」。それ以外は追加してトースト「◯◯ を推し曲に設定しました」。
- **`apps/web/src/app.js`**:
  - マイページ「推し曲設定」: 選択済みの曲をタイル表示（✕ボタンで `TOGGLE_OSHI_TRACK` → 解除）。`state.unlockedTrackIds` から選択可能な曲をチップ一覧で表示し、タップで追加。
  - コレクション>推し曲タブ: `state.oshiTrackIds` があれば実曲のタイル一覧を表示。0件の場合は従来のプレースホルダー/CTAのまま。
  - クリックハンドラに `[data-toggle-oshi]` → `TOGGLE_OSHI_TRACK` dispatch を追加。
- **`scripts/test-store.mjs`**: 解放済み曲から3曲を `TOGGLE_OSHI_TRACK` で追加（`oshiTrackIds.length === OSHI_LIMIT` を確認）。4曲目は追加されないこと、1曲を再トグルすると解除されることを検証。
- 検証: `npm run test:store` で上記アサーションが通ることを確認。ブラウザで解放済みの曲から3曲（Pretender / Sunset Drive / 唱）を追加 → マイページの推し曲セクションとコレクション>推し曲タブの両方に反映されることをスクリーンショットで確認。

### E-1: 称号獲得時のトースト・演出

称号タブで条件を満たしても獲得瞬間の通知がなかったのを、トースト + 専用オーバーレイで演出するように実装。

- **`apps/web/src/store.js`**:
  - `artistGroups` / `titleProgress` を app.js から store.js へ移動してエクスポート（app.js はインポートに変更）。称号判定をストア側で行えるようにするため。
  - `unlockedTitleIds(state)`: 獲得済み称号IDの一覧を算出。
  - `dispatch()` 内でアクション適用の前後を比較し、新規に達成した称号を検知 → `pendingTitleCelebrations` キューへ追加 + トーストに「🏆 称号「◯◯」を獲得！」を追記（diff方式なので、ロード時点で既に獲得済みの称号では発火しない）。
  - `DISMISS_TITLE_CELEBRATION` アクション: キュー先頭の1件を消化。
- **`apps/web/src/data.js`**: `initialAppState()` に `pendingTitleCelebrations: []` を追加（非永続）。
- **`apps/web/index.html`**: `<div id="title-celebration-root">` を追加。
- **`apps/web/src/app.js`**: `renderTitleCelebration(state)` — 「TITLE UNLOCKED」ヘッダー・称号アイコン（揺れアニメーション）・称号名・達成条件・「やったね！」ボタンのフルスクリーンオーバーレイ（z-index 310）。パズル完成演出の表示中はそれを閉じた後に表示。複数同時獲得時は1件ずつ順に表示（「ほかに n 件」の注記つき）。
- 検証: パズル完成 → 完成演出を閉じると称号演出が表示され、「やったね！」で閉じることをスクリーンショットで確認。トーストにも称号獲得行が追記される。

### E-2: 経験値・レベルアップの実装

「完成報酬 経験値×50」とマイページの Lv 表示が実態と連動していなかったのを実装。

- **`apps/web/src/data.js`**:
  - `PIECE_EXP = 5`（新規ピース1枚あたりの獲得経験値）と `levelFromExp(exp)`（Lv.L → L+1 に L×100 exp 必要。`{level, current, next}` を返す）をエクスポート追加。
  - `initialAppState()` に `exp: 0` を追加。`seedData.user` の固定値 `level` / `levelProgress` は削除（state から算出）。
- **`apps/web/src/store.js`**: `SELECT_PIECE` で新規ピース獲得時に `+PIECE_EXP`、パズル完成時はさらに `+track.rewardExp`。レベルが上がった場合はトーストに「⬆️ レベルアップ！ Lv.n になりました」を追記。`saveState()` に `exp` を追加（LocalStorageのみ）。
- **`apps/web/src/app.js`**: ホーム・マイページのレベル表示と進捗バーを `levelFromExp(state.exp)` ベースの実計算に変更。マイページに「次のレベルまで あと◯ EXP」を追加。パズル完成演出に「⭐ +50 EXP」バッジを追加。
- **`scripts/test-store.mjs`**: `levelFromExp` の換算（0→Lv.1 / 100→Lv.2 / 300→Lv.3）、完成時の `exp = PIECE_EXP + rewardExp` 加算と永続化、レベルアップ・称号獲得のトースト文言、`DISMISS_TITLE_CELEBRATION` の消化、`ADD_FRIEND` での称号検知を検証。
- 検証: `npm run test:store` 通過。ブラウザで pretender 23枚 + exp95 の状態から最後の1枚を取得 → exp150・Lv.2 表示・複数行トースト（完成/レベルアップ/称号）を確認。

### E-3: ランキング画面の実データ連動

4タブすべてが同じ固定ダミー5曲を表示していたのを、ユーザーランキング（集めたピース数）に変更し自分の順位を実データから算出。

- **`apps/web/src/app.js`**: `renderRanking` を書き換え。
  - 自分の行: `state.collectedPieces` の合計枚数を指標に「Mia（あなた）」をハイライト表示（紫背景・順位はソートで実算出）。ヘッダーに「あなたは◯位」。
  - 今日タブ: すれちがいNPC5人（出会いデータから生成・固定枚数 `NPC_PIECES`）+ 自分。
  - 近く/全国タブ: NPC + エリア/全国のダミー参加者 + 自分。
  - 友達タブ: `state.friends` の実データから行を生成（交換回数をサブテキスト表示）。フレンド0人なら空状態（「まだフレンドがいません」+ 出会いへの導線）。
- 検証: 今日タブで「あなたは6位・24枚」（シード状態の実枚数）がハイライト表示、友達タブはフレンド0人で空状態 → フレンド追加後は「1 田中ゆき 交換2回 96枚 / 2 Mia（あなた）24枚」になることを確認。

### F-1: 完成報酬コインの実付与

パズル画面の「完成報酬 メロディコイン ×100」が表示のみで、完成時に通常の+1コインしか付与されていなかったのを実付与に変更。

- **`apps/web/src/store.js`**: `SELECT_PIECE` の完成判定（`justCompleted`）時に `completionCoins = track.rewardCoins`（100枚）をコイン加算へ追加。トーストに「🪙 完成報酬 メロディコイン +100」行を追記。
- **`apps/web/src/app.js`**: パズル完成演出のコインバッジを「+1 コイン」固定から「+${rewardCoins + 1} コイン」（新規ピース分+完成報酬）に変更。
- Supabase同期は既存の `coins` 差分同期（`sync.js` が絶対値を update）でそのまま反映されるため変更不要。
- 検証: pretender 23枚から最後の1枚を取得 → コイン 0 → 101、トースト・完成演出バッジ（🪙 +101 コイン）を確認。`test-store.mjs` に `coins === 1 + rewardCoins` のアサーションを追加。

### F-2: プレミアムプラン導線の実装

マイページ設定メニューの「プレミアムプラン」（表示のみ）を、専用画面 + 模擬加入フロー + 実際の特典反映つきで実装。

- **`apps/web/src/data.js`**: `OSHI_LIMIT_PREMIUM = 5`・`oshiLimit(state)`（プランに応じた推し曲上限）・`PREMIUM_PRICE_LABEL = "¥480 / 月"` をエクスポート。`initialAppState()` に `premium: false` を追加。
- **`apps/web/src/store.js`**:
  - `SET_PREMIUM` アクション: 加入/解約のトグル。解約時は推し曲を無料枠（3曲）まで先頭から自動調整。`saveState()` に `premium` を追加。
  - `TOGGLE_OSHI_TRACK` の上限を `oshiLimit(state)` に変更（無料3曲/プレミアム5曲）。
  - `COMPLETE_AD` のトーストにプレミアム時「⭐ プレミアム特典：広告なしで解放」を前置。
- **`apps/web/index.html` + `apps/web/src/app.js`**:
  - `premium` 画面（新規）: プラン名・価格・「プロトタイプのため決済は行われません」注記・特典3つ（広告非表示/推し曲5曲/エリアランキング）・加入ボタン（模擬決済）。加入中は「解約する」ボタン + 解約時の推し曲自動調整の説明。
  - マイページ: 設定メニューの「プレミアムプラン」行を `data-target="premium"` でクリック可能に（加入中は「⭐ 加入中」表示）。ヘッダーのユーザー名横に「⭐ プレミアム」バッジ。推し曲セクションの上限表示・チップ表示条件を `oshiLimit(state)` 連動に変更（無料上限到達時はプレミアムへのリンク）。
  - ランキング「近く」タブ: プレミアム加入中はアップセルバナーを非表示にし「⭐ プレミアム特典でエリアランキングを閲覧できます」を表示。未加入時の「詳細」ボタンは premium 画面へ遷移。
  - 広告ヒント: プレミアム加入中は `[data-ad]` クリックで確認モーダルを挟まず `COMPLETE_AD` を直接 dispatch（広告非表示の実体験）。
- 検証: 加入 → マイページにバッジ・推し曲 0/5 表示・5曲まで追加可能・ランキング近くタブの表示切り替え・ヒント解放がモーダルなしで即時実行（トーストにプレミアム特典表記）を確認。解約 → 推し曲が5曲 → 3曲に自動調整されることを確認。`test-store.mjs` にプレミアム上限・解約時トリムのアサーションを追加。

### F-3: 今日のメロディプレイリスト画面の実装

`seedData.dailyPlaylist`（ホームの「今日のメロディ」ヒーローパネルの元データ）を一覧表示する画面を実装。

- **`apps/web/index.html`**: `playlist-screen` セクションを追加。
- **`apps/web/src/app.js`**:
  - `renderPlaylist(state)`: ヘッダー（タイトル・「2026年6月4日・大学で12人と音楽でつながりました」サブタイトル＝出会いデータから生成）。プレイリスト4曲の行（アート・曲名（未解放はマスク）・アーティスト・所持ピース進捗バー・n/24 または「完成！」・▶試聴ボタン）。行タップで曲詳細（`data-open-track`）へ。
  - ホームのヒーローパネルを `data-target="playlist"` でクリック可能に（「プレイリストを見る ›」の案内を追記）。
  - クリックハンドラの `[data-preview-track]` 判定を `[data-open-track]` より先頭に移動（行内の試聴ボタンが行タップに吸われる問題の予防）。
- 検証: ホームのヒーローパネル → プレイリスト画面遷移、4曲（Sunset Drive / ブルーベリー・ナイツ / Magic Hour / ハルジオン）の進捗・試聴ボタン表示をスクリーンショットで確認。

## 2026-06-12

### G-1: ショップ画面の実装

マイページの「ショップ」（表示のみ）を実装し、メロディコインに使い道を持たせた。

- **`apps/web/src/data.js`**: `SHOP_ITEMS`（5商品）をエクスポート。`initialAppState()` に `hintTickets: 0` / `ownedDecorations: []` / `equippedDecoration: null` を追加。
  - 🎟️ ヒントチケット（15コイン・type: ticket）: 広告なしでヒントを1回解放
  - 🎲 ランダムピース（20コイン・type: piece）: 未完成パズルからランダム1ピース獲得
  - 🎩 シルクハット / 🎀 リボン（各50コイン）・👑 クラウン（100コイン）（type: decoration・買い切り）
- **`apps/web/src/store.js`**:
  - `BUY_SHOP_ITEM`: コイン不足は拒否（トースト）。チケット→所持数+1、装飾→購入と同時に自動装備（重複購入拒否）、ランダムピース→未完成トラックからランダム選択して1ピース追加。ピース獲得は通常取得と同様に経験値+5・デイリーミッション進行・完成判定（完成報酬コイン・曲名解放・完成演出・称号検知）まで連動。
  - `EQUIP_DECORATION`: 装備のトグル（同じ装飾を再選択で外す）。
  - `COMPLETE_AD` に `viaTicket` を追加: チケットを1枚消費してヒント解放（トーストに残数表示）。解放手段の優先順は プレミアム > チケット > 広告モーダル（`app.js` の `[data-ad]` ハンドラで分岐）。
  - `saveState()` に `hintTickets` / `ownedDecorations` / `equippedDecoration` を追加。
- **`apps/web/src/app.js` + `index.html`**:
  - `shop` 画面（新規）: 所持コイン・アイテム2種（チケットは所持枚数表示）・アバター装飾3種（購入済みは「装備する/外す」、コイン不足は購入ボタンを無効化）。
  - `avatarWithDeco(state)`: 装備中の装飾絵文字をアバター右上にオーバーレイ表示（ホーム・マイページのヘッダーで使用）。
  - マイページ設定メニューの「ショップ」行をクリック可能に（チケット所持時は 🎟️×n を表示）。
  - 未解放メロディ画面: チケット所持時（非プレミアム）は「🎟️ ヒントチケット n枚所持 — 広告なしで解放されます」の案内を表示。
- 検証: チケット購入（コイン-15・所持1枚）→ ランダムピース購入（ピース+1・ミッション進行）→ シルクハット購入（自動装備・ヘッダーに🎩表示）→ コイン不足のクラウンは購入ボタン無効 → チケットでヒント解放（モーダルなし・残0枚トースト）を一通り確認。

### G-2: 通知設定画面の実装

マイページの「通知設定」（表示のみ）を設定画面として実装。

- **`apps/web/src/data.js`**: `initialAppState()` に `notificationSettings: { immediate: true, digest: false, digestTime: "20:00", encounter: true, mission: true }` を追加。
- **`apps/web/src/store.js`**: `TOGGLE_NOTIFICATION`（キー単位トグル）・`SET_DIGEST_TIME`（まとめ通知の時間帯）。`saveState()` で永続化。
- **`apps/web/src/app.js` + `index.html`**: `notify-settings` 画面（新規）: 即時通知・まとめ通知（ONのとき 09:00/12:00/20:00 の時間帯チップを表示）・すれちがい通知・ミッション達成通知のスイッチUI（CSSトグル）。「プロトタイプのため実際の通知は送信されません」の注記つき。マイページ設定メニューから遷移。
- 検証: まとめ通知ON → 時間帯チップ出現 → 09:00 選択 → LocalStorage に `{digest: true, digestTime: "09:00"}` が永続化されることを確認。

### G-3: 音楽サービス連携の模擬実装

マイページの「連携する」ボタン（未機能）を模擬連携として実装。

- **`apps/web/src/data.js`**: `initialAppState()` に `linkedServices: { spotify: false, appleMusic: false, youtubeMusic: false }` を追加。
- **`apps/web/src/store.js`**: `TOGGLE_SERVICE_LINK`: 連携のトグル。連携時「🎵 ◯◯ と連携しました（プロトタイプ・模擬連携）」、解除時「◯◯ との連携を解除しました」のトースト。`saveState()` で永続化。
- **`apps/web/src/app.js`**: マイページの連携セクションを state 連動に変更。連携中はサービス名に「✓ 連携中」バッジ + ボタンが「解除」（secondary）に切り替わる。
- 検証: Spotify 連携 → ✓連携中表示・トースト・LocalStorage 永続化 → 解除でOFFに戻ることを確認。

- **`scripts/test-store.mjs`**: G-1〜G-3のアサーションを追加（チケット購入のコイン減・永続化、チケット消費でのヒント解放、ランダムピースの+1とミッション進行、装飾の自動装備・重複購入拒否・付け外し、コイン不足の購入拒否、通知設定・サービス連携の永続化）。`npm run check` / `npm run test:store` 通過。

### H-1: バックグラウンド検知の設定画面

マイページ設定メニューで唯一未機能だった「バックグラウンド検知」を設定画面として実装。

- **`apps/web/src/data.js`**: `initialAppState()` に `backgroundScan: { enabled: true, mode: "balanced", nightPause: false }` を追加。
- **`apps/web/src/store.js`**: `TOGGLE_BG_SCAN`（enabled / nightPause のトグル）・`SET_BG_SCAN_MODE`（powersave / balanced / performance）。`saveState()` で永続化。
- **`apps/web/src/app.js` + `index.html`**: `bg-settings` 画面（新規） — マスタートグル・スキャン頻度のラジオ選択（省電力=約15分 / 標準=約5分 / 高頻度=約1分・バッテリー消費の目安つき。OFF時は非表示）・「夜間は検知しない（22時〜翌6時）」トグル。設定メニューの行にも現在の状態（「オン · 省電力スキャン」等）を表示。通知設定と共通のスイッチUIを `switchToggle` / `settingRow` ヘルパーとして共通化。
- 検証: 省電力モード選択 + 夜間停止ON → LocalStorage に `{enabled: true, mode: "powersave", nightPause: true}` が永続化、メニューの行が「オン · 省電力スキャン」表示に切り替わることを確認。

### H-2: 称号の常設リワード

称号を獲得しても表示が変わるだけだったのを、獲得時にコイン/EXPボーナスを付与するように変更。

- **`apps/web/src/data.js`**: `seedData.titles` の全8称号に `rewardCoins` / `rewardExp` を追加（はじめてのひとかけら 30/30・メロディコレクター 50/50・パズルマエストロ 200/200・推しマスター 100/100・はじめてのフレンド 30/30・音楽の輪 50/50・名曲ハンター 50/50・今日のがんばり屋 20/20）。
- **`apps/web/src/store.js`**: `dispatch()` の称号検知ブロックで、獲得した称号の報酬コイン/EXPを合算して付与。EXP加算によるレベルアップも判定してトーストに追記。トーストは「🏆 称号「◯◯」を獲得！（🪙+30 ⭐+30 EXP）」形式に。
- **`apps/web/src/app.js`**: 称号獲得演出オーバーレイに報酬バッジ（🪙 +n コイン / ⭐ +n EXP）を追加。コレクション>称号タブの各称号に「獲得報酬: 🪙n · ⭐n EXP」を表示。
- 検証: パズル完成 → コイン 0 → 131（ピース1 + 完成報酬100 + 称号30）・EXP 95 → 180（+5+50+30）が一致。演出オーバーレイのバッジと称号タブの報酬表示も確認。テストの既存アサーションを称号リワード込みの期待値に更新。

### H-3: 推し曲のすれちがい連動

推し曲を設定しても表示されるだけだったのを、すれちがい（ピース交換）時に自分の推し曲が相手に届く演出として実装。

- **`apps/web/src/data.js`**: `initialAppState()` に `oshiDeliveries: {}`（ユーザーIDごとの配達累計）を追加。
- **`apps/web/src/store.js`**: `SELECT_PIECE` で推し曲が設定されていれば、出会い相手への配達回数に応じて推し曲を順番に1曲選び（ローテーション）、`oshiDeliveries[userId]` をインクリメント。トーストに「🎵 あなたの推し曲「◯◯」を ◯◯さんに届けました」を追記。`saveState()` で永続化。
- **`apps/web/src/app.js`**:
  - マイページ推し曲セクション: 説明文を「すれちがいの相手にあなたの推し曲が届きます」に変更し、配達があれば「🎵 これまでに n回 届けました」を表示。
  - フレンド詳細画面: 配達実績のある相手に「🎵 あなたの推し曲をこれまでに n回 届けました」を表示。
- 検証: 推し曲「夜に駆ける」を設定してピース交換 → トーストに配達演出・`oshiDeliveries: {user_tanaka_yuki: 1}` が永続化・マイページに「これまでに 1回 届けました」表示を確認。

- **`scripts/test-store.mjs`**: H-1〜H-3のアサーション追加（バックグラウンド検知設定の永続化、称号リワード込みのコイン/EXP期待値への更新、推し曲配達の記録・トースト・永続化）。`npm run check` / `npm run test:store` 通過。

次の候補:

- ホームの通知バッジ・「今日n件のメロディ」と通知設定の連動（即時通知OFF時はバナーを抑制する等）
- アーティストページ（コレクション>アーティストのカードから詳細ページへ遷移する導線が未実装）
- 設定メニュー残り3行（ヘルプ・利用規約・通知以外のショップ内通貨追加など）の実装

## 2026-06-17

### I-1: ホームの通知バナーと通知設定の連動

ホームの「今日n件のメロディが届いています」バナーが通知設定（G-2実装済み）と無関係だったのを連動させた。

- **`apps/web/src/app.js`**: `renderHome` の notice-panel 表示条件に `state.notificationSettings?.immediate !== false` を追加。
  - 即時通知 ON（デフォルト）: 「NEW」バッジ付きのフル強調バナー（紫「確認する」ボタン）
  - 即時通知 OFF: 🔕アイコン・opacity:0.6 の控えめバナーに切り替わり「即時通知オフ — まとめ通知でお知らせします」サブテキストを表示。「確認する」ボタンは secondary スタイルに変更。メロディは引き続きタップで確認できる。
- 検証: localStorage で `immediate: false` にセットして再ロード → バナーが🔕・半透明表示に変化することをブラウザで確認。`immediate: true` に戻すと通常バナーに復帰。

### I-2: アーティスト詳細ページの実装

コレクション > アーティストタブのアーティストカードをタップしても何も起こらなかった（詳細画面未実装）のを、アーティスト個別の曲パズル一覧ページとして実装。

- **`apps/web/src/data.js`**: `initialAppState()` に `selectedArtistId: null` を追加。
- **`apps/web/src/store.js`**:
  - `OPEN_ARTIST` アクション: `selectedArtistId` をセットして `activeScreen = "artist-detail"` へ遷移。`saveState()` に `selectedArtistId` を追加。
- **`apps/web/index.html`**: `artist-detail-screen` セクションを追加。
- **`apps/web/src/app.js`**:
  - `renderArtistDetail(state)`: ヘッダー（アーティスト名・「曲パズル n/m 完成」）、アーティストプロフィール（アバター・名前・進捗バー）、「曲パズル一覧」（全曲をリスト表示・アートブロック・タイトル/未解放マスク・進捗バー・n/24 または「完成!」）。各曲行は `data-open-track` でパズル/未解放画面へ遷移可能。戻るボタンは `data-back="collection"` でアーティストタブに戻る（`collectionTab` state が "artists" のまま保持されるため自然に戻る）。
  - `renderCollection` アーティストタブ: 各アーティストブロックのヘッダー行を `display:flex;justify-content:space-between` に変更し、アーティスト名右に「詳細 ›」ボタン（`data-open-artist="${artist.id}"`）を追加。
  - クリックハンドラに `[data-open-artist]` を追加（`OPEN_ARTIST` アクションを dispatch）。
  - `renderAll()` に `renderArtistDetail(s)` を追加。
- 検証: Official髭男dism の「詳細 ›」→ アーティスト詳細画面（Pretender 12/24・Magic Hour 22/24）が表示。戻るボタンでアーティストタブに正常復帰することをブラウザで確認。`npm run check` / `npm run test:store` 通過。

次の候補:

- 設定メニュー残り行（ヘルプ・利用規約・アプリについて等の静的テキスト画面）の実装
- コレクション > アーティスト詳細から推し曲設定へのショートカット（「この曲を推し曲に設定」ボタンをアーティスト詳細の各曲行に追加）
- ホームの「最近届いた曲」セクションをすれちがい履歴と連動（ピース取得した曲が自動追加される）

## 2026-06-23

### ネイティブ（iOS）UIリニューアル・YouTubeサムネイルパズル

ネイティブiOSアプリ（`apps/ios/`, SwiftUI）の表示まわりを設計書（Obsidian: `MelodyLien_パズル生成仕組み設計書` / `MelodyLien_UI設計・必要素材リスト`）準拠で一通り整備した。

**1. ライトモード全面化**
- `MelodyLienApp.swift` に `.preferredColorScheme(.light)`。全画面のダーク配色（`0f0a20` 等）をライト配色へ変換（背景 `F5F0FF` / カード `FFFFFF` / 枠 `E0D8F7` / ミュート `EDE8FF` / アクセント `7248E0` / 副文字 `7B6F8A`）。完成演出オーバーレイのみ意図的にダーク維持。

**2. 画面全体表示（黒帯解消）**
- 起動画面未設定によりレガシー互換モードでレターボックス（上下黒帯）になっていた問題を、`Info.plist` / `project.yml` に `UILaunchScreen` ＋ `UIApplicationSceneManifest` を追加して解消。
- `ContentView` の `BottomNavBar` を下げて（`.padding(.bottom, 14)→4`）ホームインジケーター付近に配置。

**3. YouTubeサムネイル＋6×4パズル（設計書準拠）**
- `Track` に `youtubeVideoId`／`youtubeThumbnailURL`（`i.ytimg.com/vi/{id}/mqdefault.jpg`。架空曲 `official-*` は除外）。
- `ArtBlockView`: サムネイル表示＋未解放はモザイク（`mosaic`）。`ArtBlockView(track:)` で解放=鮮明/未解放=モザイクを自動出し分け。
- `PuzzlePiecesView`（新規）: 16:9を6×4に分割し、所持ピースだけサムネイルを見せ未所持は lockedピース（`E3DAF5`）。`revealAll`/`blur` でフル表示/モザイク/ピース確認を切替。`PuzzleView`・`MysteryView`・メロディカルーセルに適用。
- `PieceSelectView`: 所持ピースはサムネイルの該当領域を切り出し表示、取得可能ピースは紫ハイライト＋タップ取得、取得不可は lockedピース（設計書 §8.2）。
- `CachedThumbnail`（新規）: `NSCache`＋`@State`＋タイムアウト付き専用`URLSession`で画像をキャッシュ。`Color.clear`基準＋`.overlay`画像で、コンテナ形状（正方形=1:1クロップ / 16:9）に追従。
- 既知の落とし穴対応: ① `img.youtube.com`はシミュレータのQUICでスタールするため`i.ytimg.com`へ。② キャッシュ判定の`if image == nil`ガードでビュー再利用時に前トラックの画像が残る取り違えを修正（常に更新）。③ ホーム「最近届いた曲」は`Dictionary.values`の不定順を解放優先＋id順の安定ソートに。

**Android（`apps/android/`）**: `Track.youtubeThumbnailUrl` のホスト/解像度をiOSと統一、`ArtBlock`にCoilでサムネイル表示を追加。ただしAndroidは現状Home画面のみのスキャフォルドで、当環境に `gradlew`/Android SDK が無くビルド検証は未実施。

検証: iPhone 16 Proシミュレータで全タブ・パズル/未解放/ピース選択/カルーセルを目視確認。`xcodebuild` は `BUILD SUCCEEDED`。

次の候補:
- Androidネイティブの各画面（メロディ/パズル/コレクション/マイページ）実装とパズル6×4リビールの移植
- iOS: パズル完成演出オーバーレイのライト/サムネイル対応
- ピース選択でピース取得後のフレンド申請カード・「次の出会いへ」導線（Web版相当）の移植

### ピース選択のサムネイル化／取得後導線／完成演出／Androidパズル

設計書の積み残し（ピース選択のサムネイルピース・取得後のフレンド/次の出会い導線）と、Android への 6×4 リビール移植を実施。

**iOS**
- `PieceSelectView`: 抽象セルを廃止し、所持ピースはサムネイルの該当領域を offset+clip で切り出して表示。取得可能＝紫ハイライト＋番号（タップ取得）、取得不可＝lockedピース（設計書 §8.2）。
- 取得後導線（Web版相当）を新規 `PostCollectSection`（フレンド申請カード＋「n人目の出会いへ」）として実装し、`MysteryView`/`PuzzleView` 末尾に配置。`AppViewModel` に `pendingFriendAdd`/`showNextEncounterPrompt`・`confirmFriendAdd`/`dismissFriendPrompt`/`goToNextEncounter`/`clearCollectPrompts` を追加。`collectPiece` で既存フレンドは交換回数+1、未フレンドはフレンド申請カードを提示。`goBack`/タブ切替で導線をクリア。
- `PuzzleCompleteOverlay`: 完成パズルを `PuzzlePiecesView(revealAll: true)` で 6×4 サムネイル全面表示に。
- 検証: シミュレータで 出会い1→5 を順に進め、フレンド既存=カード非表示/次の出会いのみ、未フレンド(山田たろう)=フレンド申請カード表示→「フレンドに追加」でトースト＋称号「はじめてのフレンド」解放、を確認。ピース選択は Pretender/夜に駆ける/Lemon 等で所持/取得可能/取得不可の3状態を確認。`xcodebuild` は `BUILD SUCCEEDED`。

**Android**
- `PuzzlePieces`（Compose・iOS `PuzzlePiecesView` の移植）を新規追加。6×4・所持ピースのみ Coil でサムネイル表示・未所持は lockedピース・`revealAll`/`mosaic` 対応。
- `PuzzleScreen` を新規追加し、`MainActivity` の PUZZLE タブ（旧プレースホルダ）を差し替え。解放済み・サムネイルあり・所持ピースありのトラックを表示。
- ⚠️ 当環境に `gradlew`/Android SDK が無く**ビルド未検証**。コードは実モデル/VM API（`Track.youtubeThumbnailUrl`・`homeState.heroTrack`・`ProgressBar` 等）に対して記述済み。実機/エミュレータでのビルド確認が必要。

次の候補:
- Android: メロディ（出会いカルーセル＋ピース選択）/コレクション/マイページ各画面の本格実装（要 Android ビルド環境）
- iOS: 取得後導線のスキップ後にも「次の出会いへ」を残すか等の細部調整

### iOS 状態永続化（UserDefaults＋Codable）

これまで iOS は毎起動で進行が全リセットされていた（永続化なし）のを修正。ピース・コイン・経験値・フレンド・課金・推し曲・各設定・クールタイムが起動後も保持される。

- **`Models.swift`**: `Friend` を `Codable` 化。保存用 `TrackProgress`（可変進行のみ）／`SaveState`（全保存項目）を追加。
- **`AppViewModel.swift`**:
  - `objectWillChange` を 1秒デバウンスで購読し、変化があれば自動保存（`MainActor.assumeIsolated` で main 隔離を担保）。
  - `persistIfLoaded()`: 現在の進行を `SaveState` にまとめ JSON で `UserDefaults`（キー `melodylien.save.v1`）へ保存。
  - `restoreState()`: seed/API ロード後に保存済み進行を上書き反映（トラックは静的フィールドを seed に残し、可変フィールドのみ復元）。`loadAll()` 末尾で呼び、以後 `isLoaded` で保存を有効化。
- 検証: 推し曲に Pretender を追加 → アプリ終了 → 再起動で「推し曲 1/3・Pretender」が復元されることをシミュレータで確認。`xcodebuild` は `BUILD SUCCEEDED`。
  （外部 `defaults write` での復元テストは cfprefsd キャッシュの都合で反映されないが、アプリ内での保存→再起動→復元は正常に動作。）

次の候補:
- iOS 試聴「少し聴く」（YouTube音声30秒・1日3回制限）の実装
- Android 各画面の本格実装（要 Android ビルド環境）
- セーブのスキーマ変更時のマイグレーション（現状はキー `v1` 固定。項目追加時はデコード失敗で進行リセットの可能性があるため、デフォルト補完デコードの導入）

### iOS 試聴「少し聴く」（YouTube音声30秒・1日3回制限）

Web版（YouTube IFrame Player API）と同等の試聴をネイティブ移植。設計書 §5.2/5.3・メロディタブ仕様準拠。

- **`Track`**: `chorusStart`（サビ位置・秒）を追加。seed の実在8曲に Web と同じ値を設定（Pretender 57 / Lemon 68 / 夜に駆ける 52 / 唱 44 / 怪獣の花唄 38 / Anytime 58 / ブルーベリー 55 / ハルジオン 62）。
- **`Models.swift`**: `PreviewRecord{date,count}` を追加。`SaveState` に `previewPlays` を追加し、項目追加で旧セーブが壊れないトレラントデコード（欠損キーはデフォルト補完）に変更。
- **`AppViewModel`**: `previewPlays`/`previewTrackId`、`previewPlaysLeft`/`canPreview`/`startPreview`/`endPreview`/`grantPreviewHintIfNeeded`、`previewDailyLimit=3`、`todayKey()`。試聴回数は永続化（日付が変われば3回に復帰）。
- **`PreviewPlayerView.swift`（新規）**:
  - `YouTubeAudioPlayer`（`WKWebView` + IFrame API）。`allowsInlineMediaPlayback`＋`mediaTypesRequiringUserActionForPlayback=[]` で自動再生、`baseURL=https://www.youtube.com`、サビ位置から `start`。映像は不透明レイヤーで隠し音声のみ。
  - ダークなオーディオプレイヤーUI（波形アニメ・伏せ字タイトル・30秒カウントダウン・プログレスバー・「本日あと N 回試聴できます」・停止/閉じる）。完了時、未解放曲はヒントLv1を自動付与し「🎁 1つ目のヒントを解放しました」を表示。
- **導線**: `MysteryView` 先頭と `MelodyView` カルーセルに「▶ 少し聴く（あとN回）」ボタン（実在動画のみ有効・上限0で無効化）。`ContentView` で `previewTrackId` を全面オーバーレイ表示。
- 検証: 米津玄師(Lemon, 未解放)で試聴 → 30秒カウントダウン→「完了」、回数 3→2、完了時「1つ目のヒントを解放しました」、閉じると「あと2回」表示をシミュレータで確認。`xcodebuild` は `BUILD SUCCEEDED`。

次の候補:
- Android 各画面の本格実装（要 Android ビルド環境）
- iOS: 試聴のサビ位置を実音再生開始（onReady）に同期させ、カウントダウンと音のズレを縮小

### iOS ヒント／答え解放の CM ゲート整合・オフライン化

ユーザーの設計意図（ヒント1・2・答えの解放は**すべてCM視聴を条件**とする）に合わせ、試聴完了時のヒントLv1自動付与を撤回。あわせて解放処理をオフライン（バックエンド非依存）に修正し、シミュレータで「通信エラー」になっていた不具合を解消。

- **試聴のヒント自動付与を撤回**: `PreviewPlayerView` の完了時ヒント付与（`grantPreviewHintIfNeeded`呼び出し・「🎁 1つ目のヒントを解放しました」）を削除し、「試聴おわり。ヒントや確認で曲名を当てよう」に変更。設計書 248 行の「未解放曲はヒント自動付与」より、593/875-877 行の「ヒントはCM/広告で解放」を優先（ユーザー判断）。
- **`applyHint` をオフライン化**: `repository.applyHint`（未提供）依存で「通信エラー」になっていたのを、ローカル `tracks` を直接更新する実装に書き換え。プレミアムは無広告・ヒントチケットがあれば消費（残数表示）してトースト。hint1→`hintLevel≥1`／hint2→`hintLevel≥2`（4択表示）／answer→`answerReady=true`。
- **答え→解放導線**: `MysteryView` の YouTube パネルで `answerReady` 時の「確認して解放」を、外部YouTubeを開かず `unlockTrack` のみ呼ぶ単一アクションに変更（Web の「確認する」に合わせアプリ内完結）。未使用化した `openYouTube` を削除。
- **`AdConfirmModal`**: 「（広告SDKは後日実装。現在は視聴を省略して解放します）」の注記を追加（モックである旨を明示）。実 SDK（Google AdMob/AdSense）連携は後日。
- 検証: Lemon(未解放)で「1つ目のヒントを見る」→視聴する→「1つ目のヒントを解放しました」、「答えを見る」→視聴する→「確認して解放」表示→タップで Lemon/米津玄師 が解放されコレクション(1/24)へ遷移することをシミュレータで確認。`xcodebuild` は `BUILD SUCCEEDED`。

次の候補:
- iOS: 広告 SDK（AdMob）連携の本格実装（CM視聴の実フロー化）
- Android 各画面の本格実装（要 Android ビルド環境）

### iOS サムネイル欠落の修正（ローカルパズル画像のバンドル）

**現状整理（DB/データ層）**: バックエンドAPI（`http://localhost:3001/api`）は未稼働で、実体は `AppViewModel.seedFallback()` のハードコードされたオフライン seed（10曲）＋ UserDefaults 永続化。iOS はサムネイルを YouTube 画像CDN（`i.ytimg.com/vi/<id>/mqdefault.jpg`）から動的取得しており、**ローカル画像を一切同梱していなかった**。そのため架空曲（`youtubeVideoId == nil`：Sunset Drive / Magic Hour）はサムネイルが表示されなかった（Web版は全10曲に `assets/puzzles/<id>/preview.png` を同梱して表示）。

- **画像の同梱**: Web版の `apps/web/assets/puzzles/<id>/preview.png` 10枚を `apps/ios/MelodyLien/Resources/Puzzles/<track_id>.png` にコピー（`pretender`→`track_pretender` に正規化）。XcodeGen の `sources: MelodyLien` 再帰取り込みでバンドル直下へ自動同梱。
- **`Track`（Models.swift）**: 表示用と判定用を分離。
  - `hasYouTubeVideo: Bool` … 実在動画を持つか（30秒試聴／YouTube確認のゲート判定用。架空曲は false）。
  - `bundledThumbnailURL` … `Bundle.main.url(forResource: id, withExtension: "png")` で同梱画像を解決。
  - `thumbnailURL: URL?` … 同梱画像を最優先し、無ければ YouTube CDN。旧 `youtubeThumbnailURL` を置換。
- **`CachedThumbnail`**: `url.isFileURL` のとき `Data(contentsOf:)` でディスクから直接読む分岐を追加（同梱画像は即時・ネットワーク不要）。
- **呼び出し側の整理**: 表示系（`PuzzlePiecesView`/`ArtBlockView`/`PieceSelectView` 等 7箇所）は `thumbnailURL` に、試聴/再生ゲート（`canPreview`/`startPreview`/`MysteryView`/`MelodyView` の各 hasVideo 判定）は `hasYouTubeVideo` に変更。これにより「架空曲も画像は出るが試聴はできない」が正しく両立。
- 検証: `xcodebuild` は `BUILD SUCCEEDED`、`.app` に 10枚の `track_*.png` が同梱されることを確認。シミュレータでコレクション一覧の全曲にサムネイルが表示され、架空曲 Sunset Drive / Magic Hour も Web 同様のプレースホルダ画像（緑グリッド）が表示されることを確認。

次の候補:
- iOS: パズルの各ピース画像（Web版 `piece_01〜24.png`）の同梱検討（現状は preview.png を6×4にスライス表示。Web の手描きピース形状とは異なる）
- iOS: 広告 SDK（AdMob）連携の本格実装
- Android 各画面の本格実装（要 Android ビルド環境）

### バックエンド（Supabase）の起動・カタログ投入・画像CDN準備

将来の「DB/CDN配信＋所有分は端末キャッシュ」に向けた第一歩。既存の Supabase プロジェクトと Go API 雛形を実稼働させた。

**現状把握**: バックエンドは想像以上に出来ていた。Go API（`main.go`＋`api/`、ビルド成功）が iOS/web の期待するエンドポイントを実装済みで、Supabase からカタログ取得→失敗時 seed フォールバックする設計。Supabase プロジェクト `MelodyLien`(`wngtvdgzzlkajtbwsurc`/東京) も実在したが **休止中(INACTIVE)** かつ全テーブル0行だった。スキーマは適用済みで、`tracks` に `thumbnail_url`・`grid_rows/cols`・`chorus_start`、per-user テーブルは `auth.users` 連携の UUID＋TEXT track_id という良設計。RLS もカタログは公開SELECT・per-userは本人のみで適切。

**実施（Supabase MCP 経由）**:
- プロジェクトを **restore（再開）** → `ACTIVE_HEALTHY`。
- **カタログ投入**: artists 8件・tracks 10件（iOS/web の正データ準拠。id は TEXT スラグ、`piece_count=24`、`chorus_start`、`thumbnail_url` は Storage 公開URL）。冪等 upsert。
- **Storage 公開バケット `puzzles` 作成**（5MB上限・png/jpeg/webp）。`thumbnail_url` は `…/storage/v1/object/public/puzzles/<track_id>/preview.png` を指す。
- 検証: anon 公開REST `/rest/v1/tracks` で全曲取得OK。Go API 起動で `catalog loaded from Supabase` を確認し `/api/tracks` が `pieceCount:24`（＝Supabase値）を返すことを確認。

**残（コード結線・別タスク）**:
- Go `api/store/supabase.go` の `supabaseTrack` に `thumbnail_url` を追加 → `model.Track`／APIレスポンス（view）→ iOS `Track` まで結線し、アプリが CDN 画像を使うようにする（現状アプリは同梱画像。`thumbnailURL` のフォールバック構造はそのまま活かせる）。
- 所有パズルの端末ディスクキャッシュ（`ThumbnailCache` を NSCache→永続化）。
- 本番 API のデプロイ先決定（現状 localhost のみ）。バックエンド3系統（Go `api/`・Go `backend/api/`・Node `server/`）の整理。

**ユーザー作業（私が代行不可）**: パズル画像10枚のアップロードは `scripts/upload-puzzles.sh` を service_role キー（環境変数 `SUPABASE_SERVICE_ROLE_KEY`）で実行。※ Storage への匿名 INSERT ポリシー付与は安全側で自動拒否されたため、秘密鍵を手元に留める方式にした。

### サムネイルを YouTube 公式MV から DB 自動投入（アップロード廃止）

上記の「画像アップロード」を見直し。設計書 `MelodyLien_パズル生成仕組み設計書.md` §2 の条件「パズルは **YouTube公式MVまたは公式リリックビデオのサムネイル** をもとに作成する」に基づき、実在曲はアップロード不要で YouTube から取得する方式に統一した。

- **DBトリガー `set_thumbnail_from_youtube()` を追加**（migration `derive_thumbnail_from_youtube`）。`tracks` の INSERT/UPDATE 時、`thumbnail_url` が NULL かつ `youtube_video_id` があれば `https://i.ytimg.com/vi/<id>/maxresdefault.jpg`（1280×720）を自動生成。明示指定された URL は上書きしない。→ **新規曲は `youtube_video_id` を入れるだけでサムネが付く仕組み**（ダミー挿入で自動生成を確認、行は削除）。
- **バックフィル**: 公式MVあり8曲は YouTube maxres に統一（先に入れた Storage URL を置換）。公式MVなしの架空2曲（sunset_drive / magic_hour）は `thumbnail_url = NULL`（アプリ側でグラデーション/同梱プレースホルダにフォールバック）。
- 検証: anon REST で全曲の `thumbnail_url` を確認。Lemon の maxres は実画像 HTTP 200・78KB を配信。全8曲 maxresdefault 利用可（200）。
- **アップロードは不要化** → `scripts/upload-puzzles.sh` を削除。Storage バケット `puzzles` は将来の架空曲アート/ピース画像用に残置（現状未使用）。

**残（コード結線）**: アプリ/Go API はまだ DB の `thumbnail_url` を使っていない。Go `supabaseTrack`→`model.Track`→APIレスポンス→iOS `Track` まで結線すれば、アプリが公式MVサムネ（CDN）を表示するようになる（同梱画像からの移行）。所有パズルの端末ディスクキャッシュ（オフライン対応）も別途。

### thumbnail_url のアプリ結線＋架空2曲の削除

**(1) thumbnail_url を Supabase→Go API→iOS まで結線**
- Go `api/store/supabase.go`: `supabaseTrack` に `thumbnail_url` を追加し `model.Track.ThumbnailURL` へマップ。
- Go `api/model/model.go`: `Track`／`TrackView` に `ThumbnailURL string json:"thumbnailUrl,omitempty"` を追加（未解放でも返す）。`store.go` の `TrackView()` で値をコピー。
- iOS `Models.swift`: `Track` に `thumbnailUrl: String?`（API/DB由来）を追加。`thumbnailURL`（表示用 computed）の優先順位を **① DB(thumbnailUrl) → ② 同梱画像 → ③ YouTube直** に変更。フォールバック構造は維持。
- 検証: Go API 起動 → `/api/tracks` が **8曲**を返し、各曲に `thumbnailUrl=https://i.ytimg.com/vi/<id>/maxresdefault.jpg` が乗ることを確認（Supabase→Go→JSON 全段疎通）。`go build ./...` OK、iOS `BUILD SUCCEEDED`。

**(2) 架空2曲（Sunset Drive / Magic Hour）をテストデータから削除**
- Supabase `tracks` から2曲を DELETE（残8曲）。
- 削除＋参照修正したファイル: iOS `AppViewModel.swift`（seed 2曲・デイリープレイリスト・`totalPuzzles 10→8`）、Go `api/store/store.go`＋`backend/api/store/store.go`（seed・`dailyTrackIDs`）、`apps/web/src/data.js`（ASSETS・track定義・playlist trackIds・recentlyAdded）、`server/db/seed.js`。デイリー/最近追加の参照は実在曲（track_show / track_kaiju 等）へ差し替え。
- iOS 同梱の `track_sunset_drive.png`／`track_magic_hour.png` を削除（→ 8枚）。`xcodegen generate` 再生成。
- 検証: コード全体に架空曲の参照が残らないことを grep で確認。各seedビルド/構文OK。シミュレータでコレクション「曲パズル **0/8**」・ホームのヒーローが実在曲（唱）の実アートワークになることを確認。

### iOS をライブAPIに接続（カタログ/サムネイルのみ・overlay方式）

iOS アプリの `loadAll()` を、seed を土台にしつつカタログ（曲・サムネイルURL）だけライブAPI（`localhost:3001` → Supabase）から取得する形に接続した。

- **`loadTracks()` を overlay 方式に変更**: 旧実装は API 結果で `tracks` を丸ごと置換しており、API 稼働時に `youtubeVideoId`/`chorusStart`/所持ピース等の seed 情報が失われた。新実装は **API の `thumbnailUrl` だけを既存 seed トラックに重ねる**（進行状態・動画ID等は seed/保存を優先）。これで画像の出所が DB/CDN（公式MVの maxres）に切り替わり、API 不通時は seed/同梱画像へフォールバック。`restoreState()` は該当フィールドのみ書き換えるため `thumbnailUrl` は保持される。
- **他のローダーは当面 seed 維持**: `loadUser`/`loadCollection`/`loadMission`/`loadEncounter`/`loadPlaylist` はバックエンドの per-user データ＋認証が未整備（ゲスト"Mia"・0コイン等のプレースホルダ）でプロトタイプ体験が劣化するため、`loadAll()` の taskgroup から外した（関数は残置、整備後に有効化）。
- 検証: ローカルで Go API を起動しアプリ起動 → 全ローダー版では home のユーザー名が API ゲスト「Mia」に変化＝ライブAPI到達を確認。overlay 限定版に戻すと「MelodyLien ユーザー」/ヒーロー唱（22/24・実アート）を維持しつつ、サムネイルは DB/CDN 取得。iOS `BUILD SUCCEEDED`。
- 補足: 本番では API 未デプロイ（`api.melodylien.app` 未設置）のため通常は seed+同梱画像で動作。API をデプロイ/起動した時のみ DB/CDN サムネが有効化される。

リポジトリ整備: 生成物 `apps/ios/MelodyLien.xcodeproj/`（XcodeGen が `project.yml` から再生成）等を除外する `.gitignore` を追加。
