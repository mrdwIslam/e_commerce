import 'package:flutter/material.dart';

/// Константы приложения NextStore
class AppConstants {
  // Приватный конструктор - нельзя создать экземпляр
  AppConstants._();

  // ════════════════════════════════════════════════════════════════════════════
  // API НАСТРОЙКИ
  // ════════════════════════════════════════════════════════════════════════════

  /// Базовый URL API
  /// 
  /// Для Android эмулятора: http://10.0.2.2:8000/api
  /// Для iOS симулятора: http://localhost:8000/api
  /// Для реального устройства: http://YOUR_IP:8000/api
  static const String baseUrl = 'http://192.168.1.109:8000/api';

  /// URL для медиа файлов (без /api)
  static String get mediaUrl => baseUrl.replaceAll('/api', '');

  /// Таймаут для запросов (секунды)
  static const int requestTimeout = 30;

  /// Таймаут для загрузки файлов (секунды)
  static const int uploadTimeout = 60;

  // ════════════════════════════════════════════════════════════════════════════
  // ХРАНИЛИЩЕ
  // ════════════════════════════════════════════════════════════════════════════

  /// Ключ для access токена
  static const String accessTokenKey = 'access_token';

  /// Ключ для refresh токена
  static const String refreshTokenKey = 'refresh_token';

  /// Ключ для данных корзины
  static const String cartKey = 'cart_data';

  /// Ключ для настроек пользователя
  static const String settingsKey = 'user_settings';

  // ════════════════════════════════════════════════════════════════════════════
  // ВАЛИДАЦИЯ
  // ════════════════════════════════════════════════════════════════════════════

  /// Минимальная длина пароля
  static const int minPasswordLength = 8;

  /// Максимальная длина пароля
  static const int maxPasswordLength = 128;

  /// Минимальная длина username
  static const int minUsernameLength = 3;

  /// Максимальная длина username
  static const int maxUsernameLength = 30;

  /// Минимальная длина телефона
  static const int minPhoneLength = 8;

  /// Максимальная длина телефона
  static const int maxPhoneLength = 20;

  /// Длина OTP кода
  static const int otpLength = 6;

  /// Время действия OTP (минуты)
  static const int otpValidityMinutes = 10;

  /// Регулярное выражение для email
  static final RegExp emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  /// Регулярное выражение для телефона
  static final RegExp phoneRegex = RegExp(
    r'^\+?[0-9]{8,20}$',
  );

  /// Регулярное выражение для username
  static final RegExp usernameRegex = RegExp(
    r'^[a-zA-Z0-9_]+$',
  );

  // ════════════════════════════════════════════════════════════════════════════
  // ПАГИНАЦИЯ
  // ════════════════════════════════════════════════════════════════════════════

  /// Количество товаров на странице
  static const int productsPerPage = 20;

  /// Количество заказов на странице
  static const int ordersPerPage = 10;

  // ════════════════════════════════════════════════════════════════════════════
  // UI КОНСТАНТЫ
  // ════════════════════════════════════════════════════════════════════════════

  /// Стандартный отступ
  static const double defaultPadding = 16.0;

  /// Маленький отступ
  static const double smallPadding = 8.0;

  /// Большой отступ
  static const double largePadding = 24.0;

  /// Радиус скругления
  static const double borderRadius = 12.0;

  /// Маленький радиус скругления
  static const double smallBorderRadius = 8.0;

  /// Большой радиус скругления
  static const double largeBorderRadius = 16.0;

  /// Высота кнопки
  static const double buttonHeight = 48.0;

  /// Высота поля ввода
  static const double inputHeight = 56.0;

  /// Размер иконки в AppBar
  static const double appBarIconSize = 24.0;

  /// Размер аватара
  static const double avatarSize = 48.0;

  /// Большой размер аватара
  static const double largeAvatarSize = 80.0;

  // ════════════════════════════════════════════════════════════════════════════
  // АНИМАЦИИ
  // ════════════════════════════════════════════════════════════════════════════

  /// Быстрая анимация
  static const Duration fastAnimation = Duration(milliseconds: 150);

  /// Стандартная анимация
  static const Duration defaultAnimation = Duration(milliseconds: 300);

  /// Медленная анимация
  static const Duration slowAnimation = Duration(milliseconds: 500);

  // ════════════════════════════════════════════════════════════════════════════
  // DEBOUNCE
  // ════════════════════════════════════════════════════════════════════════════

  /// Задержка для поиска
  static const Duration searchDebounce = Duration(milliseconds: 500);

  /// Задержка для валидации
  static const Duration validationDebounce = Duration(milliseconds: 300);

  // ════════════════════════════════════════════════════════════════════════════
  // СООБЩЕНИЯ
  // ════════════════════════════════════════════════════════════════════════════

  /// Сообщения об успехе
  static const Map<String, String> successMessages = {
    'login': 'Вы успешно вошли в систему',
    'register': 'Регистрация успешна',
    'logout': 'Вы вышли из системы',
    'passwordChanged': 'Пароль успешно изменён',
    'profileUpdated': 'Профиль обновлён',
    'orderCreated': 'Заказ успешно создан',
    'orderCancelled': 'Заказ отменён',
    'addedToCart': 'Товар добавлен в корзину',
    'removedFromCart': 'Товар удалён из корзины',
    'addedToFavorites': 'Добавлено в избранное',
    'removedFromFavorites': 'Удалено из избранного',
  };

  /// Сообщения об ошибках
  static const Map<String, String> errorMessages = {
    'network': 'Нет подключения к интернету',
    'timeout': 'Превышено время ожидания',
    'server': 'Ошибка сервера',
    'unknown': 'Произошла неизвестная ошибка',
    'unauthorized': 'Требуется авторизация',
    'forbidden': 'Доступ запрещён',
    'notFound': 'Ресурс не найден',
    'validation': 'Проверьте введённые данные',
    'emptyCart': 'Корзина пуста',
    'outOfStock': 'Товар отсутствует на складе',
  };
}

/// Валидаторы форм
class AppValidators {
  AppValidators._();

  /// Проверка email
  static String? email(String? value) {
    if (value == null || value.isEmpty) {
      return 'Введите email';
    }
    if (!AppConstants.emailRegex.hasMatch(value)) {
      return 'Введите корректный email';
    }
    return null;
  }

  /// Проверка пароля
  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'Введите пароль';
    }
    if (value.length < AppConstants.minPasswordLength) {
      return 'Минимум ${AppConstants.minPasswordLength} символов';
    }
    if (value.length > AppConstants.maxPasswordLength) {
      return 'Максимум ${AppConstants.maxPasswordLength} символов';
    }
    return null;
  }

  /// Проверка подтверждения пароля
  static String? confirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) {
      return 'Подтвердите пароль';
    }
    if (value != password) {
      return 'Пароли не совпадают';
    }
    return null;
  }

  /// Проверка username
  static String? username(String? value) {
    if (value == null || value.isEmpty) {
      return 'Введите имя пользователя';
    }
    if (value.length < AppConstants.minUsernameLength) {
      return 'Минимум ${AppConstants.minUsernameLength} символа';
    }
    if (value.length > AppConstants.maxUsernameLength) {
      return 'Максимум ${AppConstants.maxUsernameLength} символов';
    }
    if (!AppConstants.usernameRegex.hasMatch(value)) {
      return 'Только буквы, цифры и _';
    }
    return null;
  }

  /// Проверка телефона
  static String? phone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Введите телефон';
    }
    final cleaned = value.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (!AppConstants.phoneRegex.hasMatch(cleaned)) {
      return 'Введите корректный телефон';
    }
    return null;
  }

  /// Проверка имени
  static String? name(String? value, {String fieldName = 'поле'}) {
    if (value == null || value.isEmpty) {
      return 'Заполните $fieldName';
    }
    if (value.length < 2) {
      return 'Минимум 2 символа';
    }
    if (value.length > 100) {
      return 'Максимум 100 символов';
    }
    return null;
  }

  /// Проверка адреса
  static String? address(String? value) {
    if (value == null || value.isEmpty) {
      return 'Введите адрес доставки';
    }
    if (value.length < 10) {
      return 'Введите полный адрес';
    }
    return null;
  }

  /// Проверка OTP кода
  static String? otp(String? value) {
    if (value == null || value.isEmpty) {
      return 'Введите код';
    }
    if (value.length != AppConstants.otpLength) {
      return 'Код должен содержать ${AppConstants.otpLength} цифр';
    }
    if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
      return 'Только цифры';
    }
    return null;
  }

  /// Проверка обязательного поля
  static String? required(String? value, {String fieldName = 'поле'}) {
    if (value == null || value.trim().isEmpty) {
      return 'Заполните $fieldName';
    }
    return null;
  }
}

/// Цвета приложения
class AppColors {
  AppColors._();

  // Основные цвета
  static const Color primary = Color(0xFF2196F3);
  static const Color primaryDark = Color(0xFF1976D2);
  static const Color primaryLight = Color(0xFFBBDEFB);

  // Акцентные цвета
  static const Color accent = Color(0xFFFF9800);
  static const Color accentDark = Color(0xFFF57C00);

  // Фоновые цвета
  static const Color background = Color(0xFFF5F5F5);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color card = Color(0xFFFFFFFF);

  // Текстовые цвета
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textHint = Color(0xFFBDBDBD);

  // Статусные цвета
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFF44336);
  static const Color info = Color(0xFF2196F3);

  // Цвета статусов заказа
  static const Color orderPending = Color(0xFFFFA726);
  static const Color orderConfirmed = Color(0xFF42A5F5);
  static const Color orderProcessing = Color(0xFF7E57C2);
  static const Color orderShipped = Color(0xFF26A69A);
  static const Color orderDelivered = Color(0xFF66BB6A);
  static const Color orderCancelled = Color(0xFFEF5350);

  // Прочие
  static const Color divider = Color(0xFFE0E0E0);
  static const Color disabled = Color(0xFFBDBDBD);
  static const Color overlay = Color(0x80000000);
  static const Color favorite = Color(0xFFE91E63);
  static const Color star = Color(0xFFFFB300);
}

/// Текстовые стили
class AppTextStyles {
  AppTextStyles._();

  // Заголовки
  static const TextStyle headline1 = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  static const TextStyle headline2 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  static const TextStyle headline3 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  // Подзаголовки
  static const TextStyle subtitle1 = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );

  static const TextStyle subtitle2 = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );

  // Основной текст
  static const TextStyle body1 = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: AppColors.textPrimary,
  );

  static const TextStyle body2 = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: AppColors.textPrimary,
  );

  // Мелкий текст
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: AppColors.textSecondary,
  );

  // Кнопки
  static const TextStyle button = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );

  // Цена
  static const TextStyle price = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: AppColors.primary,
  );

  static const TextStyle priceSmall = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.primary,
  );

  static const TextStyle priceLarge = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.primary,
  );
}