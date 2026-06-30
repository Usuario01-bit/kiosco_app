import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/supabase_service.dart';
import '../services/store_config.dart';
import 'student_catalog_screen.dart';
import 'student_qr_screen.dart';
import 'student_qr_scanner_screen.dart';

class StudentLoginScreen extends StatefulWidget {
  const StudentLoginScreen({super.key});

  @override
  State<StudentLoginScreen> createState() => _StudentLoginScreenState();
}

class _StudentLoginScreenState extends State<StudentLoginScreen> {
  final _storage = const FlutterSecureStorage();
  final nameCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  bool loading = true;
  bool loggingIn = false;
  bool obscurePassword = true;
  String? errorMsg;
  Map<String, dynamic>? _loggedStudent;
  List<String> _suggestions = [];
  bool _showSuggestions = false;
  bool _searching = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _checkSavedSession();
  }

  Future<void> _checkSavedSession() async {
    final savedToken = await _storage.read(key: 'student_qr_token');
    if (savedToken != null && savedToken.isNotEmpty) {
      try {
        final student = await SupabaseService.instance.getStudentByQrToken(savedToken);
        if (student != null && mounted) {
          _loggedStudent = student;
          setState(() => loading = false);
          return;
        }
      } catch (_) {}
    }
    if (mounted) setState(() => loading = false);
  }

  Future<String> _generateQrToken(String name) async {
    final rng = Random.secure();
    final bytes = List<int>.generate(32, (_) => rng.nextInt(256));
    final hash = sha256.convert(bytes).toString();
    return '${name.toLowerCase().replaceAll(RegExp(r'\s+'), '_')}_${hash.substring(0, 16)}';
  }

  Future<void> _login() async {
    final name = nameCtrl.text.trim();
    final password = passwordCtrl.text.trim();

    if (name.isEmpty || password.isEmpty) {
      setState(() => errorMsg = 'Completá nombre y contraseña');
      return;
    }

    setState(() {
      loggingIn = true;
      errorMsg = null;
    });

    try {
      final student = await SupabaseService.instance.verifyStudentLogin(name, password);
      if (!mounted) return;

      if (student != null) {
        final token = await _generateQrToken(name);
        await SupabaseService.instance.setStudentQrToken(student['id'], token);

        await _storage.write(key: 'student_qr_token', value: token);

        _loggedStudent = student;
        setState(() => loggingIn = false);
        _enterCatalog();
      } else {
        setState(() {
          errorMsg = 'Nombre o contraseña incorrectos';
          loggingIn = false;
        });
      }
    } on SocketException {
      setState(() {
        errorMsg = 'Sin conexión. Verificá tu conexión a internet.';
        loggingIn = false;
      });
    } on TimeoutException {
      setState(() {
        errorMsg = 'Tiempo de espera agotado. Verificá tu conexión.';
        loggingIn = false;
      });
    } on PostgrestException {
      setState(() {
        errorMsg = 'Error del servidor. Intentá de nuevo.';
        loggingIn = false;
      });
    } catch (e) {
      debugPrint('Login error: $e');
      setState(() {
        errorMsg = 'Ocurrió un error inesperado. Intentá de nuevo.';
        loggingIn = false;
      });
    }
  }

  void _enterCatalog() {
    if (_loggedStudent == null) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => StudentCatalogScreen(student: _loggedStudent!),
      ),
    );
  }

  void _onNameChanged(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _showSuggestions = false;
        _suggestions = [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final results = await SupabaseService.instance.searchStudentsByName(value.trim());
        if (!mounted) return;
        setState(() {
          _suggestions = results.map((s) => s['name'] as String).toList();
          _showSuggestions = _suggestions.isNotEmpty;
          _searching = false;
        });
      } catch (_) {
        if (mounted) setState(() => _searching = false);
      }
    });
  }

  void _selectSuggestion(String name) {
    nameCtrl.text = name;
    setState(() {
      _showSuggestions = false;
      _suggestions = [];
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    nameCtrl.dispose();
    passwordCtrl.dispose();
    super.dispose();
  }

  Color? _getBgColor(Brightness brightness) {
    if (brightness == Brightness.dark) return null;
    return const Color(0xFFF5F5F5);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (loading) {
      return Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [cs.surface, cs.surfaceContainerHigh, cs.surface]
                  : const [Color(0xFF1E3A5F), Color(0xFF2D5F8A), Color(0xFF1E3A5F)],
            ),
          ),
          child: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_loggedStudent != null) {
      return Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [cs.surface, cs.surfaceContainerHigh, cs.surface]
                  : const [Color(0xFF1E3A5F), Color(0xFF2D5F8A), Color(0xFF1E3A5F)],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(
                        color: (isDark ? cs.primary : Colors.white24),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Icon(LucideLucideIcons.checkCircle, size: 50, color: isDark ? cs.primary : Colors.white),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Sesión iniciada',
                      style: TextStyle(color: isDark ? cs.onSurface : Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Bienvenido, ${_loggedStudent!['name']}',
                      style: TextStyle(color: isDark ? cs.onSurfaceVariant : Colors.white.withValues(alpha: 0.8), fontSize: 18),
                    ),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity, height: 56,
                      child: ElevatedButton.icon(
                        onPressed: _enterCatalog,
                        icon: const Icon(LucideIcons.shoppingBag),
                        label: const Text('Ir a la tienda', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? cs.primary : Colors.white,
                          foregroundColor: isDark ? cs.onPrimary : const Color(0xFF1E3A5F),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity, height: 50,
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => StudentQrScreen(student: _loggedStudent!)),
                        ),
                        icon: Icon(LucideIcons.qrCode, color: isDark ? cs.onSurfaceVariant : Colors.white70),
                        label: Text('Mi QR', style: TextStyle(color: isDark ? cs.onSurfaceVariant : Colors.white70)),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: isDark ? cs.outlineVariant : Colors.white.withValues(alpha: 0.3)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextButton.icon(
                      onPressed: () async {
                        if (_loggedStudent != null && _loggedStudent!['id'] != null) {
                          await SupabaseService.instance.setStudentQrToken(_loggedStudent!['id'], '');
                        }
                        await _storage.delete(key: 'student_qr_token');
                        if (mounted) setState(() => _loggedStudent = null);
                      },
                      icon: Icon(LucideIcons.logOut, color: isDark ? cs.onSurfaceVariant : Colors.white54),
                      label: Text('Cerrar sesión', style: TextStyle(color: isDark ? cs.onSurfaceVariant : Colors.white54)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [cs.surface, cs.surfaceContainerHigh, cs.surface]
                : const [Color(0xFF1E3A5F), Color(0xFF2D5F8A), Color(0xFF1E3A5F)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 100, height: 100,
                    decoration: BoxDecoration(
                      color: isDark ? cs.primary.withValues(alpha: 0.15) : Colors.white24,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Icon(LucideIcons.school, size: 50, color: isDark ? cs.primary : Colors.white),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    StoreConfig.instance.storeName,
                    style: TextStyle(
                      color: isDark ? cs.onSurface : Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Portal del Alumno',
                    style: TextStyle(color: isDark ? cs.onSurfaceVariant : Colors.white.withValues(alpha: 0.7), fontSize: 16),
                  ),
                  const SizedBox(height: 48),
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          if (errorMsg != null)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              margin: const EdgeInsets.only(bottom: 20),
                              decoration: BoxDecoration(
                                color: cs.errorContainer.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: cs.error.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                children: [
                                  Icon(LucideIcons.alertCircle, color: cs.error, size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(child: Text(errorMsg!, style: TextStyle(color: cs.error))),
                                ],
                              ),
                            ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextField(
                                controller: nameCtrl,
                                onChanged: _onNameChanged,
                                textCapitalization: TextCapitalization.words,
                                decoration: InputDecoration(
                                  labelText: 'Nombre y apellido',
                                  prefixIcon: const Icon(LucideIcons.user),
                                  filled: true,
                                  fillColor: _getBgColor(Theme.of(context).brightness),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(18),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                              if (_showSuggestions || _searching)
                                Container(
                                  constraints: const BoxConstraints(maxHeight: 180),
                                  margin: const EdgeInsets.only(top: 4),
                                  decoration: BoxDecoration(
                                    color: cs.surface,
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: [
                                      BoxShadow(color: cs.shadow.withValues(alpha: 0.15), blurRadius: 12, offset: const Offset(0, 4)),
                                    ],
                                  ),
                                  child: _searching
                                      ? const Center(child: Padding(
                                          padding: EdgeInsets.all(16),
                                          child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5)),
                                        ))
                                      : ListView.builder(
                                          padding: EdgeInsets.zero,
                                          shrinkWrap: true,
                                          itemCount: _suggestions.length,
                                          itemBuilder: (_, i) => ListTile(
                                            dense: true,
                                            title: Text(_suggestions[i]),
                                            onTap: () => _selectSuggestion(_suggestions[i]),
                                          ),
                                        ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          TextField(
                            controller: passwordCtrl,
                            obscureText: obscurePassword,
                            decoration: InputDecoration(
                              labelText: 'Contraseña temporal',
                              prefixIcon: const Icon(LucideIcons.lock),
                              suffixIcon: IconButton(
                                icon: Icon(obscurePassword ? LucideIcons.eyeOff : LucideIcons.eye),
                                onPressed: () => setState(() => obscurePassword = !obscurePassword),
                              ),
                              filled: true,
                              fillColor: _getBgColor(Theme.of(context).brightness),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            onSubmitted: (_) => _login(),
                          ),
                          const SizedBox(height: 28),
                          SizedBox(
                            width: double.infinity, height: 60,
                            child: ElevatedButton(
                              onPressed: loggingIn ? null : _login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: cs.primary,
                                foregroundColor: cs.onPrimary,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                elevation: 0,
                              ),
                              child: loggingIn
                                  ? const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.5))
                                  : const Text('Ingresar', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity, height: 50,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => StudentQrScannerScreen(
                              onStudentFound: (student) async {
                                final token = await _generateQrToken(student['name'] as String);
                                await SupabaseService.instance.setStudentQrToken(student['id'], token);
                                await _storage.write(key: 'student_qr_token', value: token);
                                if (!context.mounted) return;
                                Navigator.pushAndRemoveUntil(
                                  context,
                                  MaterialPageRoute(builder: (_) => StudentCatalogScreen(student: student)),
                                  (_) => false,
                                );
                              },
                            ),
                          ),
                        );
                      },
                      icon: const Icon(LucideIcons.qrCode_scanner),
                      label: const Text('Escanear QR para entrar'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF2563EB),
                        side: const BorderSide(color: Color(0xFF2563EB)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        textStyle: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(LucideIcons.arrowLeft),
                    label: const Text('Volver'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
