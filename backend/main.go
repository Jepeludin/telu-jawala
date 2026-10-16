package main

import (
	"log"
	"os"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
)

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func main() {
	dsn := getEnv("DATABASE_URL",
		"host=localhost user=postgres password=IME2025 dbname=jawala port=3241 sslmode=disable")

	db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{})
	if err != nil {
		log.Fatal("gagal terhubung ke database: ", err)
	}
	// Membuat / memperbarui tabel users otomatis
	if err := db.AutoMigrate(&User{}); err != nil {
		log.Fatal("gagal migrasi: ", err)
	}

	h := &Handler{
		DB:        db,
		JWTSecret: []byte(getEnv("JWT_SECRET", "ganti-dengan-secret-yang-panjang-dan-acak")),
	}

	r := gin.Default()

	r.Use(cors.New(cors.Config{
		AllowAllOrigins: true, // hanya untuk development
		AllowMethods:    []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowHeaders:    []string{"Origin", "Content-Type", "Authorization"},
	}))

	api := r.Group("/api")
	{
		api.POST("/register", h.Register)
		api.POST("/login", h.Login)
		api.GET("/me", h.AuthRequired(), h.Me)
	}

	log.Println("server berjalan di :8080")
	if err := r.Run(":8080"); err != nil {
		log.Fatal(err)
	}
}
