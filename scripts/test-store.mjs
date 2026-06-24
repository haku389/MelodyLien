/**
 * store.js の永続化テスト（npm run test:store）
 * ピース取得 → コイン・デイリーミッション・クールタイム・フレンド追加が
 * LocalStorage（streetmelody.appState.v2）へ正しく保存されることを確認する。
 */
const memory = new Map();
globalThis.localStorage = {
  getItem: (key) => memory.get(key) ?? null,
  setItem: (key, value) => memory.set(key, value),
  removeItem: (key) => memory.delete(key),
};

const { createStore } = await import("../apps/web/src/store.js");
const { seedData, OSHI_LIMIT, OSHI_LIMIT_PREMIUM, COOLDOWN_MS, PIECE_EXP, levelFromExp } = await import("../apps/web/src/data.js");

const store = createStore();
const STORAGE_KEY = "streetmelody.appState.v2";

function assert(cond, message) {
  if (!cond) throw new Error(message);
}

function saved() {
  return JSON.parse(memory.get(STORAGE_KEY));
}

// encounter_today_001 の候補0（track_pretender）を選んで未所持ピースを取得
store.dispatch({ type: "SELECT_PUZZLE" });
const trackId = store.getState().selectedTrackId;
const candidate = seedData.encounters.encounter_today_001.candidates[0];
assert(trackId === candidate.trackId, "SELECT_PUZZLE: selectedTrackId mismatch");

const ownedBefore = store.getState().collectedPieces[trackId] || [];
const pieceNumber = candidate.availablePieces.find((n) => !ownedBefore.includes(n));
assert(pieceNumber !== undefined, "no available piece to pick");
const coinsBefore = store.getState().coins;

store.dispatch({ type: "SELECT_PIECE", pieceNumber });

let s = saved();
assert(s.collectedPieces[trackId].includes(pieceNumber), "piece not persisted");
assert(s.coins === coinsBefore + 1, "coin not added for new piece");
assert(s.dailyMission.progress === 1, "daily mission progress not counted");
assert(typeof s.encounterCooldowns.encounter_today_001 === "number", "cooldown not persisted");

// 重複取得ではミッション進捗が増えないこと
store.dispatch({ type: "SWITCH_ENCOUNTER", encounterId: "encounter_today_001" });
store.dispatch({ type: "SELECT_PUZZLE" });
store.dispatch({ type: "SELECT_PIECE", pieceNumber });
assert(saved().dailyMission.progress === 1, "duplicate piece must not advance mission");

// フレンド追加 → 既フレンドとの再交換で交換回数が増えること
const enc = seedData.encounters.encounter_today_001;
store.dispatch({ type: "ADD_FRIEND", userId: enc.fromUserId, userName: enc.fromUserName });
s = saved();
assert(s.friends.length === 1 && s.friends[0].userId === enc.fromUserId, "friend not persisted");
assert(s.friends[0].exchangeCount === 1, "initial exchangeCount must be 1");

store.dispatch({ type: "SWITCH_ENCOUNTER", encounterId: "encounter_today_001" });
store.dispatch({ type: "SELECT_PUZZLE" });
store.dispatch({ type: "SELECT_PIECE", pieceNumber });
assert(saved().friends[0].exchangeCount === 2, "exchangeCount not incremented on re-exchange");

// 曲名解放の永続化
store.dispatch({ type: "OPEN_TRACK", trackId });
store.dispatch({ type: "UNLOCK_TRACK" });
assert(saved().unlockedTrackIds.includes(trackId), "unlock not persisted");

// 推し曲設定: 追加・上限・解除
const unlockedIds = saved().unlockedTrackIds;
assert(unlockedIds.length >= 4, "need at least 4 unlocked tracks for oshi test");

store.dispatch({ type: "TOGGLE_OSHI_TRACK", trackId: unlockedIds[0] });
store.dispatch({ type: "TOGGLE_OSHI_TRACK", trackId: unlockedIds[1] });
store.dispatch({ type: "TOGGLE_OSHI_TRACK", trackId: unlockedIds[2] });
assert(saved().oshiTrackIds.length === OSHI_LIMIT, `${OSHI_LIMIT} oshi tracks should be set`);

// 上限超過 → 追加されない
store.dispatch({ type: "TOGGLE_OSHI_TRACK", trackId: unlockedIds[3] });
s = saved();
assert(s.oshiTrackIds.length === OSHI_LIMIT, "oshi tracks must not exceed OSHI_LIMIT");
assert(!s.oshiTrackIds.includes(unlockedIds[3]), "track beyond limit must not be added");

// 解除
store.dispatch({ type: "TOGGLE_OSHI_TRACK", trackId: unlockedIds[0] });
s = saved();
assert(s.oshiTrackIds.length === OSHI_LIMIT - 1 && !s.oshiTrackIds.includes(unlockedIds[0]),
  "oshi track should be removed on toggle");

// すれちがい出会いの日次リフレッシュ: クールタイムが明けた出会いに再訪問できること
{
  const memory2 = new Map();
  globalThis.localStorage = {
    getItem: (key) => memory2.get(key) ?? null,
    setItem: (key, value) => memory2.set(key, value),
    removeItem: (key) => memory2.delete(key),
  };
  let s2 = createStore();

  // 1件目（encounter_today_001）を消化 → 2件目へ自動前進
  s2.dispatch({ type: "SELECT_PUZZLE" });
  const cand1 = seedData.encounters.encounter_today_001.candidates[0];
  s2.dispatch({ type: "SELECT_PIECE", pieceNumber: cand1.availablePieces[0] });
  assert(s2.getState().activeEncounterId === "encounter_today_002", "should advance to encounter_today_002");

  // encounter_today_001 のクールタイムを6時間以上前に書き換え（期限切れをシミュレート）
  const data2 = JSON.parse(memory2.get(STORAGE_KEY));
  data2.encounterCooldowns.encounter_today_001 = Date.now() - COOLDOWN_MS - 1000;
  memory2.set(STORAGE_KEY, JSON.stringify(data2));

  // ストアを再生成（保存値を読み込み）→ 2件目を消化
  s2 = createStore();
  const cand2 = seedData.encounters.encounter_today_002.candidates[0];
  s2.dispatch({ type: "SELECT_PUZZLE" });
  s2.dispatch({ type: "SELECT_PIECE", pieceNumber: cand2.availablePieces[0] });
  assert(s2.getState().activeEncounterId === "encounter_today_001",
    "encounter with expired cooldown should become available again");
}

// 経験値・レベルアップ / 称号獲得検知（独立ストア）
{
  const memory3 = new Map();
  globalThis.localStorage = {
    getItem: (key) => memory3.get(key) ?? null,
    setItem: (key, value) => memory3.set(key, value),
    removeItem: (key) => memory3.delete(key),
  };
  // track_pretender を23枚所持・exp 95・推し曲1曲の状態を仕込む（次の1枚で完成 & レベルアップ）
  memory3.set(STORAGE_KEY, JSON.stringify({
    collectedPieces: { track_pretender: Array.from({ length: 23 }, (_, i) => i + 1) },
    exp: 95,
    oshiTrackIds: ["track_yoru"],
  }));
  const s3 = createStore();

  // levelFromExp の換算（Lv.L → L+1 は L×100 exp）
  assert(levelFromExp(0).level === 1, "0 exp should be level 1");
  assert(levelFromExp(99).level === 1, "99 exp should be level 1");
  assert(levelFromExp(100).level === 2, "100 exp should be level 2");
  assert(levelFromExp(300).level === 3, "300 exp (100+200) should be level 3");

  // 最後の1ピース取得 → 完成・レベルアップ・称号獲得（称号リワード込み）・推し曲の配達
  s3.dispatch({ type: "SELECT_PUZZLE" });
  s3.dispatch({ type: "SELECT_PIECE", pieceNumber: 24 });
  const after = s3.getState();
  const track = seedData.tracks.track_pretender;
  const firstPuzzleTitle = seedData.titles.find((t) => t.id === "title_first_puzzle");
  assert(after.exp === 95 + PIECE_EXP + track.rewardExp + firstPuzzleTitle.rewardExp,
    "exp should gain PIECE_EXP + rewardExp + title rewardExp on completion");
  assert(levelFromExp(after.exp).level === 2, "should reach level 2");
  // 完成報酬コイン: 新規ピース+1 + rewardCoins(100) + 称号リワード(30)
  assert(after.coins === 1 + track.rewardCoins + firstPuzzleTitle.rewardCoins,
    "completion should grant rewardCoins + title reward on top of piece coin");
  assert(after.toast.includes("完成報酬"), "toast should announce completion reward coins");
  assert(after.toast.includes("レベルアップ"), "toast should announce level up");
  assert(after.toast.includes("はじめてのひとかけら"), "toast should announce gained title");
  assert(after.toast.includes(`🪙+${firstPuzzleTitle.rewardCoins}`), "toast should show title coin reward");
  assert(after.pendingTitleCelebrations.includes("title_first_puzzle"), "title celebration should be queued");
  assert(JSON.parse(memory3.get(STORAGE_KEY)).exp === after.exp, "exp should be persisted");

  // 推し曲のすれちがい連動: 出会い相手（田中ゆき）に推し曲が届く
  assert(after.oshiDeliveries.user_tanaka_yuki === 1, "oshi track should be delivered to encounter partner");
  assert(after.toast.includes("推し曲「夜に駆ける」"), "toast should announce oshi delivery");
  assert(JSON.parse(memory3.get(STORAGE_KEY)).oshiDeliveries.user_tanaka_yuki === 1, "oshi deliveries should be persisted");

  // 演出を閉じると先頭の称号が消化される
  const pendingBefore = after.pendingTitleCelebrations.length;
  s3.dispatch({ type: "DISMISS_TITLE_CELEBRATION" });
  assert(s3.getState().pendingTitleCelebrations.length === pendingBefore - 1,
    "dismiss should consume the first pending title");

  // フレンド追加 → 「はじめてのフレンド」称号を獲得
  s3.dispatch({ type: "ADD_FRIEND", userId: "user_tanaka_yuki", userName: "田中ゆき" });
  assert(s3.getState().pendingTitleCelebrations.includes("title_first_friend"),
    "friend title should be detected on ADD_FRIEND");
  assert(s3.getState().toast.includes("はじめてのフレンド"), "toast should include friend title");

  // プレミアムプラン: 加入で推し曲上限が5曲に拡大・解約で無料枠まで自動調整
  s3.dispatch({ type: "SET_PREMIUM", value: true });
  assert(s3.getState().premium === true, "premium should be set");
  assert(JSON.parse(memory3.get(STORAGE_KEY)).premium === true, "premium should be persisted");

  const unlocked3 = s3.getState().unlockedTrackIds;
  assert(unlocked3.length >= OSHI_LIMIT_PREMIUM + 1, "need enough unlocked tracks for premium oshi test");
  for (const id of unlocked3.slice(0, OSHI_LIMIT_PREMIUM + 1)) {
    s3.dispatch({ type: "TOGGLE_OSHI_TRACK", trackId: id });
  }
  assert(s3.getState().oshiTrackIds.length === OSHI_LIMIT_PREMIUM,
    `premium oshi limit should be ${OSHI_LIMIT_PREMIUM}`);

  s3.dispatch({ type: "SET_PREMIUM", value: false });
  assert(s3.getState().premium === false, "premium should be cancelled");
  assert(s3.getState().oshiTrackIds.length === OSHI_LIMIT,
    "oshi tracks should be trimmed to free limit on cancel");
}

// ショップ・通知設定・音楽サービス連携（独立ストア）
{
  const memory4 = new Map();
  globalThis.localStorage = {
    getItem: (key) => memory4.get(key) ?? null,
    setItem: (key, value) => memory4.set(key, value),
    removeItem: (key) => memory4.delete(key),
  };
  memory4.set(STORAGE_KEY, JSON.stringify({ coins: 100, collectedPieces: { track_pretender: [1, 2, 3] } }));
  const s4 = createStore();
  const { SHOP_ITEMS } = await import("../apps/web/src/data.js");

  const crown = SHOP_ITEMS.find((i) => i.id === "shop_deco_crown");

  // ヒントチケット購入: コイン減・所持数+1
  s4.dispatch({ type: "BUY_SHOP_ITEM", itemId: "shop_hint_ticket" });
  assert(s4.getState().coins === 100 - 15, "ticket purchase should deduct coins");
  assert(s4.getState().hintTickets === 1, "ticket count should increase");
  assert(JSON.parse(memory4.get(STORAGE_KEY)).hintTickets === 1, "tickets should be persisted");

  // チケットでヒント解放（広告なし）: チケット減・ヒントLv設定
  s4.dispatch({ type: "OPEN_TRACK", trackId: "track_pretender" });
  s4.dispatch({ type: "COMPLETE_AD", kind: "hint1", viaTicket: true });
  assert(s4.getState().hintTickets === 0, "ticket should be consumed");
  assert(s4.getState().hintLevels.track_pretender === 1, "hint level should be set via ticket");
  assert(s4.getState().toast.includes("ヒントチケット"), "toast should mention ticket use");

  // ランダムピース購入: 所持ピース合計+1・コイン減（ミッション進捗も+1）
  const totalBefore = Object.values(s4.getState().collectedPieces).reduce((n, a) => n + a.length, 0);
  const coinsBefore4 = s4.getState().coins;
  s4.dispatch({ type: "BUY_SHOP_ITEM", itemId: "shop_random_piece" });
  const totalAfter = Object.values(s4.getState().collectedPieces).reduce((n, a) => n + a.length, 0);
  assert(totalAfter === totalBefore + 1, "random piece should add exactly one piece");
  assert(s4.getState().coins <= coinsBefore4 - 20 + 110, "coins should be deducted (allowing completion bonus)");
  assert(s4.getState().dailyMission.progress === 1, "shop piece should count toward daily mission");

  // 装飾購入: 自動装備・重複購入は拒否
  s4.dispatch({ type: "BUY_SHOP_ITEM", itemId: "shop_deco_hat" });
  assert(s4.getState().ownedDecorations.includes("shop_deco_hat"), "decoration should be owned");
  assert(s4.getState().equippedDecoration === "shop_deco_hat", "decoration should be auto-equipped");
  const coinsAfterDeco = s4.getState().coins;
  s4.dispatch({ type: "BUY_SHOP_ITEM", itemId: "shop_deco_hat" });
  assert(s4.getState().coins === coinsAfterDeco, "duplicate decoration purchase must not charge");

  // 装備の付け外し
  s4.dispatch({ type: "EQUIP_DECORATION", itemId: "shop_deco_hat" });
  assert(s4.getState().equippedDecoration === null, "re-equip should unequip");

  // コイン不足の購入は拒否
  const poorCoins = s4.getState().coins;
  if (poorCoins < crown.price) {
    s4.dispatch({ type: "BUY_SHOP_ITEM", itemId: "shop_deco_crown" });
    assert(!s4.getState().ownedDecorations.includes("shop_deco_crown"), "purchase without coins must be rejected");
  }

  // 通知設定: トグルと時間帯の永続化
  s4.dispatch({ type: "TOGGLE_NOTIFICATION", key: "digest" });
  s4.dispatch({ type: "SET_DIGEST_TIME", value: "09:00" });
  const ns4 = JSON.parse(memory4.get(STORAGE_KEY)).notificationSettings;
  assert(ns4.digest === true && ns4.digestTime === "09:00", "notification settings should be persisted");

  // バックグラウンド検知設定: トグル・モードの永続化
  s4.dispatch({ type: "TOGGLE_BG_SCAN", key: "nightPause" });
  s4.dispatch({ type: "SET_BG_SCAN_MODE", value: "powersave" });
  const bg4 = JSON.parse(memory4.get(STORAGE_KEY)).backgroundScan;
  assert(bg4.nightPause === true && bg4.mode === "powersave", "background scan settings should be persisted");
  assert(bg4.enabled === true, "background scan should stay enabled by default");

  // 音楽サービス連携: トグル・永続化
  s4.dispatch({ type: "TOGGLE_SERVICE_LINK", service: "spotify" });
  assert(JSON.parse(memory4.get(STORAGE_KEY)).linkedServices.spotify === true, "service link should be persisted");
  assert(s4.getState().toast.includes("Spotify"), "toast should mention linked service");
  s4.dispatch({ type: "TOGGLE_SERVICE_LINK", service: "spotify" });
  assert(s4.getState().linkedServices.spotify === false, "service link should toggle off");
}

console.log("store persistence ok");
