import 'package:flutter/material.dart';

import '../services/api_service.dart';

const _red = Color(0xFFF45656);
const _grey = Color(0xFFA4A4A4);
const _border = Color(0xFFDBDBDB);
const _textColor = Color(0xFF555555);
const _backBlue = Color(0xFF4D7CFE);

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    final res = await ApiService.listUsers();
    if (!mounted) return;
    if (!res.ok) {
      setState(() {
        _loading = false;
        _error = res.message;
      });
      return;
    }
    setState(() {
      _users = (res.data?['items'] as List? ?? []).cast<Map<String, dynamic>>();
      _error = null;
      _loading = false;
    });
  }

  Widget _backButton() {
    return InkWell(
      onTap: () => Navigator.of(context).pop(),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFEEEEEE)),
        ),
        child: const Icon(Icons.chevron_left, size: 28, color: _backBlue),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _red));
    }
    return RefreshIndicator(
      color: _red,
      onRefresh: () => _load(silent: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          if (_error != null) ...[
            const SizedBox(height: 80),
            Center(child: Text(_error!, style: const TextStyle(color: _grey))),
            Center(
              child: TextButton(
                onPressed: _load,
                child: const Text('Coba lagi', style: TextStyle(color: _red)),
              ),
            ),
          ] else ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 12, left: 2),
              child: Text('${_users.length} akun terdaftar',
                  style: const TextStyle(fontSize: 13, color: _grey)),
            ),
            for (final u in _users) _UserTile(user: u),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 4),
              child: Row(
                children: [
                  _backButton(),
                  const SizedBox(width: 24),
                  const Text(
                    'User Management',
                    style: TextStyle(
                        fontSize: 24, letterSpacing: -0.48, color: Color(0xFF221F1F)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 371),
                  child: _body(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  final Map<String, dynamic> user;
  const _UserTile({required this.user});

  @override
  Widget build(BuildContext context) {
    final nama = (user['nama_lengkap'] ?? '').toString();
    final email = (user['email'] ?? '').toString();
    final nim = (user['nim'] ?? '').toString();
    final isAdmin = user['role'] == 'admin';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border, width: 1.5),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: isAdmin ? _red : const Color(0xFFF18080),
            child: Text(nama.isNotEmpty ? nama[0].toUpperCase() : '?',
                style: const TextStyle(fontSize: 18, color: Colors.white)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nama,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600, color: _textColor)),
                const SizedBox(height: 2),
                Text(email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: _grey)),
                Text('NIM: $nim',
                    style: const TextStyle(fontSize: 12, color: _grey)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isAdmin ? _red : const Color(0xFFF2F2F2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              isAdmin ? 'Admin' : 'Mahasiswa',
              style: TextStyle(
                  fontSize: 11, color: isAdmin ? Colors.white : _textColor),
            ),
          ),
        ],
      ),
    );
  }
}