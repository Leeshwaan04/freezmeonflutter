package models

type VibeArchetype string

const (
	Gym      VibeArchetype = "gym"
	Brunch   VibeArchetype = "brunch"
	Clubbing VibeArchetype = "clubbing"
	Travel   VibeArchetype = "travel"
	Homebody VibeArchetype = "homebody"
)

type UserProfile struct {
	ID        string        `json:"id"`
	Name      string        `json:"name"`
	Age       int           `json:"age"`
	Archetype VibeArchetype `json:"archetype"`
	VibeScore float64       `json:"vibe_score"`
	IsFrozen  bool          `json:"is_frozen"`
}

type VibeCircle struct {
	ID        string         `json:"id"`
	Name      string         `json:"name"`
	Archetype VibeArchetype  `json:"archetype"`
	Members   []UserProfile  `json:"members"`
	CreatedAt string         `json:"created_at"`
}

type Message struct {
	ID        string `json:"id"`
	CircleID  string `json:"circle_id"`
	SenderID  string `json:"sender_id"`
	Content   string `json:"content"`
	Timestamp string `json:"timestamp"`
}
