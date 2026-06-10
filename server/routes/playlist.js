import { getAllTracks } from "../db/client.js";
import { json } from "../middleware/cors.js";

export function handleDailyPlaylist(req, res) {
  const today = new Date().toISOString().slice(0, 10);
  // 今日のメロディ：全曲から最新4件（本番ではDBのdaily_playlistsテーブルから取得）
  const tracks = getAllTracks().slice(0, 4).map((t) => ({
    id: t.id,
    artistId: t.artist_id,
    color: t.color,
  }));
  json(res, 200, {
    id: `playlist_${today}`,
    date: today,
    title: "今日のメロディ",
    tracks,
  });
}
