// supabase.go — Supabase(PostgREST) からカタログデータを取得する
//
// SUPABASE_URL / SUPABASE_ANON_KEY が設定されていれば起動時に
// artists / tracks を取得し、インメモリストアの内容を置き換える。
// 取得に失敗した場合は埋め込みシードデータのまま動作する（フォールバック）。
package store

import (
	"encoding/json"
	"fmt"
	"net/http"
	"time"

	"melodylien/api/model"
)

// プロトタイプ用デフォルト（anon キーは公開前提のキー）
const (
	DefaultSupabaseURL     = "https://wngtvdgzzlkajtbwsurc.supabase.co"
	DefaultSupabaseAnonKey = "sb_publishable_oR41TcNHu-G9La0JHrnmWg_P8SfRts5"
)

type supabaseArtist struct {
	ID   string `json:"id"`
	Name string `json:"name"`
}

type supabaseTrack struct {
	ID             string `json:"id"`
	ArtistID       string `json:"artist_id"`
	Title          string `json:"title"`
	YoutubeVideoID string `json:"youtube_video_id"`
	PieceCount     int    `json:"piece_count"`
	ChorusStart    int    `json:"chorus_start"`
	RewardCoins    int    `json:"reward_coins"`
	RewardExp      int    `json:"reward_exp"`
	Color          string `json:"color"`
}

func fetchJSON(client *http.Client, url, key string, out any) error {
	req, err := http.NewRequest(http.MethodGet, url, nil)
	if err != nil {
		return err
	}
	req.Header.Set("apikey", key)
	req.Header.Set("Authorization", "Bearer "+key)

	res, err := client.Do(req)
	if err != nil {
		return err
	}
	defer res.Body.Close()
	if res.StatusCode != http.StatusOK {
		return fmt.Errorf("supabase: %s returned %d", url, res.StatusCode)
	}
	return json.NewDecoder(res.Body).Decode(out)
}

// LoadFromSupabase は PostgREST からカタログを取得してストアを更新する。
func (s *Store) LoadFromSupabase(baseURL, anonKey string) error {
	client := &http.Client{Timeout: 8 * time.Second}
	rest := baseURL + "/rest/v1"

	var sbArtists []supabaseArtist
	if err := fetchJSON(client, rest+"/artists?select=id,name", anonKey, &sbArtists); err != nil {
		return err
	}
	var sbTracks []supabaseTrack
	if err := fetchJSON(client, rest+"/tracks?select=*", anonKey, &sbTracks); err != nil {
		return err
	}
	if len(sbArtists) == 0 || len(sbTracks) == 0 {
		return fmt.Errorf("supabase: empty catalog (artists=%d tracks=%d)", len(sbArtists), len(sbTracks))
	}

	s.mu.Lock()
	defer s.mu.Unlock()

	s.artistMap = make(map[string]*model.Artist, len(sbArtists))
	for _, a := range sbArtists {
		artist := model.Artist{ID: a.ID, Name: a.Name}
		s.artistMap[a.ID] = &artist
	}

	s.trackMap = make(map[string]*model.Track, len(sbTracks))
	order := make([]model.Track, 0, len(sbTracks))
	for _, t := range sbTracks {
		track := model.Track{
			ID:          t.ID,
			ArtistID:    t.ArtistID,
			Title:       t.Title,
			PieceCount:  t.PieceCount,
			RewardCoins: t.RewardCoins,
			RewardExp:   t.RewardExp,
			Color:       t.Color,
			YoutubeID:   t.YoutubeVideoID,
		}
		// 埋め込みシードのヒント情報（伏せ字・4択）はそのまま引き継ぐ
		for i := range tracks {
			if tracks[i].ID == t.ID {
				track.Masks = tracks[i].Masks
				track.Choices = tracks[i].Choices
				track.Tone = tracks[i].Tone
				break
			}
		}
		s.trackMap[t.ID] = &track
		order = append(order, track)
	}
	// AllTracks() の走査対象も差し替える
	tracks = order

	return nil
}
