import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme.dart';
import '../../../core/global_messenger.dart';
import '../../../core/hooks/set_state_provider.dart';
import '../data/auth_notifier.dart';

/// Cambio de contraseña obligatorio: el backend marca `forcePasswordChange`
/// (login con la contraseña reseteada al RUN) y bloquea el resto de la sesión
/// hasta que se actualice. Equivalente a `app/(auth)/change-password.tsx` de la
/// app Expo, contra `POST /auth/change-password` `{ password, confirmPassword }`.
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _handleChangePassword() async {
    if (!_formKey.currentState!.validate()) return;

    final password = _passwordController.text;
    if (password != _confirmController.text) {
      ref
          .read(setStateProvider('change_password').notifier)
          .setError('Las contraseñas no coinciden');
      return;
    }

    final ok = await ref
        .read(setStateProvider('change_password').notifier)
        .guard(() async {
      await ref.read(apiClientProvider).dio.post(
            '/auth/change-password',
            data: {
              'password': password,
              'confirmPassword': _confirmController.text,
            },
          );
    });

    if (!ok || !mounted) return;

    // La marca vive solo en el usuario local: al cambiarla, se limpia.
    final auth = ref.read(authProvider);
    final user = auth.user;
    if (user != null) {
      await ref
          .read(authProvider.notifier)
          .updateProfile(user.copyWith(forcePasswordChange: false));
    }

    GlobalToast.show(
      title: 'Contraseña actualizada',
      body: 'Ya puedes continuar con tu sesión',
      kind: GlobalToastKind.success,
      duration: const Duration(seconds: 3),
    );
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final formState = ref.watch(setStateProvider('change_password'));
    final accentColor = Theme.of(context).colorScheme.primary;
    final textColor = isDark ? Colors.white : Colors.black;
    final bgColor = isDark ? AppTheme.darkBgColor : AppTheme.lightBgColor;
    final cardBg = isDark ? AppTheme.darkSurfaceColor : Colors.grey.shade50;
    final borderColor =
        isDark ? AppTheme.darkBorderColor : Colors.grey.shade300;
    final hintColor = isDark ? AppTheme.darkTextSecondary : Colors.grey;

    InputDecoration decoration({
      required String hint,
      required IconData prefixIcon,
      required bool obscure,
      required VoidCallback toggle,
    }) =>
        InputDecoration(
          prefixIcon: Icon(prefixIcon, color: hintColor),
          hintText: hint,
          hintStyle: TextStyle(color: hintColor),
          filled: true,
          fillColor: cardBg,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: borderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: accentColor, width: 2),
          ),
          suffixIcon: IconButton(
            icon: Icon(
              obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: hintColor,
            ),
            onPressed: toggle,
          ),
        );

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lock_reset_rounded, size: 56, color: accentColor),
                  const SizedBox(height: 20),
                  Text(
                    'Cambiar Contraseña',
                    style: GoogleFonts.outfit(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Debés cambiar tu contraseña antes de continuar.',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      color: hintColor,
                    ),
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    autocorrect: false,
                    enableSuggestions: false,
                    style: TextStyle(color: textColor),
                    decoration: decoration(
                      hint: 'Nueva contraseña (mínimo 8 caracteres)',
                      prefixIcon: Icons.lock_outline,
                      obscure: _obscurePassword,
                      toggle: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    validator: (v) {
                      final value = v ?? '';
                      if (value.trim().length < 8) {
                        return 'La contraseña debe tener al menos 8 caracteres';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmController,
                    obscureText: _obscureConfirm,
                    autocorrect: false,
                    enableSuggestions: false,
                    style: TextStyle(color: textColor),
                    decoration: decoration(
                      hint: 'Confirmar contraseña',
                      prefixIcon: Icons.lock_outline,
                      obscure: _obscureConfirm,
                      toggle: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Confirma la contraseña' : null,
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
                          Icon(Icons.error_outline,
                              color: Colors.red.shade700, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              formState.error!,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: Colors.red.shade700,
                              ),
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
                      onPressed: formState.isSubmitting
                          ? null
                          : _handleChangePassword,
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
                              'Guardar y Continuar',
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
      ),
    );
  }
}
