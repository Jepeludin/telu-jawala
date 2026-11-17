package main

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

// Middleware: hanya admin. Role dibaca dari database, bukan dari token,
// jadi tidak bisa dipalsukan dan tidak basi.
func (h *Handler) AdminRequired() gin.HandlerFunc {
	return func(c *gin.Context) {
		var user User
		if err := h.DB.Select("id", "role").First(&user, c.GetUint("userID")).Error; err != nil ||
			user.Role != RoleAdmin {
			c.AbortWithStatusJSON(http.StatusForbidden, gin.H{"error": "Akses ditolak"})
			return
		}
		c.Next()
	}
}

// GET /api/admin/users
func (h *Handler) ListUsers(c *gin.Context) {
	users := make([]User, 0)
	if err := h.DB.Order("id ASC").Find(&users).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Gagal memuat daftar akun"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"items": users}) // PasswordHash sudah json:"-"
}
