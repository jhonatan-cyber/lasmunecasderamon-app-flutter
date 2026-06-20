import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';





class HapticService {
  static const _enabledKey = 'haptics_enabled';
  static bool _enabled = true;

  
  static Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_enabledKey) ?? true;
  }

  
  static Future<void> setEnabled(bool enabled) async {
    _enabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
  }

  static bool get enabled => _enabled;

  

  static Future<void> light() async {
    if (!_enabled) return;
    try {
      await HapticFeedback.lightImpact();
    } catch (_) {}
  }

  static Future<void> medium() async {
    if (!_enabled) return;
    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  static Future<void> heavy() async {
    if (!_enabled) return;
    try {
      await HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  

  static Future<void> selection() async {
    if (!_enabled) return;
    try {
      await HapticFeedback.selectionClick();
    } catch (_) {}
  }

  

  
  
  
  
  static Future<void> trigger(String type) async {
    switch (type) {
      case 'light':
        await light();
      case 'medium':
        await medium();
      case 'heavy':
        await heavy();
      case 'selection':
        await selection();
    }
  }
}
