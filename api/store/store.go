// store パッケージ：インメモリDB（開発用）
// 本番では database/sql + pgx でPostgreSQLへ差し替える

package store

import (
	"fmt"
	"sync"
	"time"

	"melodylien/api/model"
)

// ─── Seed data ─────────────────────────────────

var artists = []model.Artist{
	{ID: "artist_yoasobi",  Name: "YOASOBI"},
	{ID: "artist_niziu",    Name: "NiziU"},
	{ID: "artist_yonezu",   Name: "米津玄師"},
	{ID: "artist_ado",      Name: "Ado"},
	{ID: "artist_vaundy",   Name: "Vaundy"},
	{ID: "artist_milet",    Name: "milet"},
	{ID: "artist_macaroni", Name: "マカロニえんぴつ"},
	{ID: "artist_higedan",  Name: "Official髭男dism"},
}

var tracks = []model.Track{
	{ID: "track_sunset_drive", ArtistID: "artist_niziu",    Title: "Sunset Drive",    PieceCount: 9, RewardCoins: 100, RewardExp: 50, Color: "sunset"},
	{ID: "track_lemon",        ArtistID: "artist_yonezu",   Title: "Lemon",            PieceCount: 9, RewardCoins: 100, RewardExp: 50, Color: "violet", Tone: "やさしい余韻",
		Masks:   []string{"○津玄○ / L○○o○", "米津玄○ / Le○o○", "米津玄師 / Le○on"},
		Choices: []string{"恋愛", "夏", "夜", "ドラマ"}},
	{ID: "track_yoru",         ArtistID: "artist_yoasobi",  Title: "夜に駆ける",       PieceCount: 9, RewardCoins: 100, RewardExp: 50, Color: "berry", Tone: "夜に聴きたい",
		Masks:   []string{"Y○○S○BI / ○に駆ける", "YO○SOBI / 夜に○ける", "YOASOBI / 夜に駆○る"},
		Choices: []string{"夜", "疾走感", "小説", "出会い"}},
	{ID: "track_show",         ArtistID: "artist_ado",      Title: "唱",               PieceCount: 9, RewardCoins: 100, RewardExp: 50, Color: "magic"},
	{ID: "track_kaiju",        ArtistID: "artist_vaundy",   Title: "怪獣の花唄",       PieceCount: 9, RewardCoins: 100, RewardExp: 50, Color: "sunset"},
	{ID: "track_anytime",      ArtistID: "artist_milet",    Title: "Anytime Anywhere", PieceCount: 9, RewardCoins: 100, RewardExp: 50, Color: "violet", Tone: "透明感",
		Masks:   []string{"m○ilet / A○○", "milet / Any○○", "milet / Anytime ○○"},
		Choices: []string{"透明感", "旅", "祈り", "エンディング"}},
	{ID: "track_blueberry",    ArtistID: "artist_macaroni", Title: "ブルーベリー",     PieceCount: 9, RewardCoins: 100, RewardExp: 50, Color: "berry"},
	{ID: "track_magic_hour",   ArtistID: "artist_higedan",  Title: "Magic Hour",       PieceCount: 9, RewardCoins: 100, RewardExp: 50, Color: "magic"},
	{ID: "track_halzion",      ArtistID: "artist_yoasobi",  Title: "ハルジオン",       PieceCount: 9, RewardCoins: 100, RewardExp: 50, Color: "violet"},
}

var dailyTrackIDs = []string{"track_sunset_drive", "track_blueberry", "track_magic_hour", "track_halzion"}

// ─── Store ─────────────────────────────────────

type Store struct {
	mu sync.RWMutex

	users    map[string]*model.User
	trackMap map[string]*model.Track
	artistMap map[string]*model.Artist

	// key: userID:trackID:pieceNumber
	collectedPieces map[string]bool
	// key: userID:trackID
	unlockedTracks map[string]bool
	// key: userID:trackID → level
	hintLevels map[string]int
	// key: userID:trackID
	answerReady map[string]bool
	// key: userID → []trackID
	listenLater map[string][]string
	// key: userID:date
	missions map[string]*model.Mission
	// key: date
	encounters map[string]*model.Encounter
}

func New() *Store {
	s := &Store{
		users:           make(map[string]*model.User),
		trackMap:        make(map[string]*model.Track),
		artistMap:       make(map[string]*model.Artist),
		collectedPieces: make(map[string]bool),
		unlockedTracks:  make(map[string]bool),
		hintLevels:      make(map[string]int),
		answerReady:     make(map[string]bool),
		listenLater:     make(map[string][]string),
		missions:        make(map[string]*model.Mission),
		encounters:      make(map[string]*model.Encounter),
	}

	// シードデータ登録
	for i := range tracks {
		t := tracks[i]
		s.trackMap[t.ID] = &t
	}
	for i := range artists {
		a := artists[i]
		s.artistMap[a.ID] = &a
	}

	// ゲストユーザー
	s.users["user_guest"] = &model.User{
		ID:        "user_guest",
		Name:      "Mia",
		Level:     1,
		Exp:       0,
		Coins:     0,
		CreatedAt: time.Now(),
	}

	return s
}

// ─── User ──────────────────────────────────────

func (s *Store) GetUser(userID string) (*model.User, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	u, ok := s.users[userID]
	return u, ok
}

// ─── Tracks ────────────────────────────────────

func (s *Store) GetTrack(id string) (*model.Track, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	t, ok := s.trackMap[id]
	return t, ok
}

func (s *Store) AllTracks() []*model.Track {
	s.mu.RLock()
	defer s.mu.RUnlock()
	out := make([]*model.Track, 0, len(s.trackMap))
	for i := range tracks {
		out = append(out, s.trackMap[tracks[i].ID])
	}
	return out
}

func (s *Store) GetArtistName(artistID string) string {
	s.mu.RLock()
	defer s.mu.RUnlock()
	if a, ok := s.artistMap[artistID]; ok {
		return a.Name
	}
	return ""
}

// ─── Pieces ────────────────────────────────────

func (s *Store) GetOwnedPieces(userID, trackID string) []int {
	s.mu.RLock()
	defer s.mu.RUnlock()
	var out []int
	t, ok := s.trackMap[trackID]
	if !ok {
		return out
	}
	for i := 1; i <= t.PieceCount; i++ {
		if s.collectedPieces[fmt.Sprintf("%s:%s:%d", userID, trackID, i)] {
			out = append(out, i)
		}
	}
	return out
}

func (s *Store) AddPiece(userID, trackID string, pieceNumber int) bool {
	key := fmt.Sprintf("%s:%s:%d", userID, trackID, pieceNumber)
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.collectedPieces[key] {
		return false
	}
	s.collectedPieces[key] = true
	return true
}

// ─── Unlock ────────────────────────────────────

func (s *Store) IsUnlocked(userID, trackID string) bool {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.unlockedTracks[userID+":"+trackID]
}

func (s *Store) UnlockTrack(userID, trackID string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.unlockedTracks[userID+":"+trackID] = true
}

// ─── Hint ──────────────────────────────────────

func (s *Store) GetHintLevel(userID, trackID string) int {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.hintLevels[userID+":"+trackID]
}

func (s *Store) SetHintLevel(userID, trackID string, level int) {
	s.mu.Lock()
	defer s.mu.Unlock()
	cur := s.hintLevels[userID+":"+trackID]
	if level > cur {
		s.hintLevels[userID+":"+trackID] = level
	}
}

func (s *Store) IsAnswerReady(userID, trackID string) bool {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.answerReady[userID+":"+trackID]
}

func (s *Store) SetAnswerReady(userID, trackID string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.answerReady[userID+":"+trackID] = true
}

// ─── Listen later ───────────────────────────────

func (s *Store) GetListenLater(userID string) []string {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return append([]string{}, s.listenLater[userID]...)
}

func (s *Store) AddListenLater(userID, trackID string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	for _, id := range s.listenLater[userID] {
		if id == trackID {
			return
		}
	}
	s.listenLater[userID] = append([]string{trackID}, s.listenLater[userID]...)
}

// ─── Mission ───────────────────────────────────

func (s *Store) GetMission(userID, date string) *model.Mission {
	s.mu.Lock()
	defer s.mu.Unlock()
	key := userID + ":" + date
	if m, ok := s.missions[key]; ok {
		return m
	}
	m := &model.Mission{UserID: userID, Date: date, Label: "デイリー", Current: 0, Target: 5}
	s.missions[key] = m
	return m
}

func (s *Store) IncrementMission(userID, date string) *model.Mission {
	m := s.GetMission(userID, date)
	s.mu.Lock()
	defer s.mu.Unlock()
	if m.Current < m.Target {
		m.Current++
	}
	return m
}

// ─── Encounter ─────────────────────────────────

func (s *Store) GetOrCreateEncounter(date string) *model.Encounter {
	s.mu.Lock()
	defer s.mu.Unlock()
	if enc, ok := s.encounters[date]; ok {
		return enc
	}

	slots := []string{"推し曲枠", "発見枠", "解放済み", "レア枠", "イベント"}
	candidates := make([]model.Candidate, 0, 5)
	all := make([]*model.Track, 0, len(s.trackMap))
	for i := range tracks {
		all = append(all, s.trackMap[tracks[i].ID])
	}
	for i := 0; i < 5 && i < len(all); i++ {
		candidates = append(candidates, model.Candidate{
			ID:          fmt.Sprintf("cand_%s_%d", date, i),
			TrackID:     all[i].ID,
			PieceNumber: (i % all[i].PieceCount) + 1,
			SourceSlot:  slots[i],
			Rarity:      5,
			SortOrder:   i,
		})
	}

	enc := &model.Encounter{
		ID:            "enc_" + date,
		LocationLabel: "大学",
		RewardCoins:   50,
		ExpiresAt:     time.Now().Add(45 * time.Second),
		Candidates:    candidates,
	}
	s.encounters[date] = enc
	return enc
}

// ─── Collection summary ─────────────────────────

func (s *Store) CollectionSummary(userID string) model.CollectionSummary {
	s.mu.RLock()
	defer s.mu.RUnlock()

	completedPuzzles := 0
	for i := range tracks {
		t := &tracks[i]
		owned := 0
		for n := 1; n <= t.PieceCount; n++ {
			if s.collectedPieces[fmt.Sprintf("%s:%s:%d", userID, t.ID, n)] {
				owned++
			}
		}
		if owned >= t.PieceCount {
			completedPuzzles++
		}
	}

	ll := s.listenLater[userID]
	playlists := 1
	if len(ll) > 0 {
		playlists++
	}

	return model.CollectionSummary{
		CompletedPuzzles: completedPuzzles,
		TotalPuzzles:     len(tracks),
		CompletedArtists: 0,
		TotalArtists:     len(artists),
		Playlists:        playlists,
	}
}

// ─── Playlist ──────────────────────────────────

func (s *Store) DailyPlaylist(date string) model.DailyPlaylist {
	s.mu.RLock()
	defer s.mu.RUnlock()

	items := make([]model.PlaylistItem, 0, len(dailyTrackIDs))
	for _, id := range dailyTrackIDs {
		if t, ok := s.trackMap[id]; ok {
			items = append(items, model.PlaylistItem{
				TrackID:  t.ID,
				ArtistID: t.ArtistID,
				Color:    t.Color,
			})
		}
	}
	return model.DailyPlaylist{
		ID:     "playlist_" + date,
		Date:   date,
		Title:  "今日のメロディ",
		Tracks: items,
	}
}

// ─── TrackView helper ───────────────────────────

func (s *Store) TrackView(userID string, t *model.Track) model.TrackView {
	unlocked := s.IsUnlocked(userID, t.ID)
	hintLevel := s.GetHintLevel(userID, t.ID)
	answerReady := s.IsAnswerReady(userID, t.ID)
	owned := s.GetOwnedPieces(userID, t.ID)

	view := model.TrackView{
		ID:          t.ID,
		ArtistID:    t.ArtistID,
		PieceCount:  t.PieceCount,
		RewardCoins: t.RewardCoins,
		RewardExp:   t.RewardExp,
		Color:       t.Color,
		Tone:        t.Tone,
		IsUnlocked:  unlocked,
		HintLevel:   hintLevel,
		AnswerReady: answerReady,
		OwnedPieces: owned,
		Choices:     []string{},
	}

	if unlocked {
		title := t.Title
		artistName := s.GetArtistName(t.ArtistID)
		view.Title = &title
		view.ArtistName = &artistName
	} else if len(t.Masks) > 0 {
		idx := hintLevel
		if idx >= len(t.Masks) {
			idx = len(t.Masks) - 1
		}
		masked := t.Masks[idx]
		view.MaskedLabel = &masked
		if hintLevel >= 2 {
			view.Choices = t.Choices
		}
	}

	return view
}
