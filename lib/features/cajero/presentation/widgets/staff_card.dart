import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme.dart';
import '../../domain/personal_model.dart';
import 'staff_avatar_placeholder.dart';

class StaffCard extends StatelessWidget {
  final UserStaff user;
  final VoidCallback? onTap;

  const StaffCard({super.key, required this.user, this.onTap});

  String? get _photoUrl {
    if (user.foto != null && user.foto!.isNotEmpty) {
      return 'https://dashboard.xn--lasmuecasderamon-bub.com/img/users/${user.foto}';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasQR = user.qrToken != null;

    return Card(
      elevation: 4,
      color: isDark ? AppTheme.darkSurfaceColor : AppTheme.lightSurfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Column(
          children: [
            
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(19), topRight: Radius.circular(19)),
              ),
              child: Center(
                child: Text(user.role.toUpperCase(), style: GoogleFonts.inter(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
            const SizedBox(height: 10),
            
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 54, height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2), width: 1.5),
                  ),
                  child: ClipOval(
                    child: _photoUrl != null
                        ? Image.network(_photoUrl!, fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => StaffAvatarPlaceholder(initials: user.initials))
                        : StaffAvatarPlaceholder(initials: user.initials),
                  ),
                ),
                Positioned(
                  right: 0, bottom: 0,
                  child: Container(
                    width: 16, height: 16,
                    decoration: BoxDecoration(
                      color: hasQR ? Colors.green : Colors.redAccent,
                      shape: BoxShape.circle,
                      border: Border.all(color: isDark ? AppTheme.darkSurfaceColor : Colors.white, width: 1.5),
                    ),
                    child: Icon(hasQR ? Icons.check : Icons.close, size: 10, color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10.0),
              child: Text(user.name, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                  textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            Text('@${user.nick}', style: GoogleFonts.inter(color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary, fontSize: 11),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            const Spacer(),
            
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: hasQR ? Colors.green.withValues(alpha: 0.1) : Colors.redAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(hasQR ? Icons.qr_code_rounded : Icons.qr_code_outlined, size: 11, color: hasQR ? Colors.green : Colors.redAccent),
                  const SizedBox(width: 4),
                  Text(hasQR ? 'QR Activo' : 'Sin QR', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: hasQR ? Colors.green : Colors.redAccent)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
