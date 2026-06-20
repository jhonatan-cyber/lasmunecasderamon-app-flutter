import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../domain/personal_model.dart';
import 'staff_avatar_placeholder.dart';

class StaffQrModal extends ConsumerStatefulWidget {
  final UserStaff user;
  final String codigoAsistencia;
  final Future<void> Function(String userId) onGenerateQr;
  final Future<UserStaff> Function(String userId) onFetchUser;

  const StaffQrModal({
    super.key,
    required this.user,
    required this.codigoAsistencia,
    required this.onGenerateQr,
    required this.onFetchUser,
  });

  @override
  ConsumerState<StaffQrModal> createState() => _StaffQrModalState();
}

class _StaffQrModalState extends ConsumerState<StaffQrModal> {
  Timer? _pollingTimer;
  bool _isGenerating = false;
  late UserStaff _user;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    if (_user.qrToken != null) _startPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      try {
        final updatedUser = await widget.onFetchUser(_user.id);
        if (_user.qrToken != null && updatedUser.qrToken == null) {
          _pollingTimer?.cancel();
          if (mounted) {
            setState(() => _user = updatedUser);
            AppSnackBar.showSuccess(context, 'Asistencia registrada correctamente.');
          }
        } else if (updatedUser.qrToken != _user.qrToken) {
          if (mounted) setState(() => _user = updatedUser);
        }
      } catch (_) {}
    });
  }

  Future<void> _handleGenerate() async {
    setState(() => _isGenerating = true);
    await widget.onGenerateQr(_user.id);
    
    final updated = await widget.onFetchUser(_user.id);
    if (mounted) {
      setState(() {
        _user = updated;
        _isGenerating = false;
      });
      if (updated.qrToken != null) _startPolling();
    }
  }

  String? get _photoUrl {
    if (_user.foto != null && _user.foto!.isNotEmpty) {
      return 'https://dashboard.xn--lasmuecasderamon-bub.com/img/users/${_user.foto}';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasQR = _user.qrToken != null;

    return Dialog(
      backgroundColor: isDark ? AppTheme.darkSurfaceColor : AppTheme.lightSurfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: () { _pollingTimer?.cancel(); Navigator.pop(context); },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.1), shape: BoxShape.circle),
                      child: Icon(Icons.close_rounded, size: 20, color: isDark ? Colors.white70 : Colors.black87),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              Container(
                width: 70, height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3), width: 2),
                ),
                child: ClipOval(
                  child: _photoUrl != null
                      ? Image.network(_photoUrl!, fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => StaffAvatarPlaceholder(initials: _user.initials, size: 22))
                      : StaffAvatarPlaceholder(initials: _user.initials, size: 22),
                ),
              ),
              const SizedBox(height: 12),
              Text(_user.fullName, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18), textAlign: TextAlign.center),
              const SizedBox(height: 2),
              Text('@${_user.nick}', style: GoogleFonts.inter(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                child: Text(_user.role.toUpperCase(), style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.primary, letterSpacing: 0.5)),
              ),
              const SizedBox(height: 24),
              
              if (hasQR) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: Image.network(
                    'https://api.qrserver.com/v1/create-qr-code/?size=250x250&color=e11d48&data=${_user.qrToken}',
                    width: 180, height: 180,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return SizedBox(width: 180, height: 180,
                        child: Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary)));
                    },
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.shield_outlined, size: 14, color: Colors.green),
                    const SizedBox(width: 6),
                    Text('Token de seguridad activo', style: GoogleFonts.inter(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w600)),
                  ],
                ),
                if (widget.codigoAsistencia.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)), borderRadius: BorderRadius.circular(10)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Código: ', style: GoogleFonts.inter(fontSize: 12, color: isDark ? Colors.white70 : Colors.black54)),
                        Text(widget.codigoAsistencia, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity, height: 46,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _isGenerating ? null : _handleGenerate,
                    child: _isGenerating
                        ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.primary))
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.refresh_rounded, size: 18, color: Theme.of(context).colorScheme.primary),
                              const SizedBox(width: 8),
                              Text('Regenerar QR', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                            ],
                          ),
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05), shape: BoxShape.circle),
                  child: Icon(Icons.qr_code_scanner_rounded, size: 48, color: Theme.of(context).colorScheme.primary),
                ),
                const SizedBox(height: 16),
                Text('Sin Código QR', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 6),
                Text('Este usuario no tiene un código de asistencia asignado.',
                    style: GoogleFonts.inter(color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary, fontSize: 12), textAlign: TextAlign.center),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity, height: 48,
                  child: ElevatedButton(
                    style: AppTheme.getPrimaryButtonStyle(context),
                    onPressed: _isGenerating ? null : _handleGenerate,
                    child: _isGenerating
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.qr_code_rounded, size: 20),
                              const SizedBox(width: 8),
                              Text('Generar QR', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                            ],
                          ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
