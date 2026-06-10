import { initialAppState, seedData } from "./data.js";

const STORAGE_KEY = "melodylien.appState.v1";

function loadState() {
  try {
    const saved = JSON.parse(localStorage.getItem(STORAGE_KEY) || "null");
    return saved ? { ...initialAppState(), ...saved, selectedCandidateIndex: -1 } : initialAppState();
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
  }));
}

function unique(values) {
  return [...new Set(values)];
}

function nextState(state, action) {
  if (action.type === "NAVIGATE") {
    return { ...state, activeScreen: action.screen, toast: null };
  }

  if (action.type === "SELECT_CANDIDATE_PREVIEW") {
    return { ...state, selectedCandidateIndex: action.index };
  }

  if (action.type === "SELECT_CANDIDATE") {
    const encounter = seedData.encounters[state.activeEncounterId];
    const candidate = encounter.candidates[action.index];
    const track = seedData.tracks[candidate.trackId];
    const currentPieces = state.collectedPieces[track.id] || [];
    const alreadyOwned = currentPieces.includes(candidate.pieceNumber);
    const isPuzzleComplete = currentPieces.length >= track.pieceCount;
    const collectedPieces = {
      ...state.collectedPieces,
      [track.id]: alreadyOwned ? currentPieces : unique([...currentPieces, candidate.pieceNumber]).sort((a, b) => a - b),
    };
    const coinDelta = alreadyOwned ? 0 : isPuzzleComplete ? 3 : 1;
    const nextScreen = state.unlockedTrackIds.includes(track.id) ? "puzzle" : "mystery";
    const toastMsg = alreadyOwned
      ? "所持済みのため進行状況は変わりません"
      : isPuzzleComplete
        ? `${track.title} のピースを獲得しました（+3コイン）`
        : `${track.title} のピースを獲得しました（+1コイン）`;
    return {
      ...state,
      activeScreen: nextScreen,
      selectedTrackId: track.id,
      selectedCandidateIndex: -1,
      collectedPieces,
      coins: (state.coins || 0) + coinDelta,
      recentlyAddedTrackIds: unique([track.id, ...state.recentlyAddedTrackIds]).slice(0, 6),
      toast: toastMsg,
    };
  }

  if (action.type === "OPEN_TRACK") {
    const nextScreen = state.unlockedTrackIds.includes(action.trackId) ? "puzzle" : "mystery";
    return { ...state, selectedTrackId: action.trackId, activeScreen: nextScreen, toast: null };
  }

  if (action.type === "OPEN_AD_MODAL") {
    return { ...state, selectedAdKind: action.kind };
  }

  if (action.type === "CLOSE_AD_MODAL") {
    return { ...state, selectedAdKind: null };
  }

  if (action.type === "COMPLETE_AD") {
    const trackId = state.selectedTrackId;
    const currentLevel = state.hintLevels[trackId] || 0;
    const nextLevel = action.kind === "hint1" ? Math.max(currentLevel, 1) : Math.max(currentLevel, 2);
    const answerReadyTrackIds = action.kind === "answer" ? unique([...state.answerReadyTrackIds, trackId]) : state.answerReadyTrackIds;
    return {
      ...state,
      activeScreen: "mystery",
      selectedAdKind: null,
      hintLevels: { ...state.hintLevels, [trackId]: nextLevel },
      answerReadyTrackIds,
      toast: action.kind === "answer" ? "YouTube確認リンクを表示しました" : "ヒントを解放しました",
    };
  }

  if (action.type === "UNLOCK_TRACK") {
    const track = seedData.tracks[state.selectedTrackId];
    return {
      ...state,
      activeScreen: "puzzle",
      unlockedTrackIds: unique([...state.unlockedTrackIds, state.selectedTrackId]),
      toast: `${track.artistName} / ${track.title} を解放しました`,
    };
  }

  if (action.type === "ADD_LISTEN_LATER") {
    const track = seedData.tracks[action.trackId];
    return {
      ...state,
      listenLaterTrackIds: unique([action.trackId, ...state.listenLaterTrackIds]),
      toast: `${track.title} をあとで聴くに追加しました`,
    };
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
    getState() {
      return state;
    },
    dispatch(action) {
      state = nextState(state, action);
      saveState(state);
      subscribers.forEach((subscriber) => subscriber(state, action));
    },
    subscribe(subscriber) {
      subscribers.add(subscriber);
      return () => subscribers.delete(subscriber);
    },
  };
}
