import 'package:flutter/material.dart';

import '../services/api_service.dart';

const _red = Color(0xFFF45656);
const _redSoft = Color(0xFFF18080);
const _grey = Color(0xFFA4A4A4);
const _line = Color(0xFFEEEEEE);
const _ink = Color(0xFF221F1F);

/// Satu baris notifikasi yang dibuat dari satu jadwal.
class _Notif {
  final bool upcoming; // true = Jadwal Mendatang, false = Jadwal Terlewat
  final DateTime at; // waktu mulai jadwal (UTC)
  final String subject; // bagian tebal, mis. "Kelas A"
  final String detail; // sisa kalimat, mis. "dimulai pukul 16:00 mendatang"
  final String ago; // mis. "2 jam lagi" / "20 jam lalu"

  const _Notif({
    required this.upcoming,
    required this.at,
    required this.subject,
    required this.detail,
    required this.ago,
  });
}

class NotifikasiPage extends StatefulWidget {
  const NotifikasiPage({super.key});

  @override
  State<NotifikasiPage> createState() => _NotifikasiPageState();
}

class _NotifikasiPageState extends State<NotifikasiPage> {
  static const _bulan = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
  ];

  // Jadwal yang dianggap notifikasi: 7 hari ke belakang dan 7 hari ke depan
  static const _window = Duration(days: 7);

  List<_Notif> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    final res = await ApiService.listJadwalRequests();
    if (!mounted) return;
    if (!res.ok) {
      setState(() {
        _loading = false;
        _error = res.message;
      });
      return;
    }
    final raw =
        (res.data?['items'] as List? ?? []).cast<Map<String, dynamic>>();
    setState(() {
      _items = _build(raw);
      _error = null;
      _loading = false;
    });
  }

  // ---------- Membuat notifikasi dari daftar jadwal ----------
  List<_Notif> _build(List<Map<String, dynamic>> raw) {
    final now = DateTime.now().toUtc();
    final upcoming = <_Notif>[];
    final past = <_Notif>[];

    for (final j in raw) {
      if (j['status'] == 'rejected') continue; // jadwal ditolak tidak dinotifikasi
      final at = DateTime.parse(j['scheduled_at'] as String).toUtc();
      final diff = at.difference(now);
      if (diff.abs() > _window) continue;

      final isUpcoming = !diff.isNegative;
      final notif = _Notif(
        upcoming: isUpcoming,
        at: at,
        subject: 'Kelas ${j['kelas']}',
        detail: _detail(at, now, isUpcoming),
        ago: _relative(diff),
      );
      (isUpcoming ? upcoming : past).add(notif);
    }

    upcoming.sort((a, b) => a.at.compareTo(b.at)); // terdekat dulu
    past.sort((a, b) => b.at.compareTo(a.at)); // terbaru dulu
    return [...upcoming, ...past];
  }

  // Waktu WIB (UTC+7), sama seperti jam di halaman home
  DateTime _wib(DateTime utc) => utc.add(const Duration(hours: 7));

  String _two(int n) => n.toString().padLeft(2, '0');

  String _detail(DateTime at, DateTime now, bool upcoming) {
    final a = _wib(at);
    final n = _wib(now);
    final jam = '${_two(a.hour)}:${_two(a.minute)}';
    final today = a.year == n.year && a.month == n.month && a.day == n.day;
    if (today) {
      return upcoming ? 'dimulai pukul $jam mendatang' : 'dimulai pukul $jam';
    }
    return 'dimulai ${a.day} ${_bulan[a.month - 1]} pukul $jam';
  }

  String _relative(Duration diff) {
    final upcoming = !diff.isNegative;
    final m = diff.abs().inMinutes;
    if (m < 1) return upcoming ? 'sebentar lagi' : 'baru saja';
    final String t;
    if (m < 60) {
      t = '$m menit';
    } else if (m < 1440) {
      t = '${m ~/ 60} jam';
    } else {
      t = '${m ~/ 1440} hari';
    }
    return upcoming ? '$t lagi' : '$t lalu';
  }

  // ---------- UI ----------
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
          border: Border.all(color: _line),
        ),
        child: const Icon(Icons.chevron_left, size: 28, color: _ink),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
      child: SizedBox(
        height: 48,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(alignment: Alignment.centerLeft, child: _backButton()),
            const Text(
              'Notifikasi',
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w700, color: Colors.black),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorView() {
    return Column(
      children: [
        _header(),
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error!, style: const TextStyle(color: _grey)),
                TextButton(
                  onPressed: _load,
                  child: const Text('Coba lagi', style: TextStyle(color: _red)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _listView() {
    return Column(
      children: [
        _header(),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 371),
              child: RefreshIndicator(
                color: _red,
                onRefresh: () => _load(silent: true),
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: _items.length,
                  itemBuilder: (_, i) => _NotifTile(item: _items[i]),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _content() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _red));
    }
    if (_error != null) return _errorView();
    if (_items.isEmpty) {
      return _EmptyView(onHome: () => Navigator.of(context).pop());
    }
    return _listView();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(child: _content()),
    );
  }
}

// ============================================================
// Satu item di daftar notifikasi (desain kanan)
// ============================================================
class _NotifTile extends StatelessWidget {
  final _Notif item;
  const _NotifTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                item.upcoming ? 'Jadwal Mendatang' : 'Jadwal Terlewat',
                style: const TextStyle(fontSize: 11, color: _grey),
              ),
              Text(
                item.ago,
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700, color: _redSoft),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text.rich(
            TextSpan(
              style: const TextStyle(fontSize: 14, color: Colors.black),
              children: [
                TextSpan(
                  text: item.subject,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(text: ' ${item.detail}'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Tampilan kosong (desain kiri)
// ============================================================
class _EmptyView extends StatelessWidget {
  final VoidCallback onHome;
  const _EmptyView({required this.onHome});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _BellIllustration(),
                  const SizedBox(height: 36),
                  const Text(
                    'Belum ada Notifikasi',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1.0,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Jika Anda mendapat notifikasi dari aktivitas Anda, '
                    'notifikasi tersebut akan muncul di sini.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      letterSpacing: -0.1,
                      color: _grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
          child: SizedBox(
            width: double.infinity,
            height: 58,
            child: FilledButton(
              onPressed: onHome,
              style: FilledButton.styleFrom(
                backgroundColor: _redSoft,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                textStyle: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: -0.36),
              ),
              child: const Text('Beranda'),
            ),
          ),
        ),
      ],
    );
  }
}

// Ilustrasi lonceng. Dibuat dari ikon + bentuk sederhana karena file
// notification.svg dari desain tidak tersedia di proyek.
// Untuk memakai aset asli, ganti isi widget ini dengan
// Image.asset('assets/images/notification.png', width: 200).
class _BellIllustration extends StatelessWidget {
  const _BellIllustration();

  static const _circle = Color(0xFFF0CFCE);
  static const _bellFill = Color(0xFFF7E8E6);
  static const _bellLine = Color(0xFFDE8782);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 190,
      child: Stack(
        children: [
          // lingkaran pink besar
          Positioned(
            left: 55,
            top: 22,
            child: Container(
              width: 125,
              height: 125,
              decoration:
                  const BoxDecoration(color: _circle, shape: BoxShape.circle),
            ),
          ),
          // lonceng miring: isi terang + garis tepi
          Positioned(
            left: 18,
            top: 38,
            child: Transform.rotate(
              angle: -0.42,
              child: const Stack(
                children: [
                  Icon(Icons.notifications, size: 128, color: _bellFill),
                  Icon(Icons.notifications_none, size: 128, color: _bellLine),
                ],
              ),
            ),
          ),
          // titik kecil kiri atas
          Positioned(
            left: 52,
            top: 24,
            child: Container(
              width: 11,
              height: 11,
              decoration: const BoxDecoration(
                  color: Color(0xFFE4E7FA), shape: BoxShape.circle),
            ),
          ),
          // cincin kecil kanan
          Positioned(
            right: 24,
            top: 100,
            child: Container(
              width: 11,
              height: 11,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: _bellLine, width: 1.5),
              ),
            ),
          ),
          // setengah lingkaran kecil di bawah lonceng
          Positioned(
            left: 62,
            bottom: 26,
            child: ClipRect(
              child: Align(
                alignment: Alignment.topCenter,
                heightFactor: 0.5,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: _circle,
                    shape: BoxShape.circle,
                    border: Border.all(color: _bellLine, width: 1.5),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}