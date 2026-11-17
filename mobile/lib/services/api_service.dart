import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiResult {
  final bool ok;
  final String message;
  final Map<String, dynamic>? data;
  ApiResult({required this.ok, required this.message, this.data});
}

class ApiService {
  // 10.0.2.2 = alamat "localhost" komputer Anda jika dijalankan di Android Emulator.
  // HP fisik: ganti dengan IP laptop, mis. http://192.168.1.10:8080/api
  static String get baseUrl =>
      kIsWeb ? 'http://localhost:8080/api' : 'http://10.0.2.2:8080/api';
  static const String _tokenKey = 'jwt_token';

  // ---------------------------------------------------------------------------
  // Auth
  // ---------------------------------------------------------------------------

  static Future<ApiResult> login(String email, String password) async {
    final result =
        await _post('/login', {'email': email, 'password': password}, 200);
    if (result.ok && result.data?['token'] != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, result.data!['token'] as String);
    }
    return result;
  }

  static Future<ApiResult> register({
    required String namaLengkap,
    required String nim,
    required String username,
    required String email,
    required String password,
    required String alamat,
    required String tanggalLahir, // yyyy-MM-dd
  }) {
    return _post('/register', {
      'nama_lengkap': namaLengkap,
      'nim': nim,
      'username': username,
      'email': email,
      'password': password,
      'alamat': alamat,
      'tanggal_lahir': tanggalLahir,
    }, 201);
  }

  static Future<ApiResult> me() {
    return _authed(
      (token) => http.get(Uri.parse('$baseUrl/me'),
          headers: {'Authorization': 'Bearer $token'}),
      'Gagal memuat data',
    );
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  // ---------------------------------------------------------------------------
  // Kelas
  // ---------------------------------------------------------------------------

  static Future<ApiResult> listKelas() {
    return _authed(
      (token) => http.get(Uri.parse('$baseUrl/kelas'),
          headers: {'Authorization': 'Bearer $token'}),
      'Gagal memuat kelas',
    );
  }

  static Future<ApiResult> createKelas(String nama) {
    return _authed(
      (token) => http.post(
        Uri.parse('$baseUrl/kelas'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'nama': nama}),
      ),
      'Gagal menambah kelas',
      successCode: 201,
    );
  }

  // ---------------------------------------------------------------------------
  // Jadwal
  // ---------------------------------------------------------------------------

  static Future<ApiResult> createJadwalRequest({
    required int kelasId,
    required String scheduledAt, // yyyy-MM-dd HH:mm
    required String note,
    String? fileName,
    List<int>? fileBytes,
  }) {
    return _authed(
      (token) async {
        final req =
            http.MultipartRequest('POST', Uri.parse('$baseUrl/jadwal-requests'))
              ..headers['Authorization'] = 'Bearer $token'
              ..fields['kelas_id'] = kelasId.toString()
              ..fields['scheduled_at'] = scheduledAt
              ..fields['note'] = note;
        if (fileName != null && fileBytes != null) {
          req.files.add(http.MultipartFile.fromBytes('attachment', fileBytes,
              filename: fileName));
        }
        final streamed = await req.send();
        return http.Response.fromStream(streamed);
      },
      'Gagal mengirim permintaan',
      successCode: 201,
      timeout: const Duration(seconds: 30),
    );
  }

  static Future<ApiResult> listJadwalRequests() {
    return _authed(
      (token) => http.get(Uri.parse('$baseUrl/jadwal-requests'),
          headers: {'Authorization': 'Bearer $token'}),
      'Gagal memuat jadwal',
    );
  }

  static Future<ApiResult> deleteJadwalRequest(int id) {
    return _authed(
      (token) => http.delete(Uri.parse('$baseUrl/jadwal-requests/$id'),
          headers: {'Authorization': 'Bearer $token'}),
      'Gagal menghapus jadwal',
    );
  }

  // ---------------------------------------------------------------------------
  // Admin
  // ---------------------------------------------------------------------------

  static Future<ApiResult> listUsers() {
    return _authed(
      (token) => http.get(Uri.parse('$baseUrl/admin/users'),
          headers: {'Authorization': 'Bearer $token'}),
      'Gagal memuat daftar akun',
    );
  }

  // ---------------------------------------------------------------------------
  // Foto profil
  // ---------------------------------------------------------------------------

  // Alamat server tanpa "/api", untuk membentuk URL foto
  static String get origin => baseUrl.replaceFirst(RegExp(r'/api$'), '');

  /// Mengubah path dari server (/uploads/avatars/x.jpg) menjadi URL lengkap.
  /// Mengembalikan null kalau user belum punya foto.
  static String? photoUrl(dynamic path) {
    final p = path?.toString() ?? '';
    if (p.isEmpty) return null;
    if (p.startsWith('http')) return p;
    return '$origin$p';
  }

  static Future<ApiResult> uploadPhoto({
    required String fileName,
    required List<int> bytes,
  }) {
    return _authed(
      (token) async {
        final req = http.MultipartRequest('POST', Uri.parse('$baseUrl/me/photo'))
          ..headers['Authorization'] = 'Bearer $token'
          ..files.add(
              http.MultipartFile.fromBytes('photo', bytes, filename: fileName));
        final streamed = await req.send();
        return http.Response.fromStream(streamed);
      },
      'Gagal mengunggah foto',
      timeout: const Duration(seconds: 30),
    );
  }

  // ---------------------------------------------------------------------------
  // Helper
  // ---------------------------------------------------------------------------

  // Request tanpa JWT (login, register)
  static Future<ApiResult> _post(
      String path, Map<String, dynamic> body, int successCode) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl$path'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == successCode) {
        return ApiResult(
            ok: true,
            message: json['message']?.toString() ?? 'Berhasil',
            data: json);
      }
      return ApiResult(
          ok: false, message: json['error']?.toString() ?? 'Terjadi kesalahan');
    } on SocketException {
      return ApiResult(ok: false, message: 'Tidak dapat terhubung ke server');
    } on TimeoutException {
      return ApiResult(ok: false, message: 'Server tidak merespons');
    } catch (_) {
      return ApiResult(ok: false, message: 'Terjadi kesalahan');
    }
  }

  // Request ber-JWT (respons sukses default 200)
  static Future<ApiResult> _authed(
    Future<http.Response> Function(String token) call,
    String failMessage, {
    int successCode = 200,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final token = await getToken();
    if (token == null) return ApiResult(ok: false, message: 'Belum login');
    try {
      final res = await call(token).timeout(timeout);
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == successCode) {
        return ApiResult(
            ok: true, message: body['message']?.toString() ?? 'OK', data: body);
      }
      return ApiResult(
          ok: false, message: body['error']?.toString() ?? failMessage);
    } on SocketException {
      return ApiResult(ok: false, message: 'Tidak dapat terhubung ke server');
    } on TimeoutException {
      return ApiResult(ok: false, message: 'Server tidak merespons');
    } catch (_) {
      return ApiResult(ok: false, message: 'Terjadi kesalahan');
    }
  }
}