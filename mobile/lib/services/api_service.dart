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

  static Future<ApiResult> login(String email, String password) async {
    final result = await _post('/login', {'email': email, 'password': password}, 200);
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
    required String password,
    required String alamat,
    required String tanggalLahir, // yyyy-MM-dd
  }) {
    return _post('/register', {
      'nama_lengkap': namaLengkap,
      'nim': nim,
      'username': username,
      'password': password,
      'alamat': alamat,
      'tanggal_lahir': tanggalLahir,
    }, 201);
  }

  static Future<ApiResult> me() async {
    final token = await getToken();
    if (token == null) return ApiResult(ok: false, message: 'Belum login');
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/me'), headers: {'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 10));
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200) {
        return ApiResult(ok: true, message: 'OK', data: body);
      }
      return ApiResult(ok: false, message: body['error']?.toString() ?? 'Gagal memuat data');
    } on SocketException {
      return ApiResult(ok: false, message: 'Tidak dapat terhubung ke server');
    } on TimeoutException {
      return ApiResult(ok: false, message: 'Server tidak merespons');
    } catch (_) {
      return ApiResult(ok: false, message: 'Terjadi kesalahan');
    }
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

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
            ok: true, message: json['message']?.toString() ?? 'Berhasil', data: json);
      }
      return ApiResult(ok: false, message: json['error']?.toString() ?? 'Terjadi kesalahan');
    } on SocketException {
      return ApiResult(ok: false, message: 'Tidak dapat terhubung ke server');
    } on TimeoutException {
      return ApiResult(ok: false, message: 'Server tidak merespons');
    } catch (_) {
      return ApiResult(ok: false, message: 'Terjadi kesalahan');
    }
  }
}
