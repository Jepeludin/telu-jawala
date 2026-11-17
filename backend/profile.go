package main

import (
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"net/http"
	"os"
	"path/filepath"

	"github.com/gin-gonic/gin"
)

const (
	avatarsDir     = "uploads/avatars"  // lokasi file di disk
	avatarsURLPath = "/uploads/avatars" // path URL yang disimpan di database
	maxAvatarBytes = 5 << 20            // 5 MB
)

// Jenis file yang diizinkan, ditentukan dari ISI file (bukan dari nama/ekstensi).
// SVG sengaja tidak diizinkan karena bisa memuat script.
var avatarTypes = map[string]string{
	"image/jpeg": ".jpg",
	"image/png":  ".png",
	"image/webp": ".webp",
}

// POST /api/me/photo  (multipart/form-data, field "photo", butuh JWT)
func (h *Handler) UploadPhoto(c *gin.Context) {
	userID := c.GetUint("userID")

	c.Request.Body = http.MaxBytesReader(c.Writer, c.Request.Body, maxAvatarBytes+(1<<20))
	header, err := c.FormFile("photo")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Foto tidak ditemukan atau terlalu besar (maks 5 MB)"})
		return
	}
	if header.Size > maxAvatarBytes {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Ukuran foto maksimal 5 MB"})
		return
	}

	f, err := header.Open()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Gagal membaca foto"})
		return
	}
	defer f.Close()

	sniff := make([]byte, 512)
	n, _ := f.Read(sniff)
	ext, ok := avatarTypes[http.DetectContentType(sniff[:n])]
	if !ok {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Format foto harus JPG, PNG, atau WebP"})
		return
	}

	var user User
	if err := h.DB.First(&user, userID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "User tidak ditemukan"})
		return
	}

	// Nama file acak supaya tidak bisa ditebak dan tidak bentrok / ter-cache
	buf := make([]byte, 8)
	rand.Read(buf)
	name := fmt.Sprintf("%d-%s%s", userID, hex.EncodeToString(buf), ext)
	savedPath := filepath.Join(avatarsDir, name)

	if err := os.MkdirAll(avatarsDir, 0o755); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Gagal menyimpan foto"})
		return
	}
	if err := c.SaveUploadedFile(header, savedPath); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Gagal menyimpan foto"})
		return
	}

	// Database hanya menyimpan URL (path relatif), bukan file-nya
	oldURL := user.PhotoURL
	newURL := avatarsURLPath + "/" + name
	if err := h.DB.Model(&user).Update("photo_url", newURL).Error; err != nil {
		os.Remove(savedPath)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Gagal menyimpan foto"})
		return
	}

	// Hapus foto lama supaya disk tidak menumpuk (Base() mencegah path traversal)
	if oldURL != "" {
		os.Remove(filepath.Join(avatarsDir, filepath.Base(oldURL)))
	}

	c.JSON(http.StatusOK, gin.H{
		"message":   "Foto profil diperbarui",
		"photo_url": newURL,
	})
}
