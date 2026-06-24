# MelodyLien API — Cloud Run デプロイ手順

Go API（ルートの `main.go` ＋ `api/`）を Google Cloud Run にデプロイし、本番で DB/CDN を有効化するための手順。

## 用意するもの（あなたの環境で一度だけ）

1. **gcloud CLI**: `brew install --cask google-cloud-sdk`
2. **ログイン**: `gcloud auth login`
3. **課金が有効な GCP プロジェクト**を用意し選択: `gcloud config set project <YOUR_GCP_PROJECT_ID>`

> ローカル Docker は不要です（`--source` 指定で Cloud Build がリモートでビルドします）。ルートの `Dockerfile` が使われます。

## デプロイ

リポジトリ直下で：

```bash
bash scripts/deploy-cloudrun.sh
# 任意で上書き:
# PROJECT_ID=xxx REGION=asia-northeast1 SERVICE=melodylien-api bash scripts/deploy-cloudrun.sh
```

- 初回は API 有効化（run / cloudbuild / artifactregistry）に数分かかります。
- 完了すると `https://melodylien-api-xxxxx-an.a.run.app` のような URL が表示されます。
- 動作確認: `curl <URL>/api/tracks` → 8 曲が `thumbnailUrl` 付きで返れば成功。

## デプロイ後：iOS を本番 URL に向ける

`apps/ios/MelodyLien/Services/APIService.swift` の本番 baseURL（`#else` 側、現在 `https://api.melodylien.app/api`）を、

- **A) Cloud Run の URL** にそのまま変更する（`https://<service-url>/api`）、または
- **B) カスタムドメイン** `api.melodylien.app` を Cloud Run にマッピングし、現状のままにする
  （`gcloud run domain-mappings create --service melodylien-api --domain api.melodylien.app …` ＋ DNS 設定）

のいずれか。URL が決まったら教えていただければ iOS 側の差し替えはこちらで対応します。

## 構成メモ

- 環境変数 `SUPABASE_URL` / `SUPABASE_ANON_KEY` はデプロイ時に注入（公開 anon キー。秘密ではない）。未指定でもコード内デフォルトで動作。
- `main.go` は `PORT` 環境変数を読む（Cloud Run は 8080 を注入）。
- スケール: `min-instances 0`（アイドル時は 0＝無料寄り）/ `max-instances 2` / 256Mi。プロトタイプ向けの最小構成。
