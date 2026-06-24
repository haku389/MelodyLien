-- StreetMelody PostgreSQL スキーマ

-- ユーザー
CREATE TABLE users (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name        TEXT NOT NULL,
  level       INT NOT NULL DEFAULT 1,
  exp         INT NOT NULL DEFAULT 0,
  coins       INT NOT NULL DEFAULT 0,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- アーティスト
CREATE TABLE artists (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name        TEXT NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 曲
CREATE TABLE tracks (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  artist_id       UUID NOT NULL REFERENCES artists(id),
  title           TEXT NOT NULL,
  piece_count     INT NOT NULL DEFAULT 9,
  reward_coins    INT NOT NULL DEFAULT 100,
  reward_exp      INT NOT NULL DEFAULT 50,
  youtube_video_id TEXT,
  color           TEXT NOT NULL DEFAULT 'violet',
  -- 伏せ字ヒント (JSON配列: hint level 0/1/2 の表示文字列)
  masks           JSONB,
  -- 4択ヒント選択肢
  choices         JSONB,
  tone            TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ユーザーが所持しているパズルピース
CREATE TABLE collected_pieces (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES users(id),
  track_id    UUID NOT NULL REFERENCES tracks(id),
  piece_number INT NOT NULL,
  collected_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (user_id, track_id, piece_number)
);

-- 解放済み曲（曲名・アーティスト名が見えるようになった曲）
CREATE TABLE unlocked_tracks (
  user_id     UUID NOT NULL REFERENCES users(id),
  track_id    UUID NOT NULL REFERENCES tracks(id),
  unlocked_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (user_id, track_id)
);

-- ヒント解放レベル (0=なし, 1=hint1視聴済み, 2=hint2視聴済み)
CREATE TABLE hint_levels (
  user_id     UUID NOT NULL REFERENCES users(id),
  track_id    UUID NOT NULL REFERENCES tracks(id),
  level       INT NOT NULL DEFAULT 0,
  PRIMARY KEY (user_id, track_id)
);

-- 答え確認リンク表示済み
CREATE TABLE answer_ready_tracks (
  user_id     UUID NOT NULL REFERENCES users(id),
  track_id    UUID NOT NULL REFERENCES tracks(id),
  PRIMARY KEY (user_id, track_id)
);

-- あとで聴くリスト
CREATE TABLE listen_later (
  user_id     UUID NOT NULL REFERENCES users(id),
  track_id    UUID NOT NULL REFERENCES tracks(id),
  added_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (user_id, track_id)
);

-- 近距離交換イベント
CREATE TABLE encounters (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  location_label  TEXT NOT NULL,
  reward_coins    INT NOT NULL DEFAULT 50,
  expires_at      TIMESTAMPTZ NOT NULL,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 近距離交換候補ピース（1イベントにつき最大5件）
CREATE TABLE encounter_candidates (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  encounter_id UUID NOT NULL REFERENCES encounters(id) ON DELETE CASCADE,
  track_id    UUID NOT NULL REFERENCES tracks(id),
  piece_number INT NOT NULL,
  source_slot TEXT NOT NULL, -- "推し曲枠" | "発見枠" | "解放済み" | "レア枠" | "イベント"
  rarity      INT NOT NULL DEFAULT 3, -- 1〜5
  sort_order  INT NOT NULL DEFAULT 0
);

-- デイリープレイリスト
CREATE TABLE daily_playlists (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  date        DATE NOT NULL UNIQUE,
  title       TEXT NOT NULL DEFAULT '今日のメロディ',
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE daily_playlist_tracks (
  playlist_id UUID NOT NULL REFERENCES daily_playlists(id) ON DELETE CASCADE,
  track_id    UUID NOT NULL REFERENCES tracks(id),
  sort_order  INT NOT NULL DEFAULT 0,
  PRIMARY KEY (playlist_id, track_id)
);

-- デイリーミッション進行
CREATE TABLE daily_missions (
  user_id     UUID NOT NULL REFERENCES users(id),
  date        DATE NOT NULL,
  label       TEXT NOT NULL,
  current     INT NOT NULL DEFAULT 0,
  target      INT NOT NULL DEFAULT 5,
  PRIMARY KEY (user_id, date)
);

-- インデックス
CREATE INDEX ON collected_pieces (user_id, track_id);
CREATE INDEX ON encounter_candidates (encounter_id);
CREATE INDEX ON daily_playlist_tracks (playlist_id);
