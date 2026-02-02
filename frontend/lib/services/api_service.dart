import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:http/http.dart' as http;

import '../core/constants.dart';
import '../models/category_model.dart' as models;
import '../models/product_model.dart';
import '../models/user_model.dart';
import '../models/order_model.dart';
import '../models/favorite_model.dart';
import '../models/cart_model.dart';

/// Исключение API
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final Map<String, dynamic>? errors;

  ApiException({
    required this.message,
    this.statusCode,
    this.errors,
  });

  @override
  String toString() => message;

  /// Получить первую ошибку из списка
  String get firstError {
    if (errors == null || errors!.isEmpty) return message;

    final firstKey = errors!.keys.first;
    final firstValue = errors![firstKey];

    if (firstValue is List && firstValue.isNotEmpty) {
      return firstValue.first.toString();
    }
    return firstValue.toString();
  }

  /// Получить ошибку по ключу
  String? getError(String key) {
    if (errors == null) return null;
    final value = errors![key];
    if (value is List && value.isNotEmpty) {
      return value.first.toString();
    }
    return value?.toString();
  }
}

/// Результат API запроса
class ApiResult<T> {
  final T? data;
  final ApiException? error;
  final bool isSuccess;

  ApiResult._({
    this.data,
    this.error,
    required this.isSuccess,
  });

  factory ApiResult.success(T data) {
    return ApiResult._(data: data, isSuccess: true);
  }

  factory ApiResult.failure(ApiException error) {
    return ApiResult._(error: error, isSuccess: false);
  }

  /// Выполнить действие при успехе
  void onSuccess(void Function(T data) action) {
    final currentData = data;
    if (isSuccess && currentData != null) {
      action(currentData);
    }
  }

  /// Выполнить действие при ошибке
  void onError(void Function(ApiException error) action) {
    final currentError = error;
    if (!isSuccess && currentError != null) {
      action(currentError);
    }
  }

  /// Получить данные или выбросить исключение
  T getOrThrow() {
    if (isSuccess && data != null) {
      return data as T;
    }
    throw error ?? ApiException(message: 'Неизвестная ошибка');
  }

  /// Получить данные или значение по умолчанию
  T getOrDefault(T defaultValue) {
    if (isSuccess && data != null) {
      return data as T;
    }
    return defaultValue;
  }

  /// Получить данные или null
  T? getOrNull() {
    if (isSuccess) {
      return data;
    }
    return null;
  }
}

/// Основной сервис для работы с API
class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // HTTP клиент
  final http.Client _client = http.Client();

  // Токены
  String? _accessToken;
  String? _refreshToken;

  // Callback для обновления токенов в хранилище
  Function(String?, String?)? onTokensChanged;

  // Callback при истечении сессии
  Function()? onSessionExpired;

  /// Базовый URL API
  String get baseUrl => AppConstants.baseUrl;

  /// Установить токены
  void setTokens({String? access, String? refresh}) {
    _accessToken = access;
    _refreshToken = refresh;
  }

  /// Очистить токены
  void clearTokens() {
    _accessToken = null;
    _refreshToken = null;
  }

  /// Проверка авторизации
  bool get isAuthenticated => _accessToken != null;

  /// Заголовки по умолчанию
  Map<String, String> get _defaultHeaders => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  /// Заголовки с авторизацией
  Map<String, String> get _authHeaders => {
        ..._defaultHeaders,
        if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
      };

  /// Обработка ответа
  dynamic _processResponse(http.Response response) {
    final statusCode = response.statusCode;

    // Логирование в debug режиме
    if (kDebugMode) {
      print('📡 API Response [$statusCode]: ${response.request?.url}');
      if (response.body.isNotEmpty && response.body.length < 1000) {
        print('📦 Body: ${response.body}');
      }
    }

    // Пустой ответ
    if (response.body.isEmpty) {
      if (statusCode >= 200 && statusCode < 300) {
        return <String, dynamic>{};
      }
      throw ApiException(
        message: 'Пустой ответ от сервера',
        statusCode: statusCode,
      );
    }

    // Парсинг JSON
    dynamic data;
    try {
      data = jsonDecode(response.body);
    } catch (e) {
      throw ApiException(
        message: 'Ошибка парсинга ответа',
        statusCode: statusCode,
      );
    }

    // Успешный ответ
    if (statusCode >= 200 && statusCode < 300) {
      return data;
    }

    // Ошибки
    String message = 'Произошла ошибка';
    Map<String, dynamic>? errors;

    if (data is Map<String, dynamic>) {
      message = data['detail'] as String? ??
          data['error'] as String? ??
          data['message'] as String? ??
          message;

      // Сохраняем все ошибки валидации
      if (data.containsKey('details')) {
        errors = data['details'] as Map<String, dynamic>?;
      } else {
        // Проверяем ошибки полей
        errors = <String, dynamic>{};
        data.forEach((key, value) {
          if (key != 'detail' && key != 'error' && key != 'message') {
            errors![key] = value;
          }
        });
        if (errors.isEmpty) errors = null;
      }
    }

    // Специфические ошибки по коду
    switch (statusCode) {
      case 400:
        throw ApiException(
          message: message,
          statusCode: statusCode,
          errors: errors,
        );
      case 401:
        throw ApiException(
          message: 'Требуется авторизация',
          statusCode: statusCode,
        );
      case 403:
        throw ApiException(
          message: 'Доступ запрещён',
          statusCode: statusCode,
        );
      case 404:
        throw ApiException(
          message: 'Ресурс не найден',
          statusCode: statusCode,
        );
      case 422:
        throw ApiException(
          message: message,
          statusCode: statusCode,
          errors: errors,
        );
      case 500:
        throw ApiException(
          message: 'Внутренняя ошибка сервера',
          statusCode: statusCode,
        );
      default:
        throw ApiException(
          message: message,
          statusCode: statusCode,
          errors: errors,
        );
    }
  }

  /// Обёртка для сетевых запросов с обработкой ошибок
  Future<T> _safeRequest<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on SocketException {
      throw ApiException(message: 'Нет подключения к интернету');
    } on TimeoutException {
      throw ApiException(message: 'Превышено время ожидания');
    } on FormatException {
      throw ApiException(message: 'Ошибка формата данных');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: 'Неизвестная ошибка: $e');
    }
  }

  /// GET запрос
  Future<dynamic> _get(
    String endpoint, {
    Map<String, String>? queryParams,
    bool requiresAuth = false,
  }) async {
    return _safeRequest(() async {
      var uri = Uri.parse('$baseUrl$endpoint');
      if (queryParams != null && queryParams.isNotEmpty) {
        uri = uri.replace(queryParameters: queryParams);
      }

      if (kDebugMode) {
        print('📡 GET: $uri');
      }

      final response = await _client
          .get(
            uri,
            headers: requiresAuth ? _authHeaders : _defaultHeaders,
          )
          .timeout(const Duration(seconds: 30));

      // Обработка 401 - пробуем обновить токен
      if (response.statusCode == 401 && requiresAuth && _refreshToken != null) {
        final refreshed = await _tryRefreshToken();
        if (refreshed) {
          // Повторяем запрос с новым токеном
          final retryResponse = await _client
              .get(uri, headers: _authHeaders)
              .timeout(const Duration(seconds: 30));
          return _processResponse(retryResponse);
        } else {
          onSessionExpired?.call();
        }
      }

      return _processResponse(response);
    });
  }

  /// POST запрос
  Future<dynamic> _post(
    String endpoint, {
    Map<String, dynamic>? body,
    bool requiresAuth = false,
  }) async {
    return _safeRequest(() async {
      final uri = Uri.parse('$baseUrl$endpoint');

      if (kDebugMode) {
        print('📡 POST: $uri');
        if (body != null) print('📦 Body: $body');
      }

      final response = await _client
          .post(
            uri,
            headers: requiresAuth ? _authHeaders : _defaultHeaders,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(const Duration(seconds: 30));

      // Обработка 401
      if (response.statusCode == 401 && requiresAuth && _refreshToken != null) {
        final refreshed = await _tryRefreshToken();
        if (refreshed) {
          final retryResponse = await _client
              .post(
                uri,
                headers: _authHeaders,
                body: body != null ? jsonEncode(body) : null,
              )
              .timeout(const Duration(seconds: 30));
          return _processResponse(retryResponse);
        } else {
          onSessionExpired?.call();
        }
      }

      return _processResponse(response);
    });
  }

  /// PUT запрос
  Future<dynamic> _put(
    String endpoint, {
    Map<String, dynamic>? body,
    bool requiresAuth = true,
  }) async {
    return _safeRequest(() async {
      final uri = Uri.parse('$baseUrl$endpoint');

      if (kDebugMode) {
        print('📡 PUT: $uri');
        if (body != null) print('📦 Body: $body');
      }

      final response = await _client
          .put(
            uri,
            headers: requiresAuth ? _authHeaders : _defaultHeaders,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 401 && requiresAuth && _refreshToken != null) {
        final refreshed = await _tryRefreshToken();
        if (refreshed) {
          final retryResponse = await _client
              .put(
                uri,
                headers: _authHeaders,
                body: body != null ? jsonEncode(body) : null,
              )
              .timeout(const Duration(seconds: 30));
          return _processResponse(retryResponse);
        } else {
          onSessionExpired?.call();
        }
      }

      return _processResponse(response);
    });
  }

  /// DELETE запрос
  Future<dynamic> _delete(
    String endpoint, {
    Map<String, dynamic>? body,
    bool requiresAuth = true,
  }) async {
    return _safeRequest(() async {
      final uri = Uri.parse('$baseUrl$endpoint');

      if (kDebugMode) {
        print('📡 DELETE: $uri');
      }

      // http package не поддерживает body в delete, используем Request
      final request = http.Request('DELETE', uri);
      request.headers.addAll(requiresAuth ? _authHeaders : _defaultHeaders);
      if (body != null) {
        request.body = jsonEncode(body);
      }

      final streamedResponse =
          await _client.send(request).timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 401 && requiresAuth && _refreshToken != null) {
        final refreshed = await _tryRefreshToken();
        if (refreshed) {
          final retryRequest = http.Request('DELETE', uri);
          retryRequest.headers.addAll(_authHeaders);
          if (body != null) {
            retryRequest.body = jsonEncode(body);
          }
          final retryStreamedResponse = await _client
              .send(retryRequest)
              .timeout(const Duration(seconds: 30));
          final retryResponse =
              await http.Response.fromStream(retryStreamedResponse);
          return _processResponse(retryResponse);
        } else {
          onSessionExpired?.call();
        }
      }

      return _processResponse(response);
    });
  }

  /// Попытка обновить токен
  Future<bool> _tryRefreshToken() async {
    if (_refreshToken == null) return false;

    try {
      final uri = Uri.parse('$baseUrl/token/refresh/');
      final response = await _client
          .post(
            uri,
            headers: _defaultHeaders,
            body: jsonEncode({'refresh': _refreshToken}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _accessToken = data['access'];
        onTokensChanged?.call(_accessToken, _refreshToken);
        return true;
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Token refresh failed: $e');
      }
    }

    clearTokens();
    return false;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ВАЛИДАЦИЯ (Проверка уникальности)
  // ══════════════════════════════════════════════════════════════════════════

  /// Проверка занятости username
  /// GET /api/check-username/?username=xxx
  Future<bool> isUsernameTaken(String username) async {
    try {
      final data = await _get(
        '/check-username/',
        queryParams: {'username': username},
      );
      return data['exists'] as bool? ?? false;
    } catch (e) {
      if (kDebugMode) print('❌ isUsernameTaken error: $e');
      return false;
    }
  }

  /// Проверка занятости email
  /// GET /api/check-email/?email=xxx
  Future<bool> isEmailTaken(String email) async {
    try {
      final data = await _get(
        '/check-email/',
        queryParams: {'email': email},
      );
      return data['exists'] as bool? ?? false;
    } catch (e) {
      if (kDebugMode) print('❌ isEmailTaken error: $e');
      return false;
    }
  }

  /// Проверка занятости телефона
  /// GET /api/check-phone/?phone=xxx
  Future<bool> isPhoneTaken(String phone) async {
    try {
      final data = await _get(
        '/check-phone/',
        queryParams: {'phone': phone},
      );
      return data['exists'] as bool? ?? false;
    } catch (e) {
      if (kDebugMode) print('❌ isPhoneTaken error: $e');
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // РЕГИСТРАЦИЯ
  // ══════════════════════════════════════════════════════════════════════════

  /// Регистрация нового пользователя
  /// POST /api/register/
  ///
  /// Возвращает сообщение об успехе или выбрасывает [ApiException]
  Future<String> register({
    required String username,
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phone,
  }) async {
    final data = await _post(
      '/register/',
      body: {
        'username': username,
        'email': email,
        'password': password,
        'first_name': firstName,
        'last_name': lastName,
        'phone': phone,
      },
    );

    return data['message'] as String? ?? 'Код подтверждения отправлен';
  }

  /// Подтверждение OTP кода после регистрации
  /// POST /api/verify-otp/
  ///
  /// Возвращает [AuthResult] с токенами и данными пользователя
  Future<AuthResult> verifyOtp({
    required String email,
    required String code,
  }) async {
    final data = await _post(
      '/verify-otp/',
      body: {
        'email': email,
        'code': code,
      },
    );

    final result = AuthResult.fromJson(data as Map<String, dynamic>);

    // Сохраняем токены
    _accessToken = result.tokens.access;
    _refreshToken = result.tokens.refresh;
    onTokensChanged?.call(_accessToken, _refreshToken);

    return result;
  }

  /// Повторная отправка OTP кода
  /// POST /api/resend-otp/
  Future<String> resendOtp({required String email}) async {
    final data = await _post(
      '/resend-otp/',
      body: {'email': email},
    );

    return data['message'] as String? ?? 'Новый код отправлен';
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ВХОД / ВЫХОД
  // ══════════════════════════════════════════════════════════════════════════

  /// Вход в систему
  /// POST /api/login/
  ///
  /// [usernameOrEmail] - можно использовать username или email
  Future<AuthTokens> login({
    required String usernameOrEmail,
    required String password,
  }) async {
    final data = await _post(
      '/login/',
      body: {
        'username': usernameOrEmail,
        'password': password,
      },
    );

    final tokens = AuthTokens.fromJson(data as Map<String, dynamic>);

    // Сохраняем токены
    _accessToken = tokens.access;
    _refreshToken = tokens.refresh;
    onTokensChanged?.call(_accessToken, _refreshToken);

    return tokens;
  }

  /// Выход из системы (локальный)
  void logout() {
    clearTokens();
    onTokensChanged?.call(null, null);
  }

  /// Обновление access токена
  /// POST /api/token/refresh/
  Future<String> refreshAccessToken() async {
    if (_refreshToken == null) {
      throw ApiException(message: 'Refresh token отсутствует');
    }

    final data = await _post(
      '/token/refresh/',
      body: {'refresh': _refreshToken},
    );

    final newAccessToken = data['access'] as String;
    _accessToken = newAccessToken;
    onTokensChanged?.call(_accessToken, _refreshToken);

    return newAccessToken;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // СБРОС ПАРОЛЯ
  // ══════════════════════════════════════════════════════════════════════════

  /// Запрос на сброс пароля
  /// POST /api/reset-password/
  Future<String> requestPasswordReset({required String email}) async {
    final data = await _post(
      '/reset-password/',
      body: {'email': email},
    );

    return data['message'] as String? ?? 'Код для сброса пароля отправлен';
  }

  /// Подтверждение сброса пароля
  /// POST /api/reset-password/confirm/
  ///
  /// Возвращает [AuthTokens] - пользователь автоматически авторизуется
  Future<AuthTokens> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final data = await _post(
      '/reset-password/confirm/',
      body: {
        'email': email,
        'code': code,
        'new_password': newPassword,
      },
    );

    final tokens = AuthTokens.fromJson(data['tokens'] as Map<String, dynamic>);

    // Сохраняем токены
    _accessToken = tokens.access;
    _refreshToken = tokens.refresh;
    onTokensChanged?.call(_accessToken, _refreshToken);

    return tokens;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ПРОФИЛЬ ПОЛЬЗОВАТЕЛЯ
  // ══════════════════════════════════════════════════════════════════════════

  /// Получить профиль текущего пользователя
  /// GET /api/profile/
  Future<User> getProfile() async {
    final data = await _get('/profile/', requiresAuth: true);
    return User.fromJson(data as Map<String, dynamic>);
  }

  /// Обновить профиль
  /// PUT /api/profile/
  Future<User> updateProfile({
    String? firstName,
    String? lastName,
    String? phone,
  }) async {
    final body = <String, dynamic>{};
    if (firstName != null) body['first_name'] = firstName;
    if (lastName != null) body['last_name'] = lastName;
    if (phone != null) body['phone'] = phone;

    final data = await _put('/profile/', body: body, requiresAuth: true);
    return User.fromJson(data['user'] as Map<String, dynamic>);
  }

  /// Сменить пароль
  /// POST /api/profile/change-password/
  Future<AuthTokens> changePassword({
    required String oldPassword,
    required String newPassword,
    required String newPasswordConfirm,
  }) async {
    final data = await _post(
      '/profile/change-password/',
      body: {
        'old_password': oldPassword,
        'new_password': newPassword,
        'new_password_confirm': newPasswordConfirm,
      },
      requiresAuth: true,
    );

    final tokens = AuthTokens.fromJson(data['tokens'] as Map<String, dynamic>);

    // Обновляем токены
    _accessToken = tokens.access;
    _refreshToken = tokens.refresh;
    onTokensChanged?.call(_accessToken, _refreshToken);

    return tokens;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // КАТЕГОРИИ
  // ══════════════════════════════════════════════════════════════════════════

  /// Получить список категорий
  /// GET /api/categories/
  Future<List<models.Category>> getCategories() async {
    final data = await _get('/categories/');

    if (data is List) {
      return data
          .map((item) => models.Category.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    return [];
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ТОВАРЫ
  // ══════════════════════════════════════════════════════════════════════════

  /// Получить список товаров с фильтрацией и пагинацией
  /// GET /api/products/
  Future<ProductListResponse> getProducts({
    ProductFilter? filter,
  }) async {
    final queryParams = filter?.toQueryParams() ?? <String, String>{};

    final data = await _get(
      '/products/',
      queryParams: queryParams.isNotEmpty ? queryParams : null,
      requiresAuth: isAuthenticated, // Для is_favorite
    );

    return ProductListResponse.fromJson(data as Map<String, dynamic>);
  }

  /// Получить список товаров (простой список без пагинации)
  Future<List<Product>> getProductsList({
    String? category,
    String? search,
    String? ordering,
    bool? inStock,
  }) async {
    final filter = ProductFilter(
      category: category,
      search: search,
      ordering: ordering,
      inStock: inStock,
    );

    final response = await getProducts(filter: filter);
    return response.results;
  }

  /// Получить детали товара
  /// GET /api/products/{uuid}/
  Future<Product> getProductDetails(String productId) async {
    final data = await _get(
      '/products/$productId/',
      requiresAuth: isAuthenticated,
    );
    return Product.fromJson(data as Map<String, dynamic>);
  }

  /// Поиск товаров
  Future<List<Product>> searchProducts(String query) async {
    if (query.trim().isEmpty) return [];

    final response = await getProducts(
      filter: ProductFilter(search: query),
    );
    return response.results;
  }

  /// Получить товары категории
  Future<ProductListResponse> getProductsByCategory(
    String categorySlug, {
    String? ordering,
    int? page,
  }) async {
    return getProducts(
      filter: ProductFilter(
        category: categorySlug,
        ordering: ordering,
        page: page,
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ИЗБРАННОЕ
  // ══════════════════════════════════════════════════════════════════════════

  /// Получить список избранного
  /// GET /api/favorites/
  Future<List<Favorite>> getFavorites() async {
    final data = await _get('/favorites/', requiresAuth: true);

    if (data is List) {
      return data
          .map((item) => Favorite.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    return [];
  }

  /// Добавить товар в избранное
  /// POST /api/favorites/toggle/
  Future<FavoriteToggleResult> addToFavorites(String productId) async {
    final data = await _post(
      '/favorites/toggle/',
      body: {'product_id': productId},
      requiresAuth: true,
    );

    return FavoriteToggleResult.fromJson(data as Map<String, dynamic>);
  }

  /// Удалить товар из избранного (через body)
  /// DELETE /api/favorites/toggle/
  Future<FavoriteToggleResult> removeFromFavorites(String productId) async {
    final data = await _delete(
      '/favorites/toggle/',
      body: {'product_id': productId},
      requiresAuth: true,
    );

    return FavoriteToggleResult.fromJson(data as Map<String, dynamic>);
  }

  /// Удалить товар из избранного (через URL)
  /// DELETE /api/favorites/{product_uuid}/
  Future<FavoriteToggleResult> removeFromFavoritesByUrl(
      String productId) async {
    final data = await _delete(
      '/favorites/$productId/',
      requiresAuth: true,
    );

    return FavoriteToggleResult.fromJson(data as Map<String, dynamic>);
  }

  /// Переключить избранное (добавить/удалить)
  Future<FavoriteToggleResult> toggleFavorite(String productId,
      {required bool isFavorite}) async {
    if (isFavorite) {
      return removeFromFavorites(productId);
    } else {
      return addToFavorites(productId);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ЗАКАЗЫ
  // ══════════════════════════════════════════════════════════════════════════

  /// Получить список заказов текущего пользователя
  /// GET /api/orders/
  Future<List<Order>> getOrders() async {
    final data = await _get('/orders/', requiresAuth: true);

    if (data is List) {
      return data
          .map((item) => Order.fromListJson(item as Map<String, dynamic>))
          .toList();
    }

    return [];
  }

  /// Получить детали заказа
  /// GET /api/orders/{id}/
  Future<Order> getOrderDetails(int orderId) async {
    final data = await _get('/orders/$orderId/', requiresAuth: true);
    return Order.fromJson(data as Map<String, dynamic>);
  }

  /// Создать заказ
  /// POST /api/orders/create/
  ///
  /// Гостевой заказ разрешён (без авторизации)
  Future<Order> createOrder(CreateOrderRequest request) async {
    final data = await _post(
      '/orders/create/',
      body: request.toJson(),
      requiresAuth: isAuthenticated, // Опционально
    );

    return Order.fromJson(data['order'] as Map<String, dynamic>);
  }

  /// Создать заказ из корзины
  Future<Order> createOrderFromCart({
    required Cart cart,
    required String firstName,
    required String lastName,
    required String phone,
    String? email,
    required String address,
    String? note,
  }) async {
    final items = cart.items
        .map((item) => CreateOrderItem(
              productId: item.productId,
              quantity: item.quantity,
            ))
        .toList();

    final request = CreateOrderRequest(
      firstName: firstName,
      lastName: lastName,
      phone: phone,
      email: email,
      address: address,
      note: note,
      items: items,
    );

    return createOrder(request);
  }

  /// Отменить заказ
  /// POST /api/orders/{id}/cancel/
  Future<String> cancelOrder(int orderId) async {
    final data = await _post(
      '/orders/$orderId/cancel/',
      requiresAuth: true,
    );

    return data['message'] as String? ?? 'Заказ отменён';
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ
  // ══════════════════════════════════════════════════════════════════════════

  /// Получить полный URL изображения
  String? getImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) return null;

    // Если уже полный URL
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return imagePath;
    }

    // Убираем /api из baseUrl для медиа файлов
    final mediaBaseUrl = baseUrl.replaceAll('/api', '');

    // Добавляем слеш если нужно
    if (imagePath.startsWith('/')) {
      return '$mediaBaseUrl$imagePath';
    }

    return '$mediaBaseUrl/$imagePath';
  }

  /// Освобождение ресурсов
  void dispose() {
    _client.close();
  }
}