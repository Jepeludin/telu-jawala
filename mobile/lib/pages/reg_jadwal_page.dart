import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/api_service.dart';

const _red = Color(0xFFF45656);
const _redSoft = Color(0xFFF18080);
const _grey = Color(0xFFA4A4A4);
const _border = Color(0xFFDBDBDB);
const _textColor = Color(0xFF555555);
const _labelColor = Color(0xFF5D5D5D);
const _backBlue = Color(0xFF4D7CFE);

const _maxFileBytes = 5 * 1024 * 1024; // 5 MB

// Nilai khusus untuk item "Tambah Kelas" di dropdown
const _addKelasValue = -1;

class RegJadwalPage extends StatefulWidget {
  const RegJadwalPage({super.key});

  @override
  State<RegJadwalPage> createState() => _RegJadwalPageState();
}

class _RegJadwalPageState extends State<RegJadwalPage> {
  final _formKey = GlobalKey<FormState>();
  final _scheduleCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  List<Map<String, dynamic>> _kelasList = [];
  int? _kelasId;
  DateTime? _schedule;
  PlatformFile? _file;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadKelas();
  }

  Future<void> _loadKelas() async {
    final res = await ApiService.listKelas();
    if (!mounted) return;
    final list =
        (res.data?['items'] as List? ?? []).cast<Map<String, dynamic>>();
    setState(() => _kelasList = list);
  }

  // Dialog input nama kelas -> simpan ke server -> otomatis terpilih
  Future<void> _addKelas() async {
    final ctrl = TextEditingController();
    final nama = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tambah Kelas'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 50,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            hintText: 'Nama kelas / mata kuliah',
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            child: const Text('Simpan', style: TextStyle(color: _red)),
          ),
        ],
      ),
    );
    if (nama == null || nama.isEmpty || !mounted) return;

    final res = await ApiService.createKelas(nama);
    if (!mounted) return;
    if (!res.ok) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(res.message)));
      return;
    }
    await _loadKelas();
    if (!mounted) return;
    final newId = (res.data?['kelas'] as Map?)?['id'];
    if (newId is int) setState(() => _kelasId = newId);
  }

  @override
  void dispose() {
    _scheduleCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  // Tampilan di field: 25-10-2026 08:00
  String _display(DateTime d) =>
      '${_two(d.day)}-${_two(d.month)}-${d.year} ${_two(d.hour)}:${_two(d.minute)}';

  // Format kirim ke backend: 2026-10-25 08:00
  String _api(DateTime d) =>
      '${d.year}-${_two(d.month)}-${_two(d.day)} ${_two(d.hour)}:${_two(d.minute)}';

  Future<void> _pickSchedule() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = await showDatePicker(
      context: context,
      initialDate: _schedule ?? today,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_schedule ?? now),
    );
    if (time == null) return;
    final dt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() => _schedule = dt);
    _scheduleCtrl.text = _display(dt);
  }

  Future<void> _pickFile() async {
    final res = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf', 'doc', 'docx'],
      withData: true, // supaya jalan juga di web
    );
    if (res == null || res.files.isEmpty || !mounted) return;
    final f = res.files.first;
    if (f.size > _maxFileBytes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ukuran file maksimal 5 MB')),
      );
      return;
    }
    setState(() => _file = f);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final result = await ApiService.createJadwalRequest(
      kelasId: _kelasId!,
      scheduledAt: _api(_schedule!),
      note: _noteCtrl.text.trim(),
      fileName: _file?.name,
      fileBytes: _file?.bytes,
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

  InputDecoration _decoration({
    required String hint,
    IconData? icon,
    bool multiline = false,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle:
          const TextStyle(fontSize: 14, letterSpacing: -0.28, color: _grey),
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: multiline
          ? const EdgeInsets.symmetric(horizontal: 16, vertical: 14)
          : const EdgeInsets.symmetric(vertical: 19),
      errorStyle: const TextStyle(fontSize: 12, color: _red),
      prefixIcon: icon == null
          ? null
          : Padding(
              padding: const EdgeInsets.only(left: 14),
              child: Align(
                alignment: Alignment.centerLeft,
                widthFactor: 1,
                child: Icon(icon, size: 24, color: _grey),
              ),
            ),
      prefixIconConstraints:
          const BoxConstraints(minWidth: 70, minHeight: 58),
      enabledBorder: _outline(_border),
      focusedBorder: _outline(_red),
      errorBorder: _outline(_red),
      focusedErrorBorder: _outline(_red),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6, left: 2),
        child: Text(
          text,
          style: const TextStyle(
              fontSize: 14, letterSpacing: -0.28, color: _labelColor),
        ),
      );

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

  Widget _attachment() {
    final hasFile = _file != null;
    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: _loading ? null : _pickFile,
            borderRadius: BorderRadius.circular(18),
            child: CustomPaint(
              painter: _DashedBorderPainter(),
              child: SizedBox(
                width: 162,
                height: 119,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      hasFile ? Icons.insert_drive_file_outlined : Icons.attach_file,
                      size: 34,
                      color: _grey,
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        hasFile ? _file!.name : 'Lampiran',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14, letterSpacing: -0.28, color: _grey),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (hasFile)
            TextButton(
              onPressed: _loading ? null : () => setState(() => _file = null),
              child: const Text('Hapus lampiran',
                  style: TextStyle(fontSize: 13, color: _red)),
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
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
              child: Row(
                children: [
                  _backButton(),
                  const SizedBox(width: 24),
                  const Text(
                    'Registrasi Jadwal',
                    style: TextStyle(
                        fontSize: 24, letterSpacing: -0.48, color: Colors.black),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 371),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _label('Kelas'),
                          DropdownButtonFormField<int>(
                            value: _kelasId,
                            isExpanded: true,
                            icon: const Padding(
                              padding: EdgeInsets.only(right: 8),
                              child: Icon(Icons.keyboard_arrow_down, color: _grey),
                            ),
                            style: const TextStyle(
                                fontSize: 14,
                                letterSpacing: -0.28,
                                color: _textColor),
                            decoration: _decoration(
                                hint: 'Pilih Kelas', icon: Icons.class_outlined),
                            hint: const Text('Pilih Kelas',
                                style: TextStyle(fontSize: 14, color: _grey)),
                            items: [
                              for (final k in _kelasList)
                                DropdownMenuItem<int>(
                                  value: k['id'] as int,
                                  child: Text('Kelas ${k['nama']}'),
                                ),
                              const DropdownMenuItem<int>(
                                value: _addKelasValue,
                                child: Row(
                                  children: [
                                    Icon(Icons.add_circle_outline,
                                        size: 18, color: _red),
                                    SizedBox(width: 8),
                                    Text('Tambah Kelas',
                                        style: TextStyle(color: _red)),
                                  ],
                                ),
                              ),
                            ],
                            onChanged: _loading
                                ? null
                                : (v) {
                                    if (v == _addKelasValue) {
                                      _addKelas();
                                    } else {
                                      setState(() => _kelasId = v);
                                    }
                                  },
                            validator: (v) =>
                                v == null ? 'Kolom harus diisi' : null,
                          ),
                          const SizedBox(height: 18),
                          _label('Tanggal dan Waktu'),
                          TextFormField(
                            controller: _scheduleCtrl,
                            readOnly: true,
                            onTap: _loading ? null : _pickSchedule,
                            style: const TextStyle(
                                fontSize: 14,
                                letterSpacing: -0.28,
                                color: _textColor),
                            decoration: _decoration(
                              hint: 'Pilih Tanggal dan Waktu',
                              icon: Icons.event_available_outlined,
                            ),
                            validator: (_) {
                              if (_schedule == null) return 'Kolom harus diisi';
                              if (_schedule!.isBefore(DateTime.now())) {
                                return 'Waktu tidak boleh di masa lalu';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 18),
                          _label('Note'),
                          TextFormField(
                            controller: _noteCtrl,
                            minLines: 4,
                            maxLines: 4,
                            maxLength: 1000,
                            style: const TextStyle(
                                fontSize: 14,
                                letterSpacing: -0.28,
                                color: _textColor),
                            decoration:
                                _decoration(hint: 'Tulis catatan...', multiline: true)
                                    .copyWith(counterText: ''),
                          ),
                          const SizedBox(height: 22),
                          _attachment(),
                          const SizedBox(height: 28),
                          SizedBox(
                            height: 58,
                            child: FilledButton(
                              onPressed: _loading ? null : _submit,
                              style: FilledButton.styleFrom(
                                backgroundColor: _redSoft,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                textStyle: const TextStyle(
                                    fontSize: 18, letterSpacing: -0.36),
                              ),
                              child: _loading
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Text('Kirim Permintaan'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Border putus-putus untuk kotak lampiran (Flutter tidak punya bawaan)
class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Offset.zero & size, const Radius.circular(18)));
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + 6), paint);
        d += 10;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}