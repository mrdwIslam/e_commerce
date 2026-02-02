import 'product_model.dart';

/// Элемент корзины
/// 
/// Хранится локально на устройстве
/// Используется при создании заказа
class CartItem {
  final Product product;
  int quantity;

  CartItem({
    required this.product,
    this.quantity = 1,
  });

  /// Создание из JSON (для локального хранения)
  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      product: Product.fromJson(json['product'] as Map<String, dynamic>),
      quantity: json['quantity'] as int? ?? 1,
    );
  }

  /// Преобразование в JSON (для локального хранения)
  Map<String, dynamic> toJson() {
    return {
      'product': product.toJson(),
      'quantity': quantity,
    };
  }

  /// Общая стоимость позиции
  double get total => product.price * quantity;

  /// Форматированная общая стоимость
  String get formattedTotal => '${total.toStringAsFixed(2)} TMT';

  /// ID товара (для удобства)
  String get productId => product.id;

  /// Название товара (для удобства)
  String get productName => product.name;

  /// Можно ли увеличить количество (проверка остатка)
  bool get canIncrease => quantity < product.stock;

  /// Можно ли уменьшить количество
  bool get canDecrease => quantity > 1;

  /// Максимальное доступное количество
  int get maxQuantity => product.stock;

  /// Создание копии с изменённым количеством
  CartItem copyWith({int? quantity}) {
    return CartItem(
      product: product,
      quantity: quantity ?? this.quantity,
    );
  }

  @override
  String toString() =>
      'CartItem(productId: ${product.id}, quantity: $quantity)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CartItem && other.product.id == product.id;
  }

  @override
  int get hashCode => product.id.hashCode;
}

/// Модель корзины
/// 
/// Управляет списком товаров в корзине
class Cart {
  final List<CartItem> items;

  Cart({
    List<CartItem>? items,
  }) : items = items ?? [];

  /// Создание из JSON (для локального хранения)
  factory Cart.fromJson(Map<String, dynamic> json) {
    return Cart(
      items: (json['items'] as List<dynamic>?)
              ?.map((item) => CartItem.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  /// Создание из списка JSON (альтернативный формат)
  factory Cart.fromJsonList(List<dynamic> jsonList) {
    return Cart(
      items: jsonList
          .map((item) => CartItem.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Преобразование в JSON (для локального хранения)
  Map<String, dynamic> toJson() {
    return {
      'items': items.map((item) => item.toJson()).toList(),
    };
  }

  /// Преобразование в список JSON
  List<Map<String, dynamic>> toJsonList() {
    return items.map((item) => item.toJson()).toList();
  }

  /// Пустая корзина
  factory Cart.empty() => Cart(items: []);

  /// Общее количество товаров
  int get totalItems => items.fold(0, (sum, item) => sum + item.quantity);

  /// Количество уникальных товаров
  int get uniqueItems => items.length;

  /// Общая стоимость корзины
  double get totalAmount =>
      items.fold(0.0, (sum, item) => sum + item.total);

  /// Форматированная общая стоимость
  String get formattedTotal => '${totalAmount.toStringAsFixed(2)} TMT';

  /// Пуста ли корзина
  bool get isEmpty => items.isEmpty;

  /// Не пуста ли корзина
  bool get isNotEmpty => items.isNotEmpty;

  /// Проверка наличия товара в корзине
  bool containsProduct(String productId) {
    return items.any((item) => item.product.id == productId);
  }

  /// Получить элемент корзины по ID товара
  CartItem? getItem(String productId) {
    try {
      return items.firstWhere((item) => item.product.id == productId);
    } catch (_) {
      return null;
    }
  }

  /// Получить количество товара в корзине
  int getQuantity(String productId) {
    return getItem(productId)?.quantity ?? 0;
  }

  /// Добавить товар в корзину
  Cart addItem(Product product, {int quantity = 1}) {
    final existingIndex =
        items.indexWhere((item) => item.product.id == product.id);

    final newItems = List<CartItem>.from(items);

    if (existingIndex != -1) {
      // Товар уже есть - увеличиваем количество
      final existingItem = newItems[existingIndex];
      final newQuantity = existingItem.quantity + quantity;
      
      // Проверяем остаток
      final finalQuantity =
          newQuantity > product.stock ? product.stock : newQuantity;
      
      newItems[existingIndex] = existingItem.copyWith(quantity: finalQuantity);
    } else {
      // Новый товар
      final finalQuantity = quantity > product.stock ? product.stock : quantity;
      newItems.add(CartItem(product: product, quantity: finalQuantity));
    }

    return Cart(items: newItems);
  }

  /// Удалить товар из корзины
  Cart removeItem(String productId) {
    final newItems =
        items.where((item) => item.product.id != productId).toList();
    return Cart(items: newItems);
  }

  /// Обновить количество товара
  Cart updateQuantity(String productId, int quantity) {
    if (quantity <= 0) {
      return removeItem(productId);
    }

    final newItems = items.map((item) {
      if (item.product.id == productId) {
        final finalQuantity =
            quantity > item.product.stock ? item.product.stock : quantity;
        return item.copyWith(quantity: finalQuantity);
      }
      return item;
    }).toList();

    return Cart(items: newItems);
  }

  /// Увеличить количество товара на 1
  Cart incrementItem(String productId) {
    final item = getItem(productId);
    if (item == null) return this;
    return updateQuantity(productId, item.quantity + 1);
  }

  /// Уменьшить количество товара на 1
  Cart decrementItem(String productId) {
    final item = getItem(productId);
    if (item == null) return this;
    return updateQuantity(productId, item.quantity - 1);
  }

  /// Очистить корзину
  Cart clear() => Cart.empty();

  /// Проверка валидности корзины (все товары в наличии)
  bool get isValid {
    return items.every((item) =>
        item.product.inStock && item.quantity <= item.product.stock);
  }

  /// Получить список невалидных позиций
  List<CartItem> get invalidItems {
    return items
        .where((item) =>
            !item.product.inStock || item.quantity > item.product.stock)
        .toList();
  }

  /// Создание копии
  Cart copyWith({List<CartItem>? items}) {
    return Cart(items: items ?? List<CartItem>.from(this.items));
  }

  @override
  String toString() =>
      'Cart(items: ${items.length}, total: $formattedTotal)';
}

/// Сводка корзины для отображения
class CartSummary {
  final int itemsCount;
  final int uniqueItemsCount;
  final double subtotal;
  final double? discount;
  final double? deliveryFee;
  final double total;

  CartSummary({
    required this.itemsCount,
    required this.uniqueItemsCount,
    required this.subtotal,
    this.discount,
    this.deliveryFee,
    required this.total,
  });

  factory CartSummary.fromCart(Cart cart, {double? discount, double? deliveryFee}) {
    final subtotal = cart.totalAmount;
    final discountAmount = discount ?? 0;
    final delivery = deliveryFee ?? 0;
    final total = subtotal - discountAmount + delivery;

    return CartSummary(
      itemsCount: cart.totalItems,
      uniqueItemsCount: cart.uniqueItems,
      subtotal: subtotal,
      discount: discount,
      deliveryFee: deliveryFee,
      total: total > 0 ? total : 0,
    );
  }

  String get formattedSubtotal => '${subtotal.toStringAsFixed(2)} TMT';
  String get formattedDiscount =>
      discount != null ? '-${discount!.toStringAsFixed(2)} TMT' : '';
  String get formattedDelivery =>
      deliveryFee != null ? '${deliveryFee!.toStringAsFixed(2)} TMT' : 'Бесплатно';
  String get formattedTotal => '${total.toStringAsFixed(2)} TMT';

  bool get hasDiscount => discount != null && discount! > 0;
  bool get hasFreeDelivery => deliveryFee == null || deliveryFee == 0;
}