import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/constants.dart';
import '../../models/favorite_model.dart';
import '../../models/product_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/shop_provider.dart';
import '../../services/api_service.dart';
import '../auth/login_view.dart';
import '../product/product_detail_view.dart';
import '../widgets/skeleton_card.dart';

class FavoritesView extends ConsumerStatefulWidget {
  const FavoritesView({super.key});

  @override
  ConsumerState<FavoritesView> createState() => _FavoritesViewState();
}

class _FavoritesViewState extends ConsumerState<FavoritesView>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    // Загружаем избранное
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(isAuthenticatedProvider)) {
        ref.read(favoritesProvider.notifier).loadFavorites();
      }
      _animationController.forward();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _showSnackBar({
    required String message,
    required IconData icon,
    bool isError = false,
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
      ),
    );
  }

  Future<void> _removeFromFavorites(Favorite favorite) async {
    final success = await ref
        .read(favoritesProvider.notifier)
        .removeFromFavorites(favorite.product.id);

    if (success && mounted) {
      HapticFeedback.lightImpact();
      _showSnackBar(
        message: '${favorite.product.name} удалён из избранного',
        icon: Icons.favorite_border,
      );
    }
  }

  void _addToCart(Product product) {
    ref.read(cartProvider.notifier).addItem(product);
    HapticFeedback.mediumImpact();
    _showSnackBar(
      message: '${product.name} добавлен в корзину',
      icon: Icons.shopping_bag_outlined,
    );
  }

  void _navigateToProduct(Product product) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProductDetailView(
          productId: product.id,
          heroTag: 'fav_${product.id}',
          initialProduct: product,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAuthenticated = ref.watch(isAuthenticatedProvider);
    final favoritesState = ref.watch(favoritesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(favoritesState),
      body: !isAuthenticated
          ? _buildLoginRequired()
          : favoritesState.isLoading
              ? _buildLoading()
              : favoritesState.favorites.isEmpty
                  ? _buildEmptyFavorites()
                  : _buildFavoritesList(favoritesState),
    );
  }

  PreferredSizeWidget _buildAppBar(FavoritesState state) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.arrow_back_ios_new,
            size: 18,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      title: Column(
        children: [
          const Text(
            'Избранное',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          if (state.favorites.isNotEmpty)
            Text(
              '${state.favorites.length} товаров',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
        ],
      ),
      centerTitle: true,
      actions: [
        GestureDetector(
          onTap: () {
            ref.read(favoritesProvider.notifier).loadFavorites();
          },
          child: Container(
            margin: const EdgeInsets.all(8),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.refresh,
              size: 20,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginRequired() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.favorite.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.favorite_border,
                size: 56,
                color: AppColors.favorite,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Войдите в аккаунт',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Чтобы сохранять товары в избранное,\nвойдите в свой аккаунт',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LoginView()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Войти',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Продолжить без входа',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: 4,
      itemBuilder: (context, index) => const Padding(
        padding: EdgeInsets.only(bottom: 16),
        child: SkeletonCardHorizontal(),
      ),
    );
  }

  Widget _buildEmptyFavorites() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.favorite.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.favorite_border,
                size: 56,
                color: AppColors.favorite,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Список пуст',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Добавляйте товары в избранное,\nчтобы не потерять их',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Перейти к покупкам',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFavoritesList(FavoritesState state) {
    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(favoritesProvider.notifier).loadFavorites();
      },
      color: AppColors.primary,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          itemCount: state.favorites.length,
          itemBuilder: (context, index) {
            final favorite = state.favorites[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildFavoriteItem(favorite),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFavoriteItem(Favorite favorite) {
    final product = favorite.product;
    final apiService = ApiService();
    final imageUrl = apiService.getImageUrl(product.image);
    final isInCart = ref.watch(isProductInCartProvider(product.id));

    return Dismissible(
      key: Key(favorite.id.toString()),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _removeFromFavorites(favorite),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(
          Icons.delete_outline,
          color: Colors.white,
          size: 28,
        ),
      ),
      child: GestureDetector(
        onTap: () => _navigateToProduct(product),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
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
              // Image
              Hero(
                tag: 'fav_${product.id}',
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: imageUrl != null
                            ? CachedNetworkImage(
                                imageUrl: imageUrl,
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => _buildPlaceholder(),
                                errorWidget: (_, __, ___) => _buildPlaceholder(),
                              )
                            : _buildPlaceholder(),
                      ),
                      // Out of stock overlay
                      if (!product.inStock)
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Center(
                            child: Text(
                              'Нет\nв наличии',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 14),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category
                    Text(
                      product.categoryName,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),

                    const SizedBox(height: 4),

                    // Name
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 4),

                    // Added date
                    Text(
                      'Добавлено ${favorite.addedAgo}',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textHint,
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Price and Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Price
                        Text(
                          product.formattedPrice,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),

                        // Actions
                        Row(
                          children: [
                            // Remove button
                            GestureDetector(
                              onTap: () => _removeFromFavorites(favorite),
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.favorite,
                                  size: 18,
                                  color: AppColors.favorite,
                                ),
                              ),
                            ),

                            const SizedBox(width: 8),

                            // Add to cart button
                            if (product.inStock)
                              GestureDetector(
                                onTap: () => _addToCart(product),
                                child: Container(
                                  height: 36,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isInCart
                                        ? AppColors.success
                                        : AppColors.primary,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isInCart
                                            ? Icons.check
                                            : Icons.add_shopping_cart,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        isInCart ? 'В корзине' : 'В корзину',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: 100,
      height: 100,
      color: AppColors.background,
      child: Center(
        child: Icon(
          Icons.image_outlined,
          size: 28,
          color: AppColors.textHint,
        ),
      ),
    );
  }
}