import { initialAppState, seedData } from "./data.js";

/** 次の未確認出会いID（全確認済みなら null） */
function nextUnvisitedEncounter(cooldowns) {
  return seedData.encounterOrder.find((id) => !cooldowns[id]) || null;
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
    pendingFriendAdd: state.pendingFriendAdd,
    previewPlays: state.previewPlays,
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
    // パズル完成判定: 今回のピースで初めて揃った
    const justCompleted = !wasPreviouslyComplete && newPieces.length >= track.pieceCount;
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

    // 同じ出会い相手に対してクールタイム 6時間を設定
    const encounterId = state.activeEncounterId;
    const encounterCooldowns = { ...state.encounterCooldowns, [encounterId]: Date.now() };

    // 次の未確認出会いへ自動前進
    const nextEncounterId = nextUnvisitedEncounter(encounterCooldowns);
    const activeEncounterId = nextEncounterId || state.activeEncounterId;

    // フレンド申請プロンプト（既にフレンドでなければ）
    const currentEncounter = seedData.encounters[encounterId];
    const alreadyFriend = (state.friends || []).some((f) => f.userId === currentEncounter.fromUserId);
    const pendingFriendAdd = alreadyFriend ? state.pendingFriendAdd : {
      userId: currentEncounter.fromUserId,
      userName: currentEncounter.fromUserName,
    };

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
      coins: state.coins + earnedCoins,
      recentlyAddedTrackIds: unique([track.id, ...state.recentlyAddedTrackIds]).slice(0, 6),
      encounterCooldowns,
      puzzleCompleteTrackId: justCompleted ? track.id : state.puzzleCompleteTrackId,
      pendingFriendAdd,
      toast: toastMsg,
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
    return {
      ...state,
      activeScreen: "mystery",
      selectedAdKind: null,
      hintLevels: { ...state.hintLevels, [trackId]: nextLevel },
      answerReadyTrackIds,
      toast: action.kind === "answer" ? "YouTube確認リンクを表示しました" : "ヒントを解放しました",
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

  // ─── 認証状態（undefined=確認中 / null=未ログイン / object=ログイン済み） ───
  if (action.type === "SET_AUTH") {
    return { ...state, authUser: action.user };
  }

  // ─── ログイン時: ローカル⇄Supabaseのマージ結果を反映 ───
  if (action.type === "MERGE_REMOTE_STATE") {
    const d = action.data;
    const nextEncounterId = nextUnvisitedEncounter(d.encounterCooldowns);
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
      state = nextState(state, action);
      saveState(state);
      subscribers.forEach((fn) => fn(state, action));
    },
    subscribe(fn) {
      subscribers.add(fn);
      return () => subscribers.delete(fn);
    },
  };
}
