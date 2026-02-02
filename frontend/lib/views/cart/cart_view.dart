import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/constants.dart';
import '../../models/cart_model.dart';
import '../../models/product_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/shop_provider.dart';
import '../../services/api_service.dart';
import '../auth/login_view.dart';
import '../product/product_detail_view.dart';
import 'checkout_view.dart';

class CartView extends ConsumerStatefulWidget {
  const CartView({super.key});

  @override
  ConsumerState<CartView> createState() => _CartViewState();
}

class _CartViewState extends ConsumerState<CartView>
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
    _animationController.forward();
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

  void _removeItem(CartItem item) {
    ref.read(cartProvider.notifier).removeItem(item.productId);
    HapticFeedback.lightImpact();
    _showSnackBar(
      message: '${item.productName} удалён из корзины',
      icon: Icons.delete_outline,
    );
  }

  void _clearCart() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Очистить корзину?'),
        content: const Text('Все товары будут удалены из корзины.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Отмена',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(cartProvider.notifier).clear();
              Navigator.pop(context);
              HapticFeedback.mediumImpact();
              _showSnackBar(
                message: 'Корзина очищена',
                icon: Icons.delete_sweep,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Очистить'),
          ),
        ],
      ),
    );
  }

  void _proceedToCheckout() {
    final cart = ref.read(cartProvider);

    if (cart.isEmpty) {
      _showSnackBar(
        message: 'Корзина пуста',
        icon: Icons.shopping_bag_outlined,
        isError: true,
      );
      return;
    }

    if (!cart.isValid) {
      _showSnackBar(
        message: 'Некоторые товары недоступны',
        icon: Icons.warning_amber,
        isError: true,
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CheckoutView()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final isAuthenticated = ref.watch(isAuthenticatedProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(cart),
      body: cart.isEmpty
          ? _buildEmptyCart()
          : FadeTransition(
              opacity: _fadeAnimation,
              child: _buildCartContent(cart),
            ),
      bottomNavigationBar: cart.isNotEmpty
          ? _buildBottomBar(cart, isAuthenticated)
          : null,
    );
  }

  PreferredSizeWidget _buildAppBar(Cart cart) {
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
            'Корзина',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          if (cart.isNotEmpty)
            Text(
              '${cart.totalItems} товаров',
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
        if (cart.isNotEmpty)
          GestureDetector(
            onTap: _clearCart,
            child: Container(
              margin: const EdgeInsets.all(8),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.delete_sweep_outlined,
                size: 20,
                color: AppColors.error,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyCart() {
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
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.shopping_bag_outlined,
                size: 56,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Корзина пуста',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Добавьте товары, чтобы оформить заказ',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
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

  Widget _buildCartContent(Cart cart) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 200),
      physics: const BouncingScrollPhysics(),
      itemCount: cart.items.length,
      itemBuilder: (context, index) {
        final item = cart.items[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildCartItem(item),
        );
      },
    );
  }

  Widget _buildCartItem(CartItem item) {
    final apiService = ApiService();
    final imageUrl = apiService.getImageUrl(item.product.image);
    final isAvailable = item.product.inStock && item.quantity <= item.product.stock;

    return Dismissible(
      key: Key(item.productId),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _removeItem(item),
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
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ProductDetailView(
                productId: item.productId,
                heroTag: 'cart_${item.productId}',
                initialProduct: item.product,
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: !isAvailable
                ? Border.all(color: AppColors.error.withOpacity(0.3))
                : null,
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
                tag: 'cart_${item.productId}',
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: imageUrl != null
                        ? CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => _buildPlaceholder(),
                            errorWidget: (_, __, ___) => _buildPlaceholder(),
                          )
                        : _buildPlaceholder(),
                  ),
                ),
              ),

              const SizedBox(width: 14),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name
                    Text(
                      item.productName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 4),

                    // Category
                    Text(
                      item.product.categoryName,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),

                    // Unavailable warning
                    if (!isAvailable) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.error.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.product.inStock
                              ? 'Макс: ${item.product.stock} шт.'
                              : 'Нет в наличии',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 10),

                    // Price and Quantity
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Price
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.formattedTotal,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                            if (item.quantity > 1)
                              Text(
                                '${item.product.formattedPrice} × ${item.quantity}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                          ],
                        ),

                        // Quantity Controls
                        _buildQuantityControls(item),
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

  Widget _buildQuantityControls(CartItem item) {
    final canDecrease = item.quantity > 1;
    final canIncrease = item.quantity < item.product.stock;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Decrease
          GestureDetector(
            onTap: () {
              if (canDecrease) {
                ref.read(cartProvider.notifier).decrementItem(item.productId);
                HapticFeedback.lightImpact();
              } else {
                _removeItem(item);
              }
            },
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Icon(
                canDecrease ? Icons.remove : Icons.delete_outline,
                size: 16,
                color: canDecrease ? AppColors.textPrimary : AppColors.error,
              ),
            ),
          ),

          // Quantity
          Container(
            width: 36,
            alignment: Alignment.center,
            child: Text(
              '${item.quantity}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),

          // Increase
          GestureDetector(
            onTap: () {
              if (canIncrease) {
                ref.read(cartProvider.notifier).incrementItem(item.productId);
                HapticFeedback.lightImpact();
              }
            },
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: canIncrease ? AppColors.primary : AppColors.textHint,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.add,
                size: 16,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(Cart cart, bool isAuthenticated) {
    final summary = CartSummary.fromCart(cart);

    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        20 + MediaQuery.of(context).padding.bottom,
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Summary rows
          _buildSummaryRow('Товары (${summary.itemsCount})', summary.formattedSubtotal),

          if (summary.hasDiscount) ...[
            const SizedBox(height: 8),
            _buildSummaryRow('Скидка', summary.formattedDiscount, isDiscount: true),
          ],

          const SizedBox(height: 8),
          _buildSummaryRow(
            'Доставка',
            summary.hasFreeDelivery ? 'Бесплатно' : summary.formattedDelivery,
            isFree: summary.hasFreeDelivery,
          ),

          const SizedBox(height: 12),
          Divider(color: AppColors.divider),
          const SizedBox(height: 12),

          // Total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Итого',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                summary.formattedTotal,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Checkout Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: cart.isValid ? _proceedToCheckout : null,
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
                  const Icon(Icons.shopping_cart_checkout, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    cart.isValid ? 'Оформить заказ' : 'Проверьте корзину',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Login hint
          if (!isAuthenticated) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LoginView()),
                );
              },
              child: RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                  children: [
                    const TextSpan(text: 'Войдите, чтобы отслеживать заказы. '),
                    TextSpan(
                      text: 'Войти',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    bool isDiscount = false,
    bool isFree = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDiscount
                ? AppColors.success
                : isFree
                    ? AppColors.success
                    : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}