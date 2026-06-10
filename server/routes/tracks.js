import { getAllTracks, getTrack, getCollectedPieces, isUnlocked, getHintLevel, isAnswerReady, GUEST_ID } from "../db/client.js";
import { json } from "../middleware/cors.js";

export function handleTracks(req, res, userId = GUEST_ID) {
  // GET /api/tracks
  const tracks = getAllTracks().map((t) => formatTrack(t, userId));
  json(res, 200, tracks);
}

export function handleTrack(req, res, trackId, userId = GUEST_ID) {
  const t = getTrack(trackId);
  if (!t) return json(res, 404, { error: "track not found" });
  json(res, 200, formatTrack(t, userId));
}

function formatTrack(t, userId) {
  const pieces = getCollectedPieces(userId, t.id);
  const unlocked = isUnlocked(userId, t.id);
  const hintLevel = getHintLevel(userId, t.id);
  const answerReady = isAnswerReady(userId, t.id);

  return {
    id: t.id,
    artistId: t.artist_id,
    title: unlocked ? t.title : null,
    // アーティスト名もロック中は null
    artistName: unlocked ? (t.artist_name ?? null) : null,
    pieceCount: t.piece_count,
    rewardCoins: t.reward_coins,
    rewardExp: t.reward_exp,
    color: t.color,
    tone: t.tone ?? null,
    isUnlocked: unlocked,
    hintLevel,
    answerReady,
    // ヒントレベルに応じたマスク文字列
    maskedLabel: unlocked ? null : getMask(t, hintLevel),
    // 4択ヒントはhintLevel>=2で解放
    choices: hintLevel >= 2 ? (t.choices ?? null) : null,
    ownedPieces: pieces.map((p) => p.pieceNumber),
  };
}

function getMask(track, level) {
  if (!track.masks || track.masks.length === 0) return null;
  return track.masks[Math.min(level, track.masks.length - 1)];
}
