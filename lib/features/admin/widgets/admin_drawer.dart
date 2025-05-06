import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../core/theme/theme.dart';
import '../../../core/utils/haptic_utils.dart';

/// Admin navigation drawer
class AdminDrawer extends StatelessWidget {
  /// Constructor
  const AdminDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final currentRoute = GoRouterState.of(context).matchedLocation;
    
    return Drawer(
      child: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildNavItem(
                  context: context,
                  icon: Icons.dashboard,
                  title: 'admin_dashboard'.tr(),
                  route: '/admin',
                  isSelected: currentRoute == '/admin',
                ),
                _buildNavItem(
                  context: context,
                  icon: Icons.people,
                  title: 'admin_users'.tr(),
                  route: '/admin/users',
                  isSelected: currentRoute == '/admin/users',
                ),
                /* TODO: Implement these screens
                _buildNavItem(
                  context: context,
                  icon: Icons.medical_services,
                  title: 'admin_consultations'.tr(),
                  route: '/admin/consultations',
                  isSelected: currentRoute == '/admin/consultations',
                ),
                _buildNavItem(
                  context: context,
                  icon: Icons.payment,
                  title: 'admin_payments'.tr(),
                  route: '/admin/payments',
                  isSelected: currentRoute == '/admin/payments',
                ),
                */
                const Divider(),
                _buildNavItem(
                  context: context,
                  icon: Icons.logout,
                  title: 'logout'.tr(),
                  onTap: () => _handleLogout(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return DrawerHeader(
      decoration: const BoxDecoration(
        color: AppColors.primary,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'admin_panel'.tr(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'admin_welcome'.tr(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    String? route,
    bool isSelected = false,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? AppColors.primary : null,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? AppColors.primary : null,
          fontWeight: isSelected ? FontWeight.bold : null,
        ),
      ),
      selected: isSelected,
      onTap: () {
        HapticUtils.selection();
        if (onTap != null) {
          onTap();
        } else if (route != null) {
          context.go(route);
        }
      },
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    HapticUtils.lightTap();
    // TODO: Replace with your auth logout logic
    if (context.mounted) {
      context.go('/welcome');
    }
  }
} 