import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor_hive_store/dio_cache_interceptor_hive_store.dart';
import '../../../core/api_client.dart';
import '../../../core/offline/providers.dart';
import '../domain/user.dart';

class AuthState {
  final User? user;
  final String? token;
  final bool isLoading;
  final Map<String, String>? tempAuthData;
  final String? error;

  AuthState({
    this.user,
    this.token,
    this.isLoading = false,
    this.tempAuthData,
    this.error,
  });

  AuthState copyWith({
    User? user,
    String? token,
    bool? isLoading,
    Map<String, String>? tempAuthData,
    String? error,
    bool clearUser = false,
    bool clearToken = false,
    bool clearTempAuthData = false,
    bool clearError = false,
  }) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      token: clearToken ? null : (token ?? this.token),
      isLoading: isLoading ?? this.isLoading,
      tempAuthData: clearTempAuthData ? null : (tempAuthData ?? this.tempAuthData),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiClient _apiClient;
  final _secureStorage = const FlutterSecureStorage();

  AuthNotifier(this._apiClient) : super(AuthState()) {
    checkAuth();
  }

  Future<void> checkAuth() async {
    state = state.copyWith(isLoading: true);
    try {
      final token = await _secureStorage.read(key: 'auth_token');
      final prefs = await SharedPreferences.getInstance();
      final userStr = prefs.getString('user');
      
      if (token != null && token.isNotEmpty && userStr != null) {
        final userMap = jsonDecode(userStr) as Map<String, dynamic>;
        state = state.copyWith(
          token: token,
          user: User.fromJson(userMap),
          isLoading: false,
        );
      } else {
        state = state.copyWith(isLoading: false, clearUser: true, clearToken: true);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Performs the login request.
  /// Returns `true` if verification code (OTP) is required, `false` if successfully authenticated.
    Future<bool> login({
    String? username,
    String? password,
    String? codigo,
    String? qrToken,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final Map<String, dynamic> payload = {};

      if (qrToken != null) {
        payload['qr_token'] = qrToken;
      } else if (username != null && password != null) {
        String emailToSend = username.trim();
        if (!emailToSend.contains('@')) {
          emailToSend = '$emailToSend@lasmunecasderamon.com';
        }
        payload['email'] = emailToSend;
        payload['password'] = password;
      } else {
        throw Exception('Credenciales o token QR requeridos');
      }

      if (codigo != null) {
        payload['codigo'] = codigo;
      }

      final response = await _apiClient.dio.post(
        '/auth/login',
        data: payload,
      );

      final data = response.data;

      // Handle "verification code required" flow
      if (data['requiereCodigo'] == true && username != null && password != null) {
        state = state.copyWith(
          isLoading: false,
          tempAuthData: {'username': username, 'password': password},
        );
        return true;
      }

      // Handle successful authentication
      final String? token = data['token'];
      final Map<String, dynamic>? userJson = data['user'];

      if (token != null && userJson != null) {
        final user = User.fromJson(userJson);
        
        // Save to persistent storage
        await _secureStorage.write(key: 'auth_token', value: token);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user', jsonEncode(userJson));

        state = state.copyWith(
          token: token,
          user: user,
          isLoading: false,
          clearTempAuthData: true,
        );
        return false;
      } else {
        final message = data['message'] ?? 'Error desconocido en autenticación';
        throw Exception(message);
      }
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? e.message ?? 'Error de conexión';
      state = state.copyWith(isLoading: false, error: message);
      rethrow;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  // Biometric methods
  Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('biometric_enabled') ?? false;
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometric_enabled', enabled);
    if (!enabled) {
      await removeCredentials();
    }
  }

  Future<void> saveCredentials(String username, String password) async {
    await _secureStorage.write(
      key: 'user_credentials',
      value: jsonEncode({'username': username, 'password': password}),
    );
  }

  Future<Map<String, String>?> getCredentials() async {
    final credsStr = await _secureStorage.read(key: 'user_credentials');
    if (credsStr == null) return null;
    try {
      final Map<String, dynamic> decoded = jsonDecode(credsStr);
      return {
        'username': decoded['username']?.toString() ?? '',
        'password': decoded['password']?.toString() ?? '',
      };
    } catch (_) {
      return null;
    }
  }

  Future<void> removeCredentials() async {
    await _secureStorage.delete(key: 'user_credentials');
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true);
    // Attempt backend logout (optional)
    try {
      await _apiClient.dio.post('/auth/logout');
    } catch (_) {}

    // Clear local storage
    await _secureStorage.delete(key: 'auth_token');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user');

    state = AuthState(); // Reset state
  }

  Future<void> updateProfile(User updatedUser) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user', jsonEncode(updatedUser.toJson()));
    state = state.copyWith(user: updatedUser);
  }

  /// Sends a password reset request to the backend.
  /// The backend should send a verification code to the user's email.
  Future<void> requestPasswordReset(String email) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _apiClient.dio.post('/auth/reset-password', data: {'email': email});
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? 'Error al solicitar el reset';
      state = state.copyWith(isLoading: false, error: message);
      rethrow;
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  /// Confirms a password reset with the verification code and new password.
  Future<void> confirmPasswordReset(String code, String newPassword) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _apiClient.dio.post('/auth/reset-password/confirm', data: {
        'code': code,
        'password': newPassword,
      });
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? 'Error al restablecer la contraseña';
      state = state.copyWith(isLoading: false, error: message);
      rethrow;
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }
}

// Providers definition

/// Persistent HTTP cache store (Hive‑backed).
///
/// Initialised lazily; the first read creates the store on disk under
/// the app's documents directory.
final cacheStoreProvider = FutureProvider<HiveCacheStore>((ref) {
  return ApiClient.createDefaultStore();
});

/// Pre‑configured API client with auth + cache + offline interceptors.
///
/// The cache store is injected when available — if initialisation fails
/// the client still works without caching.
/// The offline sync manager replays failed requests when connectivity
/// is restored.
final apiClientProvider = Provider<ApiClient>((ref) {
  final cacheStore = ref.watch(cacheStoreProvider).valueOrNull;
  final offlineSync = ref.watch(offlineSyncManagerProvider);
  final client = ApiClient(cacheStore: cacheStore, offlineSync: offlineSync);

  // Initialise the sync manager with this client's Dio instance so it
  // can replay queued requests.
  offlineSync.init(dio: client.dio);

  return client;
});

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AuthNotifier(apiClient);
});
