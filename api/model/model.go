package model

import "time"

// ─── User ──────────────────────────────────────

type User struct {
	ID        string    `json:"id"`
	Name      string    `json:"name"`
	Level     int       `json:"level"`
	Exp       int       `json:"exp"`
	Coins     int       `json:"coins"`
	CreatedAt time.Time `json:"createdAt"`
}

// ─── Artist ────────────────────────────────────

type Artist struct {
	ID   string `json:"id"`
	Name string `json:"name"`
}

// ─── Track ─────────────────────────────────────

type Track struct {
	ID            string   `json:"id"`
	ArtistID      string   `json:"artistId"`
	Title         string   `json:"title"`
	PieceCount    int      `json:"pieceCount"`
	RewardCoins   int      `json:"rewardCoins"`
	RewardExp     int      `json:"rewardExp"`
	Color         string   `json:"color"`
	Tone          string   `json:"tone,omitempty"`
	YoutubeID     string   `json:"youtubeId,omitempty"`
	// 内部保持用（APIレスポンスには含めない）
	Masks   []string `json:"-"`
	Choices []string `json:"-"`
}

// TrackView はユーザーごとの状態を含むAPIレスポンス用構造体
type TrackView struct {
	ID          string   `json:"id"`
	ArtistID    string   `json:"artistId"`
	Title       *string  `json:"title"`       // 未解放は null
	ArtistName  *string  `json:"artistName"`  // 未解放は null
	PieceCount  int      `json:"pieceCount"`
	RewardCoins int      `json:"rewardCoins"`
	RewardExp   int      `json:"rewardExp"`
	Color       string   `json:"color"`
	Tone        string   `json:"tone,omitempty"`
	IsUnlocked  bool     `json:"isUnlocked"`
	HintLevel   int      `json:"hintLevel"`
	AnswerReady bool     `json:"answerReady"`
	MaskedLabel *string  `json:"maskedLabel"` // ヒントレベルに応じた伏せ字
	Choices     []string `json:"choices"`     // hint level >= 2 で公開
	OwnedPieces []int    `json:"ownedPieces"`
}

// ─── Encounter ─────────────────────────────────

type Encounter struct {
	ID            string       `json:"id"`
	LocationLabel string       `json:"locationLabel"`
	RewardCoins   int          `json:"rewardCoins"`
	ExpiresAt     time.Time    `json:"expiresAt"`
	Candidates    []Candidate  `json:"candidates"`
}

type Candidate struct {
	ID          string `json:"id"`
	TrackID     string `json:"trackId"`
	PieceNumber int    `json:"pieceNumber"`
	SourceSlot  string `json:"sourceSlot"`
	Rarity      int    `json:"rarity"`
	SortOrder   int    `json:"sortOrder"`
}

// ─── Playlist ──────────────────────────────────

type DailyPlaylist struct {
	ID     string         `json:"id"`
	Date   string         `json:"date"`
	Title  string         `json:"title"`
	Tracks []PlaylistItem `json:"tracks"`
}

type PlaylistItem struct {
	TrackID  string `json:"trackId"`
	ArtistID string `json:"artistId"`
	Color    string `json:"color"`
}

// ─── Mission ───────────────────────────────────

type Mission struct {
	UserID  string `json:"userId"`
	Date    string `json:"date"`
	Label   string `json:"label"`
	Current int    `json:"current"`
	Target  int    `json:"target"`
}

// ─── Collection summary ─────────────────────────

type CollectionSummary struct {
	CompletedPuzzles int `json:"completedPuzzles"`
	TotalPuzzles     int `json:"totalPuzzles"`
	CompletedArtists int `json:"completedArtists"`
	TotalArtists     int `json:"totalArtists"`
	Playlists        int `json:"playlists"`
}
