import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';





class WhatsAppUtils {
  
  
  
  
  
  
  static Future<bool> openChat(String phone, {String? message}) async {
    final encoded = message != null ? Uri.encodeComponent(message) : '';
    final uri = 'https://wa.me/$phone${encoded.isNotEmpty ? '?text=$encoded' : ''}';

    final url = Uri.parse(uri);
    if (await canLaunchUrl(url)) {
      return await launchUrl(url, mode: LaunchMode.externalApplication);
    }
    return false;
  }

  
  static Future<bool> openGroup(String link) async {
    final url = Uri.parse(link);
    if (await canLaunchUrl(url)) {
      return await launchUrl(url, mode: LaunchMode.externalApplication);
    }
    return false;
  }

  
  
  
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
