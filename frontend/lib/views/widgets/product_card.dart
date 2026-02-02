import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/constants.dart';
import '../../models/product_model.dart';
import '../../providers/shop_provider.dart';
import '../../services/api_service.dart';

class ProductCard extends ConsumerWidget {
  final Product product;
  final String heroTag;
  final VoidCallback? onTap;
  final VoidCallback? onAddToCart;
  final VoidCallback? onToggleFavorite;
  final bool showFavoriteButton;
  final bool showAddToCartButton;
  final bool isCompact;

  const ProductCard({
    super.key,
    required this.product,
    required this.heroTag,
    this.onTap,
    this.onAddToCart,
    this.onToggleFavorite,
    this.showFavoriteButton = true,
    this.showAddToCartButton = true,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFavorite = ref.watch(isProductFavoriteProvider(product.id));
    final quantityInCart = ref.watch(productQuantityInCartProvider(product.id));
    final apiService = ApiService();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Section
            Expanded(
              flex: isCompact ? 3 : 4,
              child: _buildImageSection(
                context,
                apiService,
                isFavorite,
                quantityInCart,
              ),
            ),

            // Info Section
            Expanded(
              flex: isCompact ? 2 : 3,
              child: _buildInfoSection(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSection(
    BuildContext context,
    ApiService apiService,
    bool isFavorite,
    int quantityInCart,
  ) {
    final imageUrl = apiService.getImageUrl(product.image);

    return Stack(
      children: [
        // Product Image
        Hero(
          tag: heroTag,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              child: imageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => _buildImagePlaceholder(),
                      errorWidget: (context, url, error) =>
                          _buildImagePlaceholder(),
                    )
                  : _buildImagePlaceholder(),
            ),
          ),
        ),

        // Stock Badge
        if (!product.inStock)
          Positioned(
            top: 10,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: AppColors.error,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Нет в наличии',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

        // Low Stock Badge
        if (product.inStock && product.stock <= 5 && product.stock > 0)
          Positioned(
            top: 10,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: AppColors.warning,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Осталось ${product.stock}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

        // Favorite Button
        if (showFavoriteButton)
          Positioned(
            top: 10,
            right: 10,
            child: _buildFavoriteButton(isFavorite),
          ),

        // Cart Badge
        if (quantityInCart > 0)
          Positioned(
            bottom: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.shopping_bag_outlined,
                    color: Colors.white,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$quantityInCart',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      color: AppColors.background,
      child: Center(
        child: Icon(
          Icons.image_outlined,
          size: 40,
          color: AppColors.textHint,
        ),
      ),
    );
  }

  Widget _buildFavoriteButton(bool isFavorite) {
    return GestureDetector(
      onTap: onToggleFavorite,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isFavorite ? AppColors.favorite : Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          isFavorite ? Icons.favorite : Icons.favorite_border,
          size: 18,
          color: isFavorite ? Colors.white : AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildInfoSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category
          Text(
            product.categoryName,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
              letterSpacing: 0.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 4),

          // Product Name
          Text(
            product.name,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              height: 1.2,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          const Spacer(),

          // Price and Add Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Price
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      product.formattedPrice,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),

              // Add to Cart Button
              if (showAddToCartButton && product.inStock)
                _buildAddToCartButton(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAddToCartButton() {
    return GestureDetector(
      onTap: onAddToCart,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Icon(
          Icons.add,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }
}

/// Горизонтальная версия карточки товара
class ProductCardHorizontal extends ConsumerWidget {
  final Product product;
  final String heroTag;
  final VoidCallback? onTap;
  final VoidCallback? onAddToCart;
  final VoidCallback? onToggleFavorite;
  final VoidCallback? onRemove;
  final int? quantity;
  final bool showQuantityControls;

  const ProductCardHorizontal({
    super.key,
    required this.product,
    required this.heroTag,
    this.onTap,
    this.onAddToCart,
    this.onToggleFavorite,
    this.onRemove,
    this.quantity,
    this.showQuantityControls = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFavorite = ref.watch(isProductFavoriteProvider(product.id));
    final apiService = ApiService();
    final imageUrl = apiService.getImageUrl(product.image);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 120,
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
            // Image
            Hero(
              tag: heroTag,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(16),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(16),
                  ),
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

            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
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
                    Expanded(
                      child: Text(
                        product.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    // Price and Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          product.formattedPrice,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),

                        if (showQuantityControls && quantity != null)
                          _buildQuantityControls(ref)
                        else
                          Row(
                            children: [
                              if (onToggleFavorite != null)
                                GestureDetector(
                                  onTap: onToggleFavorite,
                                  child: Icon(
                                    isFavorite
                                        ? Icons.favorite
                                        : Icons.favorite_border,
                                    size: 22,
                                    color: isFavorite
                                        ? AppColors.favorite
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              if (onRemove != null) ...[
                                const SizedBox(width: 12),
                                GestureDetector(
                                  onTap: onRemove,
                                  child: Icon(
                                    Icons.delete_outline,
                                    size: 22,
                                    color: AppColors.error,
                                  ),
                                ),
                              ],
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
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
          size: 32,
          color: AppColors.textHint,
        ),
      ),
    );
  }

  Widget _buildQuantityControls(WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Decrease
          GestureDetector(
            onTap: () {
              ref.read(cartProvider.notifier).decrementItem(product.id);
            },
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.remove, size: 18),
            ),
          ),

          // Quantity
          Container(
            width: 40,
            alignment: Alignment.center,
            child: Text(
              '$quantity',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // Increase
          GestureDetector(
            onTap: () {
              ref.read(cartProvider.notifier).incrementItem(product.id);
            },
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.add, size: 18, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}