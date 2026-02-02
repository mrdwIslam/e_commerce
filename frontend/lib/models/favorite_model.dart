import 'product_model.dart';

/// Модель избранного товара
/// 
/// Соответствует Django модели Favorite
/// API endpoints: GET /api/favorites/, POST/DELETE /api/favorites/toggle/
class Favorite {
  final int id;
  final Product product;
  final DateTime createdAt;

  Favorite({
    required this.id,
    required this.product,
    required this.createdAt,
  });

  /// Создание из JSON ответа API
  factory Favorite.fromJson(Map<String, dynamic> json) {
    return Favorite(
      id: json['id'] as int,
      product: Product.fromJson(json['product'] as Map<String, dynamic>),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Преобразование в JSON (для кэширования)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product': product.toJson(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Форматированная дата добавления
  String get formattedDate {
    final day = createdAt.day.toString().padLeft(2, '0');
    final month = createdAt.month.toString().padLeft(2, '0');
    final year = createdAt.year;
    return '$day.$month.$year';
  }

  /// Сколько дней назад добавлено
  String get addedAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Только что';
        }
        return '${difference.inMinutes} мин. назад';
      }
      return '${difference.inHours} ч. назад';
    } else if (difference.inDays == 1) {
      return 'Вчера';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} дн. назад';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks нед. назад';
    } else {
      return formattedDate;
    }
  }

  @override
  String toString() => 'Favorite(id: $id, productId: ${product.id})';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Favorite && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Результат операции с избранным
/// 
/// Используется для ответов POST/DELETE /api/favorites/toggle/
class FavoriteToggleResult {
  final FavoriteAction action;
  final String message;

  FavoriteToggleResult({
    required this.action,
    required this.message,
  });

  factory FavoriteToggleResult.fromJson(Map<String, dynamic> json) {
    final status = json['status'] as String;
    return FavoriteToggleResult(
      action: FavoriteAction.fromString(status),
      message: json['message'] as String? ?? '',
    );
  }

  /// Был ли товар добавлен
  bool get wasAdded => action == FavoriteAction.added;

  /// Был ли товар удалён
  bool get wasRemoved => action == FavoriteAction.removed;

  /// Был ли товар уже в избранном
  bool get alreadyExists => action == FavoriteAction.exists;
}

/// Действие с избранным
enum FavoriteAction {
  added('added', 'Добавлен в избранное'),
  removed('removed', 'Удалён из избранного'),
  exists('exists', 'Уже в избранном');

  final String value;
  final String displayName;

  const FavoriteAction(this.value, this.displayName);

  static FavoriteAction fromString(String status) {
    return FavoriteAction.values.firstWhere(
      (e) => e.value == status,
      orElse: () => FavoriteAction.added,
    );
  }
}

/// Запрос на добавление/удаление из избранного
class FavoriteToggleRequest {
  final String productId;

  FavoriteToggleRequest({
    required this.productId,
  });

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
    };
  }
}