import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// WhatsApp integration utilities.
///
/// Mirrors Expo's `utils/whatsapp.ts` — opens WhatsApp with a pre-filled
/// message for a given phone number.
class WhatsAppUtils {
  /// Opens WhatsApp to chat with [phone] and an optional pre-filled [message].
  ///
  /// [phone] must be an international format number (e.g. `+51999888777`)
  /// without spaces or special characters.
  ///
  /// Returns `true` if WhatsApp was successfully launched.
  static Future<bool> openChat(String phone, {String? message}) async {
    final encoded = message != null ? Uri.encodeComponent(message) : '';
    final uri = 'https://wa.me/$phone${encoded.isNotEmpty ? '?text=$encoded' : ''}';

    final url = Uri.parse(uri);
    if (await canLaunchUrl(url)) {
      return await launchUrl(url, mode: LaunchMode.externalApplication);
    }
    return false;
  }

  /// Opens WhatsApp to a specific group using the group's invite [link].
  static Future<bool> openGroup(String link) async {
    final url = Uri.parse(link);
    if (await canLaunchUrl(url)) {
      return await launchUrl(url, mode: LaunchMode.externalApplication);
    }
    return false;
  }

  /// Returns a tappable [TextSpan] that opens WhatsApp when tapped.
  ///
  /// Useful inside a `RichText` or `Text.rich()` widget.
  static TextSpan chatTextSpan(
    String phone, {
    String? message,
    required TextStyle style,
    TextStyle? linkStyle,
    VoidCallback? onError,
  }) {
    return TextSpan(
      text: phone,
      style: (linkStyle ?? style).copyWith(
        color: Colors.blue,
        decoration: TextDecoration.underline,
      ),
      recognizer: TapGestureRecognizer()
        ..onTap = () {
          openChat(phone, message: message).catchError((_) {
            if (kDebugMode) debugPrint('WhatsAppUtils: failed to open chat');
            onError?.call();
            return false;
          });
        },
    );
  }
}
