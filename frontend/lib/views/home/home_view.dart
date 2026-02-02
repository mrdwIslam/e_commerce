import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/constants.dart';
import '../../models/product_model.dart';
import '../../models/category_model.dart' as models;
import '../../providers/auth_provider.dart';
import '../../providers/shop_provider.dart';
import '../../services/api_service.dart';
import '../widgets/product_card.dart';
import '../widgets/skeleton_card.dart';
import '../cart/cart_view.dart';
import '../profile/profile_view.dart';
import '../favorites/favorites_view.dart';
import '../orders/orders_view.dart';
import '../product/product_detail_view.dart';
import '../auth/login_view.dart';

class HomeView extends ConsumerStatefulWidget {
  const HomeView({super.key});

  @override
  ConsumerState<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends ConsumerState<HomeView>
    with SingleTickerProviderStateMixin {
  // Promo slider
  late PageController _promoController;
  Timer? _promoTimer;
  int _currentPromoPage = 0;
  final int _promoCount = 3;

  // Search
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  Timer? _searchDebounce;

  // Bottom nav
  int _currentNavIndex = 0;

  // Animation
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();

    _promoController = PageController(viewportFraction: 0.9);

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // Загружаем данные
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });

    // Автопрокрутка промо
    _startPromoTimer();
  }

  @override
  void dispose() {
    _promoTimer?.cancel();
    _searchDebounce?.cancel();
    _promoController.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _loadInitialData() {
    ref.read(categoriesProvider.notifier).loadCategories();
    ref.read(productsProvider.notifier).loadProducts();

    // Загружаем избранное если авторизован
    if (ref.read(isAuthenticatedProvider)) {
      ref.read(favoritesProvider.notifier).loadFavorites();
    }
  }

  void _startPromoTimer() {
    _promoTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_promoController.hasClients) {
        _currentPromoPage = (_currentPromoPage + 1) % _promoCount;
        _promoController.animateToPage(
          _currentPromoPage,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(AppConstants.searchDebounce, () {
      ref.read(productsProvider.notifier).setSearchQuery(value);
    });
  }

  void _handleAddToCart(Product product) {
    ref.read(cartProvider.notifier).addItem(product);
    _showSnackBar(
      message: 'Добавлено в корзину',
      icon: Icons.shopping_bag_outlined,
    );
  }

  void _handleToggleFavorite(Product product) async {
    final isAuth = ref.read(isAuthenticatedProvider);
    if (!isAuth) {
      _showSnackBar(
        message: 'Войдите, чтобы добавить в избранное',
        icon: Icons.favorite_border,
        isError: true,
        action: SnackBarAction(
          label: 'Войти',
          textColor: Colors.white,
          onPressed: () => _navigateToLogin(),
        ),
      );
      return;
    }

    final success = await ref.read(favoritesProvider.notifier).toggleFavorite(product);
    if (success) {
      final isFav = ref.read(favoritesProvider).isFavorite(product.id);
      _showSnackBar(
        message: isFav ? 'Добавлено в избранное' : 'Удалено из избранного',
        icon: isFav ? Icons.favorite : Icons.favorite_border,
      );
    }
  }

  void _showSnackBar({
    required String message,
    required IconData icon,
    bool isError = false,
    SnackBarAction? action,
  }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? AppColors.error : Colors.black87,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
        action: action,
      ),
    );
  }

  void _navigateToLogin() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LoginView()),
    );
  }

  void _navigateToProductDetail(Product product, String heroTag) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProductDetailView(
          productId: product.id,
          heroTag: heroTag,
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final productsState = ref.watch(productsProvider);
    final categoriesState = ref.watch(categoriesProvider);
    final cartItemCount = ref.watch(cartItemCountProvider);
    final favoritesCount = ref.watch(favoritesCountProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await Future.wait([
              ref.read(categoriesProvider.notifier).loadCategories(),
              ref.read(productsProvider.notifier).refresh(),
            ]);
          },
          color: AppColors.primary,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              // Header
              _buildHeader(authState),

              // Search
              _buildSearchBar(),

              // Promo Slider
              _buildPromoSection(),

              // Categories
              _buildCategoriesSection(categoriesState, productsState),

              // New Arrivals (горизонтальный список)
              if (!productsState.isLoading && productsState.products.isNotEmpty)
                _buildNewArrivalsSection(productsState.products),

              // Section Header
              _buildSectionTitle(productsState),

              // Products Grid
              _buildProductsGrid(productsState),

              // Load More Button
              if (productsState.hasMore && !productsState.isLoading)
                _buildLoadMoreButton(),

              // Bottom Padding
              const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(
        cartItemCount: cartItemCount,
        favoritesCount: favoritesCount,
        isAuthenticated: authState.isAuthenticated,
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // HEADER
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildHeader(AuthState authState) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Logo & Greeting
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    authState.isAuthenticated
                        ? 'Привет, ${authState.displayName.split(' ').first}!'
                        : 'NEXTSTORE',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (!authState.isAuthenticated)
                    Text(
                      'Добро пожаловать!',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),

            // Notification Button
            _buildHeaderButton(
              icon: Icons.notifications_none_rounded,
              onTap: () {
                _showSnackBar(
                  message: 'Уведомления скоро будут доступны',
                  icon: Icons.notifications_none_rounded,
                );
              },
              badge: 0, // Можно добавить счётчик уведомлений
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderButton({
    required IconData icon,
    required VoidCallback onTap,
    int badge = 0,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, color: AppColors.textPrimary, size: 24),
            if (badge > 0)
              Positioned(
                right: 10,
                top: 10,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SEARCH
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildSearchBar() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
        child: Row(
          children: [
            // Search Field
            Expanded(
              child: Container(
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 16),
                    Icon(
                      Icons.search_rounded,
                      color: AppColors.textHint,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocus,
                        onChanged: _onSearchChanged,
                        style: const TextStyle(
                          fontSize: 15,
                          color: AppColors.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Поиск товаров...',
                          hintStyle: TextStyle(
                            color: AppColors.textHint,
                            fontSize: 15,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    if (_searchController.text.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          _searchController.clear();
                          ref.read(productsProvider.notifier).setSearchQuery('');
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Icon(
                            Icons.close_rounded,
                            color: AppColors.textSecondary,
                            size: 20,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(width: 12),

            // Filter Button
            GestureDetector(
              onTap: () => _showFilterSheet(),
              child: Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.tune_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PROMO SECTION
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildPromoSection() {
    return SliverToBoxAdapter(
      child: Column(
        children: [
          const SizedBox(height: 16),
          SizedBox(
            height: 170,
            child: PageView.builder(
              controller: _promoController,
              onPageChanged: (page) => setState(() => _currentPromoPage = page),
              itemCount: _promoCount,
              itemBuilder: (context, index) => _buildPromoCard(index),
            ),
          ),
          const SizedBox(height: 16),
          _buildPromoIndicators(),
        ],
      ),
    );
  }

  Widget _buildPromoCard(int index) {
    final promos = [
      {
        'title': 'FLASH SALE',
        'subtitle': 'Скидки до 50%',
        'button': 'Успей купить',
        'gradient': [const Color(0xFF1A1A1A), const Color(0xFF2D2D2D)],
        'icon': Icons.flash_on_rounded,
      },
      {
        'title': 'NEW COLLECTION',
        'subtitle': 'Весна 2025',
        'button': 'Смотреть',
        'gradient': [AppColors.primary, AppColors.primaryDark],
        'icon': Icons.local_florist_rounded,
      },
      {
        'title': 'FREE DELIVERY',
        'subtitle': 'При заказе от 500 TMT',
        'button': 'Подробнее',
        'gradient': [const Color(0xFF43A047), const Color(0xFF2E7D32)],
        'icon': Icons.local_shipping_rounded,
      },
    ];

    final promo = promos[index];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: promo['gradient'] as List<Color>,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: (promo['gradient'] as List<Color>).first.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background Icon
          Positioned(
            right: -20,
            bottom: -20,
            child: Icon(
              promo['icon'] as IconData,
              size: 150,
              color: Colors.white.withOpacity(0.1),
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  promo['title'] as String,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  promo['subtitle'] as String,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    promo['button'] as String,
                    style: TextStyle(
                      color: (promo['gradient'] as List<Color>).first,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPromoIndicators() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_promoCount, (index) {
        final isActive = _currentPromoPage == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive ? AppColors.primary : AppColors.divider,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CATEGORIES
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildCategoriesSection(
    CategoriesState categoriesState,
    ProductsState productsState,
  ) {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Категории', onSeeAll: () {}),
          SizedBox(
            height: 110,
            child: categoriesState.isLoading
                ? _buildCategoriesLoading()
                : _buildCategoriesList(
                    categoriesState.categories,
                    productsState.selectedCategorySlug,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesLoading() {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: 4,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(right: 20),
        child: Column(
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: 50,
              height: 12,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoriesList(
    List<models.Category> categories,
    String? selectedSlug,
  ) {
    // Добавляем "Все" в начало
    final allCategories = [
      null, // null означает "Все"
      ...categories,
    ];

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: allCategories.length,
      itemBuilder: (context, index) {
        final category = allCategories[index];
        final isSelected = category == null
            ? selectedSlug == null
            : category.slug == selectedSlug;

        return Padding(
          padding: const EdgeInsets.only(right: 20),
          child: GestureDetector(
            onTap: () {
              ref.read(productsProvider.notifier).setCategory(category?.slug);
            },
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: isSelected
                            ? AppColors.primary.withOpacity(0.3)
                            : Colors.black.withOpacity(0.04),
                        blurRadius: isSelected ? 15 : 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: category == null
                      ? Icon(
                          Icons.grid_view_rounded,
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                          size: 28,
                        )
                      : category.hasImage
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(22),
                              child: CachedNetworkImage(
                                imageUrl: ApiService().getImageUrl(category.image) ?? '',
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Icon(
                                  Icons.category_outlined,
                                  color: isSelected ? Colors.white : AppColors.textSecondary,
                                ),
                                errorWidget: (_, __, ___) => Icon(
                                  Icons.category_outlined,
                                  color: isSelected ? Colors.white : AppColors.textSecondary,
                                ),
                              ),
                            )
                          : Icon(
                              Icons.category_outlined,
                              color: isSelected ? Colors.white : AppColors.textPrimary,
                              size: 28,
                            ),
                ),
                const SizedBox(height: 10),
                Text(
                  category?.name ?? 'Все',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? AppColors.primary : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // NEW ARRIVALS
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildNewArrivalsSection(List<Product> products) {
    final newProducts = products.take(5).toList();

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Новинки', onSeeAll: () {}),
          SizedBox(
            height: 260,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: newProducts.length,
              itemBuilder: (context, index) {
                final product = newProducts[index];
                final heroTag = 'new_${product.id}';

                return Container(
                  width: 180,
                  margin: const EdgeInsets.only(right: 16),
                  child: ProductCard(
                    product: product,
                    heroTag: heroTag,
                    onTap: () => _navigateToProductDetail(product, heroTag),
                    onAddToCart: () => _handleAddToCart(product),
                    onToggleFavorite: () => _handleToggleFavorite(product),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PRODUCTS GRID
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildSectionTitle(ProductsState state) {
    String title = 'Все товары';

    if (state.searchQuery.isNotEmpty) {
      title = 'Результаты поиска';
    } else if (state.selectedCategorySlug != null) {
      title = 'Категория';
    }

    return SliverToBoxAdapter(
      child: _buildSectionHeader(
        title,
        subtitle: state.totalCount > 0 ? '${state.totalCount} товаров' : null,
        onSeeAll: state.hasFilters ? () => ref.read(productsProvider.notifier).resetFilters() : null,
        seeAllText: 'Сбросить',
      ),
    );
  }

  Widget _buildProductsGrid(ProductsState state) {
    if (state.isLoading && state.products.isEmpty) {
      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.68,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) => const SkeletonCard(),
            childCount: 4,
          ),
        ),
      );
    }

    if (state.products.isEmpty) {
      return SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              children: [
                Icon(
                  Icons.search_off_rounded,
                  size: 64,
                  color: AppColors.textHint,
                ),
                const SizedBox(height: 16),
                Text(
                  'Товары не найдены',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Попробуйте изменить параметры поиска',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textHint,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.68,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final product = state.products[index];
            final heroTag = 'grid_${product.id}';

            return ProductCard(
              product: product,
              heroTag: heroTag,
              onTap: () => _navigateToProductDetail(product, heroTag),
              onAddToCart: () => _handleAddToCart(product),
              onToggleFavorite: () => _handleToggleFavorite(product),
            );
          },
          childCount: state.products.length,
        ),
      ),
    );
  }

  Widget _buildLoadMoreButton() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Consumer(
          builder: (context, ref, child) {
            final isLoadingMore = ref.watch(productsProvider).isLoadingMore;

            return SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: isLoadingMore
                    ? null
                    : () => ref.read(productsProvider.notifier).loadMore(),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: isLoadingMore
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'Загрузить ещё',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SECTION HEADER
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildSectionHeader(
    String title, {
    String? subtitle,
    VoidCallback? onSeeAll,
    String seeAllText = 'Смотреть все',
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
          if (onSeeAll != null)
            GestureDetector(
              onTap: onSeeAll,
              child: Text(
                seeAllText,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BOTTOM NAVIGATION
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildBottomNav({
    required int cartItemCount,
    required int favoritesCount,
    required bool isAuthenticated,
  }) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(
            icon: Icons.home_rounded,
            label: 'Главная',
            isActive: true,
            onTap: () {},
          ),
          _buildNavItem(
            icon: Icons.favorite_rounded,
            label: 'Избранное',
            badge: favoritesCount,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const FavoritesView()),
              );
            },
          ),
          _buildNavItem(
            icon: Icons.shopping_bag_rounded,
            label: 'Корзина',
            badge: cartItemCount,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CartView()),
              );
            },
          ),
          _buildNavItem(
            icon: Icons.person_rounded,
            label: 'Профиль',
            onTap: () {
              if (isAuthenticated) {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProfileView()),
                );
              } else {
                _navigateToLogin();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    bool isActive = false,
    int badge = 0,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 70,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  color: isActive ? AppColors.primary : AppColors.textHint,
                  size: 26,
                ),
                if (badge > 0)
                  Positioned(
                    right: -8,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      child: Text(
                        badge > 99 ? '99+' : '$badge',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: isActive ? AppColors.primary : AppColors.textHint,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // FILTER SHEET
  // ══════════════════════════════════════════════════════════════════════════

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const FilterSheet(),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// FILTER SHEET WIDGET
// ══════════════════════════════════════════════════════════════════════════════

class FilterSheet extends ConsumerStatefulWidget {
  const FilterSheet({super.key});

  @override
  ConsumerState<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<FilterSheet> {
  late SortOption _selectedSort;
  late bool _inStockOnly;

  @override
  void initState() {
    super.initState();
    final state = ref.read(productsProvider);
    _selectedSort = state.sortOption;
    _inStockOnly = state.inStockOnly ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Фильтры',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    ref.read(productsProvider.notifier).resetFilters();
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'Сбросить',
                    style: TextStyle(color: AppColors.error),
                  ),
                ),
              ],
            ),
          ),

          // Sort Options
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Сортировка',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                ...SortOption.values.map((option) => _buildSortOption(option)),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // In Stock Filter
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Только в наличии',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Switch(
                  value: _inStockOnly,
                  onChanged: (value) => setState(() => _inStockOnly = value),
                  activeColor: AppColors.primary,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Apply Button
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  ref.read(productsProvider.notifier).setSortOption(_selectedSort);
                  ref.read(productsProvider.notifier).setInStockOnly(
                    _inStockOnly ? true : null,
                  );
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Применить',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),

          // Safe area
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Widget _buildSortOption(SortOption option) {
    final isSelected = _selectedSort == option;

    return GestureDetector(
      onTap: () => setState(() => _selectedSort = option),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.divider,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              option.displayName,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: AppColors.primary,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}