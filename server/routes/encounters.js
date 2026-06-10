import { db, GUEST_ID } from "../db/client.js";
import { json, readBody } from "../middleware/cors.js";
import { addCollectedPiece, isUnlocked } from "../db/client.js";

// 開発用：サンプルエンカウンターを生成
function getOrCreateTodayEncounter() {
  const today = new Date().toISOString().slice(0, 10);
  if (db.encounters.has(today)) return db.encounters.get(today);

  const trackIds = [...db.tracks.keys()];
  const candidates = trackIds.slice(0, 5).map((trackId, i) => ({
    id: `cand_${today}_${i}`,
    trackId,
    pieceNumber: (i % 9) + 1,
    sourceSlot: ["推し曲枠", "発見枠", "解放済み", "レア枠", "イベント"][i],
    rarity: 5,
    sortOrder: i,
  }));

  const encounter = {
    id: `enc_${today}`,
    locationLabel: "大学",
    rewardCoins: 50,
    expiresAt: new Date(Date.now() + 45_000).toISOString(),
    candidates,
  };
  db.encounters.set(today, encounter);
  return encounter;
}

export function handleEncounters(req, res) {
  const encounter = getOrCreateTodayEncounter();
  json(res, 200, encounter);
}

export async function handleSelectPiece(req, res, encounterId, userId = GUEST_ID) {
  if (req.method !== "POST") return json(res, 405, { error: "method not allowed" });
  const body = await readBody(req);
  const { candidateIndex } = body;
  const today = new Date().toISOString().slice(0, 10);
  const encounter = db.encounters.get(today);
  if (!encounter) return json(res, 404, { error: "encounter not found" });
  const candidate = encounter.candidates[candidateIndex];
  if (!candidate) return json(res, 400, { error: "invalid candidate" });

  const added = addCollectedPiece(userId, candidate.trackId, candidate.pieceNumber);
  const unlocked = isUnlocked(userId, candidate.trackId);
  json(res, 200, {
    trackId: candidate.trackId,
    pieceNumber: candidate.pieceNumber,
    added,
    nextScreen: unlocked ? "puzzle" : "mystery",
  });
}
