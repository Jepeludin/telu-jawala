package main

import (
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
)

type createKelasRequest struct {
	Nama string `json:"nama" binding:"required"`
}

// GET /api/kelas -> daftar kelas milik user yang login
func (h *Handler) ListKelas(c *gin.Context) {
	userID := c.GetUint("userID")

	items := make([]Kelas, 0)
	if err := h.DB.Where("user_id = ?", userID).
		Order("nama ASC").Find(&items).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Gagal memuat kelas"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"items": items})
}

// POST /api/kelas
func (h *Handler) CreateKelas(c *gin.Context) {
	userID := c.GetUint("userID")

	var req createKelasRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Nama kelas wajib diisi"})
		return
	}
	nama := strings.TrimSpace(req.Nama)
	if nama == "" || len(nama) > 50 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Nama kelas 1-50 karakter"})
		return
	}

	var count int64
	h.DB.Model(&Kelas{}).Where("user_id = ? AND nama = ?", userID, nama).Count(&count)
	if count > 0 {
		c.JSON(http.StatusConflict, gin.H{"error": "Kelas sudah ada"})
		return
	}

	kelas := Kelas{UserID: userID, Nama: nama}
	if err := h.DB.Create(&kelas).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Gagal menambah kelas"})
		return
	}
	c.JSON(http.StatusCreated, gin.H{"message": "Kelas berhasil ditambahkan", "kelas": kelas})
}
