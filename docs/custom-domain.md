# 独自ドメイン（任意）— api.streetmelody.app を Cloud Run に割り当てる

API のアドレスを既定の `*.run.app` から自前ドメインに変える手順。**任意・後回しでOK**
（API エンドポイントはユーザーに表示されない）。やる場合の前提と手順は以下。

## 前提（あなた側）

- ドメイン `streetmelody.app` を所有している（レジストラで取得済み）。
- そのドメインの **DNS を編集できる**（レジストラ or Cloud DNS）。
- ドメイン所有の確認（Google Search Console での verify）。

## 手順

```bash
# 1) ドメインマッピング作成（asia-northeast1）
gcloud beta run domain-mappings create \
  --service streetmelody-api \
  --domain api.streetmelody.app \
  --region asia-northeast1 \
  --project streetmelody

# 2) 表示される DNS レコード（CNAME か A/AAAA）をドメインの DNS に追加
gcloud beta run domain-mappings describe \
  --domain api.streetmelody.app --region asia-northeast1 --project streetmelody
```

- DNS 反映＋証明書発行に最大数十分〜数時間。
- 反映後 `https://api.streetmelody.app/api/tracks` が応答するようになる。

## アプリ側

`apps/ios/StreetMelody/Services/APIService.swift` の `#else`（RELEASE）baseURL を
`https://api.streetmelody.app/api` に戻す（現在は Cloud Run の `*.run.app` URL）。
→ URL が安定するので、将来バックエンドを移しても iOS を再リリースせずに済む。

## 補足

- 現状（独自ドメイン無し）でも完全に動作する。`*.run.app` URL は恒久的に有効。
- メリットはブランド統一とポータビリティのみ（ユーザー体験は不変）。
