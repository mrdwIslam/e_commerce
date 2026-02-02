import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../providers/auth_provider.dart';

class ForgotPasswordView extends ConsumerStatefulWidget {
  const ForgotPasswordView({super.key});

  @override
  ConsumerState<ForgotPasswordView> createState() => _ForgotPasswordViewState();
}

class _ForgotPasswordViewState extends ConsumerState<ForgotPasswordView>
    with SingleTickerProviderStateMixin {
  // Шаги восстановления
  int _currentStep = 0; // 0 - email, 1 - код, 2 - новый пароль

  final _formKey = GlobalKey<FormState>();

  // Контроллеры
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Focus nodes
  final _emailFocus = FocusNode();
  final _otpFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmPasswordFocus = FocusNode();

  // Состояние
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  Timer? _resendTimer;
  int _resendSeconds = 0;

  // Анимация
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.2, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _animationController.dispose();
    _emailController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _emailFocus.dispose();
    _otpFocus.dispose();
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // НАВИГАЦИЯ ПО ШАГАМ
  // ══════════════════════════════════════════════════════════════════════════

  void _goToStep(int step) {
    _animationController.reset();
    setState(() => _currentStep = step);
    _animationController.forward();

    // Фокус на соответствующее поле
    Future.delayed(const Duration(milliseconds: 300), () {
      switch (step) {
        case 0:
          _emailFocus.requestFocus();
          break;
        case 1:
          _otpFocus.requestFocus();
          break;
        case 2:
          _passwordFocus.requestFocus();
          break;
      }
    });
  }

  void _goBack() {
    if (_currentStep > 0) {
      _goToStep(_currentStep - 1);
    } else {
      Navigator.of(context).pop();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ДЕЙСТВИЯ
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _handleSendCode() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    final error = await ref.read(authProvider.notifier).requestPasswordReset(
          _emailController.text.trim(),
        );

    if (!mounted) return;

    if (error == null) {
      _showSuccess('Код отправлен на ${_emailController.text}');
      _startResendTimer();
      _goToStep(1);
    } else {
      _showError(error);
    }
  }

  Future<void> _handleVerifyCode() async {
    if (_otpController.text.length != 6) {
      _showError('Введите 6-значный код');
      return;
    }

    // Переходим к вводу пароля (верификация будет при финальной отправке)
    _goToStep(2);
  }

  Future<void> _handleResetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    final error = await ref.read(authProvider.notifier).confirmPasswordReset(
          email: _emailController.text.trim(),
          code: _otpController.text.trim(),
          newPassword: _passwordController.text,
        );

    if (!mounted) return;

    if (error == null) {
      _showSuccessDialog();
    } else {
      _showError(error);
      // Если код неверный, возвращаем на шаг ввода кода
      if (error.toLowerCase().contains('код') ||
          error.toLowerCase().contains('code')) {
        _goToStep(1);
      }
    }
  }

  Future<void> _handleResendCode() async {
    if (_resendSeconds > 0) return;

    final error = await ref.read(authProvider.notifier).requestPasswordReset(
          _emailController.text.trim(),
        );

    if (!mounted) return;

    if (error == null) {
      _startResendTimer();
      _showSuccess('Новый код отправлен');
    } else {
      _showError(error);
    }
  }

  void _startResendTimer() {
    _resendSeconds = 60;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_resendSeconds > 0) {
          _resendSeconds--;
        } else {
          timer.cancel();
        }
      });
    });
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Иконка успеха
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: AppColors.success,
                  size: 48,
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                'Пароль изменён!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),

              const SizedBox(height: 12),

              Text(
                'Ваш пароль успешно изменён.\nТеперь вы можете войти с новым паролем.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Закрыть диалог
                    Navigator.of(context).popUntil((route) => route.isFirst);
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
                    'Отлично!',
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
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // UI BUILD
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),

                  // Кнопка назад
                  _buildBackButton(),

                  const SizedBox(height: 30),

                  // Индикатор шагов
                  _buildStepIndicator(),

                  const SizedBox(height: 30),

                  // Контент шага
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: _buildStepContent(authState.isLoading),
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackButton() {
    return GestureDetector(
      onTap: _goBack,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.arrow_back_ios_new,
          size: 20,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Row(
      children: [
        _buildStepDot(0, 'Email'),
        _buildStepLine(0),
        _buildStepDot(1, 'Код'),
        _buildStepLine(1),
        _buildStepDot(2, 'Пароль'),
      ],
    );
  }

  Widget _buildStepDot(int step, String label) {
    final isActive = _currentStep >= step;
    final isCurrent = _currentStep == step;

    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: isCurrent ? 40 : 32,
          height: isCurrent ? 40 : 32,
          decoration: BoxDecoration(
            color: isActive ? AppColors.primary : AppColors.background,
            shape: BoxShape.circle,
            border: Border.all(
              color: isActive ? AppColors.primary : AppColors.divider,
              width: 2,
            ),
            boxShadow: isCurrent
                ? [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: isActive && !isCurrent
                ? const Icon(Icons.check, color: Colors.white, size: 18)
                : Text(
                    '${step + 1}',
                    style: TextStyle(
                      fontSize: isCurrent ? 16 : 14,
                      fontWeight: FontWeight.bold,
                      color: isActive ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
            color: isActive ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine(int afterStep) {
    final isActive = _currentStep > afterStep;

    return Expanded(
      child: Container(
        height: 3,
        margin: const EdgeInsets.only(bottom: 24, left: 8, right: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : AppColors.divider,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildStepContent(bool isLoading) {
    switch (_currentStep) {
      case 0:
        return _buildEmailStep(isLoading);
      case 1:
        return _buildCodeStep(isLoading);
      case 2:
        return _buildPasswordStep(isLoading);
      default:
        return const SizedBox();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ШАГ 1: EMAIL
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildEmailStep(bool isLoading) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Заголовок
        const Text(
          'Забыли пароль?',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),

        const SizedBox(height: 12),

        Text(
          'Введите email, указанный при регистрации.\nМы отправим вам код для восстановления.',
          style: TextStyle(
            fontSize: 16,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),

        const SizedBox(height: 40),

        // Email поле
        _buildEmailField(),

        const SizedBox(height: 32),

        // Кнопка
        _buildActionButton(
          label: 'Отправить код',
          isLoading: isLoading,
          onPressed: _handleSendCode,
        ),
      ],
    );
  }

  Widget _buildEmailField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Email',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _emailController,
          focusNode: _emailFocus,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _handleSendCode(),
          style: const TextStyle(
            fontSize: 16,
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: 'example@gmail.com',
            hintStyle: TextStyle(color: AppColors.textHint),
            prefixIcon: const Icon(
              Icons.mail_outline,
              color: AppColors.textSecondary,
              size: 22,
            ),
            filled: true,
            fillColor: AppColors.background,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.error, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.error, width: 2),
            ),
          ),
          validator: AppValidators.email,
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ШАГ 2: КОД
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildCodeStep(bool isLoading) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Заголовок
        const Text(
          'Введите код',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),

        const SizedBox(height: 12),

        RichText(
          text: TextSpan(
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
            children: [
              const TextSpan(text: 'Мы отправили 6-значный код на\n'),
              TextSpan(
                text: _emailController.text,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Предупреждение о спаме
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.warning.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.warning, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Проверьте папку "Спам"',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.warning,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),

        // OTP поле
        _buildOtpField(),

        const SizedBox(height: 20),

        // Повторная отправка
        _buildResendButton(),

        const SizedBox(height: 32),

        // Кнопка
        _buildActionButton(
          label: 'Продолжить',
          isLoading: isLoading,
          onPressed: _handleVerifyCode,
        ),
      ],
    );
  }

  Widget _buildOtpField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Код подтверждения',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _otpController,
          focusNode: _otpFocus,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          textAlign: TextAlign.center,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            letterSpacing: 16,
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: '000000',
            hintStyle: TextStyle(
              color: AppColors.textHint.withOpacity(0.5),
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: 16,
            ),
            filled: true,
            fillColor: AppColors.background,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 20,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
          ),
          validator: AppValidators.otp,
        ),
      ],
    );
  }

  Widget _buildResendButton() {
    return Center(
      child: TextButton(
        onPressed: _resendSeconds == 0 ? _handleResendCode : null,
        child: Text(
          _resendSeconds > 0
              ? 'Отправить повторно через $_resendSeconds сек'
              : 'Отправить код повторно',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color:
                _resendSeconds > 0 ? AppColors.textSecondary : AppColors.primary,
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ШАГ 3: НОВЫЙ ПАРОЛЬ
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildPasswordStep(bool isLoading) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Заголовок
        const Text(
          'Новый пароль',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),

        const SizedBox(height: 12),

        Text(
          'Придумайте новый надёжный пароль.\nМинимум 8 символов.',
          style: TextStyle(
            fontSize: 16,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),

        const SizedBox(height: 40),

        // Пароль
        _buildPasswordField(
          controller: _passwordController,
          focusNode: _passwordFocus,
          nextFocus: _confirmPasswordFocus,
          label: 'Новый пароль',
          obscureText: _obscurePassword,
          onToggleObscure: () =>
              setState(() => _obscurePassword = !_obscurePassword),
          validator: AppValidators.password,
        ),

        const SizedBox(height: 20),

        // Подтверждение пароля
        _buildPasswordField(
          controller: _confirmPasswordController,
          focusNode: _confirmPasswordFocus,
          label: 'Подтвердите пароль',
          obscureText: _obscureConfirmPassword,
          textInputAction: TextInputAction.done,
          onToggleObscure: () =>
              setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
          validator: (v) =>
              AppValidators.confirmPassword(v, _passwordController.text),
        ),

        const SizedBox(height: 16),

        // Требования к паролю
        _buildPasswordRequirements(),

        const SizedBox(height: 32),

        // Кнопка
        _buildActionButton(
          label: 'Сохранить пароль',
          isLoading: isLoading,
          onPressed: _handleResetPassword,
        ),
      ],
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required FocusNode focusNode,
    FocusNode? nextFocus,
    required String label,
    required bool obscureText,
    required VoidCallback onToggleObscure,
    TextInputAction textInputAction = TextInputAction.next,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          obscureText: obscureText,
          textInputAction:
              nextFocus != null ? TextInputAction.next : textInputAction,
          onFieldSubmitted: (_) {
            if (nextFocus != null) {
              FocusScope.of(context).requestFocus(nextFocus);
            }
          },
          style: const TextStyle(
            fontSize: 16,
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: '••••••••',
            hintStyle: TextStyle(color: AppColors.textHint),
            prefixIcon: const Icon(
              Icons.lock_outline,
              color: AppColors.textSecondary,
              size: 22,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                obscureText
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: AppColors.textSecondary,
              ),
              onPressed: onToggleObscure,
            ),
            filled: true,
            fillColor: AppColors.background,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.error, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.error, width: 2),
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildPasswordRequirements() {
    final password = _passwordController.text;
    final hasMinLength = password.length >= 8;
    final hasNumber = password.contains(RegExp(r'[0-9]'));
    final hasLetter = password.contains(RegExp(r'[a-zA-Z]'));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Требования к паролю:',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          _buildRequirement('Минимум 8 символов', hasMinLength),
          const SizedBox(height: 8),
          _buildRequirement('Хотя бы одна цифра', hasNumber),
          const SizedBox(height: 8),
          _buildRequirement('Хотя бы одна буква', hasLetter),
        ],
      ),
    );
  }

  Widget _buildRequirement(String text, bool isMet) {
    return Row(
      children: [
        Icon(
          isMet ? Icons.check_circle : Icons.circle_outlined,
          size: 18,
          color: isMet ? AppColors.success : AppColors.textHint,
        ),
        const SizedBox(width: 10),
        Text(
          text,
          style: TextStyle(
            fontSize: 13,
            color: isMet ? AppColors.success : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ОБЩИЕ ВИДЖЕТЫ
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildActionButton({
    required String label,
    required bool isLoading,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}