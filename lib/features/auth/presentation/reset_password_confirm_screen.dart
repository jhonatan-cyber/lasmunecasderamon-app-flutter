import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme.dart';
import '../../../core/hooks/set_state_provider.dart';
import '../data/auth_notifier.dart';

/// Paso 2 del flujo de recuperación de contraseña.
///
/// El usuario ingresa el código recibido por email y su nueva contraseña.
class ResetPasswordConfirmScreen extends ConsumerStatefulWidget {
  const ResetPasswordConfirmScreen({super.key});

  @override
  ConsumerState<ResetPasswordConfirmScreen> createState() => _ResetPasswordConfirmScreenState();
}

class _ResetPasswordConfirmScreenState extends ConsumerState<ResetPasswordConfirmScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _confirmReset() async {
    if (!_formKey.currentState!.validate()) return;

    await ref.read(setStateProvider('reset_confirm').notifier).guard(() async {
      await ref.read(authProvider.notifier).confirmPasswordReset(
        _codeController.text.trim(),
        _passwordController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Contraseña actualizada exitosamente'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.go('/login');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final accentColor = Theme.of(context).colorScheme.primary;
    final textColor = isDark ? Colors.white : Colors.black;
    final bgColor = isDark ? AppTheme.darkBgColor : Colors.white;
    final cardBg = isDark ? AppTheme.darkSurfaceColor : Colors.grey.shade50;
    final formState = ref.watch(setStateProvider('reset_confirm'));

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textColor),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                Icon(Icons.verified_rounded, size: 56, color: accentColor),
                const SizedBox(height: 20),
                Text(
                  'Código de Verificación',
                  style: GoogleFonts.outfit(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Ingresa el código que enviamos a tu correo y establece una nueva contraseña.',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Code field
                      Text(
                        'Código de verificación',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _codeController,
                        keyboardType: TextInputType.text,
                        style: TextStyle(color: textColor, letterSpacing: 2),
                        decoration: InputDecoration(
                          prefixIcon: Icon(Icons.pin_rounded, color: isDark ? AppTheme.darkTextSecondary : Colors.grey),
                          hintText: '123456',
                          hintStyle: TextStyle(color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade400),
                          filled: true,
                          fillColor: isDark ? AppTheme.darkSurfaceColor : Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: isDark ? AppTheme.darkBorderColor : Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: isDark ? AppTheme.darkBorderColor : Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: accentColor, width: 2),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Ingresa el código';
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      // New password field
                      Text(
                        'Nueva contraseña',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: formState.flags['obscurePassword'] ?? true,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          prefixIcon: Icon(Icons.lock_outline_rounded, color: isDark ? AppTheme.darkTextSecondary : Colors.grey),
                          suffixIcon: IconButton(
                            icon: Icon(
                              (formState.flags['obscurePassword'] ?? true) ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              color: isDark ? AppTheme.darkTextSecondary : Colors.grey,
                            ),
                            onPressed: () => ref.read(setStateProvider('reset_confirm').notifier).toggleFlag('obscurePassword'),
                          ),
                          hintText: '••••••••',
                          hintStyle: TextStyle(color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade400),
                          filled: true,
                          fillColor: isDark ? AppTheme.darkSurfaceColor : Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: isDark ? AppTheme.darkBorderColor : Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: isDark ? AppTheme.darkBorderColor : Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: accentColor, width: 2),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Ingresa una contraseña';
                          if (v.length < 6) return 'Mínimo 6 caracteres';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      // Confirm password field
                      Text(
                        'Confirmar contraseña',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: formState.flags['obscureConfirm'] ?? true,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          prefixIcon: Icon(Icons.lock_outline_rounded, color: isDark ? AppTheme.darkTextSecondary : Colors.grey),
                          suffixIcon: IconButton(
                            icon: Icon(
                              (formState.flags['obscureConfirm'] ?? true) ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              color: isDark ? AppTheme.darkTextSecondary : Colors.grey,
                            ),
                            onPressed: () => ref.read(setStateProvider('reset_confirm').notifier).toggleFlag('obscureConfirm'),
                          ),
                          hintText: '••••••••',
                          hintStyle: TextStyle(color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade400),
                          filled: true,
                          fillColor: isDark ? AppTheme.darkSurfaceColor : Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: isDark ? AppTheme.darkBorderColor : Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: isDark ? AppTheme.darkBorderColor : Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: accentColor, width: 2),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Confirma tu contraseña';
                          if (v != _passwordController.text) return 'Las contraseñas no coinciden';
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                if (formState.error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            formState.error!,
                            style: GoogleFonts.inter(fontSize: 13, color: Colors.red.shade700),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: formState.isSubmitting ? null : _confirmReset,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26),
                      ),
                      elevation: 0,
                    ),
                    child: formState.isSubmitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Restablecer contraseña',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
