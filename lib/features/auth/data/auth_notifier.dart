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
    _apiClient.onUnauthorized = _handleUnauthorized;
    checkAuth();
  }

  /// El refresh token ya no sirve: se cierra la sesión localmente sin volver a
  /// llamar a la API (cualquier llamada seguiría respondiendo 401).
  void _handleUnauthorized() {
    if (state.user == null && state.token == null) return;
    _secureStorage.delete(key: 'auth_token');
    _secureStorage.delete(key: 'refresh_token');
    SharedPreferences.getInstance().then((prefs) => prefs.remove('user'));
    _apiClient.clearCache();
    state = AuthState();
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

      
      if (data['requiereCodigo'] == true && username != null && password != null) {
        state = state.copyWith(
          isLoading: false,
          tempAuthData: {'username': username, 'password': password},
        );
        return true;
      }

      
      final String? token = data['token'];
      final Map<String, dynamic>? userJson = data['user'];      if (token != null && userJson != null) {
        final user = User.fromJson(userJson);
        
        await _secureStorage.write(key: 'auth_token', value: token);
        final refreshToken = data['refreshToken'];
        if (refreshToken is String && refreshToken.isNotEmpty) {
          await _secureStorage.write(key: 'refresh_token', value: refreshToken);
        } else {
          await _secureStorage.delete(key: 'refresh_token');
        }
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user', jsonEncode(userJson));
        // Sesión nueva: descarta cualquier respuesta cacheada de la cuenta
        // anterior antes de que las pantallas empiecen a consultar datos.
        await _apiClient.clearCache();

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
    
    try {
      await _apiClient.dio.post('/auth/logout');
    } catch (_) {}

    
    await _secureStorage.delete(key: 'auth_token');
    await _secureStorage.delete(key: 'refresh_token');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user');
    await _apiClient.clearCache();

    state = AuthState(); 
  }

  Future<void> updateProfile(User updatedUser) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user', jsonEncode(updatedUser.toJson()));
    state = state.copyWith(user: updatedUser);
  }

  /// Reconsulta /auth/me y actualiza el usuario local; false si el servidor ya
  /// no lo resuelve (rol eliminado o cuenta desactivada) para que el llamador
  /// cierre la sesión.
  Future<bool> refreshUser() async {
    try {
      final res = await _apiClient.dio.get('/auth/me');
      final body = res.data;
      if (body is! Map || body['success'] != true) return false;

      final servidor = body['user'] is Map
          ? body['user'] as Map
          : (body['data'] is Map ? body['data'] : null);
      final currentUser = state.user;
      if (servidor == null || servidor['id'] == null || currentUser == null) {
        return false;
      }

      final updated = currentUser.copyWith(
        nombre: servidor['name']?.toString() ??
            servidor['nombre']?.toString() ??
            currentUser.nombre,
        email: servidor['email']?.toString() ?? currentUser.email,
        role: servidor['role']?.toString() ?? currentUser.role,
        nick: servidor['nick']?.toString() ?? currentUser.nick,
        phone: servidor['phone']?.toString() ?? currentUser.phone,
        address: servidor['address']?.toString() ?? currentUser.address,
        estadoCivil: servidor['estado_civil']?.toString() ??
            servidor['maritalStatus']?.toString() ??
            currentUser.estadoCivil,
        foto: servidor['foto']?.toString() ?? currentUser.foto,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user', jsonEncode(updated.toJson()));
      state = state.copyWith(user: updated);
      return true;
    } catch (_) {
      return false;
    }
  }

  
  
  Future<void> requestPasswordReset(String run) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _apiClient.dio.post('/auth/reset-password', data: {'run': run});
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? 'Error al resetear la contraseña';
      state = state.copyWith(isLoading: false, error: message);
      rethrow;
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }
}







final cacheStoreProvider = FutureProvider<HiveCacheStore>((ref) {
  return ApiClient.createDefaultStore();
});







final apiClientProvider = Provider<ApiClient>((ref) {
  final cacheStore = ref.watch(cacheStoreProvider).valueOrNull;
  final offlineSync = ref.watch(offlineSyncManagerProvider);
  final client = ApiClient(cacheStore: cacheStore, offlineSync: offlineSync);

  
  
  offlineSync.init(dio: client.dio);

  return client;
});

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AuthNotifier(apiClient);
});
