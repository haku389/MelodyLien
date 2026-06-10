# MelodyLien 実装記録

このファイルは、MelodyLienで実装した内容を毎回記録するためのログです。

## 現在の実装状態サマリー（2026-06-10 時点）

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
