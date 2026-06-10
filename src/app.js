import { ASSETS, formatNumber, maskForTrack, seedData } from "./data.js";
import { createStore } from "./store.js";

const store = createStore();

/* ─── Selectors ─────────────────────────────── */

function getTrack(id) { return seedData.tracks[id]; }
function getSelectedTrack(state) { return getTrack(state.selectedTrackId); }
function getOwnedPieces(state, trackId) { return state.collectedPieces[trackId] || []; }
function isUnlocked(state, trackId) { return state.unlockedTrackIds.includes(trackId); }

/* ─── Partials ───────────────────────────────── */

function coinPill(amount) {
  return `<div class="coin-pill">
    <img src="${ASSETS.coin}" alt="">
    ${formatNumber(amount)}
  </div>`;
}

function artBlock(color = "", src = "") {
  if (src) return `<div class="art-block ${color}"><img src="${src}" alt=""></div>`;
  return `<div class="art-block ${color}"></div>`;
}

function screenHeader(title, sub = "", right = "") {
  return `
    <div class="screen-header">
      <button class="icon-button" data-back="home" type="button" aria-label="戻る">‹</button>
      <div class="screen-title">
        <h1>${title}</h1>
        ${sub ? `<p>${sub}</p>` : ""}
      </div>
      ${right ? right : `<div class="header-spacer"></div>`}
    </div>`;
}

function pct(current, total) {
  return total > 0 ? Math.round((current / total) * 100) : 0;
}

function trackLabel(state, track) {
  if (isUnlocked(state, track.id)) return `${track.artistName} / ${track.title}`;
  return maskForTrack(track, state.hintLevels[track.id] || 0);
}

function maskedDisplay(state, track) {
  return trackLabel(state, track);
}

/* ─── Toast ─────────────────────────────────── */

function renderToast(state) {
  const root = document.querySelector("#toast-root");
  if (root) root.innerHTML = state.toast
    ? `<div class="toast" role="status">${state.toast}</div>` : "";
}

/* ─── Home ───────────────────────────────────── */

function computeCollection(state) {
  const allTracks = Object.values(seedData.tracks);
  const completedPuzzles = allTracks.filter(
    (t) => getOwnedPieces(state, t.id).length >= t.pieceCount
  ).length;
  const allArtists = Object.values(seedData.artists);
  const completedArtists = allArtists.filter(
    (a) => a.completedTrackPuzzles >= a.totalTrackPuzzles
  ).length;
  const playlists = 1 + (state.listenLaterTrackIds.length > 0 ? 1 : 0);
  return { completedPuzzles, totalPuzzles: allTracks.length, completedArtists, totalArtists: allArtists.length, playlists };
}

function renderHome(state) {
  const { user, mission, dailyPlaylist } = seedData;

  const heroTrackId = dailyPlaylist.trackIds[0];
  const heroTrack = getTrack(heroTrackId);
  const heroOwned = heroTrack ? getOwnedPieces(state, heroTrackId) : [];
  const heroTotal = heroTrack ? heroTrack.pieceCount : 0;
  const heroRemaining = Math.max(heroTotal - heroOwned.length, 0);

  const col = computeCollection(state);

  document.querySelector("#home-screen").innerHTML = `
    <div class="home-header">
      <img class="avatar" src="${ASSETS.mascot}" alt="${user.name}のアバター">
      <div class="home-user">
        <h1>${user.name}</h1>
        <p>Lv.${user.level}</p>
        <div class="progress"><span style="--progress:${user.levelProgress}%"></span></div>
      </div>
      ${coinPill(state.coins || 0)}
    </div>

    <div class="hero-panel">
      <div class="art-block hero-art ${heroTrack?.color ?? ""}">
        <img src="${ASSETS.cover}" alt="">
      </div>
      <div class="hero-content">
        <p class="eyebrow">今日のメロディ</p>
        <h2>${heroTrack ? (isUnlocked(state, heroTrackId) ? heroTrack.title : "未解放メロディ") : "—"}</h2>
        <div class="piece-meter">
          <strong>${heroOwned.length} / ${heroTotal}</strong>
          <span>ピース</span>
        </div>
        <div class="progress"><span style="--progress:${pct(heroOwned.length, heroTotal)}%"></span></div>
        ${heroRemaining > 0 ? `<p>あと${heroRemaining}ピースで完成！</p>` : `<p>完成！</p>`}
        <button class="btn primary" data-target="exchange" type="button">📍 近距離交換をはじめる</button>
      </div>
    </div>

    <div class="section-block">
      <div class="section-heading">
        <h2>コレクション</h2>
      </div>
      <div class="stat-grid">
        <div class="stat-tile">
          <span>曲パズル</span>
          <strong>${col.completedPuzzles} / ${col.totalPuzzles}</strong>
        </div>
        <div class="stat-tile">
          <span>アーティスト</span>
          <strong>${col.completedArtists} / ${col.totalArtists}</strong>
        </div>
        <div class="stat-tile">
          <span>プレイリスト</span>
          <strong>${col.playlists}</strong>
        </div>
      </div>
    </div>

    <div class="mission-panel">
      <h2>${mission.label}ミッション</h2>
      <strong>${mission.current} / ${mission.target}</strong>
      <div class="progress"><span style="--progress:${pct(mission.current, mission.target)}%"></span></div>
    </div>

    <div class="section-block">
      <div class="section-heading">
        <h2>最近追加した曲</h2>
        <button class="link-button" data-target="playlist" type="button">すべて見る</button>
      </div>
      <div class="song-grid">
        ${state.recentlyAddedTrackIds.slice(0, 3).map(getTrack).filter(Boolean).map((track) => `
          <button class="song-tile" data-open-track="${track.id}" type="button">
            ${artBlock(track.color)}
            <strong>${isUnlocked(state, track.id) ? track.title : "未解放メロディ"}</strong>
            <span>${track.artistName}</span>
          </button>
        `).join("")}
      </div>
    </div>
  `;
}

/* ─── Exchange ───────────────────────────────── */

function renderExchange(state) {
  const encounter = seedData.encounters[state.activeEncounterId];
  const remaining = Math.max(0, encounter.expiresInSeconds);
  const timerLabel = `残り時間 00:${String(remaining).padStart(2, "0")}`;
  const sel = state.selectedCandidateIndex ?? -1;

  document.querySelector("#exchange-screen").innerHTML = `
    ${screenHeader("ピースを選ぼう", "気になるピースを1つ選んでください",
      `<div class="timer-pill">${timerLabel}</div>`)}

    <div class="reward-strip">
      <img src="${ASSETS.coin}" alt="">
      この交換で手に入るもの
      <strong>メロディコイン ×${encounter.rewardCoins}</strong>
    </div>

    <div class="candidate-list">
      ${encounter.candidates.map((c, i) => {
        const track = getTrack(c.trackId);
        return `
          <div class="candidate-card${sel === i ? " selected" : ""}" data-select-piece="${i}">
            <span class="candidate-number">${i + 1}</span>
            <div class="art-block ${track.color}">
              <button class="play-dot" data-preview-track="${track.id}" type="button" aria-label="試聴">▶</button>
            </div>
            <div class="candidate-main">${trackLabel(state, track)}</div>
            <div class="candidate-meta">${c.rarity} · ${c.sourceSlot}</div>
          </div>`;
      }).join("")}
    </div>

    <div class="screen-action">
      ${sel >= 0
        ? `<button class="btn primary" data-confirm-piece="${sel}" type="button">このピースを選ぶ</button>`
        : `<button class="btn" type="button" disabled>ピースを選んでください</button>`}
    </div>
  `;
}

/* ─── Mystery ────────────────────────────────── */

function renderMystery(state) {
  const track = getSelectedTrack(state);
  const hintLevel = state.hintLevels[track.id] || 0;
  const answerReady = state.answerReadyTrackIds.includes(track.id);
  const showChoices = hintLevel >= 2;

  document.querySelector("#mystery-screen").innerHTML = `
    ${screenHeader("未解放メロディ", "ヒントを使ってこの曲の名前を当てよう！",
      `<button class="text-pill" data-target="home" type="button">あとで確認</button>`)}

    <div class="mystery-hero">
      <div class="mystery-art">
        <div class="art-block ${track.color}" style="aspect-ratio:1;border-radius:26px;"></div>
        <div class="lock-mark">🔒</div>
        <button class="play-fab" data-preview-track="${track.id}" type="button" aria-label="試聴">▶</button>
      </div>
      <h2>${maskedDisplay(state, track)}</h2>
      <p>未解放メロディ</p>
    </div>

    <div class="section-block">
      <div class="action-stack">
        <button class="btn pink" data-guess-track="${track.id}" type="button">曲名を当てる</button>
        <button class="btn secondary" data-ad="hint1" type="button">1つ目のヒントを見る 🎫×1</button>
        <button class="btn secondary" data-ad="hint2" type="button">2つ目のヒントを見る 🎫×1</button>
        <button class="btn coin" data-ad="answer" type="button">答えを見る CM×1</button>
      </div>
      ${showChoices ? `
        <div class="section-heading" style="margin-top:16px;">
          <h2>4択ヒント</h2>
        </div>
        <div class="choice-grid">
          ${(track.choices || []).map((c) => `<button type="button">${c}</button>`).join("")}
        </div>` : ""}
    </div>

    <div class="youtube-panel">
      <div class="youtube-icon">▶</div>
      <div>
        <strong>YouTubeで見て確認</strong>
        <p>${answerReady ? "曲名とアーティスト名を解放します" : "公式MVまたは公式リリックビデオを確認"}</p>
      </div>
      ${answerReady
        ? `<button class="btn primary btn small" data-unlock-track="${track.id}" type="button">確認する</button>`
        : `<button class="btn coin btn small" data-ad="answer" type="button">CM</button>`}
    </div>
  `;
}

/* ─── Puzzle ─────────────────────────────────── */

function renderPuzzle(state) {
  const track = getSelectedTrack(state);
  const owned = getOwnedPieces(state, track.id);
  const isLiked = state.listenLaterTrackIds.includes(track.id);

  document.querySelector("#puzzle-screen").innerHTML = `
    ${screenHeader(track.title, track.artistName,
      `<button class="icon-button" data-listen-later="${track.id}" type="button">${isLiked ? "❤️" : "🤍"}</button>`)}

    <div class="puzzle-summary">
      <div class="art-block summary-art ${track.color}">
        <img src="${track.thumbnailUrl}" alt="${track.title}">
      </div>
      <div>
        <p>曲パズル</p>
        <div class="piece-meter compact">
          <strong>${owned.length} / ${track.pieceCount}</strong>
          <span>ピース</span>
        </div>
        <div class="progress"><span style="--progress:${pct(owned.length, track.pieceCount)}%"></span></div>
        <p style="margin-top:6px;">あと${Math.max(track.pieceCount - owned.length, 0)}ピースで完成！</p>
      </div>
    </div>

    <div class="section-block">
      <div class="section-heading"><h2>所持ピース</h2></div>
      <div class="piece-grid">
        ${Array.from({ length: track.pieceCount }, (_, i) => {
          const n = i + 1;
          const has = owned.includes(n);
          return `<div class="piece-cell${has ? " owned" : ""}" aria-label="ピース${n}">
            ${has ? `<img src="${ASSETS.puzzle}" alt="" style="width:60%;opacity:.9">` : n}
          </div>`;
        }).join("")}
      </div>
    </div>

    <div class="section-block">
      <div class="section-heading"><h2>完成で手に入る報酬</h2></div>
      <div class="reward-grid">
        <div>
          <span>メロディコイン</span>
          <strong>×${track.rewardCoins}</strong>
        </div>
        <div>
          <span>経験値</span>
          <strong>×${track.rewardExp}</strong>
        </div>
      </div>
      <button class="btn primary full" data-target="exchange" type="button">ピース一覧を見る</button>
    </div>
  `;
}

/* ─── Artist ─────────────────────────────────── */

function renderArtist(state) {
  const artist = seedData.artists.artist_yoasobi;
  const tracks = ["track_yoru", "track_halzion", "track_sunset_drive", "track_anytime"].map(getTrack);
  const remaining = artist.totalTrackPuzzles - artist.completedTrackPuzzles;

  document.querySelector("#artist-screen").innerHTML = `
    ${screenHeader(artist.name, "アーティストページ",
      `<button class="icon-button" type="button">…</button>`)}

    <div class="artist-profile">
      <img src="${ASSETS.artist}" alt="${artist.name}">
      <div>
        <h2>${artist.name}</h2>
        <p>曲パズル完成数</p>
        <div class="piece-meter compact" style="margin-top:6px;">
          <strong>${artist.completedTrackPuzzles} / ${artist.totalTrackPuzzles}</strong>
          <span>完成</span>
        </div>
        <div class="progress"><span style="--progress:${pct(artist.completedTrackPuzzles, artist.totalTrackPuzzles)}%"></span></div>
      </div>
    </div>

    <div class="section-block">
      <div class="section-heading">
        <h2>曲パズル一覧</h2>
        <span>新しい順</span>
      </div>
      <div class="artist-track-grid">
        ${tracks.map((track) => {
          const owned = getOwnedPieces(state, track.id);
          const done = owned.length >= track.pieceCount;
          const locked = !isUnlocked(state, track.id) && owned.length === 0;
          const sub = done ? "完成!" : locked ? "未入手" : `あと${track.pieceCount - owned.length}`;
          return `
            <button class="song-tile" data-open-track="${track.id}" type="button">
              ${artBlock(track.color)}
              <strong>${isUnlocked(state, track.id) ? track.title : "未解放"}</strong>
              <span>${sub}</span>
            </button>`;
        }).join("")}
      </div>
    </div>

    <div class="notice-panel">
      <span style="background:#ff4060;font-size:10px;">NEW</span>
      <div>
        <strong>新しい曲が追加されました！</strong>
        <p>祝福</p>
      </div>
      <button class="btn primary btn small" data-target="exchange" type="button">集める</button>
    </div>

    <div class="section-block" style="text-align:center;padding:14px;">
      <p>アーティストパズルはあと
        <strong style="font-size:18px;color:var(--primary);">${remaining}</strong>
        曲で獲得できます！
      </p>
    </div>
  `;
}

/* ─── Playlist ───────────────────────────────── */

function renderPlaylist(state) {
  const playlist = seedData.dailyPlaylist;
  const tracks = playlist.trackIds.map(getTrack);

  document.querySelector("#playlist-screen").innerHTML = `
    ${screenHeader(playlist.title, playlist.dateLabel,
      `<button class="btn primary btn small" type="button">▶ 再生</button>`)}

    <div class="track-list">
      ${tracks.map((track) => `
        <div class="track-row">
          <div class="play-icon">▶</div>
          <div>
            <strong>${track.title}</strong>
            <p>${track.artistName} · ${track.status}</p>
          </div>
          <button class="btn secondary btn small" data-listen-later="${track.id}" type="button">
            ${state.listenLaterTrackIds.includes(track.id) ? "保存済み" : "あとで"}
          </button>
        </div>
      `).join("")}
    </div>

    <div class="notice-panel">
      <span>🎵</span>
      <div>
        <strong>今日の出会い</strong>
        <p>新アーティスト ${tracks.length}組と音楽でつながりました</p>
      </div>
      <button class="btn primary btn small" data-target="exchange" type="button">確認</button>
    </div>
  `;
}

/* ─── Modal ──────────────────────────────────── */

function renderModal(state) {
  const modal = document.querySelector("#modal");
  const titleEl = document.querySelector("#modal-title");
  const bodyEl = document.querySelector("#modal-body");
  const rewardEl = document.querySelector("#modal-reward-text");

  const CONTENT = {
    hint1:  ["広告を視聴してヒントを解放しますか？", "視聴すると以下の内容を解放できます。", "1つ目のヒントを見る"],
    hint2:  ["広告を視聴してヒントを解放しますか？", "視聴すると以下の内容を解放できます。", "2つ目のヒントを見る"],
    answer: ["広告を視聴してヒントを解放しますか？", "視聴すると以下の内容を解放できます。", "答えを見る"],
  };
  const content = CONTENT[state.selectedAdKind];

  if (!content) {
    modal.classList.remove("open");
    modal.setAttribute("aria-hidden", "true");
    return;
  }
  titleEl.textContent = content[0];
  bodyEl.textContent  = content[1];
  rewardEl.textContent = content[2];
  modal.dataset.kind = state.selectedAdKind;
  modal.classList.add("open");
  modal.setAttribute("aria-hidden", "false");
}

/* ─── Render all ─────────────────────────────── */

function renderAll() {
  const state = store.getState();
  renderHome(state);
  renderExchange(state);
  renderMystery(state);
  renderPuzzle(state);
  renderArtist(state);
  renderPlaylist(state);
  renderModal(state);
  renderToast(state);

  document.querySelectorAll(".screen").forEach((s) =>
    s.classList.toggle("active", s.dataset.screen === state.activeScreen));
  document.querySelectorAll(".nav-item").forEach((item) =>
    item.classList.toggle("active", item.dataset.target === state.activeScreen));
}

/* ─── Helpers ────────────────────────────────── */

function normalize(v) {
  return v.toLowerCase()
    .replace(/[Ａ-Ｚａ-ｚ０-９]/g, (c) => String.fromCharCode(c.charCodeAt(0) - 0xfee0))
    .replace(/[^\p{Letter}\p{Number}]/gu, "");
}

function handleGuess(track) {
  const ans = window.prompt("曲名を入力してください");
  if (!ans) return;
  if (normalize(ans) === normalize(track.title)) {
    store.dispatch({ type: "UNLOCK_TRACK" });
  } else {
    window.alert("まだ違うようです。ヒントや試聴を使ってもう一度試してください。");
  }
}

/* ─── Event delegation ───────────────────────── */

document.addEventListener("click", (e) => {
  const t = (sel) => e.target.closest(sel);

  if (t("[data-target]"))       return store.dispatch({ type: "NAVIGATE", screen: t("[data-target]").dataset.target });
  if (t("[data-back]"))         return store.dispatch({ type: "NAVIGATE", screen: t("[data-back]").dataset.back });
  if (t("[data-open-track]"))   return store.dispatch({ type: "OPEN_TRACK", trackId: t("[data-open-track]").dataset.openTrack });

  if (t("[data-select-piece]")) {
    e.stopPropagation();
    return store.dispatch({ type: "SELECT_CANDIDATE_PREVIEW", index: Number(t("[data-select-piece]").dataset.selectPiece) });
  }
  if (t("[data-confirm-piece]")) return store.dispatch({ type: "SELECT_CANDIDATE", index: Number(t("[data-confirm-piece]").dataset.confirmPiece) });

  if (t("[data-preview-track]")) {
    e.stopPropagation();
    const track = getTrack(t("[data-preview-track]").dataset.previewTrack);
    const s = store.getState();
    window.alert(isUnlocked(s, track.id)
      ? `${track.artistName} / ${track.title} を少し再生します` : "未解放メロディを少し再生します");
    return;
  }

  if (t("[data-guess-track]"))    return handleGuess(getTrack(t("[data-guess-track]").dataset.guessTrack));
  if (t("[data-listen-later]"))   return store.dispatch({ type: "ADD_LISTEN_LATER", trackId: t("[data-listen-later]").dataset.listenLater });
  if (t("[data-unlock-track]"))   return store.dispatch({ type: "UNLOCK_TRACK" });
  if (t("[data-ad]"))             return store.dispatch({ type: "OPEN_AD_MODAL", kind: t("[data-ad]").dataset.ad });
});

document.querySelector("#close-modal").addEventListener("click",   () => store.dispatch({ type: "CLOSE_AD_MODAL" }));
document.querySelector("#cancel-modal").addEventListener("click",   () => store.dispatch({ type: "CLOSE_AD_MODAL" }));
document.querySelector("#confirm-modal").addEventListener("click",  () => {
  store.dispatch({ type: "COMPLETE_AD", kind: store.getState().selectedAdKind });
});

store.subscribe(renderAll);
renderAll();
