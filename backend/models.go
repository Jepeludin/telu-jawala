package main

import "time"

const (
	RoleAdmin     = "admin"
	RoleMahasiswa = "mahasiswa"
)

// User = tabel "users" di PostgreSQL
type User struct {
	ID           uint      `gorm:"primaryKey" json:"id"`
	NamaLengkap  string    `gorm:"not null" json:"nama_lengkap"`
	NIM          string    `gorm:"uniqueIndex;not null" json:"nim"`
	Email        string    `gorm:"uniqueIndex;not null" json:"email"`
	PasswordHash string    `gorm:"not null" json:"-"`
	Role         string    `gorm:"size:20;not null;default:mahasiswa" json:"role"`
	CreatedAt    time.Time `json:"created_at"`
	PhotoURL     string    `gorm:"size:255;not null;default:''" json:"photo_url"`
}

// Kelas = tabel "kelas". Setiap kelas dimiliki satu akun.
type Kelas struct {
	ID        uint      `gorm:"primaryKey" json:"id"`
	UserID    uint      `gorm:"not null;uniqueIndex:idx_kelas_user_nama" json:"user_id"`
	User      User      `gorm:"constraint:OnDelete:CASCADE" json:"-"`
	Nama      string    `gorm:"size:50;not null;uniqueIndex:idx_kelas_user_nama" json:"nama"`
	CreatedAt time.Time `json:"created_at"`
}

func (Kelas) TableName() string { return "kelas" }

// JadwalRequest = tabel "jadwal_requests"
type JadwalRequest struct {
	ID             uint      `gorm:"primaryKey" json:"id"`
	UserID         uint      `gorm:"not null;index" json:"user_id"`
	User           User      `gorm:"constraint:OnDelete:CASCADE" json:"-"`
	KelasID        *uint     `gorm:"index" json:"kelas_id"`         // kelas milik akun ini
	Kelas          string    `gorm:"size:50;not null" json:"kelas"` // salinan nama kelas
	ScheduledAt    time.Time `gorm:"not null" json:"scheduled_at"`
	Note           string    `json:"note"`
	AttachmentPath string    `json:"-"` // nama file acak di disk
	AttachmentName string    `json:"attachment_name"`
	Status         string    `gorm:"size:20;not null;default:pending" json:"status"`
	CreatedAt      time.Time `json:"created_at"`
}
