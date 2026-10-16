package main

import "time"

// User = tabel "users" di PostgreSQL
type User struct {
	ID           uint      `gorm:"primaryKey" json:"id"`
	NamaLengkap  string    `gorm:"not null" json:"nama_lengkap"`
	NIM          string    `gorm:"uniqueIndex;not null" json:"nim"`
	Email        string    `gorm:"uniqueIndex;not null" json:"email"`
	PasswordHash string    `gorm:"not null" json:"-"` // tidak pernah dikirim ke client
	CreatedAt    time.Time `json:"created_at"`
}
