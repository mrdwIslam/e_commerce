import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/product_model.dart';
import '../../providers/shop_provider.dart';

class DetailsView extends ConsumerStatefulWidget {
  final Product product;
  final String heroTag;

  const DetailsView({super.key, required this.product, required this.heroTag});

  @override
  ConsumerState<DetailsView> createState() => _DetailsViewState();
}

class _DetailsViewState extends ConsumerState<DetailsView> {
  String selectedSize = '42';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.west, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite_border, color: Colors.black), 
            onPressed: () {}
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Column(
        children: [
          Expanded(
            flex: 5,
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFFEBEBEB),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(50)),
              ),
              child: Hero(
                tag: widget.heroTag,
                child: widget.product.image != null
                    ? CachedNetworkImage(imageUrl: widget.product.image!, fit: BoxFit.contain)
                    : const Icon(Icons.image, size: 100),
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(widget.product.categoryName, style: const TextStyle(color: Colors.grey, fontSize: 16)),
                      const Row(
                        children: [
                          Icon(Icons.star, color: Colors.black, size: 18),
                          Text(' 4.8', style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(widget.product.name, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  const Text('Выберите размер', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    children: ['40', '41', '42', '43', '44'].map((size) {
                      bool isSelected = selectedSize == size;
                      return GestureDetector(
                        onTap: () => setState(() => selectedSize = size),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 12),
                          width: 48, height: 48,
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.black : Colors.white,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            size, 
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.black, 
                              fontWeight: FontWeight.bold
                            )
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        height: 110,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
        decoration: const BoxDecoration(
          color: Colors.white, 
          borderRadius: BorderRadius.vertical(top: Radius.circular(35))
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Цена', style: TextStyle(color: Colors.grey, fontSize: 12)),
                Text('${widget.product.price.toInt()} ₽', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
              ],
            ),
            GestureDetector(
              onTap: () {
                // ПРАВИЛЬНЫЙ ВЫЗОВ ЧЕРЕЗ REF
                ref.read(shopProvider).addToCart(widget.product);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Товар добавлен'), duration: Duration(seconds: 1)),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(20)),
                child: const Text('В корзину', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}