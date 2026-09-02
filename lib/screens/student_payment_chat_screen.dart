import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../services/supabase_service.dart';

class StudentPaymentChatScreen extends StatefulWidget {
  final Map<String, dynamic> student;

  const StudentPaymentChatScreen({super.key, required this.student});

  @override
  State<StudentPaymentChatScreen> createState() => _StudentPaymentChatScreenState();
}

class _StudentPaymentChatScreenState extends State<StudentPaymentChatScreen> {
  final _supabase = SupabaseService.instance;
  final _messageCtrl = TextEditingController();
  Uint8List? _selectedImage;
  String? _selectedName;
  bool _uploading = false;

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    setState(() {
      _selectedImage = result.files.first.bytes;
      _selectedName = result.files.first.name;
    });
  }

  Future<void> _submit() async {
    if (_selectedImage == null) {
      _snack('Primero elegí la captura del pago');
      return;
    }
    setState(() => _uploading = true);
    try {
      final studentId = widget.student['id'].toString();
      final path = await _supabase.uploadPaymentCapture(
        studentId,
        _selectedName ?? 'captura.png',
        _selectedImage!,
      );
      await _supabase.submitPaymentCapture(
        studentId: studentId,
        imagePath: path,
        message: _messageCtrl.text.trim(),
      );
      _messageCtrl.clear();
      setState(() {
        _selectedImage = null;
        _selectedName = null;
      });
      if (!mounted) return;
      await _load();
      _snack('Captura enviada. Te avisamos cuando se revise.');
    } catch (e) {
      _snack('Error al enviar: $e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  List<Map<String, dynamic>> _captures = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _supabase.getStudentCaptures(widget.student['id'].toString());
      if (!mounted) return;
      setState(() {
        _captures = data;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _statusLabel(String status) {
    return status == 'revisado' ? 'Revisado' : 'Pendiente';
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '-';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    final local = dt.toLocal();
    final dd = local.day.toString().padLeft(2, '0');
    final mm = local.month.toString().padLeft(2, '0');
    return '$dd/$mm/${local.year} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Enviar pago')),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _captures.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.wallet, size: 48, color: cs.outline),
                            const SizedBox(height: 12),
                            const Text('Todavía no enviaste capturas de pago'),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _captures.length,
                        itemBuilder: (context, index) {
                          final cap = _captures[index];
                          final reviewed = cap['status'] == 'revisado';
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 2,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        reviewed ? LucideIcons.checkCircle2 : LucideIcons.clock,
                                        size: 18,
                                        color: reviewed ? Colors.green : cs.primary,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _statusLabel(cap['status'] as String? ?? 'pendiente'),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: reviewed ? Colors.green : cs.primary,
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        _formatDate(cap['created_at'] as String?),
                                        style: TextStyle(fontSize: 12, color: cs.outline),
                                      ),
                                    ],
                                  ),
                                  if ((cap['message'] as String?)?.isNotEmpty ?? false) ...[
                                    const SizedBox(height: 8),
                                    Text(cap['message'] as String),
                                  ],
                                  const SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.network(
                                      _supabase.getPaymentCaptureUrl(cap['image_url'] as String),
                                      height: 140,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        height: 140,
                                        color: cs.surfaceContainerHighest,
                                        child: const Center(child: Icon(LucideIcons.imageOff)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.surface,
              border: Border(top: BorderSide(color: cs.outlineVariant)),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_selectedImage != null) ...[
                    Stack(
                      alignment: Alignment.topRight,
                      children: [
                        Container(
                          height: 90,
                          width: 90,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            image: DecorationImage(image: MemoryImage(_selectedImage!), fit: BoxFit.cover),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => setState(() {
                            _selectedImage = null;
                            _selectedName = null;
                          }),
                          child: Container(
                            decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                            padding: const EdgeInsets.all(4),
                            child: const Icon(Icons.close, size: 14, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(LucideIcons.imagePlus),
                        tooltip: 'Adjuntar captura',
                        onPressed: _uploading ? null : _pickImage,
                      ),
                      Expanded(
                        child: TextField(
                          controller: _messageCtrl,
                          minLines: 1,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            hintText: 'Mensaje (opcional)',
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: _uploading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(LucideIcons.send),
                        tooltip: 'Enviar captura',
                        onPressed: _uploading ? null : _submit,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}