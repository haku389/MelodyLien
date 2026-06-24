# 認証 ＋ per-user データ接続プラン

iOS の残りローダー（`loadUser`/`loadCollection`/`loadMission`/`loadEncounter`/`loadPlaylist`）を、
**実ユーザーの永続データ**につなぐための設計。現状はバックエンドの per-user 層が未整備のため、
これらは seed 維持にしてある（カタログ/サムネイルのみ live API 接続済み）。

## 現状

- Supabase: per-user テーブル（`profiles`/`collected_pieces`/`unlocked_tracks`/`encounters`/`friendships` 等）は
  作成済み。RLS は「本人(`auth.uid() = user_id`)のみ読み書き可」。
- Go API: per-user 状態は **インメモリ**（`store.go` のマップ、再起動で消える）。固定 `guestID = "user_guest"` を使用。
- Web: 既に Supabase Auth（メール/Google/Apple/LINE/ゲスト匿名）＋ `sync.js` で LocalStorage⇄Supabase 同期を実装済み。
- iOS: 認証なし。

## 必須の分岐：per-user データを誰が書くか

RLS 有効のため、per-user テーブルへの書き込みには「ユーザーの JWT」か「service_role キー」が要る。
ここで2方式に分かれ、実装が大きく変わる：

### 方式A：クライアント直結（Supabase-native・推奨）
- iOS が Supabase Auth（まず匿名サインイン）で JWT を取得し、**Supabase に直接** per-user データを読み書き（RLS が本人分を保証）。
- Go API は **カタログ＋ゲームロジック**（出会い生成など）に専念。per-user の保存責務を持たない。
- 長所: Web と同方式、オフライン・端末キャッシュ＋同期（既出の方針）と相性良し、サーバ秘密鍵不要。
- iOS 作業: Supabase Swift SDK（SPM）導入 → 匿名Auth → 各ローダーを「Supabase 直クエリ」に。
- 既存の `loadUser` 等（Go API の `/me` 等）は使わず、Supabase 直に置き換え。

### 方式B：サーバ権威（Go API 集約）
- iOS は Go API のみと通信。Go API が **service_role キー**で Supabase の per-user テーブルを代理読み書き。
- 長所: ロジックをサーバへ集約。短所: Cloud Run に service_role 秘密の安全管理が必要、Go store の Supabase 化（中〜大の改修）、オフライン同期は別途。
- iOS 作業: 既存ローダーをそのまま使い、Go API に Authorization ヘッダ（ユーザー識別）を付与。
- Go 作業: JWT ミドルウェア＋ store をインメモリ→Supabase(PostgREST/pgx) に書き換え。

## フェーズ（方式確定後）

1. **iOS 認証**: 匿名サインイン（端末＝1ユーザー）。後でメール/SNS 連携に拡張（web と同等）。
2. **per-user 読み書き**:（A）Supabase 直 /（B）Go API 経由 + service_role。
3. **ローダー再接続**: `loadAll()` でコメントアウト中の loader を方式に合わせて有効化。`profiles` から表示名・コイン等。
4. **出会い/プレイリスト**: 生成ロジック（現状 Go の `GetOrCreateEncounter` 等）の置き場所を方式に合わせて決定。
5. **同期/オフライン**: 所有パズルの端末キャッシュ＋差分同期（[[thumbnail-delivery-architecture]] の方針）。

## 推奨

**方式A（クライアント直結）** を推奨。理由: web と統一でき、サーバ秘密鍵が不要、
かつ「所有パズルは端末キャッシュ＋Supabase 同期」という既定方針に最も素直に乗る。
Go API は当面カタログ専用（既に live 接続済み）として残す。
