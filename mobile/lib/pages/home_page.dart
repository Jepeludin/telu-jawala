import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import 'jadwal_page.dart';
import 'login_page.dart';
import 'notifikasi_page.dart';
import 'reg_jadwal_page.dart';
import 'user_management_page.dart';

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

const int kMaxPhotoBytes = 5 * 1024 * 1024; // 5 MB

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
// Avatar: foto dari server kalau ada, kalau tidak (atau gagal
// dimuat) tampil inisial nama. Dipakai di Home dan Profile.
// ============================================================
class _Avatar extends StatelessWidget {
  final double radius;
  final double fontSize;
  final String initial;
  final String? photoUrl;
  const _Avatar({
    required this.radius,
    required this.fontSize,
    required this.initial,
    required this.photoUrl,
  });

  @override
  Widget build(BuildContext context) {
    final fallback =
        Text(initial, style: _t(fontSize, kPrimary, weight: FontWeight.bold));
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.white,
      child: photoUrl == null
          ? fallback
          : ClipOval(
              child: Image.network(
                photoUrl!,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => fallback,
              ),
            ),
    );
  }
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
  Map<String, dynamic>? _user;
  String? _error;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final result = await ApiService.me();
    if (!mounted) return;
    if (!result.ok) {
      // Token tidak valid / kedaluwarsa -> kembali ke login
      setState(() => _error = result.message);
      _logout();
      return;
    }
    setState(() => _user = result.data);
  }

  // Dipanggil setelah foto profil berhasil diunggah: Home & Profile
  // langsung memakai foto baru tanpa memuat ulang seluruh halaman.
  void _setPhoto(String url) {
    setState(() => _user = {...?_user, 'photo_url': url});
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
    final user = _user;
    if (user == null) {
      return Scaffold(
        body: Center(
          child: _error == null
              ? const CircularProgressIndicator()
              : Text(_error!),
        ),
      );
    }

    final pages = <Widget>[
      DashboardTab(user: user, onOpenTab: (i) => setState(() => _index = i)),
      const _PlaceholderTab(title: 'Jadwal'),
      const _PlaceholderTab(title: 'Setting'),
      ProfileTab(
        user: user,
        onLogout: _logout,
        onBack: () => setState(() => _index = 0), // kembali ke tab Home
        onPhotoChanged: _setPhoto,
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: _BottomNav(
        index: _index,
        onTap: (i) => setState(() => _index = i),
      ),
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
    // Di desain Profile, menu aktifnya berwarna salmon (#F18080), bukan biru
    final active = index == 3 ? kPrimarySoft : kNavActive;

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
                          color: i == index ? active : kTextMuted,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _items[i].label,
                          style: _t(12, i == index ? active : kTextMuted),
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
  List<Map<String, dynamic>> _jadwal = [];

  // Waktu WIB (UTC+7), tidak tergantung zona waktu perangkat
  DateTime get _wib => DateTime.now().toUtc().add(const Duration(hours: 7));

  @override
  void initState() {
    super.initState();
    _now = _wib;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = _wib);
    });
    _loadJadwal();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  // Memuat jadwal milik user. Dipanggil saat tab dibuka dan setiap kali
  // kembali dari halaman Reg. Jadwal / Jadwal (yang bisa mengubah data).
  Future<void> _loadJadwal() async {
    final res = await ApiService.listJadwalRequests();
    if (!mounted || !res.ok) return;
    setState(() {
      _jadwal =
          (res.data?['items'] as List? ?? []).cast<Map<String, dynamic>>();
    });
  }

  // Jadwal terdekat yang belum lewat (jadwal berstatus ditolak diabaikan)
  Map<String, dynamic>? _nextJadwal() {
    final now = DateTime.now().toUtc();
    Map<String, dynamic>? best;
    DateTime? bestAt;
    for (final j in _jadwal) {
      if (j['status'] == 'rejected') continue;
      final at = DateTime.parse(j['scheduled_at'] as String).toUtc();
      if (at.isBefore(now)) continue;
      if (bestAt == null || at.isBefore(bestAt)) {
        best = j;
        bestAt = at;
      }
    }
    return best;
  }

  Future<void> _openAndReload(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    _loadJadwal();
  }

  // Dipakai oleh tombol lonceng di header dan tile "Notifikasi"
  void _openNotifikasi() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NotifikasiPage()),
    );
  }

  void _soon(String fitur) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$fitur: segera hadir')));
  }

  @override
  Widget build(BuildContext context) {
    final nama = (widget.user['nama_lengkap'] ?? 'Mahasiswa').toString();
    final firstName = nama.trim().split(' ').first;
    final initial = nama.isNotEmpty ? nama[0].toUpperCase() : '?';
    final photoUrl = ApiService.photoUrl(widget.user['photo_url']);

    // Menu "User Management" hanya tampil untuk admin.
    // (Pengecekan sebenarnya tetap dilakukan di server.)
    final isAdmin = widget.user['role'] == 'admin';

    final jam = '${_two(_now.hour)}:${_two(_now.minute)} WIB';
    final tanggal =
        '${_hari[_now.weekday - 1]}, ${_now.day} ${_bulan[_now.month - 1]} ${_now.year}';

    // ---------- Kartu "Jadwal Anda Hari Ini" ----------
    // Kosong kalau belum ada jadwal; kalau ada, tampil yang terdekat.
    final next = _nextJadwal();
    var jadwalTitle = 'Jadwal Anda Hari Ini';
    String? jadwalMain; // null = belum ada jadwal
    String? jadwalSub;
    if (next != null) {
      final at = DateTime.parse(next['scheduled_at'] as String)
          .toUtc()
          .add(const Duration(hours: 7));
      final today =
          at.year == _now.year && at.month == _now.month && at.day == _now.day;
      jadwalTitle = today ? 'Jadwal Anda Hari Ini' : 'Jadwal Terdekat';
      jadwalMain = '${_two(at.hour)}:${_two(at.minute)} WIB';
      jadwalSub = today
          ? 'Kelas ${next['kelas']}'
          : 'Kelas ${next['kelas']} • ${at.day} ${_bulan[at.month - 1]} ${at.year}';
    }

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
                      _Avatar(
                        radius: 24,
                        fontSize: 20,
                        initial: initial,
                        photoUrl: photoUrl,
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
                        onTap: _openNotifikasi,
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
                        Text(jadwalTitle,
                            style: _t(14, kTextMuted, weight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        if (jadwalMain == null)
                          Text('Belum ada jadwal',
                              style: _t(16, kTextMuted, weight: FontWeight.w500))
                        else ...[
                          Text(jadwalMain,
                              style: _t(20, Colors.black, weight: FontWeight.bold)),
                          if (jadwalSub != null) ...[
                            const SizedBox(height: 4),
                            Text(jadwalSub, style: _t(12, kTextMuted)),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ---------- Shortcut (2 kolom, tile 97 x 97) ----------
          // Mahasiswa: 4 menu. Admin: 5 menu (tambah User Management).
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
                    onTap: () => _openAndReload(const RegJadwalPage())),
                _IconTile(
                    icon: Icons.calendar_month_outlined,
                    label: 'Jadwal',
                    onTap: () => _openAndReload(const JadwalPage())),
                _IconTile(
                    icon: Icons.event_available_outlined,
                    label: 'Notifikasi',
                    onTap: _openNotifikasi),
                _IconTile(
                    icon: Icons.edit_notifications_outlined,
                    label: 'Edit Notifikasi',
                    onTap: () => _soon('Edit Notifikasi')),
                if (isAdmin)
                  _IconTile(
                      icon: Icons.manage_accounts_outlined,
                      label: 'User Management',
                      onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const UserManagementPage()),
                          )),
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
                    maxLines: 2, // "User Management" butuh dua baris
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
// Tab 4: Profile (desain: header merah, avatar + badge edit,
// daftar Account, tombol Logout)
// ============================================================
class ProfileTab extends StatefulWidget {
  final Map<String, dynamic> user;
  final VoidCallback onLogout;
  final VoidCallback onBack;
  final ValueChanged<String> onPhotoChanged;
  const ProfileTab({
    super.key,
    required this.user,
    required this.onLogout,
    required this.onBack,
    required this.onPhotoChanged,
  });

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  bool _uploading = false;

  void _snack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void _soon(String fitur) => _snack('$fitur: segera hadir');

  Future<void> _changePhoto() async {
    if (_uploading) return;

    final res = await FilePicker.pickFiles(
      type: FileType.image,
      withData: true, // supaya jalan juga di web
    );
    if (res == null || res.files.isEmpty || !mounted) return;

    final file = res.files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      _snack('Gagal membaca file foto');
      return;
    }
    if (bytes.length > kMaxPhotoBytes) {
      _snack('Ukuran foto maksimal 5 MB');
      return;
    }

    setState(() => _uploading = true);
    final r = await ApiService.uploadPhoto(fileName: file.name, bytes: bytes);
    if (!mounted) return;
    setState(() => _uploading = false);

    final url = r.data?['photo_url']?.toString();
    if (r.ok && url != null) widget.onPhotoChanged(url);
    _snack(r.message);
  }

  Widget _backButton() {
    return InkWell(
      onTap: widget.onBack,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white, width: 1.5),
        ),
        child: const Icon(Icons.chevron_left, size: 28, color: Colors.white),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final nama = (user['nama_lengkap'] ?? '').toString();
    final initial = nama.isNotEmpty ? nama[0].toUpperCase() : '?';
    final email = (user['email'] ?? '').toString();
    final isAdmin = user['role'] == 'admin';
    final subLine = isAdmin ? 'Administrator' : 'NIM: ${user['nim']}';
    final photoUrl = ApiService.photoUrl(user['photo_url']);

    // Geser konten ke bawah kalau status bar lebih tinggi dari desain
    final topInset = MediaQuery.of(context).padding.top;
    final dy = topInset > 38 ? topInset - 38 : 0.0;

    return SingleChildScrollView(
      child: Column(
        children: [
          // ---------- Header merah ----------
          SizedBox(
            height: 394 + dy,
            child: Stack(
              children: [
                // latar merah (ellipse besar)
                Container(
                  height: 394 + dy,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [kPrimary, kPrimarySoft],
                    ),
                    borderRadius:
                        BorderRadius.vertical(bottom: Radius.elliptical(375, 70)),
                  ),
                ),
                // lapisan transparan di atasnya (ellipse kedua)
                Container(
                  height: 262 + dy,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Color(0x14FFFFFF),
                    borderRadius:
                        BorderRadius.vertical(bottom: Radius.elliptical(375, 60)),
                  ),
                ),
                // tombol kembali
                Positioned(left: 17, top: 49 + dy, child: _backButton()),
                // judul
                Positioned(
                  left: 0,
                  right: 0,
                  top: 63 + dy,
                  child: Center(
                    child: Text('Profile',
                        style: _t(24, Colors.white, letterSpacing: -0.48)),
                  ),
                ),
                // avatar 120 + badge edit 46 di kanan bawah
                Positioned(
                  left: 0,
                  right: 0,
                  top: 142 + dy,
                  child: Center(
                    child: SizedBox(
                      width: 124,
                      height: 123,
                      child: Stack(
                        children: [
                          Positioned(
                            left: 0,
                            top: 0,
                            child: SizedBox(
                              width: 120,
                              height: 120,
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: _Avatar(
                                      radius: 60,
                                      fontSize: 48,
                                      initial: initial,
                                      photoUrl: photoUrl,
                                    ),
                                  ),
                                  if (_uploading)
                                    Positioned.fill(
                                      child: Container(
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Color(0x66000000),
                                        ),
                                        child: const Center(
                                          child: SizedBox(
                                            width: 32,
                                            height: 32,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 3,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            left: 78,
                            top: 77,
                            child: GestureDetector(
                              onTap: _changePhoto,
                              child: Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEAEAEA),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: const Color(0xFFF7F7F7), width: 5),
                                ),
                                child: const Icon(Icons.edit_outlined,
                                    size: 22, color: kTextLabel),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // nama, email, NIM
                Positioned(
                  left: 16,
                  right: 16,
                  top: 285 + dy,
                  child: Column(
                    children: [
                      Text(nama,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: _t(18, Colors.white, weight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: _t(14, Colors.white, letterSpacing: 0.25)),
                      const SizedBox(height: 2),
                      Text(subLine,
                          textAlign: TextAlign.center,
                          style: _t(14, Colors.white, letterSpacing: 0.25)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ---------- Account + daftar menu + Logout ----------
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 52),
                  Padding(
                    padding: const EdgeInsets.only(left: 17),
                    child: Text('Account',
                        style: _t(14, kPrimarySoft, letterSpacing: -0.28)),
                  ),
                  const SizedBox(height: 6),
                  _ProfileRow(
                    label: 'Edit Profile',
                    onTap: () => _soon('Edit Profile'),
                  ),
                  _ProfileRow(
                    label: 'Kelas',
                    onTap: () => _soon('Kelas'),
                  ),
                  _ProfileRow(
                    label: 'Perangkat Terdaftar',
                    onTap: () => _soon('Perangkat Terdaftar'),
                    fullWidthDivider: true,
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 17),
                    child: SizedBox(
                      width: double.infinity,
                      height: 58,
                      child: FilledButton(
                        onPressed: widget.onLogout,
                        style: FilledButton.styleFrom(
                          backgroundColor: kPrimarySoft,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          textStyle: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.36),
                        ),
                        child: const Text('Logout'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Satu baris menu: label kiri, chevron kanan, garis pemisah di bawah
class _ProfileRow extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool fullWidthDivider;
  const _ProfileRow({
    required this.label,
    required this.onTap,
    this.fullWidthDivider = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 17),
            child: SizedBox(
              height: 52,
              child: Row(
                children: [
                  Expanded(
                    child: Text(label,
                        style: _t(16, kTextLabel, letterSpacing: -0.32)),
                  ),
                  const Icon(Icons.chevron_right, size: 22, color: kTextMuted),
                ],
              ),
            ),
          ),
        ),
        Container(
          height: 1,
          margin: EdgeInsets.only(left: fullWidthDivider ? 0 : 18),
          color: const Color(0xFFEEEEEE),
        ),
      ],
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