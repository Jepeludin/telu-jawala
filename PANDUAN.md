# Panduan: Login Page JAWALA (Flutter + Golang + PostgreSQL)

Contoh ini berisi halaman **Login**, **Registrasi**, dan **Dashboard** sederhana (menampilkan nama user dan tombol Logout), lengkap dengan backend REST API.

```
Flutter (Android)  --HTTP/JSON-->  Golang (Gin)  --GORM-->  PostgreSQL
   login_page.dart                  /api/login                tabel users
```

## 1. Yang perlu diinstal

| Tool | Kegunaan | Cek instalasi |
|---|---|---|
| Go 1.21+ (go.dev/dl) | Backend | `go version` |
| PostgreSQL 14+ | Database | `psql --version` |
| Flutter SDK (docs.flutter.dev/get-started/install) | Aplikasi mobile | `flutter doctor` |
| Android Studio | Android SDK dan emulator | Buat emulator di Device Manager |
| VS Code (opsional) | Editor, tambahkan ekstensi Go, Flutter, Dart | |

Jalankan `flutter doctor` dan pastikan bagian Android toolchain bertanda centang.

## 2. Buat database

Buka terminal `psql` (atau DBeaver), lalu jalankan:

```sql
CREATE DATABASE jawala;
```

Tabel `users` tidak perlu dibuat manual. Backend membuatnya otomatis lewat `AutoMigrate`.

## 3. Backend (Golang)

### 3.1 Buat project
```bash
mkdir jawala && cd jawala
mkdir backend && cd backend
go mod init jawala-backend
```

### 3.2 Salin file
Salin `main.go`, `models.go`, dan `handlers.go` dari folder `backend/` di paket ini ke folder tersebut.

### 3.3 Instal dependency
```bash
go get github.com/gin-gonic/gin
go get gorm.io/gorm gorm.io/driver/postgres
go get github.com/golang-jwt/jwt/v5
go get golang.org/x/crypto
go mod tidy
```

### 3.4 Konfigurasi (opsional)
Secara bawaan backend memakai user `postgres`, password `postgres`, database `jawala`. Jika berbeda, atur environment variable:

**Windows (PowerShell)**
```powershell
$env:DATABASE_URL="host=localhost user=postgres password=PASSWORDMU dbname=jawala port=5432 sslmode=disable"
$env:JWT_SECRET="isi-dengan-teks-acak-yang-panjang"
```
**Mac/Linux**
```bash
export DATABASE_URL="host=localhost user=postgres password=PASSWORDMU dbname=jawala port=5432 sslmode=disable"
export JWT_SECRET="isi-dengan-teks-acak-yang-panjang"
```

### 3.5 Jalankan
```bash
go run .
```
Jika berhasil akan muncul `server berjalan di :8080`.

### 3.6 Uji dengan curl atau Postman
```bash
# Daftar
curl -X POST http://localhost:8080/api/register -H "Content-Type: application/json" \
  -d '{"nama_lengkap":"Budi","nim":"1304221001","email":"budi@student.telkomuniversity.ac.id","password":"rahasia123"}'

# Login (hasilnya berisi token)
curl -X POST http://localhost:8080/api/login -H "Content-Type: application/json" \
  -d '{"email":"budi@student.telkomuniversity.ac.id","password":"rahasia123"}'

# Data user (ganti TOKEN dengan token dari login)
curl http://localhost:8080/api/me -H "Authorization: Bearer TOKEN"
```

| Endpoint | Method | Keterangan |
|---|---|---|
| `/api/register` | POST | Membuat akun (password di-hash dengan bcrypt) |
| `/api/login` | POST | Mengembalikan JWT (berlaku 24 jam) |
| `/api/me` | GET | Data user, wajib header `Authorization: Bearer <token>` |

## 4. Aplikasi Flutter

### 4.1 Buat project
Dari folder `jawala/` (di luar `backend`):
```bash
flutter create mobile
cd mobile
```

### 4.2 Tambah dependency
```bash
flutter pub add http shared_preferences
```
`http` untuk memanggil API, `shared_preferences` untuk menyimpan token di perangkat.

### 4.3 Ganti isi folder `lib/`
Hapus `lib/main.dart` bawaan, lalu salin dari paket ini:
```
lib/main.dart
lib/services/api_service.dart
lib/pages/login_page.dart
lib/pages/register_page.dart
lib/pages/home_page.dart
```
(Buat folder `pages` dan `services` di dalam `lib/` jika belum ada.)

### 4.4 Izinkan koneksi ke backend (Android)
Buka `android/app/src/main/AndroidManifest.xml`. Tambahkan izin internet sebelum tag `<application>`, dan atribut `usesCleartextTraffic` di dalam tag `<application>`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET"/>

    <application
        android:usesCleartextTraffic="true"
        android:label="mobile"
        ... >
```
`usesCleartextTraffic` diperlukan karena saat development kita memakai `http://` (bukan `https://`). Hapus atribut ini dan pakai HTTPS saat aplikasi dirilis.

### 4.5 Sesuaikan alamat server
Di `lib/services/api_service.dart`:

| Dijalankan di | Isi `baseUrl` |
|---|---|
| Android Emulator | `http://10.0.2.2:8080/api` (bawaan) |
| HP fisik (satu Wi-Fi dengan laptop) | `http://IP-LAPTOP:8080/api`, mis. `http://192.168.1.10:8080/api` |

Untuk HP fisik, pastikan firewall laptop mengizinkan port 8080.

### 4.6 Jalankan
Nyalakan emulator dari Android Studio (Device Manager), pastikan backend masih berjalan, lalu:
```bash
flutter run
```

## 5. Alur uji coba
1. Aplikasi terbuka di halaman Login. Ketuk **Belum punya akun? Daftar**.
2. Isi form registrasi. Password minimal 8 karakter dan konfirmasinya harus sama.
3. Kembali ke Login, masuk dengan email dan password tadi.
4. Dashboard menampilkan "Hello, <nama>". Tutup aplikasi lalu buka lagi: langsung masuk Dashboard karena token tersimpan.
5. Ketuk ikon logout di kanan atas: token dihapus dan kembali ke Login.

## 6. Kesesuaian dengan DPPL

| Bagian DPPL | Di kode |
|---|---|
| Use Case #1 Registrasi Akun (validasi kolom kosong, "Password tidak cocok!") | `register_page.dart`, `Register()` |
| Use Case #2 Login (pesan "Email atau Password salah") | `login_page.dart`, `Login()` |
| Use Case #3 Logout (hapus sesi, kembali ke login) | `home_page.dart` (`_logout`) |
| Class diagram: `verifyLogin()`, `registrasiAccount()`, `getUser()` | `Login()`, `Register()`, `Me()` |

Yang berbeda dari DPPL, dan sebaiknya dicatat saat revisi dokumen:
- Query login memakai **query terparameter dan bcrypt**, bukan `WHERE password = password` seperti di contoh algoritma DPPL.
- Sesi memakai **JWT di sisi client**, jadi logout menghapus token di perangkat (bukan menghapus sesi di database).
- Field alamat dan tanggal lahir belum dimasukkan. Tambahkan kolom di `models.go` dan form jika diperlukan.
- Login SSO Telkom, verifikasi email, dan reset password belum ada.

## 7. Masalah umum

| Gejala | Penyebab dan solusi |
|---|---|
| "Tidak dapat terhubung ke server" | Backend belum jalan, `baseUrl` salah, atau izin INTERNET / `usesCleartextTraffic` belum ditambahkan |
| `gagal terhubung ke database` | Password atau nama database salah, atau PostgreSQL belum berjalan. Periksa `DATABASE_URL` |
| `go: cannot find module` | Jalankan `go mod tidy` di folder `backend` |
| Email atau NIM sudah digunakan | Data sudah terdaftar, gunakan yang lain |
| Emulator tidak bisa membuka `localhost` | Di emulator, `localhost` adalah emulator itu sendiri. Pakai `10.0.2.2` |

## 8. Langkah berikutnya
- Halaman **Profil** dan **Edit Profil** (endpoint `PUT /api/me`).
- Tabel `jadwal` beserta CRUD (Use Case #4–#7), memakai middleware `AuthRequired` yang sama.
- Notifikasi dengan Firebase Cloud Messaging (Use Case #8).
- Pindahkan token ke `flutter_secure_storage` dan gunakan HTTPS saat rilis.
