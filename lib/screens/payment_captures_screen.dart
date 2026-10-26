import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../services/supabase_service.dart';

class PaymentCapturesScreen extends StatefulWidget {
  const PaymentCapturesScreen({super.key});

  @override
  State<PaymentCapturesScreen> createState() => _PaymentCapturesScreenState();
}

class _PaymentCapturesScreenState extends State<PaymentCapturesScreen> {
  final _supabase = SupabaseService.instance;
  List<Map<String, dynamic>> _captures = [];
  final Map<String, String> _signedUrls = {};
  StreamSubscription? _sub;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _sub = _supabase.streamPaymentCaptures().listen((data) {
      if (!mounted) return;
      setState(() {
        _captures = data;
        _loading = false;
      });
      _loadSignedUrls(data);
    }, onError: (_) {
      if (mounted) setState(() => _loading = false);
    });
  }

  /// El bucket es privado: cada comprobante necesita un link temporal.
  /// Se piden en paralelo y se cachean por path.
  Future<void> _loadSignedUrls(List<Map<String, dynamic>> captures) async {
    final pending = <String>[];
    for (final cap in captures) {
      final path = cap['image_url'] as String?;
      if (path == null || path.isEmpty) continue;
      if (_signedUrls.containsKey(path)) continue;
      if (!pending.contains(path)) pending.add(path);
    }
    if (pending.isEmpty) return;

    final results = await Future.wait(pending.map((path) async {
      final url = await _supabase.getPaymentCaptureSignedUrl(path);
      return url == null ? null : MapEntry(path, url);
    }));

    if (!mounted) return;
    setState(() {
      for (final entry in results) {
        if (entry != null) _signedUrls[entry.key] = entry.value;
      }
    });
  }

  Widget _captureImage(String path, {double? height, BoxFit fit = BoxFit.cover}) {
    final url = _signedUrls[path];
    if (url == null) {
      return Container(
        height: height,
        width: double.infinity,
        alignment: Alignment.center,
        constraints: const BoxConstraints(minHeight: 80),
        child: const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return Image.network(
      url,
      height: height,
      width: double.infinity,
      fit: fit,
      errorBuilder: (_, __, ___) => Container(
        height: height,
        width: double.infinity,
        alignment: Alignment.center,
        child: const Icon(LucideIcons.imageOff),
      ),
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  int get _pendingCount => _captures.where((c) => c['status'] == 'pendiente').length;

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '-';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    final local = dt.toLocal();
    final dd = local.day.toString().padLeft(2, '0');
    final mm = local.month.toString().padLeft(2, '0');
    return '$dd/$mm/${local.year} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _markReviewed(Map<String, dynamic> capture) async {
    await _supabase.markPaymentCaptureReviewed(capture['id']);
  }

  void _openImage(Map<String, dynamic> capture) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Captura de ${capture['student'] ?? 'Desconocido'}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            ClipRRect(
              child: InteractiveViewer(
                child: _captureImage(
                  capture['image_url'] as String,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            if ((capture['message'] as String?)?.isNotEmpty ?? false)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(capture['message'] as String),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (capture['status'] == 'pendiente')
                    FilledButton.icon(
                      icon: const Icon(LucideIcons.check),
                      label: const Text('Marcar revisado'),
                      onPressed: () {
                        _markReviewed(capture);
                        Navigator.pop(ctx);
                      },
                    )
                  else
                    const Text('Ya revisado', style: TextStyle(color: Colors.green)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('Pagos${_pendingCount > 0 ? ' ($_pendingCount)' : ''}'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _captures.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.inbox, size: 48, color: cs.outline),
                      const SizedBox(height: 12),
                      const Text('No hay capturas de pago'),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _captures.length,
                  itemBuilder: (context, index) {
                    final cap = _captures[index];
                    final pending = cap['status'] == 'pendiente';
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 2,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => _openImage(cap),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    pending ? LucideIcons.alertCircle : LucideIcons.checkCircle2,
                                    size: 18,
                                    color: pending ? cs.error : Colors.green,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      cap['student'] ?? 'Desconocido',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  Text(
                                    _formatDate(cap['created_at'] as String?),
                                    style: TextStyle(fontSize: 12, color: cs.outline),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: _captureImage(
                                  cap['image_url'] as String,
                                  height: 120,
                                ),
                              ),
                              if ((cap['message'] as String?)?.isNotEmpty ?? false) ...[
                                const SizedBox(height: 8),
                                Text(cap['message'] as String),
                              ],
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    pending ? 'Pendiente de revisión' : 'Revisado',
                                    style: TextStyle(
                                      color: pending ? cs.error : Colors.green,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (pending)
                                    TextButton.icon(
                                      icon: const Icon(LucideIcons.check, size: 16),
                                      label: const Text('Revisar'),
                                      onPressed: () => _markReviewed(cap),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}