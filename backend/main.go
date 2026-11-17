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

	// Membuat / memperbarui semua tabel otomatis (cukup dipanggil sekali)
	if err := db.AutoMigrate(&User{}, &Kelas{}, &JadwalRequest{}); err != nil {
		log.Fatal("gagal migrasi: ", err)
	}
	seedAdmin(db) // membuat akun admin kalau belum ada

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

	// Hanya foto profil yang publik. Jangan menyajikan seluruh /uploads,
	// karena lampiran jadwal ada di uploads/jadwal dan harus tetap privat.
	r.Static("/uploads/avatars", "./uploads/avatars")

	api := r.Group("/api")
	{
		api.POST("/register", h.Register)
		api.POST("/login", h.Login)
		api.GET("/me", h.AuthRequired(), h.Me)
		api.POST("/me/photo", h.AuthRequired(), h.UploadPhoto)

		api.GET("/kelas", h.AuthRequired(), h.ListKelas)
		api.POST("/kelas", h.AuthRequired(), h.CreateKelas)

		api.POST("/jadwal-requests", h.AuthRequired(), h.CreateJadwalRequest)
		api.GET("/jadwal-requests", h.AuthRequired(), h.ListJadwalRequests)
		api.DELETE("/jadwal-requests/:id", h.AuthRequired(), h.DeleteJadwalRequest)

		admin := api.Group("/admin", h.AuthRequired(), h.AdminRequired())
		admin.GET("/users", h.ListUsers)
	}

	log.Println("server berjalan di :8080")
	if err := r.Run(":8080"); err != nil {
		log.Fatal(err)
	}
}
