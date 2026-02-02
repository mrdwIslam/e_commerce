import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../models/cart_model.dart';
import '../../models/order_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/shop_provider.dart';
import '../orders/order_success_view.dart';

class CheckoutView extends ConsumerStatefulWidget {
  const CheckoutView({super.key});

  @override
  ConsumerState<CheckoutView> createState() => _CheckoutViewState();
}

class _CheckoutViewState extends ConsumerState<CheckoutView> {
  final _formKey = GlobalKey<FormState>();

  // Контроллеры
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _noteController = TextEditingController();

  // Focus nodes
  final _firstNameFocus = FocusNode();
  final _lastNameFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _addressFocus = FocusNode();
  final _noteFocus = FocusNode();

  // Состояние
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _prefillUserData();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _noteController.dispose();
    _firstNameFocus.dispose();
    _lastNameFocus.dispose();
    _phoneFocus.dispose();
    _emailFocus.dispose();
    _addressFocus.dispose();
    _noteFocus.dispose();
    super.dispose();
  }

  void _prefillUserData() {
    final user = ref.read(currentUserProvider);
    if (user != null) {
      _firstNameController.text = user.firstName;
      _lastNameController.text = user.lastName;
      _phoneController.text = user.phone?.replaceAll('+993', '') ?? '';
      _emailController.text = user.email;
    }
  }

  Future<void> _submitOrder() async {
    if (!_formKey.currentState!.validate()) return;

    final cart = ref.read(cartProvider);
    if (cart.isEmpty) {
      _showSnackBar(
        message: 'Корзина пуста',
        icon: Icons.shopping_bag_outlined,
        isError: true,
      );
      return;
    }

    setState(() => _isSubmitting = true);
    FocusScope.of(context).unfocus();

    final phone = '+993${_phoneController.text.trim()}';

    final order = await ref.read(ordersProvider.notifier).createOrder(
          cart: cart,
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          phone: phone,
          email: _emailController.text.trim().isNotEmpty
              ? _emailController.text.trim()
              : null,
          address: _addressController.text.trim(),
          note: _noteController.text.trim().isNotEmpty
              ? _noteController.text.trim()
              : null,
        );

    setState(() => _isSubmitting = false);

    if (!mounted) return;

    if (order != null) {
      // Очищаем корзину
      ref.read(cartProvider.notifier).clear();

      HapticFeedback.heavyImpact();

      // Переходим на экран успеха
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => OrderSuccessView(order: order),
        ),
      );
    } else {
      final error = ref.read(ordersProvider).error;
      _showSnackBar(
        message: error ?? 'Ошибка при создании заказа',
        icon: Icons.error_outline,
        isError: true,
      );
    }
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final summary = CartSummary.fromCart(cart);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Контактные данные
              _buildSectionTitle('Контактные данные'),
              const SizedBox(height: 16),
              _buildContactForm(),

              const SizedBox(height: 32),

              // Адрес доставки
              _buildSectionTitle('Адрес доставки'),
              const SizedBox(height: 16),
              _buildAddressForm(),

              const SizedBox(height: 32),

              // Комментарий
              _buildSectionTitle('Комментарий к заказу'),
              const SizedBox(height: 16),
              _buildNoteField(),

              const SizedBox(height: 32),

              // Итого
              _buildOrderSummary(cart, summary),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomBar(summary),
    );
  }

  PreferredSizeWidget _buildAppBar() {
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
      title: const Text(
        'Оформление заказа',
        style: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      centerTitle: true,
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildContactForm() {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(
        children: [
          // Имя и Фамилия
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _firstNameController,
                  focusNode: _firstNameFocus,
                  nextFocus: _lastNameFocus,
                  label: 'Имя',
                  hint: 'Иван',
                  prefixIcon: Icons.person_outline,
                  validator: (v) => AppValidators.name(v, fieldName: 'имя'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  controller: _lastNameController,
                  focusNode: _lastNameFocus,
                  nextFocus: _phoneFocus,
                  label: 'Фамилия',
                  hint: 'Иванов',
                  prefixIcon: Icons.person_outline,
                  validator: (v) => AppValidators.name(v, fieldName: 'фамилию'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Телефон
          _buildPhoneField(),

          const SizedBox(height: 20),

          // Email (опционально)
          _buildTextField(
            controller: _emailController,
            focusNode: _emailFocus,
            nextFocus: _addressFocus,
            label: 'Email (необязательно)',
            hint: 'example@gmail.com',
            prefixIcon: Icons.mail_outline,
            keyboardType: TextInputType.emailAddress,
            validator: (v) {
              if (v == null || v.isEmpty) return null;
              return AppValidators.email(v);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    FocusNode? nextFocus,
    required String label,
    required String hint,
    required IconData prefixIcon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: keyboardType,
          textInputAction:
              nextFocus != null ? TextInputAction.next : TextInputAction.done,
          onFieldSubmitted: (_) {
            if (nextFocus != null) {
              FocusScope.of(context).requestFocus(nextFocus);
            }
          },
          style: const TextStyle(
            fontSize: 15,
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AppColors.textHint),
            prefixIcon: Icon(
              prefixIcon,
              color: AppColors.textSecondary,
              size: 20,
            ),
            filled: true,
            fillColor: AppColors.background,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppColors.primary,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppColors.error,
                width: 1,
              ),
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildPhoneField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Телефон',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _phoneController,
          focusNode: _phoneFocus,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          onFieldSubmitted: (_) {
            FocusScope.of(context).requestFocus(_emailFocus);
          },
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(8),
          ],
          style: const TextStyle(
            fontSize: 15,
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: '65 123456',
            hintStyle: TextStyle(color: AppColors.textHint),
            prefixIcon: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🇹🇲', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  const Text(
                    '+993',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(left: 10),
                    height: 20,
                    width: 1,
                    color: AppColors.divider,
                  ),
                ],
              ),
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 0,
              minHeight: 0,
            ),
            filled: true,
            fillColor: AppColors.background,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppColors.primary,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppColors.error,
                width: 1,
              ),
            ),
          ),
          validator: AppValidators.phone,
        ),
      ],
    );
  }

  Widget _buildAddressForm() {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Адрес',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _addressController,
            focusNode: _addressFocus,
            keyboardType: TextInputType.streetAddress,
            textInputAction: TextInputAction.next,
            maxLines: 3,
            onFieldSubmitted: (_) {
              FocusScope.of(context).requestFocus(_noteFocus);
            },
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: 'Город, улица, дом, квартира',
              hintStyle: TextStyle(color: AppColors.textHint),
              prefixIcon: Padding(
                padding: const EdgeInsets.only(bottom: 40),
                child: Icon(
                  Icons.location_on_outlined,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
              ),
              filled: true,
              fillColor: AppColors.background,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 2,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppColors.error,
                  width: 1,
                ),
              ),
            ),
            validator: AppValidators.address,
          ),
        ],
      ),
    );
  }

  Widget _buildNoteField() {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: TextFormField(
        controller: _noteController,
        focusNode: _noteFocus,
        keyboardType: TextInputType.text,
        textInputAction: TextInputAction.done,
        maxLines: 3,
        style: const TextStyle(
          fontSize: 15,
          color: AppColors.textPrimary,
        ),
        decoration: InputDecoration(
          hintText: 'Пожелания к заказу, время доставки и т.д.',
          hintStyle: TextStyle(color: AppColors.textHint),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(bottom: 40),
            child: Icon(
              Icons.note_outlined,
              color: AppColors.textSecondary,
              size: 20,
            ),
          ),
          filled: true,
          fillColor: AppColors.background,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildOrderSummary(Cart cart, CartSummary summary) {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ваш заказ',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),

          // Товары
          ...cart.items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${item.productName} × ${item.quantity}',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      item.formattedTotal,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              )),

          Divider(color: AppColors.divider, height: 24),

          // Доставка
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Доставка',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                summary.hasFreeDelivery ? 'Бесплатно' : summary.formattedDelivery,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: summary.hasFreeDelivery
                      ? AppColors.success
                      : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(CartSummary summary) {
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
          // Total
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'К оплате',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  summary.formattedTotal,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),

          // Submit Button
          Expanded(
            child: SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Оформить',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}