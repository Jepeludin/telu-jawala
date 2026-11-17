import 'package:flutter/material.dart';

import '../services/api_service.dart';

const _red = Color(0xFFF45656);
const _card = Color(0xFFF96767);
const _grey = Color(0xFFA4A4A4);
const _backBlue = Color(0xFF4D7CFE);
const _glass = Color(0x78FFFFFF); // putih transparan untuk tombol Edit/Hapus

class JadwalPage extends StatefulWidget {
  const JadwalPage({super.key});

  @override
  State<JadwalPage> createState() => _JadwalPageState();
}

class _JadwalPageState extends State<JadwalPage> {
  static const _hari = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
  static const _bulan = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
  ];

  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;
  int? _expandedId;

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
    final list =
        (res.data?['items'] as List? ?? []).cast<Map<String, dynamic>>();
    setState(() {
      _items = list;
      _error = null;
      _loading = false;
      // kartu pertama dibuka, seperti di desain
      _expandedId = list.isNotEmpty ? list.first['id'] as int : null;
    });
  }

  // Waktu dari server diubah ke WIB (UTC+7), sama seperti jam di home
  DateTime _wib(String iso) =>
      DateTime.parse(iso).toUtc().add(const Duration(hours: 7));

  String _two(int n) => n.toString().padLeft(2, '0');

  String _dateText(DateTime d) =>
      '${_hari[d.weekday - 1]}, ${d.day} ${_bulan[d.month - 1]} ${d.year}';

  String _timeText(DateTime d) => '${_two(d.hour)}:${_two(d.minute)} WIB';

  String _statusText(String s) {
    switch (s) {
      case 'approved':
        return 'Disetujui';
      case 'rejected':
        return 'Ditolak';
      default:
        return 'Menunggu';
    }
  }

  Future<void> _confirmDelete(Map<String, dynamic> item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus jadwal?'),
        content: const Text('Jadwal yang dihapus tidak bisa dikembalikan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Hapus', style: TextStyle(color: _red)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final res = await ApiService.deleteJadwalRequest(item['id'] as int);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(res.message)));
    if (res.ok) _load(silent: true);
  }

  void _edit() {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Edit jadwal: segera hadir')));
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
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          if (_error != null) ...[
            const SizedBox(height: 80),
            Center(child: Text(_error!, style: const TextStyle(color: _grey))),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: _load,
                child: const Text('Coba lagi', style: TextStyle(color: _red)),
              ),
            ),
          ] else if (_items.isEmpty) ...[
            const SizedBox(height: 80),
            const Center(
              child: Text('Belum ada jadwal.\nBuat lewat menu Reg. Jadwal.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _grey)),
            ),
          ] else
            for (final item in _items)
              _ScheduleCard(
                when: _wib(item['scheduled_at'] as String),
                dateText: _dateText,
                timeText: _timeText,
                kelas: (item['kelas'] ?? '').toString(),
                status: _statusText((item['status'] ?? '').toString()),
                note: (item['note'] ?? '').toString(),
                attachment: (item['attachment_name'] ?? '').toString(),
                expanded: _expandedId == item['id'],
                onToggle: () => setState(() {
                  _expandedId = _expandedId == item['id'] ? null : item['id'] as int;
                }),
                onEdit: _edit,
                onDelete: () => _confirmDelete(item),
              ),
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
                    'Tabel Jadwal',
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

class _ScheduleCard extends StatelessWidget {
  final DateTime when;
  final String Function(DateTime) dateText;
  final String Function(DateTime) timeText;
  final String kelas;
  final String status;
  final String note;
  final String attachment;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ScheduleCard({
    required this.when,
    required this.dateText,
    required this.timeText,
    required this.kelas,
    required this.status,
    required this.note,
    required this.attachment,
    required this.expanded,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.white)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _glassButton(IconData icon, String label, VoidCallback onTap) {
    return Material(
      color: _glass,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: 36,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: Colors.white),
              const SizedBox(width: 6),
              Text(label,
                  style: const TextStyle(fontSize: 14, color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: Row(
                children: [
                  Container(
                    width: 11,
                    height: 11,
                    decoration: const BoxDecoration(
                        color: Colors.white, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(dateText(when),
                            style: const TextStyle(fontSize: 16, color: Colors.white)),
                        const SizedBox(height: 2),
                        Text(timeText(when),
                            style: const TextStyle(fontSize: 12, color: Colors.white)),
                      ],
                    ),
                  ),
                  Text('KELAS $kelas',
                      style: const TextStyle(fontSize: 12, color: Colors.white)),
                  const SizedBox(width: 4),
                  Icon(
                    expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: Colors.white,
                    size: 28,
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            alignment: Alignment.topCenter,
            child: expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(35, 0, 35, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _row('Status', status),
                        if (note.isNotEmpty) _row('Note', note),
                        if (attachment.isNotEmpty) _row('Lampiran', attachment),
                        const SizedBox(height: 6),
                        _glassButton(Icons.edit_outlined, 'Edit', onEdit),
                        const SizedBox(height: 8),
                        _glassButton(Icons.delete_outline, 'Hapus', onDelete),
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}