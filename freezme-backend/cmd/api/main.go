package main

import (
	"fmt"
	"log"
	"net/http"
	"os"

	"github.com/leeshwaan04/freezme-backend/internal/api"
)

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	hub := api.NewHub()
	go hub.Run()

	router := api.SetupRouter(hub)

	fmt.Printf("❄️ Freezme Backend starting on port %s...\n", port)
	log.Fatal(http.ListenAndServe(":"+port, router))
}
