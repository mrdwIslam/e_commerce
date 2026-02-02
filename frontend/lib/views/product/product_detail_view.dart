import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/constants.dart';
import '../../models/product_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/shop_provider.dart';
import '../../services/api_service.dart';
import '../cart/cart_view.dart';
import '../auth/login_view.dart';

class ProductDetailView extends ConsumerStatefulWidget {
  final String productId;
  final String heroTag;
  final Product? initialProduct; // Опционально для быстрого отображения

  const ProductDetailView({
    super.key,
    required this.productId,
    required this.heroTag,
    this.initialProduct,
  });

  @override
  ConsumerState<ProductDetailView> createState() => _ProductDetailViewState();
}

class _ProductDetailViewState extends ConsumerState<ProductDetailView>
    with SingleTickerProviderStateMixin {
  // Количество для добавления в корзину
  int _quantity = 1;

  // Анимация
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Scroll
  final _scrollController = ScrollController();
  bool _isAppBarCollapsed = false;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    // Загружаем детали товара
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(productDetailsProvider.notifier).loadProduct(widget.productId);
      _animationController.forward();
    });

    // Слушаем скролл для AppBar
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final isCollapsed = _scrollController.hasClients &&
        _scrollController.offset > 200;

    if (isCollapsed != _isAppBarCollapsed) {
      setState(() => _isAppBarCollapsed = isCollapsed);
    }
  }

  void _incrementQuantity(Product product) {
    if (_quantity < product.stock) {
      setState(() => _quantity++);
      HapticFeedback.lightImpact();
    }
  }

  void _decrementQuantity() {
    if (_quantity > 1) {
      setState(() => _quantity--);
      HapticFeedback.lightImpact();
    }
  }

  void _addToCart(Product product) {
    ref.read(cartProvider.notifier).addItem(product, quantity: _quantity);
    HapticFeedback.mediumImpact();

    _showSnackBar(
      message: 'Добавлено в корзину: $_quantity шт.',
      icon: Icons.shopping_bag_outlined,
      action: SnackBarAction(
        label: 'Корзина',
        textColor: Colors.white,
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CartView()),
          );
        },
      ),
    );

    // Сбрасываем количество
    setState(() => _quantity = 1);
  }

  Future<void> _toggleFavorite(Product product) async {
    final isAuth = ref.read(isAuthenticatedProvider);

    if (!isAuth) {
      _showSnackBar(
        message: 'Войдите, чтобы добавить в избранное',
        icon: Icons.favorite_border,
        isError: true,
        action: SnackBarAction(
          label: 'Войти',
          textColor: Colors.white,
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const LoginView()),
            );
          },
        ),
      );
      return;
    }

    final success = await ref.read(favoritesProvider.notifier).toggleFavorite(product);

    if (success && mounted) {
      final isFav = ref.read(favoritesProvider).isFavorite(product.id);
      HapticFeedback.lightImpact();
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

  @override
  Widget build(BuildContext context) {
    final detailsState = ref.watch(productDetailsProvider);
    final cartItemCount = ref.watch(cartItemCountProvider);

    // Используем initialProduct пока загружаются детали
    final product = detailsState.product ?? widget.initialProduct;

    return Scaffold(
      backgroundColor: Colors.white,
      body: product == null
          ? _buildLoading(detailsState)
          : _buildContent(product, cartItemCount),
    );
  }

  Widget _buildLoading(ProductDetailsState state) {
    if (state.error != null) {
      return _buildError(state.error!);
    }

    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  Widget _buildError(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: AppColors.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Ошибка загрузки',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                ref.read(productDetailsProvider.notifier).loadProduct(widget.productId);
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Повторить'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Назад'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(Product product, int cartItemCount) {
    final isFavorite = ref.watch(isProductFavoriteProvider(product.id));
    final quantityInCart = ref.watch(productQuantityInCartProvider(product.id));

    return Stack(
      children: [
        // Main Content
        CustomScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          slivers: [
            // App Bar with Image
            _buildSliverAppBar(product, isFavorite, cartItemCount),

            // Product Info
            SliverToBoxAdapter(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: _buildProductInfo(product, quantityInCart),
                ),
              ),
            ),
          ],
        ),

        // Bottom Action Bar
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _buildBottomBar(product),
        ),
      ],
    );
  }

  Widget _buildSliverAppBar(Product product, bool isFavorite, int cartItemCount) {
    final apiService = ApiService();
    final imageUrl = apiService.getImageUrl(product.image);

    return SliverAppBar(
      expandedHeight: 380,
      pinned: true,
      stretch: true,
      backgroundColor: Colors.white,
      elevation: _isAppBarCollapsed ? 1 : 0,
      leading: _buildBackButton(),
      actions: [
        _buildFavoriteButton(product, isFavorite),
        _buildCartButton(cartItemCount),
        const SizedBox(width: 8),
      ],
      title: AnimatedOpacity(
        opacity: _isAppBarCollapsed ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: Text(
          product.name,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [
          StretchMode.zoomBackground,
          StretchMode.blurBackground,
        ],
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Image
            Hero(
              tag: widget.heroTag,
              child: Container(
                color: AppColors.background,
                child: imageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => _buildImagePlaceholder(),
                        errorWidget: (_, __, ___) => _buildImagePlaceholder(),
                      )
                    : _buildImagePlaceholder(),
              ),
            ),

            // Gradient overlay
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 100,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.white,
                      Colors.white.withOpacity(0),
                    ],
                  ),
                ),
              ),
            ),

            // Stock Badge
            if (!product.inStock)
              Positioned(
                top: 100,
                left: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Нет в наличии',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      color: AppColors.background,
      child: Center(
        child: Icon(
          Icons.image_outlined,
          size: 64,
          color: AppColors.textHint,
        ),
      ),
    );
  }

  Widget _buildBackButton() {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Container(
        margin: const EdgeInsets.all(8),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
            ),
          ],
        ),
        child: const Icon(
          Icons.arrow_back_ios_new,
          size: 18,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildFavoriteButton(Product product, bool isFavorite) {
    return GestureDetector(
      onTap: () => _toggleFavorite(product),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
            ),
          ],
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Icon(
            isFavorite ? Icons.favorite : Icons.favorite_border,
            key: ValueKey(isFavorite),
            size: 20,
            color: isFavorite ? AppColors.favorite : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildCartButton(int cartItemCount) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CartView()),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Icon(
              Icons.shopping_bag_outlined,
              size: 20,
              color: AppColors.textPrimary,
            ),
            if (cartItemCount > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      cartItemCount > 9 ? '9+' : '$cartItemCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductInfo(Product product, int quantityInCart) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              product.categoryName,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Name
          Text(
            product.name,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
              height: 1.2,
            ),
          ),

          const SizedBox(height: 16),

          // Price and Stock
          Row(
            children: [
              Text(
                product.formattedPrice,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const Spacer(),
              _buildStockInfo(product),
            ],
          ),

          const SizedBox(height: 24),

          // Already in cart badge
          if (quantityInCart > 0)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.success.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: AppColors.success,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'В корзине: $quantityInCart шт.',
                    style: TextStyle(
                      color: AppColors.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const CartView()),
                      );
                    },
                    child: Text(
                      'Перейти →',
                      style: TextStyle(
                        color: AppColors.success,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          if (quantityInCart > 0) const SizedBox(height: 24),

          // Quantity Selector
          if (product.inStock) ...[
            const Text(
              'Количество',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            _buildQuantitySelector(product),
            const SizedBox(height: 24),
          ],

          // Divider
          Divider(color: AppColors.divider),

          const SizedBox(height: 24),

          // Description
          const Text(
            'Описание',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),

          const SizedBox(height: 12),

          Text(
            product.description.isNotEmpty
                ? product.description
                : 'Описание товара отсутствует.',
            style: TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),

          const SizedBox(height: 24),

          // Product Details
          _buildProductDetails(product),
        ],
      ),
    );
  }

  Widget _buildStockInfo(Product product) {
    if (!product.inStock) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cancel, size: 16, color: AppColors.error),
            const SizedBox(width: 6),
            Text(
              'Нет в наличии',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.error,
              ),
            ),
          ],
        ),
      );
    }

    if (product.stock <= 5) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.warning.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_amber, size: 16, color: AppColors.warning),
            const SizedBox(width: 6),
            Text(
              'Осталось ${product.stock} шт.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.warning,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.success.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, size: 16, color: AppColors.success),
          const SizedBox(width: 6),
          Text(
            'В наличии',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.success,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuantitySelector(Product product) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Decrease Button
          GestureDetector(
            onTap: _decrementQuantity,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _quantity > 1 ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                boxShadow: _quantity > 1
                    ? [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 5,
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                Icons.remove,
                color: _quantity > 1
                    ? AppColors.textPrimary
                    : AppColors.textHint,
              ),
            ),
          ),

          // Quantity Display
          Container(
            width: 60,
            alignment: Alignment.center,
            child: Text(
              '$_quantity',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),

          // Increase Button
          GestureDetector(
            onTap: () => _incrementQuantity(product),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _quantity < product.stock
                    ? AppColors.primary
                    : AppColors.textHint,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 5,
                  ),
                ],
              ),
              child: const Icon(
                Icons.add,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductDetails(Product product) {
    final details = [
      {'icon': Icons.category_outlined, 'label': 'Категория', 'value': product.categoryName},
      {'icon': Icons.inventory_2_outlined, 'label': 'Артикул', 'value': product.id.substring(0, 8).toUpperCase()},
      if (product.inStock)
        {'icon': Icons.warehouse_outlined, 'label': 'На складе', 'value': '${product.stock} шт.'},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Характеристики',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          ...details.map((detail) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        detail['icon'] as IconData,
                        size: 18,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          detail['label'] as String,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          detail['value'] as String,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildBottomBar(Product product) {
    final totalPrice = product.price * _quantity;

    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        16 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          // Total Price
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Итого',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${totalPrice.toStringAsFixed(2)} TMT',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),

          // Add to Cart Button
          Expanded(
            child: SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: product.inStock ? () => _addToCart(product) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: AppColors.textHint,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.shopping_bag_outlined, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      product.inStock ? 'В корзину' : 'Нет в наличии',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}