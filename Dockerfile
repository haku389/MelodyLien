# MelodyLien API (Go) — Cloud Run 用コンテナ
# ルートの main.go ＋ api/ サブパッケージのみをビルドする（backend/ は別モジュールなので含めない）。
# 外部依存なし（標準ライブラリのみ）なので go.sum は不要。

FROM golang:1.26-alpine AS build
WORKDIR /src
COPY go.mod ./
COPY main.go ./
COPY api ./api
# 静的バイナリ（distroless で動かすため CGO 無効）
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /server .

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /server /server
# Cloud Run は PORT を注入する（既定 8080）。main.go は PORT 環境変数を読む。
ENV PORT=8080
EXPOSE 8080
ENTRYPOINT ["/server"]
