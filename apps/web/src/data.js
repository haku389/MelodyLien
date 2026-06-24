// すれちがいクールタイム（再訪問可能になるまでの時間）
export const COOLDOWN_MS = 6 * 60 * 60 * 1000;

// 推し曲の設定上限（無料プラン / プレミアムプラン）
export const OSHI_LIMIT = 3;
export const OSHI_LIMIT_PREMIUM = 5;

/** 現在のプランでの推し曲上限 */
export function oshiLimit(state) {
  return state.premium ? OSHI_LIMIT_PREMIUM : OSHI_LIMIT;
}

// プレミアムプラン（プロトタイプ用の表示価格）
export const PREMIUM_PRICE_LABEL = "¥480 / 月";

// ショップ商品（メロディコインの使い道）
// type: ticket=ヒントチケット / piece=ランダムピース / decoration=アバター装飾（買い切り・装備可）
export const SHOP_ITEMS = [
  { id: "shop_hint_ticket",  icon: "🎟️", name: "ヒントチケット",   desc: "広告なしでヒントを1回解放できます",             price: 15,  type: "ticket" },
  { id: "shop_random_piece", icon: "🎲", name: "ランダムピース",   desc: "未完成のパズルからランダムで1ピース獲得します", price: 20,  type: "piece" },
  { id: "shop_deco_hat",     icon: "🎩", name: "シルクハット",     desc: "アバターに装備できる装飾です",                   price: 50,  type: "decoration" },
  { id: "shop_deco_ribbon",  icon: "🎀", name: "リボン",           desc: "アバターに装備できる装飾です",                   price: 50,  type: "decoration" },
  { id: "shop_deco_crown",   icon: "👑", name: "クラウン",         desc: "アバターに装備できる装飾です",                   price: 100, type: "decoration" },
];

// 新規ピース1枚あたりの獲得経験値（パズル完成時は track.rewardExp を追加）
export const PIECE_EXP = 5;

/** 累計経験値からレベルを算出（Lv.L → L+1 へは L×100 exp 必要） */
export function levelFromExp(exp) {
  let level = 1;
  let rest = Math.max(exp || 0, 0);
  while (rest >= level * 100) {
    rest -= level * 100;
    level += 1;
  }
  return { level, current: rest, next: level * 100 };
}

export const ASSETS = {
  mascot: "./assets/mascot.svg",
  coin: "./assets/melody-coin.svg",
  puzzle: "./assets/puzzle-piece.svg",
  cover: "./assets/puzzle-cover.svg",
  artist: "./assets/artist-yoasobi.svg",
};

// パズルアセットのベースURL
export const PUZZLE_ASSETS = {
  // locked (未所持) は共通テンプレート
  lockedBase: "./assets/puzzles/locked/",
  // 曲ごとのディレクトリ（✓ = 本番YTサムネイル、★ = グリーンバック仮画像）
  tracks: {
    track_pretender:    "./assets/puzzles/pretender/",          // ✓ 本番 TQ8WlA2GXbk
    track_lemon:        "./assets/puzzles/track_lemon/",        // ✓ 本番 SX_ViT4Ra7k
    track_yoru:         "./assets/puzzles/track_yoru/",         // ✓ 本番 x8VYWazR5mE
    track_show:         "./assets/puzzles/track_show/",         // ✓ 本番 pgXpM4l_MwI
    track_kaiju:        "./assets/puzzles/track_kaiju/",        // ✓ 本番 UM9XNpgrqVk
    track_anytime:      "./assets/puzzles/track_anytime/",      // ✓ 本番 r105CzDvoo0
    track_blueberry:    "./assets/puzzles/track_blueberry/",    // ✓ 本番 Euf1-3WRino
    track_halzion:      "./assets/puzzles/track_halzion/",      // ✓ 本番 kzdJkT4kp-A
  },
};

/** ピース画像URL取得 */
export function getPieceUrl(trackId, pieceNumber, owned) {
  const n = String(pieceNumber).padStart(2, "0");
  if (owned) {
    const dir = PUZZLE_ASSETS.tracks[trackId];
    if (dir) return `${dir}piece_${n}.png`;
  }
  return `${PUZZLE_ASSETS.lockedBase}piece_${n}.png`;
}

/** パズルプレビュー画像URL（カルーセル用） */
export function getPreviewUrl(trackId) {
  const dir = PUZZLE_ASSETS.tracks[trackId];
  return dir ? `${dir}preview.png` : null;
}

export const UI_TEXT = {
  levelPrefix: "Lv.",
  pieceUnit: "ピース",
  complete: "完成",
  notAcquired: "未入手",
  unreleasedMelody: "未解放メロディ",
  nowPlayingMystery: "未解放メロディを再生中",
  aria: {
    back: "戻る",
    candidateList: "ピース候補",
    preview: "少し聴く",
    listenLater: "あとで聴く",
    menu: "メニュー",
  },
  progressLabel: "レベル進行",
  templates: {
    remainingToComplete: ({ remaining, pieceUnit, complete }) => `あと${remaining}${pieceUnit}で${complete}！`,
    remainingShort: ({ remaining }) => `あと${remaining}`,
    playlistSubtitle: ({ dateLabel, locationLabel, connectedUsers }) => `${dateLabel}・${locationLabel}で${connectedUsers}人と音楽でつながりました`,
    encounterSummary: ({ newArtists, rareTracks, coinFallbacks }) => `新しいアーティスト${newArtists}組、レア曲${rareTracks}曲、コイン報酬${coinFallbacks}件`,
    previewUnlocked: ({ artistName, title }) => `${artistName} / ${title} を少し再生します`,
  },
  prompt: {
    guessTrack: "曲名を入力してください",
    wrongAnswer: "まだ違うようです。ヒントや試聴を使ってもう一度試してください。",
    previewLocked: "未解放メロディを少し再生します",
  },
  home: {
    todayMelody: "今日のメロディ",
    collection: "コレクション",
    trackPuzzles: "曲パズル",
    artists: "アーティスト",
    playlists: "プレイリスト",
    mission: "ミッション",
    recentTracks: "最近追加した曲",
    viewAll: "すべて見る",
    openDeliveredMelody: "届いたメロディを見る",
  },
  exchange: {
    title: "ピースを選ぼう",
    subtitle: "気になるピースを1つ選んでください",
    rewardLead: "この交換で手に入るもの",
    waitingSelection: "ピースを選んでください",
    confirmSelection: "このピースを選ぶ",
    preview: "少し聴く",
  },
  mystery: {
    title: "未解放メロディ",
    subtitle: "音とヒントで曲名を当てよう",
    later: "あとで",
    guess: "曲名を当てる",
    hint1: "1つ目のヒントを見る",
    hint2: "2つ目のヒントを見る",
    answer: "答えを見る",
    choices: "4択ヒント",
    youtube: "YouTubeで見て確認",
    youtubeReady: "確認すると曲名とアーティスト名を解放します",
    youtubeLocked: "広告視聴後に確認できます",
    confirm: "確認する",
    adShort: "CM",
  },
  puzzle: {
    title: "曲パズル",
    ownedPieces: "所持ピース",
    rewards: "完成報酬",
    coins: "メロディコイン",
    exp: "経験値",
    viewPieces: "ピース一覧を見る",
  },
  artist: {
    page: "アーティストページ",
    completedTracks: "曲パズル完成数",
    trackList: "曲パズル一覧",
    sortNewest: "新しい順",
    newTrack: "新しい曲が追加されました",
    collect: "集める",
  },
  playlist: {
    play: "再生",
    listenLater: "あとで",
    saved: "保存済み",
    todayEncounter: "今日の出会い",
    check: "確認",
  },
  modal: {
    hintTitle: "ヒントを解放",
    answerTitle: "答えを確認",
    hint1Body: "広告視聴で1つ目のヒントを解放できます。",
    hint2Body: "広告視聴で2つ目のヒントを解放できます。",
    answerBody: "広告視聴でYouTube確認を表示できます。",
    hint1Reward: "伏せ字の一部を表示",
    hint2Reward: "4択ヒントを表示",
    answerReward: "公式MV確認リンクを表示",
  },
};

export const seedData = {
  user: {
    id: "user_mia",
    name: "Mia",
    coins: 0,
  },
  collectionLabels: ["曲パズル", "アーティスト", "プレイリスト"],
  mission: {
    label: "デイリー",
    target: 5,
    rewardCoins: 10,
  },
  // pieceCount: 24（6列×4行）が仕様。所持ピースはプロトタイプ用サンプル値。
  tracks: {
    track_pretender: {
      id: "track_pretender",
      title: "Pretender",
      artistId: "artist_higedan",
      artistName: "Official髭男dism",
      pieceCount: 24,
      ownedPieces: [1,2,3,4,5,6,7,8,9,10,11,12],
      rewardCoins: 100,
      rewardExp: 50,
      color: "magic",
      isUnlocked: true,
      youtubeVideoId: "TQ8WlA2GXbk",
      chorusStart: 57,
      thumbnailUrl: "./assets/puzzles/pretender/preview.png",
    },
    track_lemon: {
      id: "track_lemon",
      title: "Lemon",
      artistId: "artist_yonezu",
      artistName: "米津玄師",
      pieceCount: 24,
      ownedPieces: [],
      rewardCoins: 100,
      rewardExp: 50,
      color: "violet",
      isUnlocked: false,
      youtubeVideoId: "SX_ViT4Ra7k",
      chorusStart: 68,
      thumbnailUrl: "./assets/puzzles/track_lemon/preview.png",
      titleMasks: ["?????", "Le??n", "Le?on"],
      choices: ["恋愛", "夏", "夜", "ドラマ"],
      tone: "やさしい余韻",
    },
    track_yoru: {
      id: "track_yoru",
      title: "夜に駆ける",
      artistId: "artist_yoasobi",
      artistName: "YOASOBI",
      pieceCount: 24,
      ownedPieces: [1,2,3,4,5,6,7,8],
      rewardCoins: 100,
      rewardExp: 50,
      color: "berry",
      isUnlocked: false,
      youtubeVideoId: "x8VYWazR5mE",
      chorusStart: 52,
      thumbnailUrl: "./assets/puzzles/track_yoru/preview.png",
      titleMasks: ["?????", "夜に??る", "夜に駆?る"],
      choices: ["夜", "疾走感", "小説", "出会い"],
      tone: "夜に聴きたい",
    },
    track_show: {
      id: "track_show",
      title: "唱",
      artistId: "artist_ado",
      artistName: "Ado",
      pieceCount: 24,
      ownedPieces: [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22],
      rewardCoins: 100,
      rewardExp: 50,
      color: "magic",
      isUnlocked: true,
      youtubeVideoId: "pgXpM4l_MwI",
      chorusStart: 44,
      thumbnailUrl: "./assets/puzzles/track_show/preview.png",
    },
    track_kaiju: {
      id: "track_kaiju",
      title: "怪獣の花唄",
      artistId: "artist_vaundy",
      artistName: "Vaundy",
      pieceCount: 24,
      ownedPieces: [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18],
      rewardCoins: 100,
      rewardExp: 50,
      color: "sunset",
      isUnlocked: true,
      youtubeVideoId: "UM9XNpgrqVk",
      chorusStart: 38,
      thumbnailUrl: "./assets/puzzles/track_kaiju/preview.png",
    },
    track_anytime: {
      id: "track_anytime",
      title: "Anytime Anywhere",
      artistId: "artist_milet",
      artistName: "milet",
      pieceCount: 24,
      ownedPieces: [],
      rewardCoins: 100,
      rewardExp: 50,
      color: "violet",
      isUnlocked: false,
      youtubeVideoId: "r105CzDvoo0",
      chorusStart: 58,
      thumbnailUrl: "./assets/puzzles/track_anytime/preview.png",
      titleMasks: ["????? ???????", "Any???? ???????", "Anytime ???????"],
      choices: ["透明感", "旅", "祈り", "エンディング"],
      tone: "透明感",
    },
    track_blueberry: {
      id: "track_blueberry",
      title: "ブルーベリー・ナイツ",
      artistId: "artist_macaroni",
      artistName: "マカロニえんぴつ",
      pieceCount: 24,
      ownedPieces: [1,2,3,4,5,6,7,8],
      rewardCoins: 100,
      rewardExp: 50,
      color: "berry",
      isUnlocked: true,
      youtubeVideoId: "Euf1-3WRino",
      chorusStart: 55,
      thumbnailUrl: "./assets/puzzles/track_blueberry/preview.png",
    },
    track_halzion: {
      id: "track_halzion",
      title: "ハルジオン",
      artistId: "artist_yoasobi",
      artistName: "YOASOBI",
      pieceCount: 24,
      ownedPieces: [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18],
      rewardCoins: 100,
      rewardExp: 50,
      color: "violet",
      isUnlocked: true,
      youtubeVideoId: "kzdJkT4kp-A",
      chorusStart: 62,
      thumbnailUrl: "./assets/puzzles/track_halzion/preview.png",
    },
  },
  // 称号定義（type: puzzles=完成曲数 / artists=全曲完成アーティスト数 / friends=フレンド数 / unlocks=曲名解放数 / mission=デイリーミッション達成）
  // target: "all" は全曲数を表す。rewardCoins / rewardExp は獲得時の常設リワード
  titles: [
    { id: "title_first_puzzle",  icon: "🧩", name: "はじめてのひとかけら", description: "曲パズルを1曲完成させる",             type: "puzzles", target: 1,     rewardCoins: 30,  rewardExp: 30 },
    { id: "title_three_puzzles", icon: "🎼", name: "メロディコレクター",   description: "曲パズルを3曲完成させる",             type: "puzzles", target: 3,     rewardCoins: 50,  rewardExp: 50 },
    { id: "title_all_puzzles",   icon: "👑", name: "パズルマエストロ",     description: "全曲のパズルを完成させる",            type: "puzzles", target: "all", rewardCoins: 200, rewardExp: 200 },
    { id: "title_first_artist",  icon: "🌟", name: "推しマスター",         description: "1組のアーティストの全曲を完成させる", type: "artists", target: 1,     rewardCoins: 100, rewardExp: 100 },
    { id: "title_first_friend",  icon: "🤝", name: "はじめてのフレンド",   description: "フレンドを1人つくる",                 type: "friends", target: 1,     rewardCoins: 30,  rewardExp: 30 },
    { id: "title_three_friends", icon: "🎶", name: "音楽の輪",             description: "フレンドを3人つくる",                 type: "friends", target: 3,     rewardCoins: 50,  rewardExp: 50 },
    { id: "title_unlock_five",   icon: "🔓", name: "名曲ハンター",         description: "曲名を5曲解放する",                   type: "unlocks", target: 5,     rewardCoins: 50,  rewardExp: 50 },
    { id: "title_daily_mission", icon: "📅", name: "今日のがんばり屋",     description: "デイリーミッションを達成する",        type: "mission", target: 1,     rewardCoins: 20,  rewardExp: 20 },
  ],
  encounters: {
    encounter_today_001: {
      id: "encounter_today_001",
      locationLabel: "大学",
      fromUserId: "user_tanaka_yuki",
      fromUserName: "田中ゆき",
      connectedUsers: 12,
      summary: { newArtists: 3, rareTracks: 1, coinFallbacks: 2 },
      candidates: [
        { trackId: "track_pretender", sourceSlot: "推し曲枠", availablePieces: [13,14,15,16,17,18,19,20,21,22,23,24], rarity: "★★★★★" },
        { trackId: "track_lemon",     sourceSlot: "発見枠",   availablePieces: [1,2,3,4,5,6,7,8,9,10,11,12],          rarity: "★★★★★" },
        { trackId: "track_yoru",      sourceSlot: "発見枠",   availablePieces: [9,10,11,12,13,14,15,16],               rarity: "★★★★★" },
        { trackId: "track_kaiju",     sourceSlot: "レア枠",   availablePieces: [19,20,21,22,23,24],                     rarity: "★★★★★" },
        { trackId: "track_anytime",   sourceSlot: "イベント", availablePieces: [1,2,3,4,5,6,7,8,9,10,11,12],           rarity: "★★★★★" },
      ],
    },
    encounter_today_002: {
      id: "encounter_today_002",
      locationLabel: "渋谷駅",
      fromUserId: "user_sato_kenji",
      fromUserName: "佐藤けんじ",
      connectedUsers: 34,
      summary: { newArtists: 2, rareTracks: 0, coinFallbacks: 1 },
      candidates: [
        { trackId: "track_yoru",      sourceSlot: "推し曲枠", availablePieces: [1,2,3,4,5,6,7,8,9,10,11,12],          rarity: "★★★★★" },
        { trackId: "track_blueberry", sourceSlot: "発見枠",   availablePieces: [5,6,7,8,9,10,11,12,13,14,15,16],       rarity: "★★★★" },
        { trackId: "track_pretender", sourceSlot: "発見枠",   availablePieces: [1,2,3,4,5,6,7,8],                      rarity: "★★★★★" },
      ],
    },
    encounter_today_003: {
      id: "encounter_today_003",
      locationLabel: "カフェ",
      fromUserId: "user_suzuki_aya",
      fromUserName: "鈴木あや",
      connectedUsers: 7,
      summary: { newArtists: 1, rareTracks: 1, coinFallbacks: 0 },
      candidates: [
        { trackId: "track_show",      sourceSlot: "推し曲枠", availablePieces: [1,2,3,4,5,6,7,8,9,10,11,12],          rarity: "★★★★★" },
        { trackId: "track_lemon",     sourceSlot: "発見枠",   availablePieces: [13,14,15,16,17,18,19,20],              rarity: "★★★★★" },
        { trackId: "track_anytime",   sourceSlot: "発見枠",   availablePieces: [13,14,15,16,17,18,19,20,21,22,23,24],  rarity: "★★★★★" },
        { trackId: "track_halzion",   sourceSlot: "レア枠",   availablePieces: [19,20,21,22,23,24],                    rarity: "★★★★★" },
      ],
    },
    encounter_today_004: {
      id: "encounter_today_004",
      locationLabel: "図書館",
      fromUserId: "user_yamada_taro",
      fromUserName: "山田たろう",
      connectedUsers: 5,
      summary: { newArtists: 2, rareTracks: 0, coinFallbacks: 3 },
      candidates: [
        { trackId: "track_halzion",   sourceSlot: "推し曲枠", availablePieces: [1,2,3,4,5,6,7,8,9,10,11,12],          rarity: "★★★★★" },
        { trackId: "track_kaiju",     sourceSlot: "発見枠",   availablePieces: [1,2,3,4,5,6,7,8,9,10,11,12],          rarity: "★★★★★" },
        { trackId: "track_blueberry", sourceSlot: "発見枠",   availablePieces: [17,18,19,20,21,22,23,24],              rarity: "★★★★" },
      ],
    },
    encounter_today_005: {
      id: "encounter_today_005",
      locationLabel: "コンビニ",
      fromUserId: "user_nakamura_mika",
      fromUserName: "中村みか",
      connectedUsers: 21,
      summary: { newArtists: 1, rareTracks: 1, coinFallbacks: 0 },
      candidates: [
        { trackId: "track_blueberry", sourceSlot: "推し曲枠", availablePieces: [1,2,3,4,5,6,7,8],                     rarity: "★★★★" },
        { trackId: "track_yoru",      sourceSlot: "レア枠",   availablePieces: [17,18,19,20,21,22,23,24],              rarity: "★★★★★" },
      ],
    },
  },
  // 出会い順序（メロディ画面で前後切り替えに使用）
  encounterOrder: [
    "encounter_today_001",
    "encounter_today_002",
    "encounter_today_003",
    "encounter_today_004",
    "encounter_today_005",
  ],
  dailyPlaylist: {
    id: "playlist_today",
    encounterId: "encounter_today_001",
    dateLabel: "2026年6月4日",
    title: "今日のメロディ",
    trackIds: ["track_show", "track_blueberry", "track_kaiju", "track_halzion"],
  },
};

export function initialAppState() {
  return {
    activeScreen: "home",
    activeEncounterId: "encounter_today_001",
    selectedTrackId: "track_lemon",
    // カルーセルの現在位置（メロディ画面）
    carouselIndex: 0,
    carouselViewMode: "pieces", // "pieces" | "mosaic"
    // ピース選択中のパズル候補インデックス
    selectedCandidateIndex: -1,
    // コレクション内部タブ
    collectionTab: "puzzles",
    // ランキング内部タブ
    rankingTab: "today",
    selectedAdKind: null,
    unlockedTrackIds: Object.values(seedData.tracks).filter((track) => track.isUnlocked).map((track) => track.id),
    hintLevels: {},
    answerReadyTrackIds: [],
    collectedPieces: Object.fromEntries(
      Object.values(seedData.tracks).map((track) => {
        if (track.ownedPieces.length > 0) return [track.id, [...track.ownedPieces]];
        // 空の場合は三角分布（sum of two uniforms）で 1〜7 枚をランダム生成
        // E[X] = 4、mode = 4 付近
        const count = Math.max(1, Math.min(7, Math.round(1 + 3 * (Math.random() + Math.random()))));
        const pieces = new Set();
        while (pieces.size < count) pieces.add(Math.ceil(Math.random() * track.pieceCount));
        return [track.id, [...pieces].sort((a, b) => a - b)];
      }),
    ),
    listenLaterTrackIds: [],
    recentlyAddedTrackIds: ["track_show", "track_blueberry", "track_kaiju"],
    coins: seedData.user.coins,
    exp: 0, // 累計経験値（levelFromExp でレベル算出）
    encounterCooldowns: {}, // { [encounterId]: lastPickTimestamp }
    puzzleCompleteTrackId: null, // 完成演出表示中のトラックID
    pendingTitleCelebrations: [], // 獲得演出待ちの称号ID（先頭から順に表示）
    pendingFriendAdd: null, // { userId, userName } — ピース取得後のフレンド申請待ち
    friends: [], // [{ userId, userName, addedAt, exchangeCount }]
    selectedFriendUserId: null, // フレンド詳細画面で表示中のフレンド
    selectedArtistId: null, // アーティスト詳細画面で表示中のアーティストID
    previewPlays: {}, // { [trackId]: { date: "YYYY-MM-DD", count } } — 1曲1日3回まで
    dailyMission: { date: todayKey(), progress: 0, claimed: false }, // ピース獲得数で進行（日付単位リセット）
    oshiTrackIds: [], // 推し曲設定（解放済みの曲から最大 oshiLimit(state) 曲）
    premium: false, // プレミアムプラン加入状態（プロトタイプ・模擬決済）
    hintTickets: 0, // ショップで購入できるヒントチケット（広告の代わりに消費）
    ownedDecorations: [], // 購入済みのアバター装飾（SHOP_ITEMS の id）
    equippedDecoration: null, // 装備中の装飾 id（null=なし）
    notificationSettings: { immediate: true, digest: false, digestTime: "20:00", encounter: true, mission: true },
    linkedServices: { spotify: false, appleMusic: false, youtubeMusic: false }, // 音楽サービス連携（模擬）
    backgroundScan: { enabled: true, mode: "balanced", nightPause: false }, // バックグラウンド検知（mode: powersave/balanced/performance）
    oshiDeliveries: {}, // { [userId]: 届けた推し曲の累計回数 } — すれちがい時に自分の推し曲を相手に届ける
    authUser: undefined, // undefined=セッション確認中 / null=未ログイン / { id, email, isGuest, provider }
    toast: null,
  };
}

export function formatNumber(value) {
  return new Intl.NumberFormat("ja-JP").format(value);
}

/** 今日の日付キー（YYYY-MM-DD・日付単位のリセット判定に使用） */
export function todayKey() {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
}

/** アーティスト名は常に表示、曲名のみマスク（? × 文字数） */
export function maskForTrack(track, hintLevel) {
  if (track.isUnlocked || !track.titleMasks) return `${track.artistName} / ${track.title}`;
  const titleMask = track.titleMasks[Math.min(hintLevel, track.titleMasks.length - 1)];
  return `${track.artistName} / ${titleMask}`;
}
