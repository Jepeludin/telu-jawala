package main

import (
	"errors"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"crypto/rand"
	"encoding/hex"

	"github.com/gin-gonic/gin"
)

const (
	maxUpload  = 5 << 20 // 5 MB
	uploadsDir = "uploads/jadwal"
)

var (
	allowedExt = map[string]bool{".jpg": true, ".jpeg": true, ".png": true, ".pdf": true, ".doc": true, ".docx": true}
	wib        = time.FixedZone("WIB", 7*3600) // jam dari app dianggap WIB
)

// POST /api/jadwal-requests  (multipart/form-data, butuh JWT)
func (h *Handler) CreateJadwalRequest(c *gin.Context) {
	userID := c.GetUint("userID")

	c.Request.Body = http.MaxBytesReader(c.Writer, c.Request.Body, maxUpload+(1<<20))
	if err := c.Request.ParseMultipartForm(maxUpload); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Form tidak valid atau file terlalu besar (maks 5 MB)"})
		return
	}

	kelasID, err := strconv.ParseUint(c.PostForm("kelas_id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Kelas tidak valid"})
		return
	}
	var kelas Kelas
	// user_id ikut di WHERE: kelas milik akun lain ditolak
	if err := h.DB.Where("id = ? AND user_id = ?", kelasID, userID).
		First(&kelas).Error; err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Kelas tidak ditemukan di akun Anda"})
		return
	}

	scheduledAt, err := time.ParseInLocation("2006-01-02 15:04",
		strings.TrimSpace(c.PostForm("scheduled_at")), wib)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Format tanggal dan waktu tidak valid"})
		return
	}
	if scheduledAt.Before(time.Now()) {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Waktu tidak boleh di masa lalu"})
		return
	}

	note := strings.TrimSpace(c.PostForm("note"))
	if len(note) > 1000 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Note maksimal 1000 karakter"})
		return
	}

	jr := JadwalRequest{
		UserID:      userID,
		KelasID:     &kelas.ID,
		Kelas:       kelas.Nama,
		ScheduledAt: scheduledAt,
		Note:        note,
		Status:      "pending",
	}

	// Lampiran (opsional)
	var savedPath string
	header, err := c.FormFile("attachment")
	switch {
	case err == nil:
		ext := strings.ToLower(filepath.Ext(header.Filename))
		if !allowedExt[ext] || header.Size > maxUpload {
			c.JSON(http.StatusBadRequest, gin.H{"error": "File tidak didukung atau lebih dari 5 MB"})
			return
		}
		// Nama di disk acak; nama asli jangan dipakai sebagai path
		buf := make([]byte, 8)
		rand.Read(buf)
		stored := hex.EncodeToString(buf) + ext

		if err := os.MkdirAll(uploadsDir, 0o755); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Gagal menyimpan file"})
			return
		}
		savedPath = filepath.Join(uploadsDir, stored)
		if err := c.SaveUploadedFile(header, savedPath); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Gagal menyimpan file"})
			return
		}
		jr.AttachmentPath = stored
		jr.AttachmentName = filepath.Base(header.Filename)
	case !errors.Is(err, http.ErrMissingFile):
		c.JSON(http.StatusBadRequest, gin.H{"error": "Lampiran tidak valid"})
		return
	}

	if err := h.DB.Create(&jr).Error; err != nil {
		if savedPath != "" {
			os.Remove(savedPath)
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Gagal menyimpan permintaan"})
		return
	}

	c.JSON(http.StatusCreated, gin.H{"message": "Permintaan berhasil dikirim", "id": jr.ID})

}

// GET /api/jadwal-requests  -> daftar jadwal milik user yang login
func (h *Handler) ListJadwalRequests(c *gin.Context) {
	userID := c.GetUint("userID")

	items := make([]JadwalRequest, 0) // supaya JSON-nya [] bukan null
	if err := h.DB.Where("user_id = ?", userID).
		Order("scheduled_at DESC").Find(&items).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Gagal memuat jadwal"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"items": items})
}

// DELETE /api/jadwal-requests/:id
func (h *Handler) DeleteJadwalRequest(c *gin.Context) {
	userID := c.GetUint("userID")

	var jr JadwalRequest
	// user_id ikut di WHERE supaya tidak bisa menghapus jadwal milik orang lain
	if err := h.DB.Where("id = ? AND user_id = ?", c.Param("id"), userID).
		First(&jr).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Jadwal tidak ditemukan"})
		return
	}
	if err := h.DB.Delete(&jr).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Gagal menghapus jadwal"})
		return
	}
	if jr.AttachmentPath != "" {
		os.Remove(filepath.Join(uploadsDir, jr.AttachmentPath))
	}
	c.JSON(http.StatusOK, gin.H{"message": "Jadwal berhasil dihapus"})
}
