/// Модель товара
/// 
/// Соответствует Django модели Product
/// API endpoints: GET /api/products/, GET /api/products/{uuid}/
class Product {
  final String id; // UUID
  final String name;
  final String description;
  final double price;
  final int stock;
  final bool inStock;
  final String? image;
  final int categoryId;
  final String categoryName;
  final String categorySlug;
  final bool isFavorite;
  final DateTime? created;
  final DateTime? updated;

  Product({
    required this.id,
    required this.name,
    this.description = '',
    required this.price,
    this.stock = 0,
    this.inStock = false,
    this.image,
    required this.categoryId,
    required this.categoryName,
    required this.categorySlug,
    this.isFavorite = false,
    this.created,
    this.updated,
  });

  /// Создание из JSON ответа API
  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      price: _parseDouble(json['price']),
      stock: json['stock'] as int? ?? 0,
      inStock: json['in_stock'] as bool? ?? false,
      image: json['image'] as String?,
      categoryId: json['category'] as int? ?? 0,
      categoryName: json['category_name'] as String? ?? '',
      categorySlug: json['category_slug'] as String? ?? '',
      isFavorite: json['is_favorite'] as bool? ?? false,
      created: json['created'] != null
          ? DateTime.tryParse(json['created'] as String)
          : null,
      updated: json['updated'] != null
          ? DateTime.tryParse(json['updated'] as String)
          : null,
    );
  }

  /// Безопасный парсинг double из разных типов
  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  /// Преобразование в JSON (для кэширования)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price.toString(),
      'stock': stock,
      'in_stock': inStock,
      'image': image,
      'category': categoryId,
      'category_name': categoryName,
      'category_slug': categorySlug,
      'is_favorite': isFavorite,
      'created': created?.toIso8601String(),
      'updated': updated?.toIso8601String(),
    };
  }

  /// Форматированная цена
  String get formattedPrice => '${price.toStringAsFixed(2)} TMT';

  /// Проверка наличия изображения
  bool get hasImage => image != null && image!.isNotEmpty;

  /// Краткое описание (первые 100 символов)
  String get shortDescription {
    if (description.length <= 100) return description;
    return '${description.substring(0, 100)}...';
  }

  /// Статус наличия для отображения
  String get stockStatus {
    if (!inStock || stock == 0) return 'Нет в наличии';
    if (stock <= 5) return 'Осталось мало ($stock шт.)';
    return 'В наличии';
  }

  /// Создание копии с изменёнными полями
  Product copyWith({
    String? id,
    String? name,
    String? description,
    double? price,
    int? stock,
    bool? inStock,
    String? image,
    int? categoryId,
    String? categoryName,
    String? categorySlug,
    bool? isFavorite,
    DateTime? created,
    DateTime? updated,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      stock: stock ?? this.stock,
      inStock: inStock ?? this.inStock,
      image: image ?? this.image,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      categorySlug: categorySlug ?? this.categorySlug,
      isFavorite: isFavorite ?? this.isFavorite,
      created: created ?? this.created,
      updated: updated ?? this.updated,
    );
  }

  @override
  String toString() => 'Product(id: $id, name: $name, price: $price)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Product && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Модель для пагинированного ответа списка товаров
class ProductListResponse {
  final int count;
  final String? next;
  final String? previous;
  final List<Product> results;

  ProductListResponse({
    required this.count,
    this.next,
    this.previous,
    required this.results,
  });

  factory ProductListResponse.fromJson(Map<String, dynamic> json) {
    return ProductListResponse(
      count: json['count'] as int? ?? 0,
      next: json['next'] as String?,
      previous: json['previous'] as String?,
      results: (json['results'] as List<dynamic>?)
              ?.map((item) => Product.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  /// Есть ли следующая страница
  bool get hasNext => next != null;

  /// Есть ли предыдущая страница
  bool get hasPrevious => previous != null;
}

/// Параметры фильтрации товаров
class ProductFilter {
  final String? category;
  final String? search;
  final double? minPrice;
  final double? maxPrice;
  final bool? inStock;
  final String? ordering;
  final int? page;

  ProductFilter({
    this.category,
    this.search,
    this.minPrice,
    this.maxPrice,
    this.inStock,
    this.ordering,
    this.page,
  });

  /// Преобразование в query параметры
  Map<String, String> toQueryParams() {
    final params = <String, String>{};
    
    if (category != null && category!.isNotEmpty) {
      params['category'] = category!;
    }
    if (search != null && search!.isNotEmpty) {
      params['search'] = search!;
    }
    if (minPrice != null) {
      params['min_price'] = minPrice!.toString();
    }
    if (maxPrice != null) {
      params['max_price'] = maxPrice!.toString();
    }
    if (inStock != null && inStock!) {
      params['in_stock'] = 'true';
    }
    if (ordering != null && ordering!.isNotEmpty) {
      params['ordering'] = ordering!;
    }
    if (page != null && page! > 1) {
      params['page'] = page!.toString();
    }
    
    return params;
  }

  /// Создание копии с изменёнными полями
  ProductFilter copyWith({
    String? category,
    String? search,
    double? minPrice,
    double? maxPrice,
    bool? inStock,
    String? ordering,
    int? page,
  }) {
    return ProductFilter(
      category: category ?? this.category,
      search: search ?? this.search,
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
      inStock: inStock ?? this.inStock,
      ordering: ordering ?? this.ordering,
      page: page ?? this.page,
    );
  }

  /// Сброс фильтров
  ProductFilter clear() {
    return ProductFilter();
  }

  /// Проверка наличия активных фильтров
  bool get hasFilters =>
      category != null ||
      search != null ||
      minPrice != null ||
      maxPrice != null ||
      inStock != null ||
      ordering != null;
}

/// Варианты сортировки
enum ProductSorting {
  nameAsc('name', 'По названию (А-Я)'),
  nameDesc('-name', 'По названию (Я-А)'),
  priceAsc('price', 'Сначала дешевые'),
  priceDesc('-price', 'Сначала дорогие'),
  newestFirst('-created', 'Сначала новые'),
  oldestFirst('created', 'Сначала старые');

  final String value;
  final String displayName;

  const ProductSorting(this.value, this.displayName);
}