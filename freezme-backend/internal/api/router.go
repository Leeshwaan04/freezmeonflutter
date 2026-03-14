package api

import (
	"net/http"
)

func SetupRouter(hub *Hub) *http.ServeMux {
	mux := http.NewServeMux()
	h := NewHandler()

	// Endpoints
	mux.HandleFunc("/api/pool", h.GetPool)
	mux.HandleFunc("/api/freeze", h.ToggleFreeze)
	mux.HandleFunc("/api/circles", h.GetCircles)
	mux.HandleFunc("/api/circles/join", h.JoinCircle)

	// WebSocket endpoint
	mux.HandleFunc("/ws", func(w http.ResponseWriter, r *http.Request) {
		h.ServeWs(hub, w, r)
	})

	// Health check
	mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("❄️ Freezme API is cold and stable"))
	})

	return mux
}
