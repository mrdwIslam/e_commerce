/// Модель категории товаров
/// 
/// Соответствует Django модели Category и API endpoint GET /api/categories/
class Category {
  final int id;
  final String name;
  final String slug;
  final String? image;
  final int productsCount;

  Category({
    required this.id,
    required this.name,
    required this.slug,
    this.image,
    required this.productsCount,
  });

  /// Создание из JSON ответа API
  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as int,
      name: json['name'] as String,
      slug: json['slug'] as String,
      image: json['image'] as String?,
      productsCount: json['products_count'] as int? ?? 0,
    );
  }

  /// Преобразование в JSON (для кэширования)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'image': image,
      'products_count': productsCount,
    };
  }

  /// Проверка наличия изображения
  bool get hasImage => image != null && image!.isNotEmpty;

  @override
  String toString() => 'Category(id: $id, name: $name, slug: $slug)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Category && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}