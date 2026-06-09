import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/database_helper.dart';
import '../services/responsive.dart';
import '../services/store_config.dart';
import 'home_screen.dart';

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

  int attempts = 0;

  DateTime? lockoutUntil;

  static const int maxAttempts = 3;

  static const Duration lockoutDuration =
      Duration(seconds: 30);

  static const Duration lockoutDuration2 =
      Duration(minutes: 2);

  @override
  void initState() {

    super.initState();

    _loadLockoutState();
  }

  Future<void> _loadLockoutState() async {

    final prefs =
    await SharedPreferences.getInstance();

    setState(() {

      attempts =
      prefs.getInt('login_attempts') ?? 0;

      final until =
      prefs.getString('lockout_until');

      lockoutUntil = until != null
          ? DateTime.tryParse(until)
          : null;
    });
  }

  Future<void> _saveLockoutState() async {

    final prefs =
    await SharedPreferences.getInstance();

    await prefs.setInt(
      'login_attempts',
      attempts,
    );

    if (lockoutUntil != null) {

      await prefs.setString(
        'lockout_until',
        lockoutUntil!.toIso8601String(),
      );
    } else {

      await prefs.remove('lockout_until');
    }
  }

  Future<void> _resetLockout() async {

    attempts = 0;

    lockoutUntil = null;

    await _saveLockoutState();
  }

  bool get isLockedOut {

    if (lockoutUntil == null) return false;

    if (DateTime.now().isAfter(lockoutUntil!)) {

      lockoutUntil = null;

      return false;
    }

    return true;
  }

  Duration get remainingLockout {

    if (lockoutUntil == null) return Duration.zero;

    final remaining =
        lockoutUntil!.difference(DateTime.now());

    return remaining.isNegative
        ? Duration.zero
        : remaining;
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

    if (isLockedOut) return;

    setState(() {

      loading = true;

      errorMsg = null;
    });

    try {

      final user =
      await DatabaseHelper.instance
          .login(username, password);

      if (!mounted) return;

      if (user != null) {

        await _resetLockout();

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

        attempts++;

        if (attempts >= maxAttempts) {

          lockoutUntil = DateTime.now().add(
            attempts >= 5
                ? lockoutDuration2
                : lockoutDuration,
          );

          await _saveLockoutState();

          setState(() {

            errorMsg =
            'Demasiados intentos. Esperá ${attempts >= 5 ? "2 min" : "30 seg"}';

            loading = false;
          });
        } else {

          await _saveLockoutState();

          setState(() {

            errorMsg =
            'Usuario o contraseña incorrectos ($attempts/$maxAttempts)';

            loading = false;
          });
        }
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

                        // LOCKOUT

                        if (isLockedOut)

                          Container(

                            width:
                            double.infinity,

                            padding:
                            const EdgeInsets
                                .all(12),

                            margin:
                            const EdgeInsets
                                .only(
                              bottom: 16,
                            ),

                            decoration:
                            BoxDecoration(

                              color: Colors
                                  .orange
                                  .shade50,

                              borderRadius:
                              BorderRadius.circular(
                                16,
                              ),
                            ),

                            child: Row(

                              mainAxisAlignment:
                              MainAxisAlignment
                                  .center,

                              children: [

                                const Icon(

                                  Icons
                                      .timer_off,

                                  color: Colors
                                      .orange,
                                ),

                                const SizedBox(
                                  width: 10,
                                ),

                                Text(

                                  'Esperá ${remainingLockout.inSeconds} seg',

                                  style:
                                  const TextStyle(
                                    color: Colors
                                        .orange,
                                    fontWeight:
                                    FontWeight
                                        .bold,
                                  ),
                                ),
                              ],
                            ),
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
                                  isLockedOut
                                  ? null
                                  : loading
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
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

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
