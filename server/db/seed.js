// DBシードデータ（開発・テスト用）
// PostgreSQL接続後に server/db/client.js 経由で流す

export const SEED = {
  artists: [
    { id: "artist_yoasobi", name: "YOASOBI" },
    { id: "artist_niziu",   name: "NiziU" },
    { id: "artist_yonezu",  name: "米津玄師" },
    { id: "artist_ado",     name: "Ado" },
    { id: "artist_vaundy",  name: "Vaundy" },
    { id: "artist_milet",   name: "milet" },
    { id: "artist_macaroni",name: "マカロニえんぴつ" },
    { id: "artist_higedan", name: "Official髭男dism" },
  ],
  tracks: [
    {
      id: "track_lemon", artist_id: "artist_yonezu",
      title: "Lemon", piece_count: 9, reward_coins: 100, reward_exp: 50,
      youtube_video_id: null, color: "violet",
      masks: ["○津玄○ / L○○o○", "米津玄○ / Le○o○", "米津玄師 / Le○on"],
      choices: ["恋愛", "夏", "夜", "ドラマ"], tone: "やさしい余韻",
    },
    {
      id: "track_yoru", artist_id: "artist_yoasobi",
      title: "夜に駆ける", piece_count: 9, reward_coins: 100, reward_exp: 50,
      youtube_video_id: null, color: "berry",
      masks: ["Y○○S○BI / ○に駆ける", "YO○SOBI / 夜に○ける", "YOASOBI / 夜に駆○る"],
      choices: ["夜", "疾走感", "小説", "出会い"], tone: "夜に聴きたい",
    },
    {
      id: "track_show", artist_id: "artist_ado",
      title: "唱", piece_count: 9, reward_coins: 100, reward_exp: 50,
      youtube_video_id: null, color: "magic",
    },
    {
      id: "track_kaiju", artist_id: "artist_vaundy",
      title: "怪獣の花唄", piece_count: 9, reward_coins: 100, reward_exp: 50,
      youtube_video_id: null, color: "sunset",
    },
    {
      id: "track_anytime", artist_id: "artist_milet",
      title: "Anytime Anywhere", piece_count: 9, reward_coins: 100, reward_exp: 50,
      youtube_video_id: null, color: "violet",
      masks: ["m○ilet / A○○", "milet / Any○○", "milet / Anytime ○○"],
      choices: ["透明感", "旅", "祈り", "エンディング"], tone: "透明感",
    },
    {
      id: "track_blueberry", artist_id: "artist_macaroni",
      title: "ブルーベリー", piece_count: 9, reward_coins: 100, reward_exp: 50,
      youtube_video_id: null, color: "berry",
    },
    {
      id: "track_halzion", artist_id: "artist_yoasobi",
      title: "ハルジオン", piece_count: 9, reward_coins: 100, reward_exp: 50,
      youtube_video_id: null, color: "violet",
    },
  ],
};
