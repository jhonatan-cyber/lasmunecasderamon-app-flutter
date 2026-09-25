import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// GlobalKey del ScaffoldMessenger de la app. Se engancha en
/// `MaterialApp.router(scaffoldMessengerKey: ...)` para poder mostrar snackbars
/// desde handlers globales (SSE) que no tienen un `context` propio.
final GlobalKey<ScaffoldMessengerState> globalMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

enum GlobalToastKind { success, error, warning, info }

/// Toast global usable sin `BuildContext` (handlers SSE en tiempo real).
class GlobalToast {
  static void show({
    required String title,
    required String body,
    GlobalToastKind kind = GlobalToastKind.info,
    Duration duration = const Duration(seconds: 4),
  }) {
    final messenger = globalMessengerKey.currentState;
    if (messenger == null) return;

    final (color, icon) = switch (kind) {
      GlobalToastKind.success => (Colors.green, Icons.check_circle_outline_rounded),
      GlobalToastKind.error => (Colors.redAccent, Icons.error_outline_rounded),
      GlobalToastKind.warning => (Colors.orange.shade800, Icons.warning_amber_rounded),
      GlobalToastKind.info => (Colors.blueGrey.shade700, Icons.info_outline_rounded),
    };

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    body,
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(12),
        duration: duration,
      ),
    );
  }
}
