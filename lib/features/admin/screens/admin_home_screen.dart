import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/routes.dart';
import '../../../core/theme/theme.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:urocenter/core/utils/logger.dart';
// Import any other necessary utils or models if they were used ONLY here
import '../../../core/utils/haptic_utils.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/widgets/shimmer_loading.dart';
import '../../../core/widgets/animated_gradient_card_background.dart';
import '../../../core/theme/app_colors.dart'; // Ensure AppColors is imported

// --- Chat Status Enum (If needed ONLY here, otherwise import) ---
// enum ChatStatus { active, resolved } 

// --- Simple Chat Session Model (If needed ONLY here, otherwise import) ---
// class ChatSession { ... }

// --- Import AdminDashboard to access its state ---
import 'admin_dashboard.dart'; 
// --- END Import ---

final adminDataProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  try {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');
    
    // Fetch admin information
    final adminDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();
    
    if (!adminDoc.exists) throw Exception('Admin user not found');
    
    // Fetch counts
    final userCountSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('onboardingCompleted', isEqualTo: true)
        .count()
        .get();
    
    final activeChatsSnapshot = await FirebaseFirestore.instance
        .collection('chats')
        .where('status', isEqualTo: 'active')
        .count()
        .get();
    
    final paidUsersSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('paymentCompleted', isEqualTo: true)
        .count()
        .get();
    
    // Calculate revenue (assuming 20000 per paid user)
    final revenue = (paidUsersSnapshot.count ?? 0) * 20000.0;
    
    return {
      'adminName': adminDoc.data()?['fullName'] ?? 'Admin',
      'adminTitle': adminDoc.data()?['title'] ?? 'System Administrator',
      'userCount': userCountSnapshot.count ?? 0,
      'activeChats': activeChatsSnapshot.count ?? 0,
      'revenue': revenue,
    };
  } catch (e) {
    AppLogger.e('Error fetching admin data: $e');
    throw e;
  }
});

final recentActivitiesProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return FirebaseFirestore.instance
      .collection('activities')
      .orderBy('timestamp', descending: true)
      .limit(5)
      .snapshots()
      .map((snapshot) {
        return snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'title': data['title'] ?? 'Activity',
            'subtitle': data['description'] ?? '',
            'timestamp': (data['timestamp'] as Timestamp).toDate(),
            'type': data['type'] ?? 'system',
          };
        }).toList();
      });
});

final activeChatsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return FirebaseFirestore.instance
      .collection('chats')
      .where('status', isEqualTo: 'active')
      .orderBy('lastMessageTime', descending: true)
      .limit(3)
      .snapshots()
      .asyncMap((snapshot) async {
        final chatsList = <Map<String, dynamic>>[];
        
        for (final doc in snapshot.docs) {
          final data = doc.data();
          final participants = List<String>.from(data['participants'] ?? []);
          // Assuming first non-admin participant is the patient
          final adminId = FirebaseAuth.instance.currentUser?.uid;
          final patientId = participants.firstWhere(
            (id) => id != adminId, 
            orElse: () => ''
          );
          
          if (patientId.isEmpty) continue;
          
          // Fetch patient information
          try {
            final patientDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(patientId)
                .get();
                
            if (!patientDoc.exists) continue;
            
            final patientData = patientDoc.data() ?? {};
            
            chatsList.add({
              'id': doc.id,
              'userName': patientData['fullName'] ?? 'Unknown User',
              'userInitial': patientData['fullName'] != null && 
                             patientData['fullName'].toString().isNotEmpty 
                  ? patientData['fullName'].toString()[0] 
                  : '?',
              'lastMessage': data['lastMessageContent'] ?? 'No message',
              'lastMessageTime': (data['lastMessageTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
              'unreadCount': data['unreadCount'] ?? 0,
            });
          } catch (e) {
            AppLogger.e('Error fetching patient data for chat ${doc.id}: $e');
          }
        }
        
        return chatsList;
      });
});

/// Home tab of the admin dashboard
class AdminHomeScreen extends ConsumerStatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  ConsumerState<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends ConsumerState<AdminHomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _staggerController;
  
  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _staggerController.forward();
  }
  
  @override
  void dispose() {
    _staggerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final adminDataAsync = ref.watch(adminDataProvider);
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
        title: Text(
          'Admin Dashboard'.tr(),
          style: Theme.of(context).appBarTheme.titleTextStyle,
        ),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: Theme.of(context).appBarTheme.elevation,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: Icon(Icons.notifications_outlined, color: Theme.of(context).appBarTheme.actionsIconTheme?.color),
            tooltip: 'profile.notifications'.tr(),
            onPressed: () {
              HapticUtils.lightTap();
              context.pushNamed(RouteNames.notifications);
            },
          ),
          IconButton(
            icon: Icon(Icons.settings_outlined, color: Theme.of(context).appBarTheme.actionsIconTheme?.color),
            tooltip: 'settings.title'.tr(),
            onPressed: () {
              HapticUtils.lightTap();
              context.pushNamed(RouteNames.settings);
            },
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: _staggerController,
        builder: (context, child) {
          return RefreshIndicator(
            onRefresh: () async {
              // Refresh data (Remove invalidated providers)
              ref.invalidate(adminDataProvider);
              
              _staggerController.reset();
              await Future.delayed(const Duration(milliseconds: 300));
              _staggerController.forward();
            },
            child: adminDataAsync.when(
              data: (data) => AnimationLimiter(
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: AnimationConfiguration.toStaggeredList(
                        duration: const Duration(milliseconds: 375),
                        childAnimationBuilder: (widget) => SlideAnimation(
                          verticalOffset: 50.0,
                          child: FadeInAnimation(
                            child: widget,
                          ),
                        ),
                        children: [
                          _WelcomeAdminCard(
                            adminName: data['adminName'],
                            adminTitle: data['adminTitle'],
                            userCount: data['userCount'],
                            activeChats: data['activeChats'],
                            revenue: data['revenue'],
                          ),
      const SizedBox(height: 24),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
                                'Quick Actions'.tr(),
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
                              const SizedBox(height: 16),
                              Column(
                                children: _buildQuickActionCards(),
          ),
        ],
      ),
                          const SizedBox(height: 40), // Keep bottom padding
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              error: (error, stack) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _buildErrorCard(error.toString()),
                ),
              ),
              loading: () => const Center(
                child: CircularProgressIndicator(),
                  ),
                ),
              );
          },
        ),
    );
  }
  
  Widget _buildErrorCard(String errorMessage) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.error_outline, color: theme.colorScheme.error),
                SizedBox(width: 8),
            Text(
                  'Error'.tr(),
                  style: TextStyle(
                fontWeight: FontWeight.bold,
                    color: theme.colorScheme.error,
                  ),
              ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              errorMessage,
              style: TextStyle(fontSize: 14, color: theme.colorScheme.onErrorContainer),
            ),
            SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                ref.invalidate(adminDataProvider);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.error, 
                foregroundColor: theme.colorScheme.onError, 
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text('Retry'.tr()),
            ),
          ],
        ),
      ),
    );
  }
  
  List<Widget> _buildQuickActionCards() {
    final actions = [
      {
        'title': 'Manage Users'.tr(),
        'icon': Icons.people_outlined,
        'color': Colors.blue,
        'onTap': () {
          final adminDashboardState = context.findAncestorStateOfType<AdminDashboardState>();
          adminDashboardState?.setTabIndex(2);
        },
      },
      {
        'title': 'consultations.title'.tr(),
        'icon': Icons.message_outlined,
        'color': Colors.green,
        'onTap': () => context.go('/admin/consultations'),
      },
      {
        'title': 'calls.title'.tr(),
        'icon': Icons.call_outlined,
        'color': Colors.orange,
        'onTap': () => context.go('/admin/calls'),
      },
      {
        'title': 'analytics.title'.tr(),
        'icon': Icons.analytics_outlined,
        'color': Colors.purple,
        'onTap': () => context.go('/admin/analytics'),
      },
    ];
    
    return List.generate(
      actions.length,
      (index) => AnimationConfiguration.staggeredList(
        position: index,
        duration: const Duration(milliseconds: 375),
        child: SlideAnimation(
          verticalOffset: 50.0,
          child: FadeInAnimation(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: _AdminActionCard(
                title: actions[index]['title'] as String,
                icon: actions[index]['icon'] as IconData,
                iconColor: actions[index]['color'] as Color,
                onTap: actions[index]['onTap'] as Function(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminActionCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  const _AdminActionCard({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });

  @override
  State<_AdminActionCard> createState() => _AdminActionCardState();
}

class _AdminActionCardState extends State<_AdminActionCard> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _iconScaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutQuint,
      ),
    );
    
    _iconScaleAnimation = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutQuint,
                  ),
    );
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    _animationController.forward();
         HapticUtils.lightTap();
  }

  void _handleTapUp(TapUpDetails details) {
    _animationController.reverse().then((_) {
    });
    widget.onTap();
  }
  
  void _handleTapCancel() {
    _animationController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        );
      },
      child: Container(
        margin: EdgeInsets.zero,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(isDark ? 51 : 26),
              blurRadius: 8,
              spreadRadius: 0.5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTapDown: _handleTapDown,
            onTapUp: _handleTapUp,
            onTapCancel: _handleTapCancel,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                children: [
                  AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, iconChild) {
                      return Transform.scale(
                        scale: _iconScaleAnimation.value,
                        child: iconChild,
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: widget.iconColor.withAlpha(26),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        widget.icon,
                        color: widget.iconColor,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                    Icons.arrow_forward_ios,
                    color: theme.colorScheme.onSurface.withAlpha(77),
                    size: 14,
              ),
            ],
          ),
            ),
          ),
        ),
                    ),
    );
  }
}

class _WelcomeAdminCard extends StatefulWidget {
  final String adminName;
  final String adminTitle;
  final int userCount;
  final int activeChats;
  final double revenue;

  const _WelcomeAdminCard({
    required this.adminName,
    required this.adminTitle,
    required this.userCount,
    required this.activeChats,
    required this.revenue,
  });

  @override
  State<_WelcomeAdminCard> createState() => _WelcomeAdminCardState();
    }
    
class _WelcomeAdminCardState extends State<_WelcomeAdminCard> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currencyFormatter = NumberFormat.compactCurrency(
      locale: context.locale.toString(), // Use context locale for currency
      symbol: 'IQD ', 
      decimalDigits: 0,
    );

    return AnimatedGradientCardBackground(
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(45), // Slightly more opaque icon bg
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.admin_panel_settings,
                    color: Colors.white, // Icon remains white
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Welcome back, Dr. Ali Kamal",
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white, 
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.adminTitle, 
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withOpacity(0.9),
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Column(
              children: [
                _buildSummaryItemRow('admin.users'.tr(), widget.userCount.toString(), Icons.group_outlined, theme),
                _buildDivider(),
                _buildSummaryItemRow('admin.active_chats'.tr(), widget.activeChats.toString(), Icons.chat_bubble_outline, theme),
                _buildDivider(),
                _buildSummaryItemRow('admin.revenue'.tr(), currencyFormatter.format(widget.revenue), Icons.attach_money_outlined, theme),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItemRow(String title, String value, IconData icon, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0), // Add some vertical padding
      child: Row(
        children: [
          Icon(
            icon, 
            color: Colors.white, // Summary Icon: fully white
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white.withOpacity(0.9),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              color: Colors.white, // Value text: remains white and bold
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(color: Colors.white.withOpacity(0.25), height: 20, thickness: 0.8, indent: 0, endIndent: 0);
  }
} 
