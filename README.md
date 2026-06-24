# StreetMelody

StreetMelody（ストリートメロディ）は、近くにいる人の推し曲と出会い、曲やアーティストのピースを集める音楽交流アプリです。

このリポジトリには、Webプロトタイプ（静的SPA）・Go APIサーバー・Supabase連携を実装しています。

## 構成

```text
apps/web/        Webプロトタイプ（ES Modules・依存なし静的SPA）
  serve.py       開発サーバー（port 5174・ESModuleキャッシュバスト付き）
  src/data.js    シードデータ・初期状態
  src/store.js   状態管理（LocalStorage永続化）
  src/app.js     画面描画・イベント処理
  src/supabase.js Supabase Auth クライアント
  src/api.js     Go API クライアント（未起動時はローカルへフォールバック）
main.go / api/   Go APIサーバー（port 3001・Supabaseカタログ連携）
docs/            実装記録
```

バックエンド: Supabase プロジェクト `StreetMelody`（ap-northeast-1）
— PostgreSQL（RLS有効・9テーブル）+ Supabase Auth

## 使い方

```sh
# Webプロトタイプ（http://127.0.0.1:5174/）
python3 apps/web/serve.py

# Go API（http://localhost:3001/api/・任意）
go run .
```

Go API は起動時に Supabase からカタログ（曲・アーティスト）を取得します。
未起動でも Web プロトタイプは LocalStorage のみで動作します。

## 検証

```sh
npm run check
npm run test:store
go build ./...
```

## 実装済み機能

### コア体験
- ホーム / メロディ / ピース選択 / 未解放メロディ / 曲パズル / コレクション / ランキング / マイページ の8画面
- 24ピースパズル（6×4実画像グリッド・所持状況表示・モザイク⇄ピース表示切替）
- 初期ピース1〜7枚ランダム付与（三角分布・中央4枚が最頻）
- メロディコイン（新規ピース+1 / 完成後重複+3）
- 未解放曲の伏せ字（`?`マスク）・広告ヒント段階解放・YouTube確認フロー
- パズル完成演出（パーティクル・完成画像・曲名自動解放）

### すれちがい体験
- 出会い5件の順番制フロー（進捗ドット・順番待ちロック・自動前進）
- 同一ユーザーとのクールタイム6時間（バナー・残り時間表示）
- ピース取得後のフレンド申請（追加/スキップ・🎵フレンドマーク）

### 試聴
- YouTube IFrame 30秒試聴（音声のみ・サビ位置から再生・波形アニメーション）
- 試聴回数制限（1曲1日3回・残り回数表示・日付リセット）

### バックエンド・認証
- Supabase プロジェクト（PostgreSQL・RLS・サインアップ時profiles自動作成）
- Go API: Supabaseカタログ取得（フォールバック付き）・曲検索 `/api/search`
- ログイン: メール / Google / Apple / LINE / ゲスト（匿名・機能制限つき）
- ゲスト制限: フレンド・ランキング参加不可（アカウント登録導線あり）

## 実装記録

実装内容は [docs/implementation-log.md](./docs/implementation-log.md) に記録します。
