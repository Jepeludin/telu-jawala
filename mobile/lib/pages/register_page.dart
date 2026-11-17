import 'package:flutter/material.dart';

import '../services/api_service.dart';

const _red = Color(0xFFF45656);
const _grey = Color(0xFFA4A4A4);
const _border = Color(0xFFDBDBDB);
const _divider = Color(0xFFD9D9D9);
const _textColor = Color(0xFF555555);

// Ganti path ini jika file logo Anda berbeda. Pastikan foldernya
// sudah terdaftar di pubspec.yaml (flutter: assets:).
const _logoAsset = 'assets/images/logo_telkom_university.png';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _namaCtrl = TextEditingController();
  final _nimCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _alamatCtrl = TextEditingController();
  final _tanggalCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  bool _showPassword = false;
  bool _showConfirmation = false;
  bool _loading = false;

  @override
  void dispose() {
    for (final c in [
      _namaCtrl,
      _nimCtrl,
      _usernameCtrl,
      _emailCtrl, // baru
      _passCtrl,
      _confirmCtrl,
      _alamatCtrl,
      _tanggalCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Kolom harus diisi' : null;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 20, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) {
      final mm = picked.month.toString().padLeft(2, '0');
      final dd = picked.day.toString().padLeft(2, '0');
      _tanggalCtrl.text = '${picked.year}-$mm-$dd';
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final result = await ApiService.register(
      namaLengkap: _namaCtrl.text.trim(),
      nim: _nimCtrl.text.trim(),
      username: _usernameCtrl.text.trim(),
      email: _emailCtrl.text.trim(), // baru
      password: _passCtrl.text,
      alamat: _alamatCtrl.text.trim(),
      tanggalLahir: _tanggalCtrl.text.trim(),
    );

    if (!mounted) return;
    setState(() => _loading = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(result.message)));
    if (result.ok) Navigator.of(context).pop();
  }

  OutlineInputBorder _outline(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: color, width: 1.5),
      );

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    bool obscure = false,
    bool requiredMark = false,
    Widget? suffix,
    bool readOnly = false,
    VoidCallback? onTap,
    Iterable<String>? autofillHints,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscure,
        readOnly: readOnly,
        onTap: onTap,
        autofillHints: autofillHints,
        validator: validator ?? _required,
        style: const TextStyle(
          fontSize: 14,
          letterSpacing: -0.28,
          color: _textColor,
          height: 20 / 14,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            fontSize: 14,
            letterSpacing: -0.28,
            color: _grey,
          ),
          filled: true,
          fillColor: Colors.white,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 19),
          errorStyle: const TextStyle(fontSize: 12, color: _red),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 14),
            child: Align(
              alignment: Alignment.centerLeft,
              widthFactor: 1,
              child: Icon(icon, size: 24, color: _grey),
            ),
          ),
          prefixIconConstraints:
              const BoxConstraints(minWidth: 70, minHeight: 58),
          suffixIcon: suffix ??
              (requiredMark
                  ? Padding(
                      padding: const EdgeInsets.only(right: 20),
                      child: Center(
                        widthFactor: 1,
                        child: Transform.translate(
                          // glyph "*" secara bawaan tampil di bagian atas baris
                          offset: Offset(0, 5),
                          child: Text(
                            '*',
                            style: TextStyle(
                                fontSize: 20, height: 1, color: _grey),
                          ),
                        ),
                      ),
                    )
                  : null),
          suffixIconConstraints:
              const BoxConstraints(minWidth: 45, minHeight: 58),
          enabledBorder: _outline(_border),
          focusedBorder: _outline(_red),
          errorBorder: _outline(_red),
          focusedErrorBorder: _outline(_red),
        ),
      ),
    );
  }

  Widget _eyeButton({required bool visible, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: IconButton(
        onPressed: onTap,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        icon: Icon(
          visible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          size: 20,
          color: _grey,
        ),
        tooltip: visible ? 'Sembunyikan password' : 'Tampilkan password',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 371),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 22, 16, 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Image.asset(
                        _logoAsset,
                        width: 108,
                        height: 106,
                        fit: BoxFit.cover,
                        semanticLabel: 'Logo Telkom University',
                        errorBuilder: (_, __, ___) => const SizedBox(
                          width: 108,
                          height: 106,
                          child: Icon(Icons.school_outlined,
                              size: 64, color: _grey),
                        ),
                      ),
                    ),
                    const SizedBox(height: 0),
                    Container(
                      margin: const EdgeInsets.fromLTRB(4, 0, 4, 0),
                      height: 1,
                      color: _divider,
                    ),
                    const SizedBox(height: 22),
                    const Center(
                      child: Text(
                        'REGISTRASI AKUN',
                        style: TextStyle(
                          fontSize: 20,
                          height: 1,
                          letterSpacing: -0.40,
                          color: _grey,
                        ),
                      ),
                    ),
                    const SizedBox(height: 26),
                    _field(
                      controller: _namaCtrl,
                      hint: 'Nama Lengkap',
                      icon: Icons.person_outline,
                      requiredMark: true,
                      autofillHints: const [AutofillHints.name],
                    ),
                    _field(
                      controller: _nimCtrl,
                      hint: 'NIM',
                      icon: Icons.badge_outlined,
                      keyboardType: TextInputType.number,
                      requiredMark: true,
                    ),
                    _field(
                      controller: _usernameCtrl,
                      hint: 'Username',
                      icon: Icons.account_circle_outlined,
                      requiredMark: true,
                      autofillHints: const [AutofillHints.username],
                    ),
                    _field(
                      controller: _emailCtrl,
                      hint: 'Email Address',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      requiredMark: true,
                      autofillHints: const [AutofillHints.email],
                      validator: (v) {
                        final value = v?.trim() ?? '';
                        if (value.isEmpty) return 'Kolom harus diisi';
                        if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) {
                          return 'Format email tidak valid';
                        }
                        return null;
                      },
                    ),
                    _field(
                      controller: _passCtrl,
                      hint: 'Password',
                      icon: Icons.lock_outline,
                      obscure: !_showPassword,
                      autofillHints: const [AutofillHints.newPassword],
                      suffix: _eyeButton(
                        visible: _showPassword,
                        onTap: () =>
                            setState(() => _showPassword = !_showPassword),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Kolom harus diisi';
                        if (v.length < 8) return 'Password minimal 8 karakter';
                        return null;
                      },
                    ),
                    _field(
                      controller: _confirmCtrl,
                      hint: 'Konfirmasi Password',
                      icon: Icons.lock_outline,
                      obscure: !_showConfirmation,
                      autofillHints: const [AutofillHints.newPassword],
                      suffix: _eyeButton(
                        visible: _showConfirmation,
                        onTap: () => setState(
                            () => _showConfirmation = !_showConfirmation),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Kolom harus diisi';
                        if (v != _passCtrl.text) {
                          return 'Password dan konfirmasi password harus sama.';
                        }
                        return null;
                      },
                    ),
                    _field(
                      controller: _alamatCtrl,
                      hint: 'Alamat',
                      icon: Icons.location_on_outlined,
                      autofillHints: const [AutofillHints.fullStreetAddress],
                    ),
                    _field(
                      controller: _tanggalCtrl,
                      hint: 'Tanggal Lahir',
                      icon: Icons.calendar_month_outlined,
                      readOnly: true,
                      onTap: _pickDate,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 58,
                      child: FilledButton(
                        onPressed: _loading ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: _red,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.36,
                          ),
                        ),
                        child: _loading
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Register'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed:
                          _loading ? null : () => Navigator.of(context).pop(),
                      child: const Text.rich(
                        TextSpan(
                          text: 'Sudah punya akun? ',
                          style: TextStyle(fontSize: 14, color: _grey),
                          children: [
                            TextSpan(
                              text: 'Kembali ke Login',
                              style: TextStyle(
                                color: _red,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}