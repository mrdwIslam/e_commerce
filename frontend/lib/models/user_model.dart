/// Модель пользователя
/// 
/// Соответствует Django модели User + Profile
/// Используется в API endpoints: /api/profile/, /api/verify-otp/, /api/login/
class User {
  final int id;
  final String username;
  final String email;
  final String firstName;
  final String lastName;
  final String? phone;
  final String? avatar;
  final DateTime? dateJoined;

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.phone,
    this.avatar,
    this.dateJoined,
  });

  /// Создание из JSON ответа API
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      username: json['username'] as String,
      email: json['email'] as String,
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      phone: json['phone'] as String?,
      avatar: json['avatar'] as String?,
      dateJoined: json['date_joined'] != null
          ? DateTime.tryParse(json['date_joined'] as String)
          : null,
    );
  }

  /// Преобразование в JSON (для кэширования)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'first_name': firstName,
      'last_name': lastName,
      'phone': phone,
      'avatar': avatar,
      'date_joined': dateJoined?.toIso8601String(),
    };
  }

  /// Полное имя пользователя
  String get fullName {
    final name = '$firstName $lastName'.trim();
    return name.isNotEmpty ? name : username;
  }

  /// Инициалы для аватара
  String get initials {
    if (firstName.isNotEmpty && lastName.isNotEmpty) {
      return '${firstName[0]}${lastName[0]}'.toUpperCase();
    } else if (firstName.isNotEmpty) {
      return firstName[0].toUpperCase();
    } else if (username.isNotEmpty) {
      return username[0].toUpperCase();
    }
    return '?';
  }

  /// Проверка наличия аватара
  bool get hasAvatar => avatar != null && avatar!.isNotEmpty;

  /// Проверка заполненности профиля
  bool get isProfileComplete =>
      firstName.isNotEmpty && lastName.isNotEmpty && phone != null && phone!.isNotEmpty;

  /// Создание копии с изменёнными полями
  User copyWith({
    int? id,
    String? username,
    String? email,
    String? firstName,
    String? lastName,
    String? phone,
    String? avatar,
    DateTime? dateJoined,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phone: phone ?? this.phone,
      avatar: avatar ?? this.avatar,
      dateJoined: dateJoined ?? this.dateJoined,
    );
  }

  @override
  String toString() => 'User(id: $id, username: $username, email: $email)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is User && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Модель токенов аутентификации
class AuthTokens {
  final String access;
  final String refresh;

  AuthTokens({
    required this.access,
    required this.refresh,
  });

  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    return AuthTokens(
      access: json['access'] as String,
      refresh: json['refresh'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'access': access,
      'refresh': refresh,
    };
  }
}

/// Результат аутентификации (после verify-otp или login)
class AuthResult {
  final AuthTokens tokens;
  final User? user;

  AuthResult({
    required this.tokens,
    this.user,
  });

  factory AuthResult.fromJson(Map<String, dynamic> json) {
    // Для verify-otp ответа
    if (json.containsKey('tokens')) {
      return AuthResult(
        tokens: AuthTokens.fromJson(json['tokens'] as Map<String, dynamic>),
        user: json['user'] != null
            ? User.fromJson(json['user'] as Map<String, dynamic>)
            : null,
      );
    }
    // Для login ответа (токены в корне)
    return AuthResult(
      tokens: AuthTokens.fromJson(json),
      user: null,
    );
  }
}