# SwiftUI / Jetpack Compose 移植対応表

Webプロトタイプ（`apps/web/`）をネイティブアプリへ移植する際の対応表。
プロトタイプの構造（画面・状態管理・データ・外部連携）ごとに、SwiftUI（iOS）と Jetpack Compose（Android）での実現方法をまとめる。

## 1. アーキテクチャ全体

| Webプロトタイプ | SwiftUI | Jetpack Compose |
|---|---|---|
| 静的SPA + ES Modules | SwiftUI App ライフサイクル | Single-Activity + Compose |
| `store.js`（reducer + subscribe） | `@Observable` クラス（または TCA の Reducer） | `ViewModel` + `StateFlow` + sealed class Action |
| `nextState(state, action)` 純粋関数 | TCA `Reducer` / 自前 `reduce(state:action:)` | `MVI` reduce 関数（`(State, Action) -> State`） |
| LocalStorage（`melodylien.appState.v2`） | `UserDefaults`（小規模）/ SwiftData（拡張時） | `DataStore<Preferences>`（小規模）/ Room（拡張時） |
| `data.js` シードデータ | バンドル内 JSON + `Codable` 構造体 | assets 内 JSON + `kotlinx.serialization` |
| `serve.py` キャッシュバスティング | 不要（ネイティブビルド） | 不要（ネイティブビルド） |

## 2. 画面対応（`index.html` の `<section data-screen>` 単位）

| 画面（data-screen） | SwiftUI | Jetpack Compose |
|---|---|---|
| 全画面切替（`renderAll` + `.active`） | `TabView` + `NavigationStack` | `Scaffold` + `NavigationBar` + Navigation Compose |
| `home` | `HomeView` | `HomeScreen` |
| `melody`（カルーセル） | `MelodyView` + `TabView(.page)` | `MelodyScreen` + `HorizontalPager` |
| `piece-select`（6×4グリッド） | `LazyVGrid(columns: 6)` | `LazyVerticalGrid(GridCells.Fixed(6))` |
| `mystery`（未解放メロディ） | `MysteryView` | `MysteryScreen` |
| `puzzle`（曲パズル詳細） | `PuzzleView` + `LazyVGrid` | `PuzzleScreen` + `LazyVerticalGrid` |
| `collection`（内部タブ4つ） | `Picker(.segmented)` か自前タブ | `TabRow` / `SecondaryTabRow` |
| `ranking`（内部タブ4つ） | 同上 | 同上 |
| `mypage` | `MypageView` + `List` | `MypageScreen` + `LazyColumn` |
| `friends` / `friend-detail` | `NavigationLink` で push 遷移 | `navController.navigate("friend/{id}")` |
| 下部ナビ（`.bottom-nav` 5タブ） | `TabView` | `NavigationBar` + `NavigationBarItem` |

## 3. コンポーネント・演出対応

| Webプロトタイプ | SwiftUI | Jetpack Compose |
|---|---|---|
| 広告確認モーダル（`#modal`） | `.sheet` / `.alert` | `AlertDialog` / `ModalBottomSheet` |
| トースト（`#toast-root`・複数行対応） | overlay + `withAnimation`（自前） | `SnackbarHost`（または自前 overlay） |
| パズル完成演出（パーティクル28個 + バウンス） | `Canvas` + `TimelineView` / `phaseAnimator` | `Canvas` + `rememberInfiniteTransition` |
| 進捗バー（`.progress` CSS変数） | `ProgressView(value:)` | `LinearProgressIndicator(progress)` |
| ピース画像グリッド（locked/owned オーバーレイ） | `Image` + `.overlay` + `.opacity` | `Image` + `Box` + `alpha` |
| モザイク表示（`blur(12px)`） | `.blur(radius: 12)` | `Modifier.blur(12.dp)`（API 31+） |
| 波形アニメーション（試聴モーダル13本バー） | `TimelineView` + `Capsule` | `rememberInfiniteTransition` + `Canvas` |
| ログインオーバーレイ（`#auth-root`） | `.fullScreenCover` | `Dialog(properties = fullscreen)` |
| 称号カード（グレースケール⇄カラー切替） | `.saturation(0/1)` + 条件付きスタイル | `ColorFilter.colorMatrix(saturation)` |

## 4. 状態・ロジック対応（`store.js` のアクション単位）

| アクション | 移植時の注意 |
|---|---|
| `NAVIGATE` / `OPEN_FRIEND` / `OPEN_TRACK` | ナビゲーションはネイティブのスタック管理に置き換え（state の `activeScreen` は不要になる） |
| `SELECT_PIECE`（コイン・ミッション・フレンド交換回数・クールタイムを一括更新） | reduce 関数をそのまま移植可能。テストを必ず移植（`npm run test:store` 相当） |
| `RECORD_PREVIEW_PLAY` / `getDailyMissionProgress`（`todayKey()` 日付リセット） | `Calendar.current.startOfDay` / `LocalDate.now()` で同等の日付キー判定 |
| `MERGE_REMOTE_STATE`（Supabase 和集合マージ） | `sync.js` のマージ規則（和集合・max・新しい方）をそのまま移植 |
| クールタイム6時間（`encounterCooldowns`） | `Date.now()` → `Date()` / `System.currentTimeMillis()` |

## 5. 外部連携対応

| Webプロトタイプ | SwiftUI | Jetpack Compose |
|---|---|---|
| YouTube IFrame API（音声のみ・サビ位置再生） | `youtube-ios-player-helper`（WKWebView ラッパー） | `android-youtube-player`（Pierfrancesco Soffritti） |
| ※規約注意 | YouTube の再生はプレイヤー表示が原則必須。オフスクリーン再生はネイティブでは規約違反になりやすいため、ミニプレイヤー表示への変更を推奨 | 同左 |
| Supabase（`@supabase/supabase-js`） | `supabase-swift` | `supabase-kt` |
| Supabase Auth（メール/OAuth/匿名） | `supabase-swift` Auth + `ASWebAuthenticationSession` | `supabase-kt` Auth + Custom Tabs |
| Go API `/api/search`（250msデバウンス） | `URLSession` + `.task(id:)` + `Task.sleep` | Retrofit/Ktor + `snapshotFlow().debounce(250)` |
| すれちがい通信（現状はシードデータでモック） | `MultipeerConnectivity` / CoreBluetooth + CoreLocation | Nearby Connections API / BLE + FusedLocation |

## 6. 移植優先順位の目安

1. **データ層**: `data.js` の構造体定義（Codable / kotlinx.serialization）と `store.js` の reduce 関数 — ロジックは純粋関数なのでほぼ機械的に移植できる
2. **コア画面**: home → melody → piece-select → mystery → puzzle の取得フロー一式
3. **永続化 + Supabase 同期**: UserDefaults/DataStore → `sync.js` 相当のマージ
4. **演出系**: パズル完成パーティクル・波形アニメーション・トースト
5. **すれちがい通信の実装**: プロトタイプでモックしている部分の本実装（ネイティブでしかできない要素）
