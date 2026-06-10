package main

import (
	"fmt"
	"net/http"
	"os"

	"melodylien/handler"
	"melodylien/store"
)

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "3001"
	}

	s := store.New()
	h := handler.New(s)

	mux := http.NewServeMux()
	mux.Handle("/api/", h)

	addr := ":" + port
	fmt.Printf("MelodyLien API listening on http://localhost%s\n", addr)
	if err := http.ListenAndServe(addr, mux); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
