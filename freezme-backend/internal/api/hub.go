package api

import (
	"log"
)

type Hub struct {
	// Registered clients. CircleID -> map of clients
	circles map[string]map[*Client]bool

	// Inbound messages from the clients.
	broadcast chan MessageWrapper

	// Register requests from the clients.
	register chan *Client

	// Unregister requests from clients.
	unregister chan *Client
}

type MessageWrapper struct {
	CircleID string
	Message  []byte
}

func NewHub() *Hub {
	return &Hub{
		broadcast:  make(chan MessageWrapper),
		register:   make(chan *Client),
		unregister: make(chan *Client),
		circles:    make(map[string]map[*Client]bool),
	}
}

func (h *Hub) Run() {
	for {
		select {
		case client := <-h.register:
			if h.circles[client.circleID] == nil {
				h.circles[client.circleID] = make(map[*Client]bool)
			}
			h.circles[client.circleID][client] = true
			log.Printf("Client registered to circle: %s", client.circleID)

		case client := <-h.unregister:
			if _, ok := h.circles[client.circleID][client]; ok {
				delete(h.circles[client.circleID], client)
				close(client.send)
				log.Printf("Client unregistered from circle: %s", client.circleID)
			}

		case msgWrapper := <-h.broadcast:
			for client := range h.circles[msgWrapper.CircleID] {
				select {
				case client.send <- msgWrapper.Message:
				default:
					close(client.send)
					delete(h.circles[client.circleID], client)
				}
			}
		}
	}
}
