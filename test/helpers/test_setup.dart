import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lasmunecasderamon_flutter/features/auth/data/auth_notifier.dart';



/// Dio que responde con `routes` cuando el path contiene alguna de sus claves
/// (y `{success: true}` en el resto), para tests que necesitan payloads
/// concretos de un endpoint.
Dio createMockDioWithRoutes(Map<String, dynamic> routes) {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        for (final entry in routes.entries) {
          if (options.path.contains(entry.key)) {
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: entry.value,
              ),
            );
            return;
          }
        }
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
