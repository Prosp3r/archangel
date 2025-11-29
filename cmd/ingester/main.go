// cmd/ingester/main.go
package main

import (
	"context"
	"encoding/json"
	"log"
	"os"
	"os/signal"
	"time"

	"archangel/internal/database"
	"archangel/internal/models"

	"github.com/redis/go-redis/v9"
	"gopkg.in/yaml.v3"
)

type Config struct {
	Database struct {
		URL string `yaml:"url"`
	} `yaml:"database"`
	Valkey struct {
		Addr      string `yaml:"addr"`
		Password  string `yaml:"password"`
		DB        int    `yaml:"db"`
		SignalKey string `yaml:"signal_key"`
	} `yaml:"valkey"`
}

func main() {
	config := loadConfig()

	db := database.Connect(config.Database.URL)
	defer db.Close()

	rdb := redis.NewClient(&redis.Options{
		Addr:     config.Valkey.Addr,
		Password: config.Valkey.Password,
		DB:       config.Valkey.DB,
	})

	ctx, cancel := signal.NotifyContext(context.Background(), os.Interrupt)
	defer cancel()

	log.Println("ARCHANGEL Ingester started. Waiting for signals...")

	for {
		select {
		case <-ctx.Done():
			log.Println("Shutting down ingester...")
			return
		default:
			result, err := rdb.BLPop(ctx, 5*time.Second, config.Valkey.SignalKey).Result()
			if err == redis.Nil {
				continue
			}
			if err != nil {
				log.Printf("Valkey error: %v", err)
				time.Sleep(3 * time.Second)
				continue
			}

			if len(result) < 2 {
				continue
			}

			jsonStr := result[1]
			var signal models.Signal
			if err := json.Unmarshal([]byte(jsonStr), &signal); err != nil {
				log.Printf("Invalid signal JSON: %v", err)
				continue
			}

			if err := database.InsertSignal(db, &signal); err != nil {
				log.Printf("Failed to insert signal: %v", err)
			} else {
				log.Printf("Ingested signal: %s %s @ %.2f", signal.Symbol, signal.Direction, signal.Entry)
			}
		}
	}
}

func loadConfig() Config {
	data, err := os.ReadFile("../../config.yaml")
	if err != nil {
		log.Fatal("Cannot read config.yaml:", err)
	}
	var c Config
	if err := yaml.Unmarshal(data, &c); err != nil {
		log.Fatal("Invalid config:", err)
	}
	return c
}
