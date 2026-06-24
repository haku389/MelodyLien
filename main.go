package main

import (
	"fmt"
	"net/http"
	"os"

	"streetmelody/api/handler"
	"streetmelody/api/store"
)

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "3001"
	}

	s := store.New()

	// Supabase からカタログ取得（失敗時は埋め込みシードで継続）
	sbURL := os.Getenv("SUPABASE_URL")
	if sbURL == "" {
		sbURL = store.DefaultSupabaseURL
	}
	sbKey := os.Getenv("SUPABASE_ANON_KEY")
	if sbKey == "" {
		sbKey = store.DefaultSupabaseAnonKey
	}
	if err := s.LoadFromSupabase(sbURL, sbKey); err != nil {
		fmt.Fprintf(os.Stderr, "supabase unavailable, using embedded seed: %v\n", err)
	} else {
		fmt.Println("catalog loaded from Supabase:", sbURL)
	}

	h := handler.New(s)

	mux := http.NewServeMux()
	mux.Handle("/api/", h)

	addr := ":" + port
	fmt.Printf("StreetMelody API listening on http://localhost%s\n", addr)
	if err := http.ListenAndServe(addr, mux); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
