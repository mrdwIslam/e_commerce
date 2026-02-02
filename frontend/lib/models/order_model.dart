/// Статусы заказа
/// 
/// Соответствует Django Order.OrderStatus
enum OrderStatus {
  pending('pending', 'Ожидает обработки'),
  confirmed('confirmed', 'Подтвержден'),
  processing('processing', 'В обработке'),
  shipped('shipped', 'Отправлен'),
  delivered('delivered', 'Доставлен'),
  cancelled('cancelled', 'Отменен');

  final String value;
  final String displayName;

  const OrderStatus(this.value, this.displayName);

  /// Получение статуса из строки API
  static OrderStatus fromString(String status) {
    return OrderStatus.values.firstWhere(
      (e) => e.value == status,
      orElse: () => OrderStatus.pending,
    );
  }

  /// Можно ли отменить заказ с данным статусом
  bool get canCancel =>
      this == OrderStatus.pending || this == OrderStatus.confirmed;

  /// Цвет статуса для UI (возвращает hex код)
  int get colorValue {
    switch (this) {
      case OrderStatus.pending:
        return 0xFFFFA726; // Orange
      case OrderStatus.confirmed:
        return 0xFF42A5F5; // Blue
      case OrderStatus.processing:
        return 0xFF7E57C2; // Purple
      case OrderStatus.shipped:
        return 0xFF26A69A; // Teal
      case OrderStatus.delivered:
        return 0xFF66BB6A; // Green
      case OrderStatus.cancelled:
        return 0xFFEF5350; // Red
    }
  }

  /// Иконка статуса (название Material Icon)
  String get iconName {
    switch (this) {
      case OrderStatus.pending:
        return 'schedule';
      case OrderStatus.confirmed:
        return 'check_circle_outline';
      case OrderStatus.processing:
        return 'settings';
      case OrderStatus.shipped:
        return 'local_shipping';
      case OrderStatus.delivered:
        return 'done_all';
      case OrderStatus.cancelled:
        return 'cancel';
    }
  }
}

/// Элемент заказа (товар в заказе)
/// 
/// Соответствует Django модели OrderItem
class OrderItem {
  final int id;
  final String? productId;
  final String productName;
  final String? productImage;
  final double price;
  final int quantity;

  OrderItem({
    required this.id,
    this.productId,
    required this.productName,
    this.productImage,
    required this.price,
    required this.quantity,
  });

  /// Создание из JSON ответа API
  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'] as int,
      productId: json['product_id'] as String?,
      productName: json['product_name'] as String,
      productImage: json['product_image'] as String?,
      price: double.parse(json['price'].toString()),
      quantity: json['quantity'] as int,
    );
  }

  /// Преобразование в JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': productId,
      'product_name': productName,
      'product_image': productImage,
      'price': price.toString(),
      'quantity': quantity,
    };
  }

  /// Общая стоимость позиции
  double get total => price * quantity;

  /// Форматированная цена
  String get formattedPrice => '${price.toStringAsFixed(2)} TMT';

  /// Форматированная общая стоимость
  String get formattedTotal => '${total.toStringAsFixed(2)} TMT';

  /// Проверка наличия изображения
  bool get hasImage => productImage != null && productImage!.isNotEmpty;

  @override
  String toString() =>
      'OrderItem(id: $id, productName: $productName, quantity: $quantity)';
}

/// Модель заказа
/// 
/// Соответствует Django модели Order
class Order {
  final int id;
  final String orderNumber;
  final String firstName;
  final String lastName;
  final String phone;
  final String? email;
  final String address;
  final OrderStatus status;
  final String statusDisplay;
  final double totalAmount;
  final String? note;
  final List<OrderItem> items;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Order({
    required this.id,
    required this.orderNumber,
    required this.firstName,
    required this.lastName,
    required this.phone,
    this.email,
    required this.address,
    required this.status,
    required this.statusDisplay,
    required this.totalAmount,
    this.note,
    required this.items,
    required this.createdAt,
    this.updatedAt,
  });

  /// Создание из JSON ответа API (полный заказ)
  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] as int,
      orderNumber: json['order_number'] as String,
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String?,
      address: json['address'] as String? ?? '',
      status: OrderStatus.fromString(json['status'] as String),
      statusDisplay: json['status_display'] as String? ?? '',
      totalAmount: double.parse(json['total_amount'].toString()),
      note: json['note'] as String?,
      items: (json['items'] as List<dynamic>?)
              ?.map((item) => OrderItem.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  /// Создание из JSON ответа API (список заказов - краткая версия)
  factory Order.fromListJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] as int,
      orderNumber: json['order_number'] as String,
      firstName: '',
      lastName: '',
      phone: '',
      email: null,
      address: '',
      status: OrderStatus.fromString(json['status'] as String),
      statusDisplay: json['status_display'] as String? ?? '',
      totalAmount: double.parse(json['total_amount'].toString()),
      note: null,
      items: [], // В списке items не возвращаются
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: null,
    );
  }

  /// Преобразование в JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_number': orderNumber,
      'first_name': firstName,
      'last_name': lastName,
      'phone': phone,
      'email': email,
      'address': address,
      'status': status.value,
      'status_display': statusDisplay,
      'total_amount': totalAmount.toString(),
      'note': note,
      'items': items.map((item) => item.toJson()).toList(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// Полное имя получателя
  String get fullName => '$firstName $lastName'.trim();

  /// Количество товаров в заказе
  int get itemsCount => items.fold(0, (sum, item) => sum + item.quantity);

  /// Форматированная сумма заказа
  String get formattedTotal => '${totalAmount.toStringAsFixed(2)} TMT';

  /// Форматированная дата создания
  String get formattedDate {
    final day = createdAt.day.toString().padLeft(2, '0');
    final month = createdAt.month.toString().padLeft(2, '0');
    final year = createdAt.year;
    final hour = createdAt.hour.toString().padLeft(2, '0');
    final minute = createdAt.minute.toString().padLeft(2, '0');
    return '$day.$month.$year $hour:$minute';
  }

  /// Можно ли отменить заказ
  bool get canCancel => status.canCancel;

  @override
  String toString() =>
      'Order(id: $id, orderNumber: $orderNumber, status: ${status.value})';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Order && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Модель для создания заказа (отправка на API)
class CreateOrderRequest {
  final String firstName;
  final String lastName;
  final String phone;
  final String? email;
  final String address;
  final String? note;
  final List<CreateOrderItem> items;

  CreateOrderRequest({
    required this.firstName,
    required this.lastName,
    required this.phone,
    this.email,
    required this.address,
    this.note,
    required this.items,
  });

  /// Преобразование в JSON для отправки на API
  Map<String, dynamic> toJson() {
    return {
      'first_name': firstName,
      'last_name': lastName,
      'phone': phone,
      if (email != null && email!.isNotEmpty) 'email': email,
      'address': address,
      if (note != null && note!.isNotEmpty) 'note': note,
      'items': items.map((item) => item.toJson()).toList(),
    };
  }
}

/// Элемент для создания заказа
class CreateOrderItem {
  final String productId;
  final int quantity;

  CreateOrderItem({
    required this.productId,
    required this.quantity,
  });

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'quantity': quantity,
    };
  }
}