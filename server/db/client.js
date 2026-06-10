// PostgreSQL接続クライアント
// 本番では DATABASE_URL 環境変数からpg接続を確立する
// 現在はインメモリストアで代替（開発用）

import { SEED } from "./seed.js";

// ─── In-memory store（DB未接続時のフォールバック）──────────

const db = {
  users: new Map(),
  artists: new Map(SEED.artists.map((a) => [a.id, a])),
  tracks: new Map(SEED.tracks.map((t) => [t.id, t])),
  collectedPieces: new Map(),  // key: `${userId}:${trackId}:${pieceNumber}`
  unlockedTracks: new Set(),   // key: `${userId}:${trackId}`
  hintLevels: new Map(),       // key: `${userId}:${trackId}` → level
  answerReady: new Set(),      // key: `${userId}:${trackId}`
  listenLater: new Map(),      // key: userId → Set<trackId>
  encounters: new Map(),
  encounterCandidates: new Map(),
  dailyPlaylists: new Map(),
  dailyMissions: new Map(),    // key: `${userId}:${date}`
};

// 開発用ゲストユーザー初期化
const GUEST_ID = "user_guest";
db.users.set(GUEST_ID, {
  id: GUEST_ID,
  name: "Mia",
  level: 1,
  exp: 0,
  coins: 0,
  created_at: new Date().toISOString(),
});

export { db, GUEST_ID };

// ─── クエリヘルパー ───────────────────────────────────────

export function getUser(userId) {
  return db.users.get(userId) ?? null;
}

export function getTrack(trackId) {
  return db.tracks.get(trackId) ?? null;
}

export function getAllTracks() {
  return [...db.tracks.values()];
}

export function getArtist(artistId) {
  return db.artists.get(artistId) ?? null;
}

export function getAllArtists() {
  return [...db.artists.values()];
}

export function getCollectedPieces(userId, trackId) {
  const pieces = [];
  for (const [key, piece] of db.collectedPieces) {
    if (key.startsWith(`${userId}:${trackId}:`)) pieces.push(piece);
  }
  return pieces;
}

export function addCollectedPiece(userId, trackId, pieceNumber) {
  const key = `${userId}:${trackId}:${pieceNumber}`;
  if (db.collectedPieces.has(key)) return false;
  db.collectedPieces.set(key, { userId, trackId, pieceNumber, collectedAt: new Date().toISOString() });
  return true;
}

export function isUnlocked(userId, trackId) {
  return db.unlockedTracks.has(`${userId}:${trackId}`);
}

export function unlockTrack(userId, trackId) {
  db.unlockedTracks.add(`${userId}:${trackId}`);
}

export function getHintLevel(userId, trackId) {
  return db.hintLevels.get(`${userId}:${trackId}`) ?? 0;
}

export function setHintLevel(userId, trackId, level) {
  db.hintLevels.set(`${userId}:${trackId}`, level);
}

export function isAnswerReady(userId, trackId) {
  return db.answerReady.has(`${userId}:${trackId}`);
}

export function setAnswerReady(userId, trackId) {
  db.answerReady.add(`${userId}:${trackId}`);
}

export function getListenLater(userId) {
  return [...(db.listenLater.get(userId) ?? new Set())];
}

export function addListenLater(userId, trackId) {
  if (!db.listenLater.has(userId)) db.listenLater.set(userId, new Set());
  db.listenLater.get(userId).add(trackId);
}

export function getDailyMission(userId, date) {
  return db.dailyMissions.get(`${userId}:${date}`) ?? {
    userId, date, label: "デイリー", current: 0, target: 5,
  };
}

export function incrementMission(userId, date) {
  const key = `${userId}:${date}`;
  const m = db.dailyMissions.get(key) ?? { userId, date, label: "デイリー", current: 0, target: 5 };
  m.current = Math.min(m.current + 1, m.target);
  db.dailyMissions.set(key, m);
  return m;
}
