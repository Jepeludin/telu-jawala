package main

import (
	"log"
	"strings"

	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"
)

// seedAdmin membuat akun admin sekali saja (kalau emailnya belum ada).
func seedAdmin(db *gorm.DB) {
	email := strings.ToLower(getEnv("ADMIN_EMAIL", "admin@telkomuniversity.ac.id"))
	password := getEnv("ADMIN_PASSWORD", "admin123")

	var count int64
	db.Model(&User{}).Where("email = ?", email).Count(&count)
	if count > 0 {
		return
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		log.Fatal("gagal membuat hash admin: ", err)
	}
	admin := User{
		NamaLengkap:  "Administrator",
		NIM:          "ADMIN",
		Email:        email,
		PasswordHash: string(hash),
		Role:         RoleAdmin,
	}
	if err := db.Create(&admin).Error; err != nil {
		log.Fatal("gagal membuat akun admin: ", err)
	}
	log.Println("akun admin dibuat:", email)
}
