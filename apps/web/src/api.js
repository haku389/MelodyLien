/**
 * api.js — Go API クライアント（最小構成）
 *
 * 開発サーバー: apps/web/serve.py（port 5174）
 * Go API サーバー: backend/api/main.go（port 3001）
 *
 * Go API が起動していない場合はローカルの seedData へフォールバックする。
 */

const API_BASE = "http://localhost:3001/api";

/** fetch wrapper。タイムアウト付き。失敗時は null を返す。 */
async function apiFetch(path, opts = {}) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 3000);
  try {
    const res = await fetch(API_BASE + path, {
      ...opts,
      signal: controller.signal,
      headers: { "Content-Type": "application/json", ...(opts.headers || {}) },
    });
    clearTimeout(timer);
    if (!res.ok) return null;
    return await res.json();
  } catch {
    clearTimeout(timer);
    return null;
  }
}

// ─── エンドポイント ────────────────────────────────

/**
 * 曲検索
 * @param {string} q 検索キーワード
 * @returns {Promise<Array<{trackId,title,artistName,color,youtubeId}>>}
 */
export async function searchTracks(q) {
  const data = await apiFetch(`/search?q=${encodeURIComponent(q)}`);
  return data ? data.results : null; // null = API 未起動
}

/**
 * 全曲一覧取得
 * @returns {Promise<Array>|null}
 */
export async function fetchTracks() {
  return await apiFetch("/tracks");
}

/**
 * 今日の出会い取得
 * @returns {Promise<Object>|null}
 */
export async function fetchEncounter() {
  return await apiFetch("/encounters/today");
}

/**
 * ピース追加（POST）
 * @param {string} trackId
 * @param {number} pieceNumber
 */
export async function postPiece(trackId, pieceNumber) {
  return await apiFetch(`/tracks/${trackId}/pieces`, {
    method: "POST",
    body: JSON.stringify({ pieceNumber }),
  });
}

/**
 * ユーザー情報取得
 */
export async function fetchMe() {
  return await apiFetch("/me");
}
