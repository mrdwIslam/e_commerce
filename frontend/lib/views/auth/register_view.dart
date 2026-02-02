import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class RegisterView extends ConsumerStatefulWidget {
  const RegisterView({super.key});

  @override
  ConsumerState<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends ConsumerState<RegisterView>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _apiService = ApiService();

  // Контроллеры
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _otpController = TextEditingController();

  // Focus nodes
  final _usernameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmPasswordFocus = FocusNode();
  final _firstNameFocus = FocusNode();
  final _lastNameFocus = FocusNode();
  final _otpFocus = FocusNode();

  // Состояние
  bool _isCodeSent = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  Timer? _debounce;
  Timer? _resendTimer;
  int _resendSeconds = 0;

  // Ошибки валидации
  String? _usernameError;
  String? _emailError;
  String? _phoneError;

  // Состояние проверки
  bool _isCheckingUsername = false;
  bool _isCheckingEmail = false;
  bool _isCheckingPhone = false;

  // Анимация
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
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _resendTimer?.cancel();
    _animationController.dispose();

    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _otpController.dispose();

    _usernameFocus.dispose();
    _emailFocus.dispose();
    _phoneFocus.dispose();
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();
    _firstNameFocus.dispose();
    _lastNameFocus.dispose();
    _otpFocus.dispose();

    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ВАЛИДАЦИЯ В РЕАЛЬНОМ ВРЕМЕНИ
  // ══════════════════════════════════════════════════════════════════════════

  void _onUsernameChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    if (value.length < 3) {
      setState(() {
        _usernameError = null;
        _isCheckingUsername = false;
      });
      return;
    }

    setState(() => _isCheckingUsername = true);

    _debounce = Timer(AppConstants.validationDebounce, () async {
      if (!mounted) return;

      // Проверяем формат
      if (!AppConstants.usernameRegex.hasMatch(value)) {
        setState(() {
          _usernameError = 'Только буквы, цифры и _';
          _isCheckingUsername = false;
        });
        return;
      }

      // Проверяем занятость
      final taken = await _apiService.isUsernameTaken(value);
      if (mounted) {
        setState(() {
          _usernameError = taken ? 'Этот логин уже занят' : null;
          _isCheckingUsername = false;
        });
      }
    });
  }

  void _onEmailChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    if (value.isEmpty) {
      setState(() {
        _emailError = null;
        _isCheckingEmail = false;
      });
      return;
    }

    // Быстрая проверка формата
    if (!value.contains('@')) {
      setState(() {
        _emailError = 'Введите корректный email';
        _isCheckingEmail = false;
      });
      return;
    }

    setState(() => _isCheckingEmail = true);

    _debounce = Timer(AppConstants.validationDebounce, () async {
      if (!mounted) return;

      if (!AppConstants.emailRegex.hasMatch(value)) {
        setState(() {
          _emailError = 'Некорректный формат email';
          _isCheckingEmail = false;
        });
        return;
      }

      final taken = await _apiService.isEmailTaken(value);
      if (mounted) {
        setState(() {
          _emailError = taken ? 'Email уже зарегистрирован' : null;
          _isCheckingEmail = false;
        });
      }
    });
  }

  void _onPhoneChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    if (value.length < 8) {
      setState(() {
        _phoneError = null;
        _isCheckingPhone = false;
      });
      return;
    }

    setState(() => _isCheckingPhone = true);

    _debounce = Timer(AppConstants.validationDebounce, () async {
      if (!mounted) return;

      final fullPhone = '+993$value';
      final taken = await _apiService.isPhoneTaken(fullPhone);
      if (mounted) {
        setState(() {
          _phoneError = taken ? 'Номер уже используется' : null;
          _isCheckingPhone = false;
        });
      }
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ОСНОВНЫЕ ДЕЙСТВИЯ
  // ══════════════════════════════════════════════════════════════════════════

  bool get _hasValidationErrors =>
      _usernameError != null || _emailError != null || _phoneError != null;

  Future<void> _handleRegister() async {
    if (_hasValidationErrors) {
      _showError('Исправьте ошибки в форме');
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final error = await ref.read(authProvider.notifier).register(
          username: _usernameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          phone: '+993${_phoneController.text.trim()}',
        );

    if (!mounted) return;

    if (error == null) {
      setState(() => _isCodeSent = true);
      _startResendTimer();
      _animationController.reset();
      _animationController.forward();
      _showSuccess('Код отправлен на ${_emailController.text}');
    } else {
      _showError(error);
    }
  }

  Future<void> _handleVerifyOtp() async {
    if (_otpController.text.length != 6) {
      _showError('Введите 6-значный код');
      return;
    }

    final error = await ref.read(authProvider.notifier).verifyOtp(
          _emailController.text.trim(),
          _otpController.text.trim(),
        );

    if (!mounted) return;

    if (error == null) {
      _showSuccess('Регистрация завершена!');
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      _showError(error);
    }
  }

  Future<void> _handleResendOtp() async {
    if (_resendSeconds > 0) return;

    final error = await ref.read(authProvider.notifier).resendOtp(
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
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),

                    // Кнопка назад
                    _buildBackButton(),

                    const SizedBox(height: 30),

                    // Заголовок
                    _buildHeader(),

                    const SizedBox(height: 40),

                    // Форма
                    if (!_isCodeSent) ...[
                      _buildRegistrationForm(),
                    ] else ...[
                      _buildOtpForm(),
                    ],

                    const SizedBox(height: 32),

                    // Кнопка действия
                    _buildActionButton(authState.isLoading),

                    const SizedBox(height: 24),

                    // Ссылка на вход
                    if (!_isCodeSent) _buildLoginLink(),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackButton() {
    return GestureDetector(
      onTap: () {
        if (_isCodeSent) {
          setState(() => _isCodeSent = false);
          _animationController.reset();
          _animationController.forward();
        } else {
          Navigator.of(context).pop();
        }
      },
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

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _isCodeSent ? 'Подтверждение' : 'Создать аккаунт',
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _isCodeSent
              ? 'Введите код, отправленный на\n${_emailController.text}'
              : 'Заполните данные для регистрации',
          style: TextStyle(
            fontSize: 16,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildRegistrationForm() {
    return Column(
      children: [
        // Имя и Фамилия в одной строке
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
                nextFocus: _usernameFocus,
                label: 'Фамилия',
                hint: 'Иванов',
                prefixIcon: Icons.person_outline,
                validator: (v) => AppValidators.name(v, fieldName: 'фамилию'),
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Username
        _buildTextField(
          controller: _usernameController,
          focusNode: _usernameFocus,
          nextFocus: _emailFocus,
          label: 'Имя пользователя',
          hint: 'username',
          prefixIcon: Icons.alternate_email,
          onChanged: _onUsernameChanged,
          externalError: _usernameError,
          isChecking: _isCheckingUsername,
          validator: AppValidators.username,
        ),

        const SizedBox(height: 20),

        // Email
        _buildTextField(
          controller: _emailController,
          focusNode: _emailFocus,
          nextFocus: _phoneFocus,
          label: 'Email',
          hint: 'example@gmail.com',
          prefixIcon: Icons.mail_outline,
          keyboardType: TextInputType.emailAddress,
          onChanged: _onEmailChanged,
          externalError: _emailError,
          isChecking: _isCheckingEmail,
          validator: AppValidators.email,
        ),

        const SizedBox(height: 20),

        // Телефон
        _buildPhoneField(),

        const SizedBox(height: 20),

        // Пароль
        _buildTextField(
          controller: _passwordController,
          focusNode: _passwordFocus,
          nextFocus: _confirmPasswordFocus,
          label: 'Пароль',
          hint: '••••••••',
          prefixIcon: Icons.lock_outline,
          obscureText: _obscurePassword,
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: AppColors.textSecondary,
            ),
            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          ),
          validator: AppValidators.password,
        ),

        const SizedBox(height: 20),

        // Подтверждение пароля
        _buildTextField(
          controller: _confirmPasswordController,
          focusNode: _confirmPasswordFocus,
          label: 'Подтвердите пароль',
          hint: '••••••••',
          prefixIcon: Icons.lock_outline,
          obscureText: _obscureConfirmPassword,
          textInputAction: TextInputAction.done,
          suffixIcon: IconButton(
            icon: Icon(
              _obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: AppColors.textSecondary,
            ),
            onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
          ),
          validator: (v) => AppValidators.confirmPassword(v, _passwordController.text),
        ),
      ],
    );
  }

  Widget _buildOtpForm() {
    return Column(
      children: [
        // Предупреждение о спаме
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.warning.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.warning.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.warning),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Проверьте папку "Спам", если не нашли письмо',
                  style: TextStyle(
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

        const SizedBox(height: 24),

        // Повторная отправка
        _buildResendButton(),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    FocusNode? nextFocus,
    required String label,
    required String hint,
    required IconData prefixIcon,
    Widget? suffixIcon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    TextInputAction textInputAction = TextInputAction.next,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
    String? externalError,
    bool isChecking = false,
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
          keyboardType: keyboardType,
          textInputAction: nextFocus != null ? TextInputAction.next : textInputAction,
          onChanged: onChanged,
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
            hintText: hint,
            hintStyle: TextStyle(
              color: AppColors.textHint,
              fontSize: 16,
            ),
            prefixIcon: Icon(prefixIcon, color: AppColors.textSecondary, size: 22),
            suffixIcon: isChecking
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : (externalError == null && controller.text.isNotEmpty && onChanged != null
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: Icon(Icons.check_circle, color: AppColors.success, size: 22),
                      )
                    : suffixIcon),
            errorText: externalError,
            filled: true,
            fillColor: AppColors.background,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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

  Widget _buildPhoneField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Телефон',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _phoneController,
          focusNode: _phoneFocus,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          onChanged: _onPhoneChanged,
          onFieldSubmitted: (_) {
            FocusScope.of(context).requestFocus(_passwordFocus);
          },
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(8),
          ],
          style: const TextStyle(
            fontSize: 16,
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: '65 123456',
            hintStyle: TextStyle(
              color: AppColors.textHint,
              fontSize: 16,
            ),
            prefixIcon: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '🇹🇲',
                    style: TextStyle(fontSize: 20),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    '+993',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(left: 12),
                    height: 24,
                    width: 1,
                    color: AppColors.divider,
                  ),
                ],
              ),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
            suffixIcon: _isCheckingPhone
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : (_phoneError == null && _phoneController.text.length >= 8
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: Icon(Icons.check_circle, color: AppColors.success, size: 22),
                      )
                    : null),
            errorText: _phoneError,
            filled: true,
            fillColor: AppColors.background,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
          ),
          validator: AppValidators.phone,
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
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
        onPressed: _resendSeconds == 0 ? _handleResendOtp : null,
        child: Text(
          _resendSeconds > 0
              ? 'Отправить повторно через $_resendSeconds сек'
              : 'Отправить код повторно',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _resendSeconds > 0 ? AppColors.textSecondary : AppColors.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(bool isLoading) {
    final bool isDisabled = isLoading || _hasValidationErrors;

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: isDisabled ? null : (_isCodeSent ? _handleVerifyOtp : _handleRegister),
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
                _isCodeSent ? 'Подтвердить' : 'Зарегистрироваться',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  Widget _buildLoginLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Уже есть аккаунт? ',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: const Text(
            'Войти',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }
}