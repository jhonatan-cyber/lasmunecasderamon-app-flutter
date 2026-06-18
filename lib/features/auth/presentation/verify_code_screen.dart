import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/auth_notifier.dart';
import '../../../core/hooks/set_state_provider.dart';
import '../../../core/theme.dart';

class VerifyCodeScreen extends ConsumerStatefulWidget {
  const VerifyCodeScreen({super.key});

  @override
  ConsumerState<VerifyCodeScreen> createState() => _VerifyCodeScreenState();
}

class _VerifyCodeScreenState extends ConsumerState<VerifyCodeScreen> {
  final List<TextEditingController> _controllers = List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  Future<void> _verifyCode() async {
    final code = _controllers.map((c) => c.text.trim()).join();
    if (code.length < 4) {
      ref.read(setStateProvider('verify_code').notifier).setError('Por favor ingresa los 4 dígitos');
      return;
    }

    final authState = ref.read(authProvider);
    final tempAuthData = authState.tempAuthData;

    if (tempAuthData == null) {
      ref.read(setStateProvider('verify_code').notifier).setError('Error de sesión. Vuelve al login.');
      return;
    }

    ref.read(setStateProvider('verify_code').notifier).clearError();

    try {
      final notifier = ref.read(authProvider.notifier);
      await notifier.login(
        username: tempAuthData['username']!,
        password: tempAuthData['password']!,
        codigo: code,
      );
      // Success redirect is handled automatically by the router listening to authProvider!
    } catch (e) {
      ref.read(setStateProvider('verify_code').notifier).setError(e.toString().replaceAll('Exception: ', ''));
      // Clear code inputs on error to let them retry
      for (var controller in _controllers) {
        controller.clear();
      }
      _focusNodes[0].requestFocus();
    }
  }

  void _onKeyInput(int index, String value) {
    if (value.isNotEmpty) {
      // Clean non-digits
      final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.isEmpty) {
        _controllers[index].clear();
        return;
      }
      
      _controllers[index].text = digits.substring(0, 1);
      
      // Move to next field
      if (index < 3) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
        _verifyCode();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final formState = ref.watch(setStateProvider('verify_code'));
    final accentColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      body: Stack(
        children: [
          // Background Premium Gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accentColor.withValues(alpha: 0.8), // Terracotta shadow
                  AppTheme.darkBgColor, // Obsidian
                  AppTheme.darkBgColor,
                  const Color(0xFF140D0B), // Warm wood accent
                ],
                stops: [0.0, 0.4, 0.8, 1.0],
              ),
            ),
          ),
          
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Back Button
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                        onPressed: () {
                          context.pop();
                        },
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Icon and Header
                    const Icon(
                      Icons.security_rounded,
                      size: 64,
                      color: AppTheme.secondaryColor, // Amber
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Código de Verificación',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Ingresá el código de 4 dígitos enviado a tu cuenta',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppTheme.darkTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Card Container
                    Container(
                      padding: const EdgeInsets.all(28.0),
                      decoration: BoxDecoration(
                        color: AppTheme.darkSurfaceColor.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: AppTheme.darkBorderColor,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 32,
                            offset: const Offset(0, 16),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Error Banner
                          if (formState.error != null || authState.error != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.errorColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: AppTheme.errorColor.withValues(alpha: 0.3),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                formState.error ?? authState.error!,
                                style: GoogleFonts.inter(
                                  color: const Color(0xFFFCA5A5),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],

                          // 4 Digits Row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: List.generate(4, (index) {
                              return SizedBox(
                                width: 56,
                                height: 64,
                                child: KeyboardListener(
                                  focusNode: FocusNode(), // Dummy focus node for key listener
                                  onKeyEvent: (KeyEvent event) {
                                    if (event is KeyDownEvent &&
                                        event.logicalKey == LogicalKeyboardKey.backspace &&
                                        _controllers[index].text.isEmpty &&
                                        index > 0) {
                                      _focusNodes[index - 1].requestFocus();
                                    }
                                  },
                                  child: TextFormField(
                                    controller: _controllers[index],
                                    focusNode: _focusNodes[index],
                                    style: GoogleFonts.outfit(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      LengthLimitingTextInputFormatter(2), // Allow 2 momentarily to catch paste/input
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    textInputAction: TextInputAction.next,
                                    onChanged: (value) => _onKeyInput(index, value),
                                    decoration: InputDecoration(
                                      counterText: '',
                                      contentPadding: EdgeInsets.zero,
                                      enabledBorder: OutlineInputBorder(
                                        borderSide: const BorderSide(color: Color(0xFF262629), width: 1.5),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderSide: const BorderSide(color: AppTheme.secondaryColor, width: 2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                          const SizedBox(height: 32),

                          // Verify Button
                          ElevatedButton(
                            onPressed: authState.isLoading ? null : _verifyCode,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              textStyle: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            child: authState.isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const Text('Verificar Código'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
