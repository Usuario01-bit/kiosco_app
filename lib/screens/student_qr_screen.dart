import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../services/supabase_service.dart';

class StudentQrScreen extends StatefulWidget {
  final Map<String, dynamic> student;

  const StudentQrScreen({super.key, required this.student});

  @override
  State<StudentQrScreen> createState() => _StudentQrScreenState();
}

class _StudentQrScreenState extends State<StudentQrScreen> {
  String? qrToken;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadToken();
  }

  Future<void> _loadToken() async {
    final storage = const FlutterSecureStorage();
    final token = await storage.read(key: 'student_qr_token');
    if (token != null) {
      final student = await SupabaseService.instance.getStudentByQrToken(token);
      if (student != null && mounted) {
        setState(() {
          qrToken = token;
          loading = false;
        });
        return;
      }
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Mi QR')),
      body: Center(
        child: loading
            ? const CircularProgressIndicator()
            : qrToken == null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.qrCode_2, size: 64, color: cs.onSurfaceVariant),
                      const SizedBox(height: 16),
                      Text('No hay QR disponible', style: TextStyle(fontSize: 18, color: cs.onSurfaceVariant)),
                      const SizedBox(height: 8),
                      Text('Iniciá sesión primero', style: TextStyle(color: cs.onSurfaceVariant)),
                    ],
                  )
                : Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.student['name'] as String,
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        if ((widget.student['grade'] ?? widget.student['grado']) != null && ((widget.student['grade'] ?? widget.student['grado']) as String).trim().isNotEmpty)
                          Text(
                            (widget.student['grade'] ?? widget.student['grado']) as String,
                            style: TextStyle(fontSize: 16, color: cs.onSurfaceVariant),
                          ),
                        const SizedBox(height: 32),
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: cs.brightness == Brightness.dark ? cs.surfaceContainerHigh : Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: cs.shadow.withValues(alpha: 0.1),
                                blurRadius: 30,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: QrImageView(
                            data: qrToken!,
                            version: QrVersions.auto,
                            size: 250,
                            eyeStyle: QrEyeStyle(
                              eyeShape: QrEyeShape.square,
                              color: cs.primary,
                            ),
                            dataModuleStyle: QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.square,
                              color: cs.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Mostrá este QR en el kiosco',
                          style: TextStyle(fontSize: 16, color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}
