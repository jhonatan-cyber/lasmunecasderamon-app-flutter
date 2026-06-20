import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_auth/local_auth.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:lasmunecasderamon_flutter/core/theme.dart'; 
import 'package:lasmunecasderamon_flutter/core/haptic_service.dart';
import '../../../core/hooks/set_state_provider.dart';
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
    await HapticService.light();
    final notifier = ref.read(setStateProvider('login').notifier);
    notifier.clearError();

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
          notifier.startSubmit();
          
          final u = creds['username'] ?? '';
          final p = creds['password'] ?? '';
          
          final requiere2FA = await authNotifier.login(username: u, password: p);
          
          if (requiere2FA) {
            notifier.endSubmit();
            if (mounted) context.push('/login-code');
          } else {
            notifier.endSubmit();
          }
        } else {
          notifier.setError('No hay credenciales guardadas. Inicia sesión manualmente primero.');
        }
      }
    } catch (e) {
      notifier.setError('Error al autenticar con biometría: ${e.toString().replaceFirst('Exception: ', '')}');
      notifier.endSubmit();
    }
  }

  Future<void> _login() async {
    await HapticService.light();
    if (!_formKey.currentState!.validate()) return;

    final u = _usernameController.text.trim();
    final p = _passwordController.text.trim();

    await ref.read(setStateProvider('login').notifier).guard(() async {
      final authNotifier = ref.read(authProvider.notifier);
      final requiere2FA = await authNotifier.login(username: u, password: p);

      if (requiere2FA && mounted) {
        context.push('/login-code');
      } else if (_isBiometricAvailable) {
        await authNotifier.saveCredentials(u, p);
        await authNotifier.setBiometricEnabled(true);
      }
    });
  }

  void _openQRScanner() {
    HapticService.light();
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: AppTheme.darkSurfaceColor,
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
                          Navigator.of(context).pop(); 
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
    await ref.read(setStateProvider('login').notifier).guard(() async {
      final authNotifier = ref.read(authProvider.notifier);
      final requiere2FA = await authNotifier.login(qrToken: qrToken);
      if (requiere2FA && mounted) context.push('/login-code');
    });
  }

  void _showForgotPasswordDialog() {
    context.push('/auth/reset-password');
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final formState = ref.watch(setStateProvider('login'));
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;
    final obscurePassword = formState.flags['obscurePassword'] ?? true;
    final isBusy = formState.isSubmitting || authState.isLoading;
    
    final accentColor = Theme.of(context).colorScheme.primary;
    final textColor = isDark ? Colors.white : Colors.black;
    final labelColor = isDark ? AppTheme.darkTextSecondary : const Color(0xFF4B5563);
    final borderColor = isDark ? AppTheme.darkBorderColor : const Color(0xFFD1D5DB);

    
    const transitionDuration = Duration(milliseconds: 250);
    const transitionCurve = Curves.easeOutCubic;

    return AnimatedTheme(
      data: AppTheme.getTheme(isDark ? Brightness.dark : Brightness.light, accentColor),
      duration: transitionDuration,
      child: Scaffold(
        body: Stack(
          children: [
            
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    accentColor.withValues(alpha: 0.8), 
                    const Color(0xFF0F0F10), 
                    const Color(0xFF0F0F10),
                    const Color(0xFF140D0B), 
                  ],
                  stops: [0.0, 0.4, 0.8, 1.0],
                ),
              ),
            ),
            
            AnimatedOpacity(
              opacity: isDark ? 0.0 : 1.0,
              duration: transitionDuration,
              curve: transitionCurve,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      accentColor.withValues(alpha: 0.05),
                      const Color(0xFFF9FAFB),
                      const Color(0xFFF9FAFB),
                      accentColor.withValues(alpha: 0.08),
                    ],
                    stops: [0.0, 0.4, 0.8, 1.0],
                  ),
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

                      
                      Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            
                            if (formState.error != null || authState.error != null) ...[
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
                                  formState.error ?? authState.error!,
                                  style: GoogleFonts.inter(
                                    color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

                            
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
                                  obscureText: obscurePassword,
                                  textInputAction: TextInputAction.done,
                                  onFieldSubmitted: (_) => _login(),
                                  decoration: InputDecoration(
                                    prefixIcon: Icon(Icons.lock_outline_rounded, color: labelColor),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                        color: labelColor,
                                      ),
                                      onPressed: () {
                                        ref.read(setStateProvider('login').notifier).toggleFlag('obscurePassword', defaultValue: true);
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
                                  onTap: isBusy ? null : _login,
                                  borderRadius: BorderRadius.circular(30),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    alignment: Alignment.center,
                                    child: isBusy
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
                              
                              _buildQuickLoginButton(
                                icon: Icons.qr_code_scanner_rounded,
                                label: 'Código QR',
                                onPressed: _openQRScanner,
                                isDark: isDark,
                                accentColor: accentColor,
                              ),
                              
                              
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
            
            
            Positioned(
              top: 50,
              right: 20,
              child: CircleAvatar(
                backgroundColor: isDark ? AppTheme.darkSurfaceColor : Colors.white,
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
    final btnBg = isDark ? AppTheme.darkSurfaceColor : Colors.white;
    final borderColor = isDark ? AppTheme.darkBorderColor : const Color(0xFFD1D5DB);
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
