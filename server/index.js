import http from "node:http";
import { withCors, json } from "./middleware/cors.js";
import { handleTracks, handleTrack } from "./routes/tracks.js";
import {
  handleMe, handleCollection, handleUnlockTrack, handleCollectPiece,
  handleHint, handleListenLater, handleMission,
} from "./routes/users.js";
import { handleEncounters, handleSelectPiece } from "./routes/encounters.js";
import { handleDailyPlaylist } from "./routes/playlist.js";

const PORT = process.env.PORT ?? 3001;

// ─── ルーティング ────────────────────────────────────────────
// パターン: [method, regex, handler]
// method: null = 全メソッド許可

const ROUTES = [
  // ユーザー
  ["GET",  /^\/api\/me$/,                                    (q, r) => handleMe(q, r)],
  ["GET",  /^\/api\/me\/collection$/,                        (q, r) => handleCollection(q, r)],
  ["GET",  /^\/api\/me\/mission$/,                           (q, r) => handleMission(q, r)],
  ["GET",  /^\/api\/me\/listen-later$/,                      (q, r) => json(r, 200, [])],

  // 曲
  ["GET",  /^\/api\/tracks$/,                                (q, r) => handleTracks(q, r)],
  ["GET",  /^\/api\/tracks\/([^/]+)$/,                       (q, r, m) => handleTrack(q, r, m[1])],
  ["POST", /^\/api\/tracks\/([^/]+)\/unlock$/,               (q, r, m) => handleUnlockTrack(q, r, m[1])],
  ["POST", /^\/api\/tracks\/([^/]+)\/pieces$/,               (q, r, m) => handleCollectPiece(q, r, m[1])],
  ["POST", /^\/api\/tracks\/([^/]+)\/hint$/,                 (q, r, m) => handleHint(q, r, m[1])],
  ["POST", /^\/api\/tracks\/([^/]+)\/listen-later$/,         (q, r, m) => handleListenLater(q, r, m[1])],

  // 交換イベント
  ["GET",  /^\/api\/encounters\/today$/,                     (q, r) => handleEncounters(q, r)],
  ["POST", /^\/api\/encounters\/([^/]+)\/select$/,           (q, r, m) => handleSelectPiece(q, r, m[1])],

  // プレイリスト
  ["GET",  /^\/api\/playlist\/daily$/,                       (q, r) => handleDailyPlaylist(q, r)],
];

function dispatch(req, res) {
  const url = new URL(req.url, `http://localhost`).pathname;
  for (const [method, pattern, handler] of ROUTES) {
    const match = url.match(pattern);
    if (match && (!method || req.method === method || req.method === "OPTIONS")) {
      handler(req, res, match);
      return;
    }
  }
  json(res, 404, { error: "not found", path: url });
}

const server = http.createServer(withCors(dispatch));
server.listen(PORT, () => {
  console.log(`MelodyLien API listening on http://localhost:${PORT}`);
});
