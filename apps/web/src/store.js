import { initialAppState, seedData, todayKey, COOLDOWN_MS, oshiLimit, PIECE_EXP, levelFromExp, SHOP_ITEMS } from "./data.js";

/** クールタイムが明けている（未訪問 or 6時間経過済み）か */
function isAvailable(cooldowns, id) {
  return !cooldowns[id] || Date.now() - cooldowns[id] >= COOLDOWN_MS;
}

/** 次に受け取れる出会いID（未確認 or クールタイム明け。なければ null） */
function nextAvailableEncounter(cooldowns) {
  return seedData.encounterOrder.find((id) => isAvailable(cooldowns, id)) || null;
}

/** デイリーミッションの進行状況（日付が変わっていれば未達成扱いでリセット） */
export function getDailyMissionProgress(state) {
  const dm = state.dailyMission;
  if (!dm || dm.date !== todayKey()) return { date: todayKey(), progress: 0, claimed: false };
  return dm;
}

/** トラックをアーティスト単位にまとめ、完成曲数を所持ピースから算出 */
export function artistGroups(state) {
  const groups = new Map();
  for (const t of Object.values(seedData.tracks)) {
    if (!groups.has(t.artistId)) groups.set(t.artistId, { id: t.artistId, name: t.artistName, tracks: [] });
    groups.get(t.artistId).tracks.push(t);
  }
  return [...groups.values()].map((g) => ({
    ...g,
    completed: g.tracks.filter((t) => (state.collectedPieces[t.id] || []).length >= t.pieceCount).length,
  }));
}

/** 称号の進捗（current / target / unlocked）を state から算出 */
export function titleProgress(state, title) {
  const tracks = Object.values(seedData.tracks);
  const target = title.target === "all" ? tracks.length : title.target;
  let current = 0;
  if (title.type === "puzzles") current = tracks.filter((t) => (state.collectedPieces[t.id] || []).length >= t.pieceCount).length;
  if (title.type === "artists") current = artistGroups(state).filter((g) => g.completed >= g.tracks.length).length;
  if (title.type === "friends") current = (state.friends || []).length;
  if (title.type === "unlocks") current = state.unlockedTrackIds.length;
  if (title.type === "mission") current = getDailyMissionProgress(state).claimed ? 1 : 0;
  return { current: Math.min(current, target), target, unlocked: current >= target };
}

/** 現在の state で獲得済みの称号ID一覧 */
function unlockedTitleIds(state) {
  return seedData.titles.filter((t) => titleProgress(state, t).unlocked).map((t) => t.id);
}

const STORAGE_KEY = "melodylien.appState.v2";

function loadState() {
  try {
    const saved = JSON.parse(localStorage.getItem(STORAGE_KEY) || "null");
    return saved
      ? { ...initialAppState(), ...saved, carouselIndex: 0, selectedCandidateIndex: -1 }
      : initialAppState();
  } catch {
    return initialAppState();
  }
}

function saveState(state) {
  localStorage.setItem(STORAGE_KEY, JSON.stringify({
    activeScreen: state.activeScreen,
    activeEncounterId: state.activeEncounterId,
    selectedTrackId: state.selectedTrackId,
    unlockedTrackIds: state.unlockedTrackIds,
    hintLevels: state.hintLevels,
    answerReadyTrackIds: state.answerReadyTrackIds,
    collectedPieces: state.collectedPieces,
    listenLaterTrackIds: state.listenLaterTrackIds,
    recentlyAddedTrackIds: state.recentlyAddedTrackIds,
    coins: state.coins,
    encounterCooldowns: state.encounterCooldowns,
    friends: state.friends,
    selectedFriendUserId: state.selectedFriendUserId,
    selectedArtistId: state.selectedArtistId,
    pendingFriendAdd: state.pendingFriendAdd,
    previewPlays: state.previewPlays,
    dailyMission: state.dailyMission,
    oshiTrackIds: state.oshiTrackIds,
    exp: state.exp,
    premium: state.premium,
    hintTickets: state.hintTickets,
    ownedDecorations: state.ownedDecorations,
    equippedDecoration: state.equippedDecoration,
    notificationSettings: state.notificationSettings,
    linkedServices: state.linkedServices,
    backgroundScan: state.backgroundScan,
    oshiDeliveries: state.oshiDeliveries,
  }));
}

function unique(values) {
  return [...new Set(values)];
}

function nextState(state, action) {

  // ─── ナビゲーション ──────────────────────────────
  if (action.type === "NAVIGATE") {
    return { ...state, activeScreen: action.screen, toast: null };
  }

  // ─── カルーセル操作（届いた画面） ────────────────
  if (action.type === "CAROUSEL_NEXT") {
    const encounter = seedData.encounters[state.activeEncounterId];
    const max = encounter.candidates.length - 1;
    return { ...state, carouselIndex: Math.min(state.carouselIndex + 1, max), carouselViewMode: "pieces" };
  }

  if (action.type === "CAROUSEL_PREV") {
    return { ...state, carouselIndex: Math.max(state.carouselIndex - 1, 0), carouselViewMode: "pieces" };
  }

  if (action.type === "TOGGLE_CAROUSEL_VIEW") {
    return { ...state, carouselViewMode: state.carouselViewMode === "pieces" ? "mosaic" : "pieces" };
  }

  // ─── 「このパズルにする」 → ピース選択画面へ ──────
  if (action.type === "SELECT_PUZZLE") {
    // carouselIndex のパズルを選んでピース選択画面へ
    const encounter = seedData.encounters[state.activeEncounterId];
    const candidate = encounter.candidates[state.carouselIndex];
    return {
      ...state,
      activeScreen: "piece-select",
      selectedCandidateIndex: state.carouselIndex,
      selectedTrackId: candidate.trackId,
      toast: null,
    };
  }

  // ─── ピース選択確定 ──────────────────────────────
  if (action.type === "SELECT_PIECE") {
    const encounter = seedData.encounters[state.activeEncounterId];
    const candidate = encounter.candidates[state.selectedCandidateIndex];
    const track = seedData.tracks[candidate.trackId];
    const pieceNumber = action.pieceNumber;

    const currentPieces = state.collectedPieces[track.id] || [];
    const alreadyOwned = currentPieces.includes(pieceNumber);

    // コイン加算: 新規ピース → +1枚 / 全揃い後の重複 → +3枚
    const newPieces = alreadyOwned
      ? currentPieces
      : unique([...currentPieces, pieceNumber]).sort((a, b) => a - b);
    const wasPreviouslyComplete = currentPieces.length >= track.pieceCount;
    const earnedCoins = alreadyOwned ? (wasPreviouslyComplete ? 3 : 0) : 1;

    const collectedPieces = { ...state.collectedPieces, [track.id]: newPieces };
    // パズル完成判定: 今回のピースで初めて揃った（完成報酬コインを付与）
    const justCompleted = !wasPreviouslyComplete && newPieces.length >= track.pieceCount;
    const completionCoins = justCompleted ? track.rewardCoins : 0;
    const nextScreen = (state.unlockedTrackIds.includes(track.id) || justCompleted) ? "puzzle" : "mystery";
    // 完成時は曲名を自動解放
    const unlockedTrackIds = justCompleted
      ? unique([...state.unlockedTrackIds, track.id])
      : state.unlockedTrackIds;

    const toastMsg = alreadyOwned
      ? wasPreviouslyComplete
        ? `すでに揃っています。メロディコイン ×${earnedCoins} を獲得しました`
        : "このピースはすでに持っています"
      : justCompleted
        ? `🎉 ${track.artistName} / ${track.title} パズル完成！`
        : `${track.artistName} のピースを獲得！ メロディコイン ×${earnedCoins}`;

    // ─── デイリーミッション進行（新規ピース獲得でカウント・日付単位リセット） ───
    const dm = getDailyMissionProgress(state);
    const missionTarget = seedData.mission.target;
    const missionProgress = alreadyOwned ? dm.progress : Math.min(dm.progress + 1, missionTarget);
    const missionJustAchieved = !dm.claimed && missionProgress >= missionTarget;
    const dailyMission = { date: todayKey(), progress: missionProgress, claimed: dm.claimed || missionJustAchieved };
    const bonusCoins = missionJustAchieved ? seedData.mission.rewardCoins : 0;

    // ─── 経験値（新規ピース +PIECE_EXP / 完成時 +rewardExp）・レベルアップ判定 ───
    const earnedExp = alreadyOwned ? 0 : PIECE_EXP + (justCompleted ? track.rewardExp : 0);
    const exp = (state.exp || 0) + earnedExp;
    const leveledUp = levelFromExp(exp).level > levelFromExp(state.exp || 0).level;

    const toast = [
      toastMsg,
      justCompleted ? `🪙 完成報酬 メロディコイン +${completionCoins}` : "",
      missionJustAchieved ? `🎉 デイリーミッション達成！メロディコイン +${bonusCoins}` : "",
      leveledUp ? `⬆️ レベルアップ！ Lv.${levelFromExp(exp).level} になりました` : "",
    ].filter(Boolean).join("\n");

    // 同じ出会い相手に対してクールタイム 6時間を設定
    const encounterId = state.activeEncounterId;
    const encounterCooldowns = { ...state.encounterCooldowns, [encounterId]: Date.now() };

    // 次に受け取れる出会いへ自動前進（未確認 or クールタイム明け）
    const nextEncounterId = nextAvailableEncounter(encounterCooldowns);
    const activeEncounterId = nextEncounterId || state.activeEncounterId;

    // フレンド申請プロンプト（既にフレンドでなければ）／既フレンドなら交換回数を加算
    const currentEncounter = seedData.encounters[encounterId];
    const alreadyFriend = (state.friends || []).some((f) => f.userId === currentEncounter.fromUserId);
    const friends = alreadyFriend
      ? state.friends.map((f) =>
          f.userId === currentEncounter.fromUserId ? { ...f, exchangeCount: f.exchangeCount + 1 } : f)
      : state.friends;
    const pendingFriendAdd = alreadyFriend ? state.pendingFriendAdd : {
      userId: currentEncounter.fromUserId,
      userName: currentEncounter.fromUserName,
    };

    // 推し曲のすれちがい連動: 設定中の推し曲を相手に順番に1曲届ける
    const oshiIds = state.oshiTrackIds || [];
    const deliveredBefore = (state.oshiDeliveries || {})[currentEncounter.fromUserId] || 0;
    const deliveredTrack = oshiIds.length > 0 ? seedData.tracks[oshiIds[deliveredBefore % oshiIds.length]] : null;
    const oshiDeliveries = deliveredTrack
      ? { ...(state.oshiDeliveries || {}), [currentEncounter.fromUserId]: deliveredBefore + 1 }
      : (state.oshiDeliveries || {});

    return {
      ...state,
      activeScreen: nextScreen,
      activeEncounterId,
      selectedTrackId: track.id,
      selectedCandidateIndex: -1,
      carouselIndex: 0,
      carouselViewMode: "pieces",
      collectedPieces,
      unlockedTrackIds,
      coins: state.coins + earnedCoins + bonusCoins + completionCoins,
      exp,
      recentlyAddedTrackIds: unique([track.id, ...state.recentlyAddedTrackIds]).slice(0, 6),
      encounterCooldowns,
      dailyMission,
      puzzleCompleteTrackId: justCompleted ? track.id : state.puzzleCompleteTrackId,
      friends,
      pendingFriendAdd,
      oshiDeliveries,
      toast: deliveredTrack
        ? `${toast}\n🎵 あなたの推し曲「${deliveredTrack.title}」を ${currentEncounter.fromUserName} さんに届けました`
        : toast,
    };
  }

  // ─── トラックを開く ──────────────────────────────
  if (action.type === "OPEN_TRACK") {
    const nextScreen = state.unlockedTrackIds.includes(action.trackId) ? "puzzle" : "mystery";
    return { ...state, selectedTrackId: action.trackId, activeScreen: nextScreen, toast: null };
  }

  // ─── 広告モーダル ────────────────────────────────
  if (action.type === "OPEN_AD_MODAL") {
    return { ...state, selectedAdKind: action.kind };
  }

  if (action.type === "CLOSE_AD_MODAL") {
    return { ...state, selectedAdKind: null };
  }

  if (action.type === "COMPLETE_AD") {
    const trackId = state.selectedTrackId;
    const currentLevel = state.hintLevels[trackId] || 0;
    const nextLevel = action.kind === "hint1"
      ? Math.max(currentLevel, 1)
      : Math.max(currentLevel, 2);
    const answerReadyTrackIds = action.kind === "answer"
      ? unique([...state.answerReadyTrackIds, trackId])
      : state.answerReadyTrackIds;
    // 解放手段: プレミアム（広告非表示）> ヒントチケット消費 > 広告視聴後
    const hintTickets = action.viaTicket ? (state.hintTickets || 0) - 1 : state.hintTickets;
    const prefix = state.premium
      ? "⭐ プレミアム特典：広告なしで解放 — "
      : action.viaTicket
        ? `🎟️ ヒントチケットを使用（残り${hintTickets}枚）— `
        : "";
    return {
      ...state,
      activeScreen: "mystery",
      selectedAdKind: null,
      hintLevels: { ...state.hintLevels, [trackId]: nextLevel },
      answerReadyTrackIds,
      hintTickets,
      toast: prefix + (action.kind === "answer" ? "YouTube確認リンクを表示しました" : "ヒントを解放しました"),
    };
  }

  // ─── 曲解放 ─────────────────────────────────────
  if (action.type === "UNLOCK_TRACK") {
    const track = seedData.tracks[state.selectedTrackId];
    return {
      ...state,
      activeScreen: "puzzle",
      unlockedTrackIds: unique([...state.unlockedTrackIds, state.selectedTrackId]),
      toast: `${track.artistName} / ${track.title} を解放しました`,
    };
  }

  // ─── あとで聴く ──────────────────────────────────
  if (action.type === "ADD_LISTEN_LATER") {
    const track = seedData.tracks[action.trackId];
    return {
      ...state,
      listenLaterTrackIds: unique([action.trackId, ...state.listenLaterTrackIds]),
      toast: `${track.title} をあとで聴くに追加しました`,
    };
  }

  // コレクション・ランキング内部タブ切り替え
  if (action.type === "SET_COLLECTION_TAB") {
    return { ...state, collectionTab: action.tab };
  }

  if (action.type === "SET_RANKING_TAB") {
    return { ...state, rankingTab: action.tab };
  }

  // ─── 試聴回数を記録（1曲1日3回まで・カウントは日付単位でリセット） ───
  if (action.type === "RECORD_PREVIEW_PLAY") {
    const prev = (state.previewPlays || {})[action.trackId];
    const count = prev && prev.date === action.date ? prev.count + 1 : 1;
    return {
      ...state,
      previewPlays: {
        ...(state.previewPlays || {}),
        [action.trackId]: { date: action.date, count },
      },
    };
  }

  if (action.type === "ADD_FRIEND") {
    const already = (state.friends || []).some((f) => f.userId === action.userId);
    if (already) return { ...state, pendingFriendAdd: null };
    return {
      ...state,
      pendingFriendAdd: null,
      friends: [...(state.friends || []), {
        userId: action.userId,
        userName: action.userName,
        addedAt: Date.now(),
        exchangeCount: 1,
      }],
      toast: `${action.userName} さんをフレンドに追加しました 🎵`,
    };
  }

  if (action.type === "DISMISS_FRIEND_PROMPT") {
    return { ...state, pendingFriendAdd: null };
  }

  // ─── 推し曲設定（最大 oshiLimit(state) 曲・トグル） ──────
  if (action.type === "TOGGLE_OSHI_TRACK") {
    const current = state.oshiTrackIds || [];
    if (current.includes(action.trackId)) {
      return { ...state, oshiTrackIds: current.filter((id) => id !== action.trackId) };
    }
    const limit = oshiLimit(state);
    if (current.length >= limit) {
      return { ...state, toast: `推し曲は${limit}曲まで設定できます${state.premium ? "" : "（プレミアムで5曲まで）"}` };
    }
    const track = seedData.tracks[action.trackId];
    return {
      ...state,
      oshiTrackIds: [...current, action.trackId],
      toast: `${track.title} を推し曲に設定しました`,
    };
  }

  // ─── フレンド詳細画面を開く ───────────────────────
  if (action.type === "OPEN_FRIEND") {
    return { ...state, selectedFriendUserId: action.userId, activeScreen: "friend-detail" };
  }

  // ─── アーティスト詳細画面を開く ──────────────────
  if (action.type === "OPEN_ARTIST") {
    return { ...state, selectedArtistId: action.artistId, activeScreen: "artist-detail" };
  }

  if (action.type === "SWITCH_ENCOUNTER") {
    return {
      ...state,
      activeEncounterId: action.encounterId,
      carouselIndex: 0,
      carouselViewMode: "pieces",
    };
  }

  if (action.type === "DISMISS_PUZZLE_COMPLETE") {
    return { ...state, puzzleCompleteTrackId: null };
  }

  // ─── 称号獲得演出を閉じる（先頭の1件を消化） ──────
  if (action.type === "DISMISS_TITLE_CELEBRATION") {
    return { ...state, pendingTitleCelebrations: (state.pendingTitleCelebrations || []).slice(1) };
  }

  // ─── ショップ購入（メロディコインを消費） ──────
  if (action.type === "BUY_SHOP_ITEM") {
    const item = SHOP_ITEMS.find((i) => i.id === action.itemId);
    if (!item) return state;
    if (item.type === "decoration" && (state.ownedDecorations || []).includes(item.id)) {
      return { ...state, toast: `${item.name} はすでに持っています` };
    }
    if (state.coins < item.price) {
      return { ...state, toast: `メロディコインが足りません（必要: ${item.price}枚）` };
    }

    // ヒントチケット: 所持数+1
    if (item.type === "ticket") {
      return {
        ...state,
        coins: state.coins - item.price,
        hintTickets: (state.hintTickets || 0) + 1,
        toast: `${item.icon} ${item.name} を購入しました（所持 ${(state.hintTickets || 0) + 1}枚）`,
      };
    }

    // アバター装飾: 買い切り・購入時に自動装備
    if (item.type === "decoration") {
      return {
        ...state,
        coins: state.coins - item.price,
        ownedDecorations: [...(state.ownedDecorations || []), item.id],
        equippedDecoration: item.id,
        toast: `${item.icon} ${item.name} を購入して装備しました`,
      };
    }

    // ランダムピース: 未完成パズルからランダムで1ピース獲得（完成判定つき）
    const incomplete = Object.values(seedData.tracks).filter(
      (t) => (state.collectedPieces[t.id] || []).length < t.pieceCount);
    if (incomplete.length === 0) {
      return { ...state, toast: "すべてのパズルが完成しています！" };
    }
    const track = incomplete[Math.floor(Math.random() * incomplete.length)];
    const current = state.collectedPieces[track.id] || [];
    const missing = [];
    for (let n = 1; n <= track.pieceCount; n++) if (!current.includes(n)) missing.push(n);
    const pieceNumber = missing[Math.floor(Math.random() * missing.length)];
    const newPieces = [...current, pieceNumber].sort((a, b) => a - b);

    const justCompleted = newPieces.length >= track.pieceCount;
    const completionCoins = justCompleted ? track.rewardCoins : 0;
    const unlockedTrackIds = justCompleted
      ? unique([...state.unlockedTrackIds, track.id])
      : state.unlockedTrackIds;

    // デイリーミッション（ピース獲得でカウント）と経験値は通常取得と同様に進行
    const dm = getDailyMissionProgress(state);
    const missionProgress = Math.min(dm.progress + 1, seedData.mission.target);
    const missionJustAchieved = !dm.claimed && missionProgress >= seedData.mission.target;
    const bonusCoins = missionJustAchieved ? seedData.mission.rewardCoins : 0;
    const exp = (state.exp || 0) + PIECE_EXP + (justCompleted ? track.rewardExp : 0);
    const leveledUp = levelFromExp(exp).level > levelFromExp(state.exp || 0).level;

    return {
      ...state,
      coins: state.coins - item.price + completionCoins + bonusCoins,
      exp,
      collectedPieces: { ...state.collectedPieces, [track.id]: newPieces },
      unlockedTrackIds,
      dailyMission: { date: todayKey(), progress: missionProgress, claimed: dm.claimed || missionJustAchieved },
      puzzleCompleteTrackId: justCompleted ? track.id : state.puzzleCompleteTrackId,
      recentlyAddedTrackIds: unique([track.id, ...state.recentlyAddedTrackIds]).slice(0, 6),
      toast: [
        justCompleted
          ? `🎲 ${track.artistName} のピースを獲得 → 🎉 パズル完成！`
          : `🎲 ${state.unlockedTrackIds.includes(track.id) ? track.title : track.artistName} のピースを獲得しました`,
        justCompleted ? `🪙 完成報酬 メロディコイン +${completionCoins}` : "",
        missionJustAchieved ? `🎉 デイリーミッション達成！メロディコイン +${bonusCoins}` : "",
        leveledUp ? `⬆️ レベルアップ！ Lv.${levelFromExp(exp).level} になりました` : "",
      ].filter(Boolean).join("\n"),
    };
  }

  // ─── アバター装飾の装備切り替え（同じ装飾を再選択で外す） ──────
  if (action.type === "EQUIP_DECORATION") {
    if (!(state.ownedDecorations || []).includes(action.itemId)) return state;
    return {
      ...state,
      equippedDecoration: state.equippedDecoration === action.itemId ? null : action.itemId,
    };
  }

  // ─── 通知設定（トグル・まとめ通知の時間帯） ──────
  if (action.type === "TOGGLE_NOTIFICATION") {
    const ns = state.notificationSettings || initialAppState().notificationSettings;
    return { ...state, notificationSettings: { ...ns, [action.key]: !ns[action.key] } };
  }

  if (action.type === "SET_DIGEST_TIME") {
    const ns = state.notificationSettings || initialAppState().notificationSettings;
    return { ...state, notificationSettings: { ...ns, digestTime: action.value } };
  }

  // ─── バックグラウンド検知設定（トグル・スキャン頻度） ──────
  if (action.type === "TOGGLE_BG_SCAN") {
    const bg = state.backgroundScan || initialAppState().backgroundScan;
    return { ...state, backgroundScan: { ...bg, [action.key]: !bg[action.key] } };
  }

  if (action.type === "SET_BG_SCAN_MODE") {
    const bg = state.backgroundScan || initialAppState().backgroundScan;
    return { ...state, backgroundScan: { ...bg, mode: action.value } };
  }

  // ─── 音楽サービス連携（模擬・トグル） ──────
  if (action.type === "TOGGLE_SERVICE_LINK") {
    const ls = state.linkedServices || initialAppState().linkedServices;
    const next = !ls[action.service];
    const names = { spotify: "Spotify", appleMusic: "Apple Music", youtubeMusic: "YouTube Music" };
    return {
      ...state,
      linkedServices: { ...ls, [action.service]: next },
      toast: next
        ? `🎵 ${names[action.service]} と連携しました（プロトタイプ・模擬連携）`
        : `${names[action.service]} との連携を解除しました`,
    };
  }

  // ─── プレミアムプラン加入/解約（プロトタイプ・模擬決済） ──────
  if (action.type === "SET_PREMIUM") {
    if (action.value === state.premium) return state;
    // 解約時、推し曲が無料上限を超えていれば先頭から無料枠分だけ残す
    const oshiTrackIds = action.value
      ? state.oshiTrackIds
      : (state.oshiTrackIds || []).slice(0, oshiLimit({ premium: false }));
    return {
      ...state,
      premium: action.value,
      oshiTrackIds,
      toast: action.value
        ? "🎉 プレミアムプランに加入しました（プロトタイプ・模擬決済）"
        : "プレミアムプランを解約しました",
    };
  }

  // ─── 認証状態（undefined=確認中 / null=未ログイン / object=ログイン済み） ───
  if (action.type === "SET_AUTH") {
    return { ...state, authUser: action.user };
  }

  // ─── ログイン時: ローカル⇄Supabaseのマージ結果を反映 ───
  if (action.type === "MERGE_REMOTE_STATE") {
    const d = action.data;
    const nextEncounterId = nextAvailableEncounter(d.encounterCooldowns);
    return {
      ...state,
      collectedPieces: d.collectedPieces,
      unlockedTrackIds: d.unlockedTrackIds,
      friends: d.friends,
      encounterCooldowns: d.encounterCooldowns,
      coins: d.coins,
      activeEncounterId: nextEncounterId || state.activeEncounterId,
    };
  }

  if (action.type === "SHOW_TOAST") {
    return { ...state, toast: action.message };
  }

  if (action.type === "CLEAR_TOAST") {
    return { ...state, toast: null };
  }

  return state;
}

export function createStore() {
  let state = loadState();
  const subscribers = new Set();

  return {
    getState() { return state; },
    dispatch(action) {
      const titlesBefore = unlockedTitleIds(state);
      state = nextState(state, action);
      // 新規に達成した称号を検知 → 常設リワード付与 + 獲得演出キュー + トースト追記
      const gained = unlockedTitleIds(state).filter((id) => !titlesBefore.includes(id));
      if (gained.length > 0) {
        const titles = gained.map((id) => seedData.titles.find((t) => t.id === id));
        const rewardCoins = titles.reduce((n, t) => n + (t.rewardCoins || 0), 0);
        const rewardExp = titles.reduce((n, t) => n + (t.rewardExp || 0), 0);
        const exp = (state.exp || 0) + rewardExp;
        const leveledUp = levelFromExp(exp).level > levelFromExp(state.exp || 0).level;
        const lines = titles.map((t) => `🏆 称号「${t.name}」を獲得！（🪙+${t.rewardCoins} ⭐+${t.rewardExp} EXP）`);
        if (leveledUp) lines.push(`⬆️ レベルアップ！ Lv.${levelFromExp(exp).level} になりました`);
        state = {
          ...state,
          coins: state.coins + rewardCoins,
          exp,
          pendingTitleCelebrations: [...(state.pendingTitleCelebrations || []), ...gained],
          toast: [state.toast, ...lines].filter(Boolean).join("\n"),
        };
      }
      saveState(state);
      subscribers.forEach((fn) => fn(state, action));
    },
    subscribe(fn) {
      subscribers.add(fn);
      return () => subscribers.delete(fn);
    },
  };
}
