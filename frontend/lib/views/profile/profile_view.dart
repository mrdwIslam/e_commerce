import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/constants.dart';
import '../../providers/auth_provider.dart';
import '../../providers/shop_provider.dart';
import '../../services/api_service.dart';
import '../auth/login_view.dart';
import '../orders/orders_view.dart';
import '../favorites/favorites_view.dart';
import 'edit_profile_view.dart';
import 'change_password_view.dart';

class ProfileView extends ConsumerStatefulWidget {
  const ProfileView({super.key});

  @override
  ConsumerState<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends ConsumerState<ProfileView> {
  @override
  void initState() {
    super.initState();
    // Обновляем профиль при открытии
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authProvider.notifier).refreshProfile();
    });
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Выйти из аккаунта?'),
        content: const Text('Вы уверены, что хотите выйти?'),
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
            child: const Text('Выйти'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(authProvider.notifier).logout();
      
      // Очищаем данные
      ref.read(favoritesProvider.notifier).clear();
      ref.read(ordersProvider.notifier).clear();

      if (mounted) {
        HapticFeedback.mediumImpact();
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginView()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final ordersCount = ref.watch(ordersCountProvider);
    final favoritesCount = ref.watch(favoritesCountProvider);
    final user = authState.user;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // App Bar
          _buildAppBar(authState),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Profile Card
                  _buildProfileCard(authState),

                  const SizedBox(height: 24),

                  // Stats Row
                  _buildStatsRow(ordersCount, favoritesCount),

                  const SizedBox(height: 24),

                  // Menu Items
                  _buildMenuSection(),

                  const SizedBox(height: 24),

                  // App Info
                  _buildAppInfo(),

                  const SizedBox(height: 24),

                  // Logout Button
                  _buildLogoutButton(),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(AuthState authState) {
    return SliverAppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      pinned: true,
      expandedHeight: 60,
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
        'Профиль',
        style: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      centerTitle: true,
      actions: [
        GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const EditProfileView()),
            );
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
              Icons.edit_outlined,
              size: 20,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileCard(AuthState authState) {
    final user = authState.user;
    final apiService = ApiService();
    final avatarUrl = user?.avatar != null
        ? apiService.getImageUrl(user!.avatar)
        : null;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Avatar
          Stack(
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary,
                      AppColors.primaryDark,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: avatarUrl != null
                    ? ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: avatarUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => _buildAvatarPlaceholder(user),
                          errorWidget: (_, __, ___) =>
                              _buildAvatarPlaceholder(user),
                        ),
                      )
                    : _buildAvatarPlaceholder(user),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Name
          Text(
            authState.displayName,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),

          const SizedBox(height: 4),

          // Email
          Text(
            authState.email,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),

          if (authState.phone.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              authState.phone,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAvatarPlaceholder(user) {
    return Center(
      child: Text(
        user?.initials ?? '?',
        style: const TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildStatsRow(int ordersCount, int favoritesCount) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.shopping_bag_outlined,
            label: 'Заказы',
            value: '$ordersCount',
            color: AppColors.primary,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const OrdersView()),
              );
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            icon: Icons.favorite_outline,
            label: 'Избранное',
            value: '$favoritesCount',
            color: AppColors.favorite,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const FavoritesView()),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuSection() {
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
      child: Column(
        children: [
          _buildMenuItem(
            icon: Icons.person_outline,
            title: 'Редактировать профиль',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const EditProfileView()),
              );
            },
          ),
          _buildDivider(),
          _buildMenuItem(
            icon: Icons.lock_outline,
            title: 'Сменить пароль',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ChangePasswordView()),
              );
            },
          ),
          _buildDivider(),
          _buildMenuItem(
            icon: Icons.receipt_long_outlined,
            title: 'Мои заказы',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const OrdersView()),
              );
            },
          ),
          _buildDivider(),
          _buildMenuItem(
            icon: Icons.favorite_outline,
            title: 'Избранное',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const FavoritesView()),
              );
            },
          ),
          _buildDivider(),
          _buildMenuItem(
            icon: Icons.notifications_outlined,
            title: 'Уведомления',
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Скоро',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Скоро будет доступно'),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  margin: const EdgeInsets.all(16),
                ),
              );
            },
          ),
          _buildDivider(),
          _buildMenuItem(
            icon: Icons.help_outline,
            title: 'Помощь',
            onTap: () {
              _showHelpDialog();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.textSecondary, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (trailing != null)
                trailing
              else
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

  Widget _buildDivider() {
    return Divider(
      height: 1,
      indent: 74,
      endIndent: 20,
      color: AppColors.divider,
    );
  }

  Widget _buildAppInfo() {
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
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDark],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.shopping_bag_outlined,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'NextStore',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Версия 1.0.0',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Разработано с ❤️ для Туркменистана',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton.icon(
        onPressed: _handleLogout,
        icon: const Icon(Icons.logout),
        label: const Text('Выйти из аккаунта'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.error,
          side: BorderSide(color: AppColors.error),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Помощь'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHelpItem(Icons.phone, '+993 12 345678'),
            const SizedBox(height: 12),
            _buildHelpItem(Icons.email, 'support@nextstore.tm'),
            const SizedBox(height: 12),
            _buildHelpItem(Icons.location_on, 'Ашхабад, Туркменистан'),
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

  Widget _buildHelpItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 12),
        Text(
          text,
          style: const TextStyle(fontSize: 14),
        ),
      ],
    );
  }
}