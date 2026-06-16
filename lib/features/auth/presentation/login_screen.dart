import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_auth/local_auth.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:lasmunecasderamon_flutter/core/theme.dart'; // Para themeModeProvider y AppTheme
import '../data/auth_notifier.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  String? _localError;
  bool _isLoading = false;

  // Biometrics and QR status
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _isBiometricAvailable = false;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _checkBiometrics() async {
    try {
      final canAuthenticateWithBiometrics = await _localAuth.canCheckBiometrics;
      final hasBiometrics = await _localAuth.isDeviceSupported();
      final isAvailable = canAuthenticateWithBiometrics && hasBiometrics;
      
      if (mounted) {
        setState(() {
          _isBiometricAvailable = isAvailable;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isBiometricAvailable = false;
        });
      }
    }
  }

  Future<void> _authenticateBiometrics() async {
    setState(() {
      _localError = null;
    });

    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Inicia sesión con tu huella dactilar',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
      
      if (authenticated) {
        final authNotifier = ref.read(authProvider.notifier);
        final creds = await authNotifier.getCredentials();
        
        if (creds != null) {
          setState(() {
            _isLoading = true;
          });
          
          final u = creds['username'] ?? '';
          final p = creds['password'] ?? '';
          
          final requiere2FA = await authNotifier.login(username: u, password: p);
          
          if (requiere2FA) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
              context.push('/login-code');
            }
          }
        } else {
          setState(() {
            _localError = 'No hay credenciales guardadas. Inicia sesión manualmente primero.';
          });
        }
      }
    } catch (e) {
      setState(() {
        _localError = 'Error al autenticar con biometría: ${e.toString().replaceFirst('Exception: ', '')}';
        _isLoading = false;
      });
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _localError = null;
    });

    final u = _usernameController.text.trim();
    final p = _passwordController.text.trim();

    try {
      final authNotifier = ref.read(authProvider.notifier);
      final requiere2FA = await authNotifier.login(username: u, password: p);

      if (requiere2FA) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          context.push('/login-code');
        }
      } else {
        if (_isBiometricAvailable) {
          await authNotifier.saveCredentials(u, p);
          await authNotifier.setBiometricEnabled(true);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _localError = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  void _openQRScanner() {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: const Color(0xFF18181A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: SizedBox(
              width: double.infinity,
              height: 420,
              child: Stack(
                children: [
                  MobileScanner(
                    onDetect: (capture) async {
                      final List<Barcode> barcodes = capture.barcodes;
                      if (barcodes.isNotEmpty) {
                        final qrData = barcodes.first.rawValue;
                        if (qrData != null) {
                          Navigator.of(context).pop(); // Cerrar modal
                          _loginWithQR(qrData);
                        }
                      }
                    },
                  ),
                  Positioned(
                    top: 16,
                    right: 16,
                    child: CircleAvatar(
                      backgroundColor: Colors.black54,
                      child: IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 24,
                    left: 20,
                    right: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Text(
                        'Escanea el código QR de asistencia',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _loginWithQR(String qrToken) async {
    setState(() {
      _isLoading = true;
      _localError = null;
    });
    try {
      final authNotifier = ref.read(authProvider.notifier);
      final requiere2FA = await authNotifier.login(qrToken: qrToken);
      
      if (requiere2FA) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          context.push('/login-code');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _localError = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  void _showForgotPasswordDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF18181A),
          title: Text(
            'Recuperar Contraseña',
            style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Por favor, comunícate con el Administrador o el personal de Soporte Técnico de la empresa para reestablecer tus credenciales de acceso.',
            style: GoogleFonts.inter(color: const Color(0xFF9CA3AF)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Entendido',
                style: GoogleFonts.inter(color: const Color(0xFFD84315), fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;
    
    final accentColor = const Color(0xFFD84315);
    final textColor = isDark ? Colors.white : Colors.black;
    final labelColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563);
    final borderColor = isDark ? const Color(0xFF262629) : const Color(0xFFD1D5DB);

    // Dynamic duration and curve for theme transition
    const transitionDuration = Duration(milliseconds: 250);
    const transitionCurve = Curves.easeOutCubic;

    return AnimatedTheme(
      data: isDark ? AppTheme.darkTheme : AppTheme.lightTheme,
      duration: transitionDuration,
      child: Scaffold(
        body: Stack(
          children: [
            // Dark Background Gradient (base layer)
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF2E0C04), // Terracotta shadow
                    Color(0xFF0F0F10), // Obsidian
                    Color(0xFF0F0F10),
                    Color(0xFF140D0B), // Warm wood accent
                  ],
                  stops: [0.0, 0.4, 0.8, 1.0],
                ),
              ),
            ),
            // Light Background Gradient (fades in/out over dark layer)
            AnimatedOpacity(
              opacity: isDark ? 0.0 : 1.0,
              duration: transitionDuration,
              curve: transitionCurve,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFFFF3F0),
                      Color(0xFFF9FAFB),
                      Color(0xFFF9FAFB),
                      Color(0xFFFFECE5),
                    ],
                    stops: [0.0, 0.4, 0.8, 1.0],
                  ),
                ),
              ),
            ),
            
            // Theme Toggle Button (Top Right)
            Positioned(
              top: 50,
              right: 20,
              child: CircleAvatar(
                backgroundColor: isDark ? const Color(0xFF18181A) : Colors.white,
                child: IconButton(
                  icon: Icon(
                    isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                    color: isDark ? Colors.yellow : Colors.deepPurple,
                  ),
                  onPressed: () {
                    ref.read(themeModeProvider.notifier).state = 
                      isDark ? ThemeMode.light : ThemeMode.dark;
                  },
                ),
              ),
            ),

            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Brand Logo/Header Area
                      Center(
                        child: Image.asset(
                          'assets/images/logo2.png',
                          height: 110,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.restaurant_menu_rounded,
                              size: 64,
                              color: accentColor,
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 36),

                      // No-Card Form container directly on background
                      Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Error Display
                            if (_localError != null || authState.error != null) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  _localError ?? authState.error!,
                                  style: GoogleFonts.inter(
                                    color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

                            // Username Field
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(left: 16, bottom: 6),
                                  child: AnimatedDefaultTextStyle(
                                    duration: transitionDuration,
                                    curve: transitionCurve,
                                    style: GoogleFonts.inter(
                                      color: labelColor,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    child: const Text('Nick'),
                                  ),
                                ),
                                TextFormField(
                                  controller: _usernameController,
                                  style: TextStyle(color: textColor),
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  decoration: InputDecoration(
                                    prefixIcon: Icon(Icons.person_outline_rounded, color: labelColor),
                                    hintText: 'Nick',
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                    enabledBorder: OutlineInputBorder(
                                      borderSide: BorderSide(color: borderColor, width: 1.5),
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderSide: BorderSide(color: accentColor, width: 2),
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                    errorBorder: OutlineInputBorder(
                                      borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                    focusedErrorBorder: OutlineInputBorder(
                                      borderSide: const BorderSide(color: Color(0xFFEF4444), width: 2),
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Por favor ingresa tu nick';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // Password Field
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(left: 16, bottom: 6),
                                  child: AnimatedDefaultTextStyle(
                                    duration: transitionDuration,
                                    curve: transitionCurve,
                                    style: GoogleFonts.inter(
                                      color: labelColor,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    child: const Text('Contraseña'),
                                  ),
                                ),
                                TextFormField(
                                  controller: _passwordController,
                                  style: TextStyle(color: textColor),
                                  obscureText: _obscurePassword,
                                  textInputAction: TextInputAction.done,
                                  onFieldSubmitted: (_) => _login(),
                                  decoration: InputDecoration(
                                    prefixIcon: Icon(Icons.lock_outline_rounded, color: labelColor),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                        color: labelColor,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _obscurePassword = !_obscurePassword;
                                        });
                                      },
                                    ),
                                    hintText: '••••••••',
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                    enabledBorder: OutlineInputBorder(
                                      borderSide: BorderSide(color: borderColor, width: 1.5),
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderSide: BorderSide(color: accentColor, width: 2),
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                    errorBorder: OutlineInputBorder(
                                      borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                    focusedErrorBorder: OutlineInputBorder(
                                      borderSide: const BorderSide(color: Color(0xFFEF4444), width: 2),
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Por favor ingresa tu contraseña';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                            
                            // Forgot Password Link
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _showForgotPasswordDialog,
                                child: Text(
                                  '¿Olvidaste tu contraseña?',
                                  style: GoogleFonts.inter(
                                    color: accentColor,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Login Button (AnimatedContainer for smooth theme morphing)
                            AnimatedContainer(
                              duration: transitionDuration,
                              curve: transitionCurve,
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white : Colors.black,
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: (_isLoading || authState.isLoading) ? null : _login,
                                  borderRadius: BorderRadius.circular(30),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    alignment: Alignment.center,
                                    child: (_isLoading || authState.isLoading)
                                      ? SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(
                                              isDark ? Colors.black : Colors.white,
                                            ),
                                          ),
                                        )
                                      : AnimatedDefaultTextStyle(
                                          duration: transitionDuration,
                                          curve: transitionCurve,
                                          style: GoogleFonts.inter(
                                            color: isDark ? Colors.black : Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          child: const Text('Iniciar Sesión'),
                                        ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Quick login options (QR and Fingerprint)
                      Column(
                        children: [
                          Row(
                            children: [
                              Expanded(child: Divider(color: borderColor, thickness: 1)),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: AnimatedDefaultTextStyle(
                                  duration: transitionDuration,
                                  curve: transitionCurve,
                                  style: GoogleFonts.inter(
                                    color: labelColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  child: const Text('O ingresa con'),
                                ),
                              ),
                              Expanded(child: Divider(color: borderColor, thickness: 1)),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // QR Login Button
                              _buildQuickLoginButton(
                                icon: Icons.qr_code_scanner_rounded,
                                label: 'Código QR',
                                onPressed: _openQRScanner,
                                isDark: isDark,
                                accentColor: accentColor,
                              ),
                              
                              // Biometrics Login Button (only show if available)
                              if (_isBiometricAvailable) ...[
                                const SizedBox(width: 24),
                                _buildQuickLoginButton(
                                  icon: Icons.fingerprint_rounded,
                                  label: 'Huella',
                                  onPressed: _authenticateBiometrics,
                                  isDark: isDark,
                                  accentColor: accentColor,
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickLoginButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required bool isDark,
    required Color accentColor,
  }) {
    final btnBg = isDark ? const Color(0xFF18181A) : Colors.white;
    final borderColor = isDark ? const Color(0xFF262629) : const Color(0xFFD1D5DB);
    final textColor = isDark ? Colors.white : Colors.black;
    
    const transitionDuration = Duration(milliseconds: 250);
    const transitionCurve = Curves.easeOutCubic;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: AnimatedContainer(
            duration: transitionDuration,
            curve: transitionCurve,
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: btnBg,
              shape: BoxShape.circle,
              border: Border.all(color: borderColor, width: 1.5),
            ),
            child: Center(
              child: Icon(icon, color: accentColor, size: 28),
            ),
          ),
        ),
        const SizedBox(height: 8),
        AnimatedDefaultTextStyle(
          duration: transitionDuration,
          curve: transitionCurve,
          style: GoogleFonts.inter(
            color: textColor,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          child: Text(label),
        ),
      ],
    );
  }
}
