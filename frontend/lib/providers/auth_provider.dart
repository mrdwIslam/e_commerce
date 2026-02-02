import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/user_model.dart';
import '../services/api_service.dart';

/// Состояние аутентификации
class AuthState {
  final bool isAuthenticated;
  final bool isLoading;
  final String? accessToken;
  final String? refreshToken;
  final User? user;
  final String? errorMessage;

  const AuthState({
    this.isAuthenticated = false,
    this.isLoading = false,
    this.accessToken,
    this.refreshToken,
    this.user,
    this.errorMessage,
  });

  /// Начальное состояние
  factory AuthState.initial() => const AuthState();

  /// Состояние загрузки
  factory AuthState.loading() => const AuthState(isLoading: true);

  /// Авторизованное состояние
  factory AuthState.authenticated({
    required String accessToken,
    required String refreshToken,
    User? user,
  }) {
    return AuthState(
      isAuthenticated: true,
      accessToken: accessToken,
      refreshToken: refreshToken,
      user: user,
    );
  }

  /// Состояние ошибки
  factory AuthState.error(String message) {
    return AuthState(errorMessage: message);
  }

  /// Имя пользователя для отображения
  String get displayName {
    if (user != null) {
      return user!.fullName.isNotEmpty ? user!.fullName : user!.username;
    }
    return 'Гость';
  }

  /// Email пользователя
  String get email => user?.email ?? '';

  /// Телефон пользователя
  String get phone => user?.phone ?? '';

  /// Аватар пользователя
  String? get avatar => user?.avatar;

  /// Копирование с изменениями
  AuthState copyWith({
    bool? isAuthenticated,
    bool? isLoading,
    String? accessToken,
    String? refreshToken,
    User? user,
    String? errorMessage,
    bool clearError = false,
    bool clearUser = false,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      user: clearUser ? null : (user ?? this.user),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  String toString() {
    return 'AuthState(isAuthenticated: $isAuthenticated, isLoading: $isLoading, user: ${user?.username})';
  }
}

/// Notifier для управления аутентификацией
class AuthNotifier extends StateNotifier<AuthState> {
  final ApiService _apiService;
  final FlutterSecureStorage _storage;

  AuthNotifier({
    ApiService? apiService,
    FlutterSecureStorage? storage,
  })  : _apiService = apiService ?? ApiService(),
        _storage = storage ?? const FlutterSecureStorage(),
        super(const AuthState()) {
    _init();
  }

  /// Ключи для хранения токенов
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';

  /// Инициализация - проверка сохранённых токенов
  Future<void> _init() async {
    try {
      final accessToken = await _storage.read(key: _accessTokenKey);
      final refreshToken = await _storage.read(key: _refreshTokenKey);

      if (accessToken != null && refreshToken != null) {
        // Устанавливаем токены в API сервис
        _apiService.setTokens(access: accessToken, refresh: refreshToken);

        // Настраиваем callback для обновления токенов
        _setupTokenCallbacks();

        // Пробуем загрузить профиль
        try {
          final user = await _apiService.getProfile();
          state = AuthState.authenticated(
            accessToken: accessToken,
            refreshToken: refreshToken,
            user: user,
          );
        } catch (e) {
          // Токен невалиден - очищаем
          if (kDebugMode) print('❌ Token invalid, clearing: $e');
          await _clearTokens();
        }
      }
    } catch (e) {
      if (kDebugMode) print('❌ Auth init error: $e');
    }
  }

  /// Настройка callback'ов для API сервиса
  void _setupTokenCallbacks() {
    _apiService.onTokensChanged = (access, refresh) async {
      if (access != null && refresh != null) {
        await _saveTokens(access, refresh);
        state = state.copyWith(
          accessToken: access,
          refreshToken: refresh,
        );
      } else {
        await _clearTokens();
        state = AuthState.initial();
      }
    };

    _apiService.onSessionExpired = () async {
      await logout();
    };
  }

  /// Сохранение токенов
  Future<void> _saveTokens(String accessToken, String refreshToken) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
  }

  /// Очистка токенов
  Future<void> _clearTokens() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    _apiService.clearTokens();
  }

  /// Очистить ошибку
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  // ════════════════════════════════════════════════════════════════════════════
  // ВХОД
  // ════════════════════════════════════════════════════════════════════════════

  /// Вход в систему
  Future<bool> login(String usernameOrEmail, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final tokens = await _apiService.login(
        usernameOrEmail: usernameOrEmail,
        password: password,
      );

      await _saveTokens(tokens.access, tokens.refresh);
      _setupTokenCallbacks();

      // Загружаем профиль
      User? user;
      try {
        user = await _apiService.getProfile();
      } catch (e) {
        if (kDebugMode) print('⚠️ Could not load profile: $e');
      }

      state = AuthState.authenticated(
        accessToken: tokens.access,
        refreshToken: tokens.refresh,
        user: user,
      );

      return true;
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Ошибка входа: $e',
      );
      return false;
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // РЕГИСТРАЦИЯ
  // ════════════════════════════════════════════════════════════════════════════

  /// Регистрация нового пользователя
  /// Возвращает null при успехе или сообщение об ошибке
  Future<String?> register({
    required String username,
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phone,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _apiService.register(
        username: username,
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
        phone: phone,
      );

      state = state.copyWith(isLoading: false);
      return null; // Успех
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
      return e.firstError;
    } catch (e) {
      final message = 'Ошибка регистрации: $e';
      state = state.copyWith(isLoading: false, errorMessage: message);
      return message;
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // OTP ВЕРИФИКАЦИЯ
  // ════════════════════════════════════════════════════════════════════════════

  /// Подтверждение OTP кода
  /// Возвращает null при успехе или сообщение об ошибке
  Future<String?> verifyOtp(String email, String code) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final result = await _apiService.verifyOtp(email: email, code: code);

      await _saveTokens(result.tokens.access, result.tokens.refresh);
      _setupTokenCallbacks();

      state = AuthState.authenticated(
        accessToken: result.tokens.access,
        refreshToken: result.tokens.refresh,
        user: result.user,
      );

      return null; // Успех
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
      return e.message;
    } catch (e) {
      final message = 'Ошибка подтверждения: $e';
      state = state.copyWith(isLoading: false, errorMessage: message);
      return message;
    }
  }

  /// Повторная отправка OTP
  Future<String?> resendOtp(String email) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _apiService.resendOtp(email: email);
      state = state.copyWith(isLoading: false);
      return null; // Успех
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
      return e.message;
    } catch (e) {
      final message = 'Ошибка отправки кода: $e';
      state = state.copyWith(isLoading: false, errorMessage: message);
      return message;
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // СБРОС ПАРОЛЯ
  // ════════════════════════════════════════════════════════════════════════════

  /// Запрос сброса пароля (шаг 1)
  Future<String?> requestPasswordReset(String email) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _apiService.requestPasswordReset(email: email);
      state = state.copyWith(isLoading: false);
      return null; // Успех
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
      return e.message;
    } catch (e) {
      final message = 'Ошибка: $e';
      state = state.copyWith(isLoading: false, errorMessage: message);
      return message;
    }
  }

  /// Подтверждение сброса пароля (шаг 2)
  Future<String?> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final tokens = await _apiService.confirmPasswordReset(
        email: email,
        code: code,
        newPassword: newPassword,
      );

      await _saveTokens(tokens.access, tokens.refresh);
      _setupTokenCallbacks();

      // Загружаем профиль
      User? user;
      try {
        user = await _apiService.getProfile();
      } catch (e) {
        if (kDebugMode) print('⚠️ Could not load profile: $e');
      }

      state = AuthState.authenticated(
        accessToken: tokens.access,
        refreshToken: tokens.refresh,
        user: user,
      );

      return null; // Успех
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
      return e.message;
    } catch (e) {
      final message = 'Ошибка сброса пароля: $e';
      state = state.copyWith(isLoading: false, errorMessage: message);
      return message;
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // ПРОФИЛЬ
  // ════════════════════════════════════════════════════════════════════════════

  /// Загрузить/обновить профиль
  Future<void> refreshProfile() async {
    if (!state.isAuthenticated) return;

    try {
      final user = await _apiService.getProfile();
      state = state.copyWith(user: user);
    } catch (e) {
      if (kDebugMode) print('❌ Refresh profile error: $e');
    }
  }

  /// Обновить данные профиля
  Future<String?> updateProfile({
    String? firstName,
    String? lastName,
    String? phone,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final user = await _apiService.updateProfile(
        firstName: firstName,
        lastName: lastName,
        phone: phone,
      );

      state = state.copyWith(isLoading: false, user: user);
      return null; // Успех
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
      return e.message;
    } catch (e) {
      final message = 'Ошибка обновления: $e';
      state = state.copyWith(isLoading: false, errorMessage: message);
      return message;
    }
  }

  /// Сменить пароль
  Future<String?> changePassword({
    required String oldPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final tokens = await _apiService.changePassword(
        oldPassword: oldPassword,
        newPassword: newPassword,
        newPasswordConfirm: confirmPassword,
      );

      await _saveTokens(tokens.access, tokens.refresh);

      state = state.copyWith(
        isLoading: false,
        accessToken: tokens.access,
        refreshToken: tokens.refresh,
      );

      return null; // Успех
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
      return e.message;
    } catch (e) {
      final message = 'Ошибка смены пароля: $e';
      state = state.copyWith(isLoading: false, errorMessage: message);
      return message;
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // ВЫХОД
  // ════════════════════════════════════════════════════════════════════════════

  /// Выход из системы
  Future<void> logout() async {
    await _clearTokens();
    _apiService.logout();
    state = AuthState.initial();
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ПРОВАЙДЕРЫ
// ══════════════════════════════════════════════════════════════════════════════

/// Основной провайдер аутентификации
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});

/// Провайдер статуса авторизации
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).isAuthenticated;
});

/// Провайдер загрузки
final isAuthLoadingProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).isLoading;
});

/// Провайдер текущего пользователя
final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authProvider).user;
});

/// Провайдер имени пользователя
final userDisplayNameProvider = Provider<String>((ref) {
  return ref.watch(authProvider).displayName;
});