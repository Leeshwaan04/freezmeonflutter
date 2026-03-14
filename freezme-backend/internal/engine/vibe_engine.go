package engine

import (
	"math"
	"github.com/leeshwaan04/freezme-backend/internal/models"
)

type VibeEngine struct {
	// Vector storage or Pinecone client would go here
}

func NewVibeEngine() *VibeEngine {
	return &VibeEngine{}
}

// CalculateCompatibility returns a score between 0 and 1
func (e *VibeEngine) CalculateCompatibility(userA, userB *models.UserProfile) float64 {
	if userA.Archetype != userB.Archetype {
		return 0.1 // Baseline if archetypes don't match
	}
	
	// Complex vector math simulation
	score := (userA.VibeScore + userB.VibeScore) / 2.0
	return math.Min(1.0, score+0.2) // High intent boost
}

func (e *VibeEngine) GetDailyPool(user *models.UserProfile, candidates []*models.UserProfile) []*models.UserProfile {
	var pool []*models.UserProfile
	for _, c := range candidates {
		if c.ID == user.ID || c.IsFrozen {
			continue
		}
		if e.CalculateCompatibility(user, c) > 0.6 {
			pool = append(pool, c)
		}
	}
	return pool
}
