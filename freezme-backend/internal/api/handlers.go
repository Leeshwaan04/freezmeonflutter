package api

import (
	"encoding/json"
	"net/http"
	"github.com/leeshwaan04/freezme-backend/internal/engine"
	"github.com/leeshwaan04/freezme-backend/internal/models"
)

type Handler struct {
	Engine *engine.VibeEngine
}

func NewHandler() *Handler {
	return &Handler{
		Engine: engine.NewVibeEngine(),
	}
}

func (h *Handler) GetPool(w http.ResponseWriter, r *http.Request) {
	// Mock implementation for Phase 8
	user := &models.UserProfile{
		ID:        "current-user",
		Archetype: models.Gym,
		VibeScore: 0.8,
	}

	candidates := []*models.UserProfile{
		{ID: "1", Name: "Alex", Archetype: models.Gym, VibeScore: 0.9},
		{ID: "2", Name: "Jordan", Archetype: models.Gym, VibeScore: 0.75},
		{ID: "3", Name: "Taylor", Archetype: models.Brunch, VibeScore: 0.9},
	}

	pool := h.Engine.GetDailyPool(user, candidates)
	
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(pool)
}

func (h *Handler) ToggleFreeze(w http.ResponseWriter, r *http.Request) {
	// Mock freeze logic
	response := map[string]string{"status": "success", "message": "Profile status updated"}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

func (h *Handler) GetCircles(w http.ResponseWriter, r *http.Request) {
	// Mock circles for Phase 8
	circles := []models.VibeCircle{
		{
			ID:        "c1",
			Name:      "Morning Gym Enthusiasts",
			Archetype: models.Gym,
			CreatedAt: "2026-03-14T07:00:00Z",
		},
		{
			ID:        "c2",
			Name:      "Brunch Detectives",
			Archetype: models.Brunch,
			CreatedAt: "2026-03-14T07:00:00Z",
		},
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(circles)
}

func (h *Handler) JoinCircle(w http.ResponseWriter, r *http.Request) {
	// Mock join logic
	response := map[string]string{"status": "joined", "message": "Joined vibe circle successfully"}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}
