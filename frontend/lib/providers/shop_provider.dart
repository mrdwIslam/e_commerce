import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/category_model.dart' as models;
import '../models/product_model.dart';
import '../models/cart_model.dart';
import '../models/order_model.dart';
import '../models/favorite_model.dart';
import '../services/api_service.dart';
import 'auth_provider.dart';

// ══════════════════════════════════════════════════════════════════════════════
// ENUMS
// ══════════════════════════════════════════════════════════════════════════════

/// Опции сортировки для UI
enum SortOption {
  none('Без сортировки', null),
  priceLowToHigh('Сначала дешевые', 'price'),
  priceHighToLow('Сначала дорогие', '-price'),
  nameAZ('По названию (А-Я)', 'name'),
  nameZA('По названию (Я-А)', '-name'),
  newest('Сначала новые', '-created'),
  oldest('Сначала старые', 'created');

  final String displayName;
  final String? apiValue;

  const SortOption(this.displayName, this.apiValue);
}

// ══════════════════════════════════════════════════════════════════════════════
// CATEGORIES STATE
// ══════════════════════════════════════════════════════════════════════════════

/// Состояние категорий
class CategoriesState {
  final List<models.Category> categories;
  final bool isLoading;
  final String? error;

  const CategoriesState({
    this.categories = const [],
    this.isLoading = false,
    this.error,
  });

  CategoriesState copyWith({
    List<models.Category>? categories,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return CategoriesState(
      categories: categories ?? this.categories,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Notifier для категорий
class CategoriesNotifier extends StateNotifier<CategoriesState> {
  final ApiService _apiService;

  CategoriesNotifier({ApiService? apiService})
      : _apiService = apiService ?? ApiService(),
        super(const CategoriesState());

  /// Загрузить категории
  Future<void> loadCategories() async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final categories = await _apiService.getCategories();
      state = state.copyWith(categories: categories, isLoading: false);
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Ошибка загрузки: $e');
    }
  }

  /// Обновить категории
  Future<void> refresh() async {
    state = state.copyWith(isLoading: false);
    await loadCategories();
  }
}
// ══════════════════════════════════════════════════════════════════════════════
// PRODUCTS STATE
// ══════════════════════════════════════════════════════════════════════════════

/// Состояние товаров
class ProductsState {
  final List<Product> products;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final String? selectedCategorySlug;
  final String searchQuery;
  final SortOption sortOption;
  final bool? inStockOnly;
  final int currentPage;
  final bool hasMore;
  final int totalCount;

  const ProductsState({
    this.products = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.selectedCategorySlug,
    this.searchQuery = '',
    this.sortOption = SortOption.none,
    this.inStockOnly,
    this.currentPage = 1,
    this.hasMore = true,
    this.totalCount = 0,
  });

  /// Есть ли активные фильтры
  bool get hasFilters =>
      selectedCategorySlug != null ||
      searchQuery.isNotEmpty ||
      sortOption != SortOption.none ||
      inStockOnly == true;

  ProductsState copyWith({
    List<Product>? products,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    String? selectedCategorySlug,
    String? searchQuery,
    SortOption? sortOption,
    bool? inStockOnly,
    int? currentPage,
    bool? hasMore,
    int? totalCount,
    bool clearError = false,
    bool clearCategory = false,
    bool clearInStock = false,
  }) {
    return ProductsState(
      products: products ?? this.products,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: clearError ? null : (error ?? this.error),
      selectedCategorySlug:
          clearCategory ? null : (selectedCategorySlug ?? this.selectedCategorySlug),
      searchQuery: searchQuery ?? this.searchQuery,
      sortOption: sortOption ?? this.sortOption,
      inStockOnly: clearInStock ? null : (inStockOnly ?? this.inStockOnly),
      currentPage: currentPage ?? this.currentPage,
      hasMore: hasMore ?? this.hasMore,
      totalCount: totalCount ?? this.totalCount,
    );
  }
}

/// Notifier для товаров
class ProductsNotifier extends StateNotifier<ProductsState> {
  final ApiService _apiService;

  ProductsNotifier({ApiService? apiService})
      : _apiService = apiService ?? ApiService(),
        super(const ProductsState());

  /// Создать фильтр из текущего состояния
  ProductFilter _buildFilter({int? page}) {
    return ProductFilter(
      category: state.selectedCategorySlug,
      search: state.searchQuery.isNotEmpty ? state.searchQuery : null,
      ordering: state.sortOption.apiValue,
      inStock: state.inStockOnly,
      page: page ?? state.currentPage,
    );
  }

  /// Загрузить товары
  Future<void> loadProducts({bool refresh = false}) async {
    if (state.isLoading) return;

    state = state.copyWith(
      isLoading: true,
      clearError: true,
      currentPage: refresh ? 1 : state.currentPage,
      products: refresh ? [] : state.products,
    );

    try {
      final filter = _buildFilter(page: 1);
      final response = await _apiService.getProducts(filter: filter);

      state = state.copyWith(
        products: response.results,
        isLoading: false,
        currentPage: 1,
        hasMore: response.hasNext,
        totalCount: response.count,
      );
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Ошибка загрузки: $e');
    }
  }

  /// Загрузить больше товаров (пагинация)
  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;

    state = state.copyWith(isLoadingMore: true);

    try {
      final nextPage = state.currentPage + 1;
      final filter = _buildFilter(page: nextPage);
      final response = await _apiService.getProducts(filter: filter);

      state = state.copyWith(
        products: [...state.products, ...response.results],
        isLoadingMore: false,
        currentPage: nextPage,
        hasMore: response.hasNext,
      );
    } on ApiException catch (e) {
      state = state.copyWith(isLoadingMore: false, error: e.message);
    } catch (e) {
      state = state.copyWith(isLoadingMore: false, error: 'Ошибка: $e');
    }
  }

  /// Обновить товары
  Future<void> refresh() async {
    await loadProducts(refresh: true);
  }

  /// Установить категорию
  void setCategory(String? categorySlug) {
    if (state.selectedCategorySlug == categorySlug) return;
    state = state.copyWith(
      selectedCategorySlug: categorySlug,
      clearCategory: categorySlug == null,
    );
    loadProducts(refresh: true);
  }

  /// Установить поисковый запрос
  void setSearchQuery(String query) {
    if (state.searchQuery == query) return;
    state = state.copyWith(searchQuery: query);
    loadProducts(refresh: true);
  }

  /// Установить сортировку
  void setSortOption(SortOption option) {
    if (state.sortOption == option) return;
    state = state.copyWith(sortOption: option);
    loadProducts(refresh: true);
  }

  /// Установить фильтр "только в наличии"
  void setInStockOnly(bool? value) {
    if (state.inStockOnly == value) return;
    state = state.copyWith(inStockOnly: value, clearInStock: value == null);
    loadProducts(refresh: true);
  }

  /// Сбросить все фильтры
  void resetFilters() {
    state = const ProductsState();
    loadProducts(refresh: true);
  }

  /// Очистить ошибку
  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// CART STATE
// ══════════════════════════════════════════════════════════════════════════════

/// Notifier для корзины (локальная)
class CartNotifier extends StateNotifier<Cart> {
  CartNotifier() : super(Cart.empty());

  /// Добавить товар
  void addItem(Product product, {int quantity = 1}) {
    state = state.addItem(product, quantity: quantity);
  }

  /// Удалить товар
  void removeItem(String productId) {
    state = state.removeItem(productId);
  }

  /// Обновить количество
  void updateQuantity(String productId, int quantity) {
    state = state.updateQuantity(productId, quantity);
  }

  /// Увеличить количество на 1
  void incrementItem(String productId) {
    state = state.incrementItem(productId);
  }

  /// Уменьшить количество на 1
  void decrementItem(String productId) {
    state = state.decrementItem(productId);
  }

  /// Очистить корзину
  void clear() {
    state = Cart.empty();
  }

  /// Проверить наличие товара
  bool containsProduct(String productId) {
    return state.containsProduct(productId);
  }

  /// Получить количество товара
  int getQuantity(String productId) {
    return state.getQuantity(productId);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// FAVORITES STATE
// ══════════════════════════════════════════════════════════════════════════════

/// Состояние избранного
class FavoritesState {
  final List<Favorite> favorites;
  final Set<String> favoriteProductIds;
  final bool isLoading;
  final String? error;

  const FavoritesState({
    this.favorites = const [],
    this.favoriteProductIds = const {},
    this.isLoading = false,
    this.error,
  });

  /// Проверить, в избранном ли товар
  bool isFavorite(String productId) => favoriteProductIds.contains(productId);

  FavoritesState copyWith({
    List<Favorite>? favorites,
    Set<String>? favoriteProductIds,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return FavoritesState(
      favorites: favorites ?? this.favorites,
      favoriteProductIds: favoriteProductIds ?? this.favoriteProductIds,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Notifier для избранного
class FavoritesNotifier extends StateNotifier<FavoritesState> {
  final ApiService _apiService;
  final Ref _ref;

  FavoritesNotifier(this._ref, {ApiService? apiService})
      : _apiService = apiService ?? ApiService(),
        super(const FavoritesState());

  /// Загрузить избранное
  Future<void> loadFavorites() async {
    final isAuthenticated = _ref.read(isAuthenticatedProvider);
    if (!isAuthenticated) {
      state = const FavoritesState();
      return;
    }

    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final favorites = await _apiService.getFavorites();
      final productIds = favorites.map((f) => f.product.id).toSet();

      state = state.copyWith(
        favorites: favorites,
        favoriteProductIds: productIds,
        isLoading: false,
      );
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Ошибка загрузки: $e');
    }
  }

  /// Переключить избранное
  Future<bool> toggleFavorite(Product product) async {
    final isAuthenticated = _ref.read(isAuthenticatedProvider);
    if (!isAuthenticated) {
      return false;
    }

    final isFav = state.isFavorite(product.id);

    // Оптимистичное обновление UI
    if (isFav) {
      state = state.copyWith(
        favoriteProductIds: {...state.favoriteProductIds}..remove(product.id),
        favorites: state.favorites.where((f) => f.product.id != product.id).toList(),
      );
    } else {
      state = state.copyWith(
        favoriteProductIds: {...state.favoriteProductIds, product.id},
      );
    }

    try {
      final result = await _apiService.toggleFavorite(product.id, isFavorite: isFav);

      // Если добавили - перезагружаем для получения полных данных
      if (result.wasAdded) {
        await loadFavorites();
      }

      return true;
    } on ApiException catch (e) {
      // Откатываем изменение при ошибке
      if (isFav) {
        state = state.copyWith(
          favoriteProductIds: {...state.favoriteProductIds, product.id},
        );
      } else {
        state = state.copyWith(
          favoriteProductIds: {...state.favoriteProductIds}..remove(product.id),
        );
      }
      state = state.copyWith(error: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(error: 'Ошибка: $e');
      return false;
    }
  }

  /// Удалить из избранного
  Future<bool> removeFromFavorites(String productId) async {
    try {
      await _apiService.removeFromFavorites(productId);

      state = state.copyWith(
        favoriteProductIds: {...state.favoriteProductIds}..remove(productId),
        favorites: state.favorites.where((f) => f.product.id != productId).toList(),
      );

      return true;
    } on ApiException catch (e) {
      state = state.copyWith(error: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(error: 'Ошибка: $e');
      return false;
    }
  }

  /// Очистить (при выходе)
  void clear() {
    state = const FavoritesState();
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ORDERS STATE
// ══════════════════════════════════════════════════════════════════════════════

/// Состояние заказов
class OrdersState {
  final List<Order> orders;
  final bool isLoading;
  final bool isCreating;
  final String? error;
  final Order? lastCreatedOrder;

  const OrdersState({
    this.orders = const [],
    this.isLoading = false,
    this.isCreating = false,
    this.error,
    this.lastCreatedOrder,
  });

  OrdersState copyWith({
    List<Order>? orders,
    bool? isLoading,
    bool? isCreating,
    String? error,
    Order? lastCreatedOrder,
    bool clearError = false,
    bool clearLastOrder = false,
  }) {
    return OrdersState(
      orders: orders ?? this.orders,
      isLoading: isLoading ?? this.isLoading,
      isCreating: isCreating ?? this.isCreating,
      error: clearError ? null : (error ?? this.error),
      lastCreatedOrder:
          clearLastOrder ? null : (lastCreatedOrder ?? this.lastCreatedOrder),
    );
  }
}

/// Notifier для заказов
class OrdersNotifier extends StateNotifier<OrdersState> {
  final ApiService _apiService;
  final Ref _ref;

  OrdersNotifier(this._ref, {ApiService? apiService})
      : _apiService = apiService ?? ApiService(),
        super(const OrdersState());

  /// Загрузить заказы
  Future<void> loadOrders() async {
    final isAuthenticated = _ref.read(isAuthenticatedProvider);
    if (!isAuthenticated) {
      state = const OrdersState();
      return;
    }

    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final orders = await _apiService.getOrders();
      state = state.copyWith(orders: orders, isLoading: false);
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Ошибка загрузки: $e');
    }
  }

  /// Получить детали заказа
  Future<Order?> getOrderDetails(int orderId) async {
    try {
      return await _apiService.getOrderDetails(orderId);
    } on ApiException catch (e) {
      state = state.copyWith(error: e.message);
      return null;
    } catch (e) {
      state = state.copyWith(error: 'Ошибка: $e');
      return null;
    }
  }

  /// Создать заказ
  Future<Order?> createOrder({
    required Cart cart,
    required String firstName,
    required String lastName,
    required String phone,
    String? email,
    required String address,
    String? note,
  }) async {
    if (cart.isEmpty) {
      state = state.copyWith(error: 'Корзина пуста');
      return null;
    }

    state = state.copyWith(isCreating: true, clearError: true, clearLastOrder: true);

    try {
      final order = await _apiService.createOrderFromCart(
        cart: cart,
        firstName: firstName,
        lastName: lastName,
        phone: phone,
        email: email,
        address: address,
        note: note,
      );

      // Добавляем в начало списка
      state = state.copyWith(
        orders: [order, ...state.orders],
        isCreating: false,
        lastCreatedOrder: order,
      );

      return order;
    } on ApiException catch (e) {
      state = state.copyWith(isCreating: false, error: e.message);
      return null;
    } catch (e) {
      state = state.copyWith(isCreating: false, error: 'Ошибка создания: $e');
      return null;
    }
  }

  /// Отменить заказ
  Future<bool> cancelOrder(int orderId) async {
    try {
      await _apiService.cancelOrder(orderId);

      // Обновляем статус в списке
      final updatedOrders = state.orders.map((order) {
        if (order.id == orderId) {
          return Order(
            id: order.id,
            orderNumber: order.orderNumber,
            firstName: order.firstName,
            lastName: order.lastName,
            phone: order.phone,
            email: order.email,
            address: order.address,
            status: OrderStatus.cancelled,
            statusDisplay: OrderStatus.cancelled.displayName,
            totalAmount: order.totalAmount,
            note: order.note,
            items: order.items,
            createdAt: order.createdAt,
            updatedAt: DateTime.now(),
          );
        }
        return order;
      }).toList();

      state = state.copyWith(orders: updatedOrders);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(error: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(error: 'Ошибка отмены: $e');
      return false;
    }
  }

  /// Обновить заказы
  Future<void> refresh() async {
    state = state.copyWith(isLoading: false);
    await loadOrders();
  }

  /// Очистить последний созданный заказ
  void clearLastOrder() {
    state = state.copyWith(clearLastOrder: true);
  }

  /// Очистить (при выходе)
  void clear() {
    state = const OrdersState();
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// PRODUCT DETAILS STATE
// ══════════════════════════════════════════════════════════════════════════════

/// Состояние деталей товара
class ProductDetailsState {
  final Product? product;
  final bool isLoading;
  final String? error;

  const ProductDetailsState({
    this.product,
    this.isLoading = false,
    this.error,
  });

  ProductDetailsState copyWith({
    Product? product,
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool clearProduct = false,
  }) {
    return ProductDetailsState(
      product: clearProduct ? null : (product ?? this.product),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Notifier для деталей товара
class ProductDetailsNotifier extends StateNotifier<ProductDetailsState> {
  final ApiService _apiService;

  ProductDetailsNotifier({ApiService? apiService})
      : _apiService = apiService ?? ApiService(),
        super(const ProductDetailsState());

  /// Загрузить детали товара
  Future<void> loadProduct(String productId) async {
    state = state.copyWith(isLoading: true, clearError: true, clearProduct: true);

    try {
      final product = await _apiService.getProductDetails(productId);
      state = state.copyWith(product: product, isLoading: false);
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Ошибка загрузки: $e');
    }
  }

  /// Очистить
  void clear() {
    state = const ProductDetailsState();
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// PROVIDERS
// ══════════════════════════════════════════════════════════════════════════════

/// Провайдер категорий
final categoriesProvider =
    StateNotifierProvider<CategoriesNotifier, CategoriesState>((ref) {
  return CategoriesNotifier();
});

/// Провайдер товаров
final productsProvider =
    StateNotifierProvider<ProductsNotifier, ProductsState>((ref) {
  return ProductsNotifier();
});

/// Провайдер корзины
final cartProvider = StateNotifierProvider<CartNotifier, Cart>((ref) {
  return CartNotifier();
});

/// Провайдер избранного
final favoritesProvider =
    StateNotifierProvider<FavoritesNotifier, FavoritesState>((ref) {
  return FavoritesNotifier(ref);
});

/// Провайдер заказов
final ordersProvider =
    StateNotifierProvider<OrdersNotifier, OrdersState>((ref) {
  return OrdersNotifier(ref);
});

/// Провайдер деталей товара
final productDetailsProvider =
    StateNotifierProvider<ProductDetailsNotifier, ProductDetailsState>((ref) {
  return ProductDetailsNotifier();
});

// ══════════════════════════════════════════════════════════════════════════════
// COMPUTED PROVIDERS (Вычисляемые провайдеры)
// ══════════════════════════════════════════════════════════════════════════════

/// Количество товаров в корзине
final cartItemCountProvider = Provider<int>((ref) {
  return ref.watch(cartProvider).totalItems;
});

/// Общая сумма корзины
final cartTotalProvider = Provider<double>((ref) {
  return ref.watch(cartProvider).totalAmount;
});

/// Форматированная сумма корзины
final cartTotalFormattedProvider = Provider<String>((ref) {
  return ref.watch(cartProvider).formattedTotal;
});

/// Пуста ли корзина
final isCartEmptyProvider = Provider<bool>((ref) {
  return ref.watch(cartProvider).isEmpty;
});

/// Количество избранных
final favoritesCountProvider = Provider<int>((ref) {
  return ref.watch(favoritesProvider).favorites.length;
});

/// Количество заказов
final ordersCountProvider = Provider<int>((ref) {
  return ref.watch(ordersProvider).orders.length;
});

/// Проверка товара в избранном
final isProductFavoriteProvider = Provider.family<bool, String>((ref, productId) {
  return ref.watch(favoritesProvider).isFavorite(productId);
});

/// Проверка товара в корзине
final isProductInCartProvider = Provider.family<bool, String>((ref, productId) {
  return ref.watch(cartProvider).containsProduct(productId);
});

/// Количество товара в корзине
final productQuantityInCartProvider = Provider.family<int, String>((ref, productId) {
  return ref.watch(cartProvider).getQuantity(productId);
});

/// Список категорий для выбора (с "Все")
final categoryOptionsProvider = Provider<List<({String? slug, String name})>>((ref) {
  final categories = ref.watch(categoriesProvider).categories;
  return [
    (slug: null, name: 'Все'),
    ...categories.map((c) => (slug: c.slug, name: c.name)),
  ];
});

// ══════════════════════════════════════════════════════════════════════════════
// LEGACY SUPPORT (Для совместимости со старым кодом)
// ══════════════════════════════════════════════════════════════════════════════

/// Старый shopProvider для обратной совместимости
/// @deprecated Используйте отдельные провайдеры: productsProvider, cartProvider и т.д.
final shopProvider = Provider<ShopNotifierLegacy>((ref) {
  return ShopNotifierLegacy(ref);
});

/// Legacy класс для обратной совместимости
class ShopNotifierLegacy {
  final Ref _ref;

  ShopNotifierLegacy(this._ref);

  // Геттеры для совместимости
  List<Product> get products => _ref.read(productsProvider).products;
  Cart get cartState => _ref.read(cartProvider);
  List<CartItem> get cart => _ref.read(cartProvider).items;
  List<Product> get favorites =>
      _ref.read(favoritesProvider).favorites.map((f) => f.product).toList();
  List<Order> get orders => _ref.read(ordersProvider).orders;
  bool get isLoading => _ref.read(productsProvider).isLoading;
  int get cartCount => _ref.read(cartProvider).totalItems;
  double get totalAmount => _ref.read(cartProvider).totalAmount;

  // Методы для совместимости
  Future<void> loadProducts() => _ref.read(productsProvider.notifier).loadProducts();
  void addToCart(Product product) => _ref.read(cartProvider.notifier).addItem(product);
  void removeOneItem(Product product) =>
      _ref.read(cartProvider.notifier).decrementItem(product.id);
  bool isFavorite(Product product) =>
      _ref.read(favoritesProvider).isFavorite(product.id);
  Future<void> toggleFavorite(Product product) =>
      _ref.read(favoritesProvider.notifier).toggleFavorite(product);
  void setCategory(String category) {
    final slug = category == 'Все' ? null : category;
    _ref.read(productsProvider.notifier).setCategory(slug);
  }
  void setSearchQuery(String query) =>
      _ref.read(productsProvider.notifier).setSearchQuery(query);
  void resetFilters() => _ref.read(productsProvider.notifier).resetFilters();
}