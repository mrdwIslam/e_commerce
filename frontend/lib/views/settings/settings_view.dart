import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../providers/auth_provider.dart';
import '../auth/login_view.dart';
import '../profile/edit_profile_view.dart';
import '../profile/change_password_view.dart';

class SettingsView extends ConsumerStatefulWidget {
  const SettingsView({super.key});

  @override
  ConsumerState<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends ConsumerState<SettingsView> {
  bool _notificationsEnabled = true;
  bool _darkMode = false;
  String _selectedLanguage = 'Русский';

  final List<String> _languages = ['Русский', 'Türkmençe', 'English'];

  Future<void> _handleDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.warning_amber, color: AppColors.error, size: 24),
            ),
            const SizedBox(width: 12),
            const Text('Удалить аккаунт?'),
          ],
        ),
        content: const Text(
          'Это действие необратимо. Все ваши данные, заказы и избранное будут удалены навсегда.',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Отмена',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      // Здесь можно добавить API вызов для удаления аккаунта
      HapticFeedback.heavyImpact();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.white),
              SizedBox(width: 12),
              Text('Функция скоро будет доступна'),
            ],
          ),
          backgroundColor: AppColors.info,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  void _showLanguageSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
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

            // Title
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.language,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Text(
                    'Выберите язык',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),

            Divider(color: AppColors.divider, height: 1),

            // Language Options
            ...(_languages.map((lang) => _buildLanguageOption(lang))),

            SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageOption(String language) {
    final isSelected = _selectedLanguage == language;
    String flag;
    
    switch (language) {
      case 'Русский':
        flag = '🇷🇺';
        break;
      case 'Türkmençe':
        flag = '🇹🇲';
        break;
      case 'English':
        flag = '🇺🇸';
        break;
      default:
        flag = '🌐';
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() => _selectedLanguage = language);
          HapticFeedback.lightImpact();
          Navigator.pop(context);
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Text(flag, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 12),
                  Text('Язык изменён на $language'),
                ],
              ),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.all(16),
              duration: const Duration(seconds: 2),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Text(flag, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  language,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected ? AppColors.primary : AppColors.textPrimary,
                  ),
                ),
              ),
              if (isSelected)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPrivacyPolicy() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
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
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Политика конфиденциальности',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.close, size: 20),
                      ),
                    ),
                  ],
                ),
              ),

              Divider(color: AppColors.divider, height: 1),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPolicySection(
                        '1. Сбор информации',
                        'Мы собираем информацию, которую вы предоставляете при регистрации, оформлении заказа и использовании нашего приложения. Это может включать имя, email, номер телефона и адрес доставки.',
                      ),
                      _buildPolicySection(
                        '2. Использование информации',
                        'Собранная информация используется для обработки заказов, улучшения сервиса, отправки уведомлений о статусе заказа и предоставления персонализированных рекомендаций.',
                      ),
                      _buildPolicySection(
                        '3. Защита данных',
                        'Мы применяем современные методы шифрования и защиты данных для обеспечения безопасности вашей персональной информации.',
                      ),
                      _buildPolicySection(
                        '4. Передача данных третьим лицам',
                        'Мы не продаем и не передаем вашу личную информацию третьим лицам, за исключением случаев, необходимых для выполнения заказа (например, службе доставки).',
                      ),
                      _buildPolicySection(
                        '5. Cookies и аналитика',
                        'Приложение может использовать аналитические инструменты для улучшения пользовательского опыта и анализа использования сервиса.',
                      ),
                      _buildPolicySection(
                        '6. Ваши права',
                        'Вы имеете право запросить доступ к своим данным, их исправление или удаление. Для этого свяжитесь с нашей службой поддержки.',
                      ),
                      _buildPolicySection(
                        '7. Изменения политики',
                        'Мы оставляем за собой право изменять данную политику. Актуальная версия всегда доступна в приложении.',
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Последнее обновление: Январь 2025',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPolicySection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  void _showAboutApp() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Logo
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.shopping_bag_outlined,
                  color: Colors.white,
                  size: 40,
                ),
              ),

              const SizedBox(height: 20),

              // App Name
              const Text(
                'NextStore',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                'Версия 1.0.0',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),

              const SizedBox(height: 20),

              // Divider
              Divider(color: AppColors.divider),

              const SizedBox(height: 20),

              // Info
              _buildAboutRow(Icons.code, 'Flutter & Django'),
              const SizedBox(height: 12),
              _buildAboutRow(Icons.location_on_outlined, 'Туркменистан'),
              const SizedBox(height: 12),
              _buildAboutRow(Icons.calendar_today_outlined, '2025'),

              const SizedBox(height: 24),

              // Copyright
              Text(
                '© 2025 NextStore. Все права защищены.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textHint,
                ),
              ),

              const SizedBox(height: 20),

              // Close Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Закрыть',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAboutRow(IconData icon, String text) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAuthenticated = ref.watch(isAuthenticatedProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Account Section
            if (isAuthenticated) ...[
              _buildSectionTitle('Аккаунт'),
              _buildSettingsGroup([
                _buildSettingsTile(
                  icon: Icons.person_outline,
                  title: 'Личные данные',
                  subtitle: 'Имя, Email, Телефон',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const EditProfileView()),
                    );
                  },
                ),
                _buildDivider(),
                _buildSettingsTile(
                  icon: Icons.lock_outline,
                  title: 'Сменить пароль',
                  subtitle: 'Обновить текущий пароль',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ChangePasswordView()),
                    );
                  },
                ),
              ]),
              const SizedBox(height: 28),
            ],

            // App Settings Section
            _buildSectionTitle('Приложение'),
            _buildSettingsGroup([
              _buildSwitchTile(
                icon: Icons.notifications_none_rounded,
                title: 'Уведомления',
                subtitle: 'Push-уведомления о заказах',
                value: _notificationsEnabled,
                onChanged: (v) {
                  setState(() => _notificationsEnabled = v);
                  HapticFeedback.lightImpact();
                },
              ),
              _buildDivider(),
              _buildSwitchTile(
                icon: Icons.dark_mode_outlined,
                title: 'Тёмная тема',
                subtitle: 'Скоро будет доступно',
                value: _darkMode,
                onChanged: (v) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Тёмная тема скоро будет доступна'),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      margin: const EdgeInsets.all(16),
                    ),
                  );
                },
                isDisabled: true,
              ),
              _buildDivider(),
              _buildSettingsTile(
                icon: Icons.language,
                title: 'Язык',
                subtitle: _selectedLanguage,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _selectedLanguage == 'Русский'
                          ? '🇷🇺'
                          : _selectedLanguage == 'Türkmençe'
                              ? '🇹🇲'
                              : '🇺🇸',
                      style: const TextStyle(fontSize: 20),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.chevron_right,
                      color: AppColors.textHint,
                      size: 22,
                    ),
                  ],
                ),
                onTap: _showLanguageSelector,
              ),
            ]),

            const SizedBox(height: 28),

            // Info Section
            _buildSectionTitle('Информация'),
            _buildSettingsGroup([
              _buildSettingsTile(
                icon: Icons.description_outlined,
                title: 'Политика конфиденциальности',
                onTap: _showPrivacyPolicy,
              ),
              _buildDivider(),
              _buildSettingsTile(
                icon: Icons.help_outline,
                title: 'Помощь и поддержка',
                onTap: () {
                  _showHelpDialog();
                },
              ),
              _buildDivider(),
              _buildSettingsTile(
                icon: Icons.info_outline,
                title: 'О приложении',
                subtitle: 'Версия 1.0.0',
                onTap: _showAboutApp,
              ),
            ]),

            // Delete Account
            if (isAuthenticated) ...[
              const SizedBox(height: 40),
              Center(
                child: TextButton.icon(
                  onPressed: _handleDeleteAccount,
                  icon: Icon(Icons.delete_forever_outlined, color: AppColors.error),
                  label: Text(
                    'Удалить аккаунт',
                    style: TextStyle(
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 40),
          ],
        ),
      ),
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
        'Настройки',
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
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSettingsGroup(List<Widget> children) {
    return Container(
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
      child: Column(children: children),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      indent: 72,
      endIndent: 20,
      color: AppColors.divider,
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.textSecondary, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              trailing ??
                  Icon(
                    Icons.chevron_right,
                    color: AppColors.textHint,
                    size: 22,
                  ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    required Function(bool) onChanged,
    bool isDisabled = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: isDisabled ? AppColors.textHint : AppColors.textSecondary,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDisabled ? AppColors.textHint : AppColors.textPrimary,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textHint,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: isDisabled ? null : onChanged,
            activeColor: AppColors.primary,
            activeTrackColor: AppColors.primary.withOpacity(0.3),
            inactiveThumbColor: AppColors.textHint,
            inactiveTrackColor: AppColors.divider,
          ),
        ],
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.support_agent, color: AppColors.primary, size: 24),
            ),
            const SizedBox(width: 12),
            const Text('Поддержка'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildContactRow(Icons.phone, '+993 12 345678'),
            const SizedBox(height: 16),
            _buildContactRow(Icons.email, 'support@nextstore.tm'),
            const SizedBox(height: 16),
            _buildContactRow(Icons.access_time, 'Пн-Пт: 9:00 - 18:00'),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  Widget _buildContactRow(IconData icon, String text) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: AppColors.primary),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ],
    );
  }
}