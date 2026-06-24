/**
 * sync.js — ログイン時の LocalStorage ⇄ Supabase 同期
 *
 * ゲスト（匿名認証・ローカルゲスト）は同期対象外（ローカルのみで完結）。
 * ログイン時: ローカルとリモートを和集合でマージしてローカルへ反映 → リモートへ書き戻し。
 * ログイン後: ピース獲得・曲解放・フレンド追加などの操作を都度リモートへ反映。
 */
import { supabase } from "./supabase.js";
import { seedData } from "./data.js";

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function unique(values) {
  return [...new Set(values)];
}

/** すれちがい相手（NPC）の userId を表示名から逆引き */
function npcIdForName(name) {
  for (const enc of Object.values(seedData.encounters)) {
    if (enc.fromUserName === name) return enc.fromUserId;
  }
  return null;
}

async function fetchRemote(userId) {
  const [pieces, tracks, friends, cooldowns, profile] = await Promise.all([
    supabase.from("collected_pieces").select("track_id, piece_number").eq("user_id", userId),
    supabase.from("unlocked_tracks").select("track_id").eq("user_id", userId),
    supabase.from("friendships").select("friend_name, friend_user_id, exchange_count, added_at").eq("user_id", userId),
    supabase.from("encounter_cooldowns").select("encounter_id, last_pick_at").eq("user_id", userId),
    supabase.from("profiles").select("coins").eq("user_id", userId).maybeSingle(),
  ]);

  const collectedPieces = {};
  for (const row of pieces.data || []) {
    (collectedPieces[row.track_id] ??= []).push(row.piece_number);
  }

  const friendsList = (friends.data || []).map((r) => ({
    userId: r.friend_user_id || npcIdForName(r.friend_name) || `name:${r.friend_name}`,
    userName: r.friend_name,
    addedAt: new Date(r.added_at).getTime(),
    exchangeCount: r.exchange_count,
  }));

  const encounterCooldowns = {};
  for (const row of cooldowns.data || []) {
    encounterCooldowns[row.encounter_id] = new Date(row.last_pick_at).getTime();
  }

  return {
    collectedPieces,
    unlockedTrackIds: (tracks.data || []).map((r) => r.track_id),
    friends: friendsList,
    encounterCooldowns,
    coins: profile.data?.coins ?? 0,
  };
}

/** ローカル・リモートを和集合でマージ（フレンドはfriend_name、クールタイムは新しい方を採用） */
function mergeStates(local, remote) {
  const collectedPieces = {};
  for (const trackId of unique([...Object.keys(local.collectedPieces || {}), ...Object.keys(remote.collectedPieces)])) {
    collectedPieces[trackId] = unique([
      ...(local.collectedPieces?.[trackId] || []),
      ...(remote.collectedPieces[trackId] || []),
    ]).sort((a, b) => a - b);
  }

  const unlockedTrackIds = unique([...(local.unlockedTrackIds || []), ...remote.unlockedTrackIds]);

  const friends = [...(local.friends || [])];
  for (const rf of remote.friends) {
    if (!friends.some((f) => f.userName === rf.userName)) friends.push(rf);
  }

  const encounterCooldowns = { ...(local.encounterCooldowns || {}) };
  for (const [id, ts] of Object.entries(remote.encounterCooldowns)) {
    encounterCooldowns[id] = Math.max(encounterCooldowns[id] || 0, ts);
  }

  return {
    collectedPieces,
    unlockedTrackIds,
    friends,
    encounterCooldowns,
    coins: Math.max(local.coins || 0, remote.coins || 0),
  };
}

async function pushRemote(userId, merged) {
  const pieceRows = [];
  for (const [trackId, nums] of Object.entries(merged.collectedPieces)) {
    for (const n of nums) pieceRows.push({ user_id: userId, track_id: trackId, piece_number: n });
  }
  const trackRows = merged.unlockedTrackIds.map((trackId) => ({ user_id: userId, track_id: trackId }));
  const friendRows = merged.friends.map((f) => ({
    user_id: userId,
    friend_name: f.userName,
    friend_user_id: UUID_RE.test(f.userId) ? f.userId : null,
    exchange_count: f.exchangeCount,
    added_at: new Date(f.addedAt).toISOString(),
  }));
  const cooldownRows = Object.entries(merged.encounterCooldowns).map(([encounterId, ts]) => ({
    user_id: userId,
    encounter_id: encounterId,
    last_pick_at: new Date(ts).toISOString(),
  }));

  await Promise.all([
    pieceRows.length ? supabase.from("collected_pieces").upsert(pieceRows, { onConflict: "user_id,track_id,piece_number" }) : null,
    trackRows.length ? supabase.from("unlocked_tracks").upsert(trackRows, { onConflict: "user_id,track_id" }) : null,
    friendRows.length ? supabase.from("friendships").upsert(friendRows, { onConflict: "user_id,friend_name" }) : null,
    cooldownRows.length ? supabase.from("encounter_cooldowns").upsert(cooldownRows, { onConflict: "user_id,encounter_id" }) : null,
    supabase.from("profiles").update({ coins: merged.coins }).eq("user_id", userId),
  ]);
}

/** ログイン時: リモートとローカルをマージしてローカルへ反映 + リモートへ書き戻す */
export async function syncOnLogin(userId, store) {
  try {
    const remote = await fetchRemote(userId);
    const merged = mergeStates(store.getState(), remote);
    store.dispatch({ type: "MERGE_REMOTE_STATE", data: merged });
    await pushRemote(userId, merged);
  } catch (err) {
    console.error("[sync] login sync failed:", err);
  }
}

/** ログイン中の操作を都度リモートへ反映（失敗してもローカル動作は継続） */
export function syncAfterAction(userId, prevState, nextState, action) {
  if (!userId) return;

  if (action.type === "SELECT_PIECE") {
    const trackId = nextState.selectedTrackId;
    supabase.from("collected_pieces")
      .upsert({ user_id: userId, track_id: trackId, piece_number: action.pieceNumber }, { onConflict: "user_id,track_id,piece_number" })
      .then(({ error }) => error && console.error("[sync] piece:", error));

    if (nextState.unlockedTrackIds.includes(trackId) && !prevState.unlockedTrackIds.includes(trackId)) {
      supabase.from("unlocked_tracks")
        .upsert({ user_id: userId, track_id: trackId }, { onConflict: "user_id,track_id" })
        .then(({ error }) => error && console.error("[sync] unlock:", error));
    }

    if (nextState.coins !== prevState.coins) {
      supabase.from("profiles").update({ coins: nextState.coins }).eq("user_id", userId)
        .then(({ error }) => error && console.error("[sync] coins:", error));
    }

    const encounterId = prevState.activeEncounterId;
    if (nextState.encounterCooldowns[encounterId] !== prevState.encounterCooldowns[encounterId]) {
      supabase.from("encounter_cooldowns")
        .upsert(
          { user_id: userId, encounter_id: encounterId, last_pick_at: new Date(nextState.encounterCooldowns[encounterId]).toISOString() },
          { onConflict: "user_id,encounter_id" },
        )
        .then(({ error }) => error && console.error("[sync] cooldown:", error));
    }

    // 既フレンドとの再交換で exchange_count が増えた場合はリモートへ反映
    const exchanged = (nextState.friends || []).find((f) =>
      (prevState.friends || []).some((pf) => pf.userName === f.userName && pf.exchangeCount !== f.exchangeCount));
    if (exchanged) {
      supabase.from("friendships")
        .update({ exchange_count: exchanged.exchangeCount })
        .eq("user_id", userId).eq("friend_name", exchanged.userName)
        .then(({ error }) => error && console.error("[sync] exchange:", error));
    }
    return;
  }

  if (action.type === "ADD_FRIEND") {
    const friend = nextState.friends[nextState.friends.length - 1];
    if (!friend) return;
    supabase.from("friendships")
      .upsert({
        user_id: userId,
        friend_name: friend.userName,
        friend_user_id: UUID_RE.test(friend.userId) ? friend.userId : null,
        exchange_count: friend.exchangeCount,
        added_at: new Date(friend.addedAt).toISOString(),
      }, { onConflict: "user_id,friend_name" })
      .then(({ error }) => error && console.error("[sync] friend:", error));
    return;
  }

  if (action.type === "UNLOCK_TRACK") {
    supabase.from("unlocked_tracks")
      .upsert({ user_id: userId, track_id: nextState.selectedTrackId }, { onConflict: "user_id,track_id" })
      .then(({ error }) => error && console.error("[sync] unlock:", error));
  }
}
