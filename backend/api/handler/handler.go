package handler

import (
	"encoding/json"
	"net/http"
	"strings"
	"time"

	"melodylien/store"
)

const guestID = "user_guest"

type Handler struct {
	store *store.Store
}

func New(s *store.Store) *Handler {
	return &Handler{store: s}
}

// ─── Helpers ───────────────────────────────────

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}

func readJSON(r *http.Request, v any) error {
	return json.NewDecoder(r.Body).Decode(v)
}

func today() string {
	return time.Now().Format("2006-01-02")
}

func pathSeg(r *http.Request, idx int) string {
	parts := strings.Split(strings.Trim(r.URL.Path, "/"), "/")
	if idx < len(parts) {
		return parts[idx]
	}
	return ""
}

// ─── Router ────────────────────────────────────

func (h *Handler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	// CORS
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PATCH, OPTIONS")
	w.Header().Set("Access-Control-Allow-Headers", "Content-Type")
	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusNoContent)
		return
	}

	p := strings.TrimPrefix(r.URL.Path, "/api")

	switch {
	// User
	case p == "/me" && r.Method == http.MethodGet:
		h.getMe(w, r)
	case p == "/me/collection" && r.Method == http.MethodGet:
		h.getCollection(w, r)
	case p == "/me/mission" && r.Method == http.MethodGet:
		h.getMission(w, r)

	// Tracks
	case p == "/tracks" && r.Method == http.MethodGet:
		h.listTracks(w, r)
	case strings.HasPrefix(p, "/tracks/"):
		h.trackRouter(w, r, strings.TrimPrefix(p, "/tracks/"))

	// Encounter
	case p == "/encounters/today" && r.Method == http.MethodGet:
		h.getEncounter(w, r)
	case strings.HasPrefix(p, "/encounters/") && strings.HasSuffix(p, "/select"):
		h.selectPiece(w, r)

	// Playlist
	case p == "/playlist/daily" && r.Method == http.MethodGet:
		h.getDailyPlaylist(w, r)

	// Music search
	case p == "/search" && r.Method == http.MethodGet:
		h.searchTracks(w, r)

	default:
		writeJSON(w, http.StatusNotFound, map[string]string{"error": "not found"})
	}
}

// ─── User handlers ──────────────────────────────

func (h *Handler) getMe(w http.ResponseWriter, r *http.Request) {
	u, ok := h.store.GetUser(guestID)
	if !ok {
		writeJSON(w, http.StatusNotFound, map[string]string{"error": "user not found"})
		return
	}
	writeJSON(w, http.StatusOK, u)
}

func (h *Handler) getCollection(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, h.store.CollectionSummary(guestID))
}

func (h *Handler) getMission(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, h.store.GetMission(guestID, today()))
}

// ─── Track handlers ─────────────────────────────

func (h *Handler) listTracks(w http.ResponseWriter, r *http.Request) {
	all := h.store.AllTracks()
	views := make([]any, 0, len(all))
	for _, t := range all {
		views = append(views, h.store.TrackView(guestID, t))
	}
	writeJSON(w, http.StatusOK, views)
}

func (h *Handler) trackRouter(w http.ResponseWriter, r *http.Request, rest string) {
	// rest: "<trackID>" or "<trackID>/unlock" or "<trackID>/pieces" etc.
	parts := strings.SplitN(rest, "/", 2)
	trackID := parts[0]
	sub := ""
	if len(parts) == 2 {
		sub = parts[1]
	}

	t, ok := h.store.GetTrack(trackID)
	if !ok {
		writeJSON(w, http.StatusNotFound, map[string]string{"error": "track not found"})
		return
	}

	switch sub {
	case "":
		writeJSON(w, http.StatusOK, h.store.TrackView(guestID, t))
	case "unlock":
		if r.Method != http.MethodPost {
			writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "POST only"})
			return
		}
		h.store.UnlockTrack(guestID, trackID)
		writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
	case "pieces":
		if r.Method != http.MethodPost {
			writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "POST only"})
			return
		}
		var body struct {
			PieceNumber int `json:"pieceNumber"`
		}
		if err := readJSON(r, &body); err != nil || body.PieceNumber < 1 {
			writeJSON(w, http.StatusBadRequest, map[string]string{"error": "pieceNumber required"})
			return
		}
		added := h.store.AddPiece(guestID, trackID, body.PieceNumber)
		if added {
			h.store.IncrementMission(guestID, today())
		}
		writeJSON(w, http.StatusOK, map[string]bool{"added": added})
	case "hint":
		if r.Method != http.MethodPost {
			writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "POST only"})
			return
		}
		var body struct {
			Kind string `json:"kind"` // "hint1" | "hint2" | "answer"
		}
		if err := readJSON(r, &body); err != nil {
			writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid body"})
			return
		}
		switch body.Kind {
		case "hint1":
			h.store.SetHintLevel(guestID, trackID, 1)
		case "hint2":
			h.store.SetHintLevel(guestID, trackID, 2)
		case "answer":
			h.store.SetAnswerReady(guestID, trackID)
		}
		writeJSON(w, http.StatusOK, map[string]any{
			"hintLevel":   h.store.GetHintLevel(guestID, trackID),
			"answerReady": h.store.IsAnswerReady(guestID, trackID),
		})
	case "listen-later":
		if r.Method != http.MethodPost {
			writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "POST only"})
			return
		}
		h.store.AddListenLater(guestID, trackID)
		writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
	default:
		writeJSON(w, http.StatusNotFound, map[string]string{"error": "not found"})
	}
}

// ─── Encounter handlers ─────────────────────────

func (h *Handler) getEncounter(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, h.store.GetOrCreateEncounter(today()))
}

func (h *Handler) selectPiece(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "POST only"})
		return
	}
	enc := h.store.GetOrCreateEncounter(today())
	var body struct {
		CandidateIndex int `json:"candidateIndex"`
	}
	if err := readJSON(r, &body); err != nil || body.CandidateIndex < 0 || body.CandidateIndex >= len(enc.Candidates) {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid candidateIndex"})
		return
	}
	c := enc.Candidates[body.CandidateIndex]
	added := h.store.AddPiece(guestID, c.TrackID, c.PieceNumber)
	if added {
		h.store.IncrementMission(guestID, today())
	}
	nextScreen := "mystery"
	if h.store.IsUnlocked(guestID, c.TrackID) {
		nextScreen = "puzzle"
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"trackId":     c.TrackID,
		"pieceNumber": c.PieceNumber,
		"added":       added,
		"nextScreen":  nextScreen,
	})
}

// ─── Playlist handler ───────────────────────────

func (h *Handler) getDailyPlaylist(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, h.store.DailyPlaylist(today()))
}

// ─── Search handler ─────────────────────────────

func (h *Handler) searchTracks(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query().Get("q")
	results := h.store.SearchTracks(q)
	if results == nil {
		results = []store.SearchResult{}
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"query":   q,
		"results": results,
	})
}
