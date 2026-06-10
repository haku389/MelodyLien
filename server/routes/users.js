import {
  getUser, getAllTracks, getCollectedPieces, isUnlocked, getListenLater,
  getDailyMission, addCollectedPiece, unlockTrack, setHintLevel, getHintLevel,
  setAnswerReady, isAnswerReady, addListenLater, incrementMission, GUEST_ID,
} from "../db/client.js";
import { json, readBody } from "../middleware/cors.js";

export function handleMe(req, res) {
  const user = getUser(GUEST_ID);
  if (!user) return json(res, 404, { error: "user not found" });
  json(res, 200, user);
}

export function handleCollection(req, res, userId = GUEST_ID) {
  const tracks = getAllTracks();
  const completed = tracks.filter((t) => {
    const owned = getCollectedPieces(userId, t.id);
    return owned.length >= t.piece_count;
  });
  const unlocked = tracks.filter((t) => isUnlocked(userId, t.id));
  json(res, 200, {
    completedPuzzles: completed.length,
    totalPuzzles: tracks.length,
    unlockedTracks: unlocked.length,
    listenLater: getListenLater(userId).length,
  });
}

export async function handleUnlockTrack(req, res, trackId, userId = GUEST_ID) {
  if (req.method !== "POST") return json(res, 405, { error: "method not allowed" });
  unlockTrack(userId, trackId);
  json(res, 200, { ok: true });
}

export async function handleCollectPiece(req, res, trackId, userId = GUEST_ID) {
  if (req.method !== "POST") return json(res, 405, { error: "method not allowed" });
  const body = await readBody(req);
  const { pieceNumber } = body;
  if (!Number.isInteger(pieceNumber)) return json(res, 400, { error: "pieceNumber required" });
  const added = addCollectedPiece(userId, trackId, pieceNumber);
  incrementMission(userId, new Date().toISOString().slice(0, 10));
  json(res, 200, { added });
}

export async function handleHint(req, res, trackId, userId = GUEST_ID) {
  if (req.method !== "POST") return json(res, 405, { error: "method not allowed" });
  const body = await readBody(req);
  const { kind } = body; // "hint1" | "hint2" | "answer"
  const current = getHintLevel(userId, trackId);
  if (kind === "hint1") setHintLevel(userId, trackId, Math.max(current, 1));
  if (kind === "hint2") setHintLevel(userId, trackId, Math.max(current, 2));
  if (kind === "answer") setAnswerReady(userId, trackId);
  json(res, 200, {
    hintLevel: getHintLevel(userId, trackId),
    answerReady: isAnswerReady(userId, trackId),
  });
}

export async function handleListenLater(req, res, trackId, userId = GUEST_ID) {
  if (req.method !== "POST") return json(res, 405, { error: "method not allowed" });
  addListenLater(userId, trackId);
  json(res, 200, { ok: true });
}

export function handleMission(req, res, userId = GUEST_ID) {
  const date = new Date().toISOString().slice(0, 10);
  json(res, 200, getDailyMission(userId, date));
}
