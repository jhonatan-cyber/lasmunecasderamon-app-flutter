import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lasmunecasderamon_flutter/features/auth/data/auth_notifier.dart';



Dio createMockDio() {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        
        handler.resolve(
          Response(
            requestOptions: options,
            statusCode: 200,
            data: {'success': true},
          ),
        );
      },
    ),
  );
  return dio;
}








void setupTestEnvironment() {
  SharedPreferences.setMockInitialValues({});
  GoogleFonts.config.allowRuntimeFetching = false;
}




void tearDownTestEnvironment() {
  GoogleFonts.config.allowRuntimeFetching = true;
}






















class TestAuthNotifier extends AuthNotifier {
  TestAuthNotifier(super.apiClient);

  @override
  Future<void> checkAuth() async {
    state = AuthState(isLoading: false);
  }
}

ProviderScope createTestApp({
  required Widget child,
  List<Override> overrides = const [],
}) {
  return ProviderScope(
    overrides: overrides,
    child: child,
  );
}
