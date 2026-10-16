import 'package:flutter/material.dart';

import '../services/api_service.dart';
import 'home_page.dart';
import 'register_page.dart';

const _red = Color(0xFFF45656);
const _grey = Color(0xFFA4A4A4);
const _border = Color(0xFFDBDBDB);
const _divider = Color(0xFFD9D9D9);
const _textColor = Color(0xFF555555);

// Samakan path ini dengan yang dipakai di register_page.dart.
// Pastikan foldernya sudah terdaftar di pubspec.yaml (flutter: assets:).
const _logoAsset = 'assets/images/logo_telkom_university.png';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _showPassword = false;
  bool _loading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final result =
        await ApiService.login(_emailCtrl.text.trim(), _passwordCtrl.text);

    if (!mounted) return;
    setState(() => _loading = false);

    if (result.ok) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(result.message)));
    }
  }

  OutlineInputBorder _outline(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: color, width: 1.5),
      );

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required String? Function(String?) validator,
    TextInputType? keyboardType,
    bool obscure = false,
    Widget? suffix,
    Iterable<String>? autofillHints,
    TextInputAction? textInputAction,
    VoidCallback? onSubmitted,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscure,
        autofillHints: autofillHints,
        textInputAction: textInputAction,
        onFieldSubmitted: onSubmitted == null ? null : (_) => onSubmitted(),
        validator: validator,
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
          suffixIcon: suffix,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 371),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Image.asset(
                        _logoAsset,
                        width: 157,
                        height: 153,
                        fit: BoxFit.cover,
                        semanticLabel: 'Telkom University',
                        errorBuilder: (_, __, ___) => const SizedBox(
                          width: 157,
                          height: 153,
                          child: Icon(Icons.school_outlined,
                              size: 80, color: _grey),
                        ),
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      height: 1,
                      color: _divider,
                    ),
                    const SizedBox(height: 15),
                    const Center(
                      child: Text(
                        'LOGIN AKUN',
                        style: TextStyle(
                          fontSize: 20,
                          height: 1,
                          letterSpacing: -0.40,
                          color: _grey,
                        ),
                      ),
                    ),
                    const SizedBox(height: 44),
                    _field(
                      controller: _emailCtrl,
                      hint: 'Email Address',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      textInputAction: TextInputAction.next,
                      validator: (v) {
                        final value = v?.trim() ?? '';
                        if (value.isEmpty) return 'Kolom harus diisi';
                        if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                            .hasMatch(value)) {
                          return 'Format email tidak valid';
                        }
                        return null;
                      },
                    ),
                    _field(
                      controller: _passwordCtrl,
                      hint: 'Password',
                      icon: Icons.lock_outline,
                      obscure: !_showPassword,
                      autofillHints: const [AutofillHints.password],
                      textInputAction: TextInputAction.done,
                      onSubmitted: _loading ? null : _submit,
                      suffix: Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: IconButton(
                          onPressed: () =>
                              setState(() => _showPassword = !_showPassword),
                          padding: EdgeInsets.zero,
                          constraints:
                              const BoxConstraints(minWidth: 28, minHeight: 28),
                          tooltip: _showPassword
                              ? 'Sembunyikan password'
                              : 'Tampilkan password',
                          icon: Icon(
                            _showPassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 20,
                            color: _grey,
                          ),
                        ),
                      ),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Kolom harus diisi' : null,
                    ),
                    const SizedBox(height: 40),
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
                            : const Text('Sign In'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _loading
                          ? null
                          : () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const RegisterPage(),
                                ),
                              ),
                      child: const Text.rich(
                        TextSpan(
                          text: 'Belum punya akun? ',
                          style: TextStyle(fontSize: 14, color: _grey),
                          children: [
                            TextSpan(
                              text: 'Daftar',
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