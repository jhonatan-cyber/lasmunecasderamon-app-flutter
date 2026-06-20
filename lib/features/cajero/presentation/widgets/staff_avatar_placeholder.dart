import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class StaffAvatarPlaceholder extends StatelessWidget {
  final String initials;
  final double size;

  const StaffAvatarPlaceholder({super.key, required this.initials, this.size = 22});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
      child: Center(
        child: Text(
          initials.isNotEmpty ? initials : 'U',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary, fontSize: size),
        ),
      ),
    );
  }
}
