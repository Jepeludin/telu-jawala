import 'dart:async';

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import 'login_page.dart';

// ============================================================
// Design tokens (diambil dari desain Tailwind / Figma)
// ============================================================
const Color kPrimary = Color(0xFFF45656); // jam, aksen utama
const Color kPrimarySoft = Color(0xFFF18080); // kartu & judul "Ringkasan"
const Color kBorder = Color(0xFFDBDBDB); // border tile
const Color kDivider = Color(0xFFD9D9D9); // garis pemisah
const Color kTextMuted = Color(0xFFA4A4A4); // teks abu-abu
const Color kTextLabel = Color(0xFF5D5D5D); // label tile
const Color kNavActive = Color(0xFF567DF4); // menu bawah aktif
const String kFont = 'Inter';

TextStyle _t(double size, Color color,
    {FontWeight weight = FontWeight.w400, double letterSpacing = 0}) {
  return TextStyle(
    fontFamily: kFont,
    fontSize: size,
    color: color,
    fontWeight: weight,
    letterSpacing: letterSpacing,
  );
}

// ============================================================
// HomePage = kerangka (bottom navigation + 4 tab)
// ============================================================
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<ApiResult> _userFuture;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _userFuture = ApiService.me();
  }

  Future<void> _logout() async {
    await ApiService.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ApiResult>(
      future: _userFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final result = snapshot.data!;
        if (!result.ok) {
          // Token tidak valid / kedaluwarsa -> kembali ke login
          WidgetsBinding.instance.addPostFrameCallback((_) => _logout());
          return Scaffold(body: Center(child: Text(result.message)));
        }
        final user = result.data!;

        final pages = <Widget>[
          DashboardTab(user: user, onOpenTab: (i) => setState(() => _index = i)),
          const _PlaceholderTab(title: 'Jadwal'),
          const _PlaceholderTab(title: 'Setting'),
          ProfileTab(user: user, onLogout: _logout),
        ];

        return Scaffold(
          backgroundColor: Colors.white,
          body: IndexedStack(index: _index, children: pages),
          bottomNavigationBar: _BottomNav(
            index: _index,
            onTap: (i) => setState(() => _index = i),
          ),
        );
      },
    );
  }
}

// ============================================================
// Bottom navigation custom (putih, sudut atas 16, shadow ke atas)
// ============================================================
class _NavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  const _NavItem(this.icon, this.selectedIcon, this.label);
}

class _BottomNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  const _BottomNav({required this.index, required this.onTap});

  static const _items = [
    _NavItem(Icons.home_outlined, Icons.home, 'Home'),
    _NavItem(Icons.history, Icons.history, 'Jadwal'),
    _NavItem(Icons.settings_outlined, Icons.settings, 'Setting'),
    _NavItem(Icons.person_outline, Icons.person, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Color(0x0F000000), // #0000000f
            blurRadius: 16,
            offset: Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: [
              for (var i = 0; i < _items.length; i++)
                Expanded(
                  child: InkWell(
                    onTap: () => onTap(i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          i == index ? _items[i].selectedIcon : _items[i].icon,
                          size: 21,
                          color: i == index ? kNavActive : kTextMuted,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _items[i].label,
                          style: _t(12, i == index ? kNavActive : kTextMuted),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// Tab 1: Dashboard
// ============================================================
class DashboardTab extends StatefulWidget {
  final Map<String, dynamic> user;
  final void Function(int) onOpenTab;
  const DashboardTab({super.key, required this.user, required this.onOpenTab});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  static const _hari = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
  static const _bulan = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
  ];

  Timer? _timer;
  late DateTime _now;

  // Waktu WIB (UTC+7), tidak tergantung zona waktu perangkat
  DateTime get _wib => DateTime.now().toUtc().add(const Duration(hours: 7));

  @override
  void initState() {
    super.initState();
    _now = _wib;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = _wib);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  void _soon(String fitur) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$fitur: segera hadir')));
  }

  @override
  Widget build(BuildContext context) {
    final nama = (widget.user['nama_lengkap'] ?? 'Mahasiswa').toString();
    final firstName = nama.trim().split(' ').first;
    final initial = nama.isNotEmpty ? nama[0].toUpperCase() : '?';

    final jam = '${_two(_now.hour)}:${_two(_now.minute)} WIB';
    final tanggal =
        '${_hari[_now.weekday - 1]}, ${_now.day} ${_bulan[_now.month - 1]} ${_now.year}';

    // Desain: avatar mulai di y=46 (di bawah status bar)
    final topInset = MediaQuery.of(context).padding.top;
    final headerTop = topInset > 38 ? topInset + 8 : 46.0;

    return SingleChildScrollView(
      child: Column(
        children: [
          // ---------- Header merah + kartu jam ----------
          SizedBox(
            height: 394,
            child: Stack(
              children: [
                Container(
                  height: 380,
                  width: double.infinity,
                  padding: EdgeInsets.fromLTRB(18, headerTop, 18, 0),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [kPrimary, kPrimarySoft],
                    ),
                    borderRadius:
                        BorderRadius.vertical(bottom: Radius.elliptical(375, 70)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.white,
                        child: Text(initial,
                            style: _t(20, kPrimary, weight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 15),
                          child: Text('Hello, $firstName',
                              overflow: TextOverflow.ellipsis,
                              style: _t(18, Colors.white, letterSpacing: -0.36)),
                        ),
                      ),
                      InkWell(
                        onTap: () => _soon('Notifikasi'),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white, width: 1.5),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.notifications_none,
                              color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  top: 121,
                  height: 233,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(jam, style: _t(32, kPrimary, weight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(tanggal, style: _t(12, kTextMuted)),
                        const SizedBox(height: 18),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40),
                          child: Container(height: 2, color: kDivider),
                        ),
                        const SizedBox(height: 18),
                        Text('Jadwal Anda Hari Ini',
                            style: _t(14, kTextMuted, weight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        // TODO: ganti dengan data jadwal dari API
                        Text('08:00 WIB -  16:00 WIB',
                            style: _t(20, Colors.black, weight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ---------- 4 shortcut (2 x 2, tile 97 x 97) ----------
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 270),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 69,
              runSpacing: 25,
              children: [
                _IconTile(
                    icon: Icons.event_note_outlined,
                    label: 'Reg. Jadwal',
                    onTap: () => _soon('Registrasi Jadwal')),
                _IconTile(
                    icon: Icons.calendar_month_outlined,
                    label: 'Jadwal',
                    onTap: () => widget.onOpenTab(1)),
                _IconTile(
                    icon: Icons.event_available_outlined,
                    label: 'Notifikasi',
                    onTap: () => _soon('Notifikasi')),
                _IconTile(
                    icon: Icons.edit_notifications_outlined,
                    label: 'Edit Notifikasi',
                    onTap: () => _soon('Edit Notifikasi')),
              ],
            ),
          ),

          // ---------- Ringkasan ----------
          const SizedBox(height: 15),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25),
            child: Container(height: 3, color: kDivider),
          ),
          const SizedBox(height: 9),
          Text('Ringkasan',
              style: _t(17, kPrimarySoft, letterSpacing: -0.40)),
          const SizedBox(height: 11),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: kPrimarySoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _IconTile(
                      icon: Icons.pie_chart_outline,
                      label: 'Grafik',
                      onTap: () => _soon('Grafik ringkasan')),
                  const SizedBox(width: 40),
                  _IconTile(
                      icon: Icons.table_chart_outlined,
                      label: 'Tabel',
                      onTap: () => _soon('Tabel ringkasan')),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// Tile putih 97x97, radius 18, border 1.5 #dbdbdb, ikon 40, label 12
class _IconTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _IconTile({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 97,
      height: 97,
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: kBorder, width: 1.5),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Column(
            children: [
              const SizedBox(height: 14),
              Icon(icon, size: 40, color: kPrimary),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: _t(12, kTextLabel)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// Tab 4: Profile (berisi tombol Logout)
// ============================================================
class ProfileTab extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback onLogout;
  const ProfileTab({super.key, required this.user, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    final nama = (user['nama_lengkap'] ?? '').toString();
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 16),
          Center(
            child: CircleAvatar(
              radius: 44,
              backgroundColor: kPrimary,
              child: Text(nama.isNotEmpty ? nama[0].toUpperCase() : '?',
                  style: const TextStyle(fontSize: 36, color: Colors.white)),
            ),
          ),
          const SizedBox(height: 12),
          Center(
              child: Text(nama,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
          Center(child: Text('NIM: ${user['nim']}')),
          Center(
              child: Text(user['email'].toString(),
                  style: const TextStyle(color: kTextMuted))),
          const SizedBox(height: 24),
          const ListTile(title: Text('Edit Profile'), trailing: Icon(Icons.chevron_right)),
          const ListTile(title: Text('Kelas'), trailing: Icon(Icons.chevron_right)),
          const ListTile(
              title: Text('Perangkat Terdaftar'), trailing: Icon(Icons.chevron_right)),
          const SizedBox(height: 16),
          SizedBox(
            height: 50,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: kPrimary),
              onPressed: onLogout,
              child: const Text('Logout'),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Tab sementara untuk Jadwal & Setting
// ============================================================
class _PlaceholderTab extends StatelessWidget {
  final String title;
  const _PlaceholderTab({required this.title});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text('Halaman $title: segera hadir',
          style: const TextStyle(color: kTextMuted)),
    );
  }
}