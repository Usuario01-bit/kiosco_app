import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/env.dart';
import '../services/responsive.dart';
import '../services/store_config.dart';
import '../services/supabase_service.dart';
import 'home_screen.dart';
import 'student_login_screen.dart';

class LoginScreen extends StatefulWidget {

  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState
    extends State<LoginScreen> {

  final usernameCtrl =
  TextEditingController();

  final passwordCtrl =
  TextEditingController();

  bool loading = false;

  bool obscurePassword = true;

  String? errorMsg;

  @override
  void initState() {

    super.initState();
  }

  Future<void> _login() async {

    final username =
    usernameCtrl.text.trim();

    final password =
    passwordCtrl.text.trim();

    if (username.isEmpty ||
        password.isEmpty) {

      setState(() {

        errorMsg =
        'Completá usuario y contraseña';
      });

      return;
    }

    setState(() {

      loading = true;

      errorMsg = null;
    });

    try {

      final email = '$username@kiosco.app';

      final user =
      await SupabaseService.instance
          .loginAdmin(email, password);

      if (!mounted) return;

      if (user != null) {

        Navigator.pushReplacement(

          context,
          MaterialPageRoute(
            builder: (_) => HomeScreen(
              username: user['username'] as String,
              role: user['role'] as String? ?? 'admin',
            ),
          ),
        );
      } else {

        setState(() {

          errorMsg =
          'Usuario o contraseña incorrectos';

          loading = false;
        });
      }
    } catch (e) {

      debugPrint('Login error: $e');

      setState(() {

        errorMsg = 'Error: $e';
        loading = false;
      });
    }
  }

  @override
  void dispose() {

    usernameCtrl.dispose();

    passwordCtrl.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      body: Container(

        width: double.infinity,

        height: double.infinity,

        decoration: const BoxDecoration(

          gradient: LinearGradient(

            begin: Alignment.topLeft,

            end: Alignment.bottomRight,

            colors: [

              Color(0xFF1E3A5F),

              Color(0xFF2D5F8A),

              Color(0xFF1E3A5F),
            ],
          ),
        ),

        child: SafeArea(

          child: Center(

            child: SingleChildScrollView(

              padding:
              EdgeInsets.symmetric(
                horizontal: R.sp(context, 32),
              ),

              child: Column(

                mainAxisAlignment:
                MainAxisAlignment.center,

                children: [

                  // ICON

                  Container(

                    width: 100,

                    height: 100,

                    decoration: BoxDecoration(

                      color: Colors.white24,

                      borderRadius:
                      BorderRadius.circular(
                        30,
                      ),
                    ),

                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: Image.asset(
                        'assets/app_icon.png',
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // TITLE

                  Text(

                    StoreConfig.instance.storeName,

                    style: TextStyle(

                      color: Colors.white,

                      fontSize: 36,

                      fontWeight:
                      FontWeight.bold,

                      letterSpacing: 1.2,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(

                    'Iniciá sesión para continuar',

                    style: TextStyle(

                      color:
                      Colors.white.withValues(alpha: 0.7),

                      fontSize: 16,
                    ),
                  ),

                  const SizedBox(height: 48),

                  // CARD

                  Container(

                    width: double.infinity,

                    padding:
                    EdgeInsets.all(R.sp(context, 32)),

                    decoration: BoxDecoration(

                      color: Colors.white,

                      borderRadius:
                      BorderRadius.circular(
                        28,
                      ),

                      boxShadow: [

                        BoxShadow(

                          color:
                          Colors.black26,

                          blurRadius: 30,

                          offset:
                          const Offset(
                            0,
                            10,
                          ),
                        ),
                      ],
                    ),

                    child: Column(

                      children: [

                        // ERROR

                        if (errorMsg != null)

                          Container(

                            width:
                            double.infinity,

                            padding:
                            const EdgeInsets
                                .all(14),

                            margin:
                            const EdgeInsets
                                .only(
                              bottom: 20,
                            ),

                            decoration:
                            BoxDecoration(

                              color: Colors.red
                                  .shade50,

                              borderRadius:
                              BorderRadius.circular(
                                16,
                              ),

                              border:
                              Border.all(
                                color: Colors
                                    .red
                                    .shade200,
                              ),
                            ),

                            child: Row(

                              children: [

                                const Icon(

                                  Icons
                                      .error_outline,

                                  color: Colors
                                      .red,
                                ),

                                const SizedBox(
                                  width: 10,
                                ),

                                Expanded(

                                  child: Text(

                                    errorMsg!,

                                    style: const TextStyle(
                                      color: Colors.red,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // USERNAME

                        TextField(

                          controller:
                          usernameCtrl,

                          decoration:
                          InputDecoration(

                            labelText:
                            'Usuario',

                            prefixIcon:
                            const Icon(
                              Icons.person,
                            ),

                            filled: true,

                            fillColor:
                            const Color(
                              0xFFF5F5F5,
                            ),

                            border:
                            OutlineInputBorder(

                              borderRadius:
                              BorderRadius.circular(
                                18,
                              ),

                              borderSide:
                              BorderSide
                                  .none,
                            ),
                          ),
                        ),

                        const SizedBox(
                          height: 18,
                        ),

                        // PASSWORD

                        TextField(

                          controller:
                          passwordCtrl,

                          obscureText:
                          obscurePassword,

                          onSubmitted:
                              (_) => _login(),

                          decoration:
                          InputDecoration(

                            labelText:
                            'Contraseña',

                            prefixIcon:
                            const Icon(
                              Icons.lock,
                            ),

                            suffixIcon:
                            IconButton(

                              icon: Icon(

                                obscurePassword
                                    ? Icons
                                        .visibility_off
                                    : Icons
                                        .visibility,
                              ),

                              onPressed: () {

                                setState(() {

                                  obscurePassword =
                                      !obscurePassword;
                                });
                              },
                            ),

                            filled: true,

                            fillColor:
                            const Color(
                              0xFFF5F5F5,
                            ),

                            border:
                            OutlineInputBorder(

                              borderRadius:
                              BorderRadius.circular(
                                18,
                              ),

                              borderSide:
                              BorderSide
                                  .none,
                            ),
                          ),
                        ),

                        const SizedBox(
                          height: 28,
                        ),

                        // BUTTON

                        ClipRRect(

                          borderRadius:
                          BorderRadius.circular(
                            20,
                          ),

                          child: Container(

                            width:
                            double.infinity,

                            height: 60,

                            decoration:
                            const BoxDecoration(

                              gradient:
                              LinearGradient(
                                colors: [
                                  Color(
                                    0xFF2563EB,
                                  ),
                                  Color(
                                    0xFF1D4ED8,
                                  ),
                                ],
                              ),
                            ),

                            child: ElevatedButton(

                              onPressed:
                                  loading
                                      ? null
                                      : _login,

                              style:
                              ElevatedButton
                                  .styleFrom(

                                backgroundColor:
                                Colors
                                    .transparent,

                                shadowColor:
                                Colors
                                    .transparent,

                                shape:
                                RoundedRectangleBorder(
                                  borderRadius:
                                  BorderRadius
                                      .circular(
                                    20,
                                  ),
                                ),

                                elevation: 0,
                              ),

                      child: loading
                                    ? const SizedBox(
                                        width: 28,
                                        height:
                                            28,
                                        child:
                                            CircularProgressIndicator(
                                          color: Colors
                                              .white,
                                          strokeWidth:
                                              2.5,
                                        ),
                                      )
                                    : const Text(
                                        'Ingresar',
                                        style:
                                            TextStyle(
                                          color: Colors
                                              .white,
                                          fontSize:
                                              20,
                                          fontWeight:
                                              FontWeight
                                                  .bold,
                                        ),
                                      ),
                            ),
                          ),
                        ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const StudentLoginScreen()),
                                );
                              },
                              icon: const Icon(Icons.school),
                              label: const Text('Portal del Alumno'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF2563EB),
                                side: const BorderSide(color: Color(0xFF2563EB)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                textStyle: const TextStyle(fontSize: 16),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // QR DOWNLOAD
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: QrImageView(
                            data: Env.downloadUrl,
                            size: 60,
                            backgroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '¿No tenés la app?',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Escaneá el QR para descargar',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // FOOTER

                  Text(

                    'v1.0.0',

                    style: TextStyle(

                      color: Colors.white
                          .withValues(alpha: 0.4),

                      fontSize: 14,
                    ),
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
