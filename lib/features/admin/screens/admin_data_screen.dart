import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:urocenter/core/utils/logger.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import '../../../app/routes.dart';
import '../../../core/theme/theme.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/haptic_utils.dart';
import '../../../core/widgets/shimmer_loading.dart';

// --- Moved Models/Enums specific to this screen ---

enum TimePeriod { week, month, all }

class UserInfo {
  final String id;
  final String name;
  final DateTime joinDate;
  // Add other relevant fields like status if needed

  UserInfo({required this.id, required this.name, required this.joinDate});
}

class StatsData {
  final double revenue;
  final int newUsers;
  final int consultations;
  // Add previous period data for trends if desired
  final double prevRevenue;
  final int prevNewUsers;
  final int prevConsultations;

  StatsData({
    required this.revenue,
    required this.newUsers,
    required this.consultations,
    this.prevRevenue = 0,
    this.prevNewUsers = 0,
    this.prevConsultations = 0,
  });
}

enum Trend { up, down, none }

// --- End Moved Models/Enums ---

final statsDataProvider = FutureProvider.family<StatsData, TimePeriod>((ref, period) async {
  try {
    DateTime? startDate;
    DateTime? prevStartDate;
    
    final now = DateTime.now();
    
    switch (period) {
      case TimePeriod.week:
        startDate = now.subtract(const Duration(days: 7));
        prevStartDate = startDate.subtract(const Duration(days: 7));
        break;
      case TimePeriod.month:
        startDate = now.subtract(const Duration(days: 30));
        prevStartDate = startDate.subtract(const Duration(days: 30));
        break;
      case TimePeriod.all:
        startDate = null;
        prevStartDate = null;
        break;
    }
    
    // Current period queries
    Query usersQuery = FirebaseFirestore.instance.collection('users');
    Query paidUsersQuery = FirebaseFirestore.instance
        .collection('users')
        .where('paymentCompleted', isEqualTo: true);
    Query consultationsQuery = FirebaseFirestore.instance.collection('chats');
    
    // Apply date filters for current period
    if (startDate != null) {
      usersQuery = usersQuery.where('profileCreatedAt', isGreaterThanOrEqualTo: startDate);
      paidUsersQuery = paidUsersQuery.where('profileCreatedAt', isGreaterThanOrEqualTo: startDate);
      consultationsQuery = consultationsQuery.where('createdAt', isGreaterThanOrEqualTo: startDate);
    }
    
    // Get current period data
    final userCountSnapshot = await usersQuery.count().get();
    final paidUsersSnapshot = await paidUsersQuery.count().get();
    final consultationsSnapshot = await consultationsQuery.count().get();
    
    final newUsers = userCountSnapshot.count ?? 0;
    final paidUsers = paidUsersSnapshot.count ?? 0;
    final consultations = consultationsSnapshot.count ?? 0;
    
    // Revenue calculation (assuming 20000 per paid user)
    final revenue = paidUsers * 20000.0;
    
    // Previous period data for trend calculation
    int prevNewUsers = 0;
    int prevPaidUsers = 0;
    int prevConsultations = 0;
    double prevRevenue = 0;
    
    if (prevStartDate != null && period != TimePeriod.all) {
      // Previous period queries
      Query prevUsersQuery = FirebaseFirestore.instance
          .collection('users')
          .where('profileCreatedAt', isGreaterThanOrEqualTo: prevStartDate)
          .where('profileCreatedAt', isLessThan: startDate);
          
      Query prevPaidUsersQuery = FirebaseFirestore.instance
          .collection('users')
          .where('paymentCompleted', isEqualTo: true)
          .where('profileCreatedAt', isGreaterThanOrEqualTo: prevStartDate)
          .where('profileCreatedAt', isLessThan: startDate);
          
      Query prevConsultationsQuery = FirebaseFirestore.instance
          .collection('chats')
          .where('createdAt', isGreaterThanOrEqualTo: prevStartDate)
          .where('createdAt', isLessThan: startDate);
      
      // Get previous period data
      final prevUserCountSnapshot = await prevUsersQuery.count().get();
      final prevPaidUsersSnapshot = await prevPaidUsersQuery.count().get();
      final prevConsultationsSnapshot = await prevConsultationsQuery.count().get();
      
      prevNewUsers = prevUserCountSnapshot.count ?? 0;
      prevPaidUsers = prevPaidUsersSnapshot.count ?? 0;
      prevConsultations = prevConsultationsSnapshot.count ?? 0;
      
      // Previous period revenue
      prevRevenue = prevPaidUsers * 20000.0;
    }
    
    return StatsData(
      revenue: revenue,
      newUsers: newUsers,
      consultations: consultations,
      prevRevenue: prevRevenue,
      prevNewUsers: prevNewUsers,
      prevConsultations: prevConsultations,
    );
  } catch (e) {
    AppLogger.e('Error fetching stats data: $e');
    throw e;
  }
});

final usersListProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return FirebaseFirestore.instance
      .collection('users')
      .orderBy('profileCreatedAt', descending: true)
      .snapshots()
      .map((snapshot) {
        return snapshot.docs.map((doc) {
          final data = doc.data();
          final timestamp = data['profileCreatedAt'] as Timestamp?;
          
          return {
            'id': doc.id,
            'name': data['fullName'] as String? ?? 'Unknown User',
            'email': data['email'] as String? ?? '',
            'phone': data['phone'] as String? ?? '',
            'joinDate': timestamp?.toDate() ?? DateTime.now(),
            'paymentCompleted': data['paymentCompleted'] as bool? ?? false,
            'onboardingCompleted': data['onboardingCompleted'] as bool? ?? false,
          };
        }).toList();
      });
});

/// Data & Analytics tab of the admin dashboard
class AdminDataScreen extends ConsumerStatefulWidget {
  const AdminDataScreen({super.key});

  @override
  ConsumerState<AdminDataScreen> createState() => _AdminDataScreenState();
}

class _AdminDataScreenState extends ConsumerState<AdminDataScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  String _userSearchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  TimePeriod _selectedTimePeriod = TimePeriod.week;
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey = GlobalKey<RefreshIndicatorState>();
  
  // Animations
  late AnimationController _statsAnimationController;
  late Animation<double> _statsAnimation;

  // Add a list to manage ToggleButtons selection state
  late List<bool> _timePeriodSelection;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _timePeriodSelection = TimePeriod.values.map((period) => period == _selectedTimePeriod).toList();
    
    // Setup animations
    _statsAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _statsAnimation = CurvedAnimation(
      parent: _statsAnimationController,
      curve: Curves.easeOutCubic,
    );
    
    _statsAnimationController.forward();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _statsAnimationController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Data & Analytics'.tr(),
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
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Theme.of(context).colorScheme.primary,
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: Theme.of(context).unselectedWidgetColor,
          tabs: [
            Tab(text: 'Analytics'.tr()),
            Tab(text: 'User List'.tr()),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAnalyticsView(),
          _buildUserListView(),
        ],
      ),
    );
  }

  Widget _buildAnalyticsView() {
    final statsDataAsync = ref.watch(statsDataProvider(_selectedTimePeriod));
    final theme = Theme.of(context);
    final currencyFormatter = NumberFormat.compactCurrency(locale: 'en_US', symbol: 'IQD ', decimalDigits: 0);
    final numberFormatter = NumberFormat.compact();

    return Column( // Root is now a Column
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16.0, left: 16.0, right: 16.0), // Add padding around selector
          child: _buildTimePeriodSelector(), // Selector is the first child
        ),
        // const SizedBox(height: 16), // Spacing after selector, if needed (padding on ListView might be enough)
        Expanded( // The rest of the content is Expanded
          child: RefreshIndicator(
            key: _refreshIndicatorKey,
            color: theme.colorScheme.primary,
            backgroundColor: theme.colorScheme.surface,
            onRefresh: () async {
              ref.invalidate(statsDataProvider(_selectedTimePeriod));
            },
            child: statsDataAsync.when(
              data: (statsData) => AnimationLimiter(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 16.0), // Adjusted padding for content
                  children: AnimationConfiguration.toStaggeredList(
                    duration: const Duration(milliseconds: 375),
                    childAnimationBuilder: (widget) => SlideAnimation(
                      verticalOffset: 50.0,
                      child: FadeInAnimation(
                        child: widget,
                      ),
                    ),
                    children: [
                      // _buildTimePeriodSelector(), // REMOVED FROM HERE
                      // const SizedBox(height: 20), // Original spacing, can be adjusted
                      _buildStatCard(
                        'Revenue'.tr(),
                        currencyFormatter.format(statsData.revenue),
                        Icons.monetization_on_outlined,
                        AppColors.success,
                        theme: theme,
                      ),
                       const SizedBox(height: 12),
                       _buildStatCard(
                        'New Users'.tr(),
                        numberFormatter.format(statsData.newUsers),
                        Icons.person_add_alt_outlined,
                        AppColors.info,
                        theme: theme,
                      ),
                       const SizedBox(height: 12),
                       _buildStatCard(
                        'Consultations'.tr(),
                        numberFormatter.format(statsData.consultations),
                        Icons.healing_outlined,
                        AppColors.warning,
                        theme: theme,
                      ),
                       const SizedBox(height: 32),
                       _buildComingSoonChart(),
                    ],
                  ),
                ),
              ),
              error: (error, stack) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _buildErrorCard(error.toString(), theme),
                ),
              ),
              loading: () => Center(child: CircularProgressIndicator(color: theme.colorScheme.primary)),
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildComingSoonChart() {
    final theme = Theme.of(context);
    final cardTheme = theme.cardTheme;
    final isDark = theme.brightness == Brightness.dark;

    // Determine colors and shapes from CardTheme, with fallbacks
    final cardColor = cardTheme.color ?? theme.colorScheme.surface;
    final cardShape = cardTheme.shape as RoundedRectangleBorder? ?? 
                      RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
    final cardBorderRadius = cardShape.borderRadius as BorderRadius? ?? BorderRadius.circular(12);
    final cardShadowColor = cardTheme.shadowColor ?? theme.shadowColor;
    final cardElevation = cardTheme.elevation ?? 2.0;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: cardBorderRadius,
        boxShadow: [
          BoxShadow(
            color: cardShadowColor.withAlpha(isDark ? 51 : 26),
            blurRadius: cardElevation * 4,
            spreadRadius: cardElevation / 4,
            offset: Offset(0, cardElevation),
          ),
        ],
        border: cardShape.side != BorderSide.none 
                ? Border.fromBorderSide(cardShape.side) 
                : Border.all(
                    color: theme.colorScheme.outline.withAlpha(isDark ? 77 : 51),
                    width: 0.5,
                  ),
      ),
      clipBehavior: cardTheme.clipBehavior ?? Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.insert_chart_outlined,
                color: theme.colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Performance Charts'.tr(),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            height: 160,
            width: double.infinity,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withAlpha(51),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.outline.withAlpha(77),
                width: 1,
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.auto_graph,
                    size: 50,
                    color: theme.colorScheme.onSurfaceVariant.withAlpha(153),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Detailed analytics coming soon'.tr(),
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildErrorCard(String errorMessage, ThemeData theme) {
    return Card(
      color: theme.colorScheme.errorContainer.withAlpha(150),
      margin: const EdgeInsets.symmetric(vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.error_outline, color: theme.colorScheme.error),
                const SizedBox(width: 8),
                Text(
                  'Error loading data'.tr(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage,
              style: TextStyle(fontSize: 14, color: theme.colorScheme.onErrorContainer),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh, size: 18),
              label: Text('Retry'.tr()),
              onPressed: () {
                ref.invalidate(statsDataProvider(_selectedTimePeriod));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatCard(
    String title,
    String value, 
    IconData icon,
    Color iconAccentColor, // Renamed for clarity, this is for the icon and its small bg
    {required ThemeData theme}
  ) {
    final isDark = theme.brightness == Brightness.dark;
    final cardTheme = theme.cardTheme;

    // Determine colors and shapes from CardTheme, with fallbacks
    final cardColor = cardTheme.color ?? theme.colorScheme.surface;
    final cardShape = cardTheme.shape as RoundedRectangleBorder? ?? 
                      RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
    final cardBorderRadius = cardShape.borderRadius as BorderRadius? ?? BorderRadius.circular(12);
    final cardShadowColor = cardTheme.shadowColor ?? theme.shadowColor;
    final cardElevation = cardTheme.elevation ?? 2.0;
    
    final titleTextStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant, 
      fontSize: 13,
    );
    final valueTextStyle = theme.textTheme.titleMedium?.copyWith(
       fontWeight: FontWeight.w600,
       color: theme.colorScheme.onSurface,
       letterSpacing: 0.2,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 0), 
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: cardColor, // Use color from CardTheme
        borderRadius: cardBorderRadius, // Use borderRadius from CardTheme
        boxShadow: [ // Use shadow from CardTheme, adjusted as in _buildComingSoonChart
          BoxShadow(
            color: cardShadowColor.withAlpha(isDark ? 51 : 26),
            blurRadius: cardElevation * 4,
            spreadRadius: cardElevation / 4,
            offset: Offset(0, cardElevation),
          ),
        ],
        // Use border from CardTheme if it exists and is not none
        border: cardShape.side != BorderSide.none 
                ? Border.fromBorderSide(cardShape.side) 
                : null, // No border if cardTheme doesn't specify one or if side is none
      ),
      clipBehavior: cardTheme.clipBehavior ?? Clip.hardEdge, 
      child: Row( 
        children: [
          Container( 
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconAccentColor.withAlpha(isDark ? 77 : 38), // Keep icon accent color logic
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: iconAccentColor, // Keep icon accent color logic
              size: 24,
            ),
          ),
          const SizedBox(width: 16), 
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: titleTextStyle),
                const SizedBox(height: 3),
                Text(value, style: valueTextStyle),
              ],
            ),
          ),
          Icon( 
            Icons.arrow_forward_ios,
            color: theme.colorScheme.onSurface.withAlpha(77),
            size: 14,
          ),
        ],
      ),
    );
  }

   Widget _buildTimePeriodSelector() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      // The outer container is already transparent and has no shadow from previous step
      // It might not even be needed if ToggleButtons is centered directly
      // For now, keeping it to allow for potential future padding/margin adjustments easily
      padding: const EdgeInsets.symmetric(vertical: 8.0), // Overall padding for the selector area
      child: LayoutBuilder( // Use LayoutBuilder to make ToggleButtons take appropriate width
        builder: (context, constraints) {
          return Center(
            child: ToggleButtons(
              isSelected: _timePeriodSelection,
              onPressed: (int index) {
                if (_timePeriodSelection[index]) return; // Do nothing if already selected

                HapticUtils.selection();
                setState(() {
                  _selectedTimePeriod = TimePeriod.values[index];
                  for (int i = 0; i < _timePeriodSelection.length; i++) {
                    _timePeriodSelection[i] = i == index;
                  }
                });
                // Reset animation for the new time period
                _statsAnimationController.reset();
                _statsAnimationController.forward();
              },
              color: theme.colorScheme.onSurfaceVariant.withAlpha(200), // Unselected text/icon color
              selectedColor: theme.colorScheme.onPrimary,       // Selected text/icon color
              fillColor: theme.colorScheme.primary,             // Background of selected button
              splashColor: theme.colorScheme.primaryContainer.withAlpha(100),
              highlightColor: theme.colorScheme.primaryContainer.withAlpha(50),
              borderColor: theme.colorScheme.outline.withAlpha(77),      // Border for unselected
              selectedBorderColor: theme.colorScheme.primary,    // Border for selected
              borderRadius: BorderRadius.circular(20.0),
              borderWidth: 1.5,
              constraints: BoxConstraints.expand(
                height: 44, // Fixed height for buttons
                // Calculate width for each button, subtracting a small buffer for padding/borders
                width: (constraints.maxWidth - 12.0) / TimePeriod.values.length, 
              ),
              children: TimePeriod.values.map((period) {
                String label;
                switch (period) {
                  case TimePeriod.week:
                    label = 'Week'.tr();
                    break;
                  case TimePeriod.month:
                    label = 'Month'.tr();
                    break;
                  case TimePeriod.all:
                    label = 'All Time'.tr();
                    break;
                }
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 0), // Keep horizontal padding minimal
                  child: Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13, // <<< REDUCED FONT SIZE from 14 to 13
                      // Color is handled by ToggleButtons' color/selectedColor
                    ),
                    textAlign: TextAlign.center, // Ensure text is centered if padding makes space
                  ),
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildUserListView() {
    final usersListAsync = ref.watch(usersListProvider);
    final theme = Theme.of(context);

    return Column(
      children: [
        AnimationConfiguration.synchronized(
          duration: const Duration(milliseconds: 500),
          child: SlideAnimation(
            verticalOffset: 50.0,
            child: FadeInAnimation(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0), // Standard padding
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(color: theme.colorScheme.onSurface), // Theme color for text
                  decoration: InputDecoration(
                    // InputDecoration should pick up from theme mostly
                    hintText: 'Search users...'.tr(),
                    // hintStyle will be from theme
                    prefixIcon: Icon(Icons.search, color: theme.colorScheme.onSurfaceVariant), // Theme color
                    // fillColor will be from theme (AppColors.inputBackground/Dark)
                    // border, enabledBorder, focusedBorder will be from theme
                    suffixIcon: _userSearchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, color: theme.colorScheme.onSurfaceVariant),
                            onPressed: () {
                              HapticUtils.lightTap();
                              _searchController.clear();
                              setState(() => _userSearchQuery = '');
                            },
                          )
                        : null,
                  ),
                  onChanged: (value) => setState(() => _userSearchQuery = value), 
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: usersListAsync.when(
            data: (users) {
              final filteredUsers = _userSearchQuery.isEmpty
                ? users
                : users.where((user) {
                    final query = _userSearchQuery.toLowerCase();
                    final name = (user['name'] as String).toLowerCase();
                    final email = (user['email'] as String).toLowerCase();
                    final phone = (user['phone'] as String).toLowerCase();
                    
                    return name.contains(query) || 
                          email.contains(query) || 
                          phone.contains(query);
              }).toList();

              if (filteredUsers.isEmpty) {
                 return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 60,
                        color: theme.colorScheme.onSurfaceVariant.withAlpha(128),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _userSearchQuery.isEmpty 
                            ? 'admin.no_users_found'.tr()
                            : 'admin.no_users_match'.tr(namedArgs: {'query': _userSearchQuery}),
                        style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 16)
                      ),
                    ],
                  ),
                  );
              }
              
              return AnimationLimiter(
                child: RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(usersListProvider);
                  },
                     child: ListView.builder(
                    itemCount: filteredUsers.length,
                  padding: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
                      itemBuilder: (context, index) {
                      final theme = Theme.of(context);
                      final isDark = theme.brightness == Brightness.dark;
                      final user = filteredUsers[index];
                      final userName = user['name'] as String;
                      final joinDate = user['joinDate'] as DateTime;
                      final hasPaid = user['paymentCompleted'] as bool;
                      final hasCompletedOnboarding = user['onboardingCompleted'] as bool;
                      
                      String userStatus = 'New';
                      Color statusColor = theme.colorScheme.primary; 
                      
                      if (hasPaid) {
                        userStatus = 'Paid';
                        statusColor = Colors.green; 
                      } else if (hasCompletedOnboarding) {
                        userStatus = 'Active';
                        statusColor = Colors.orange; 
                      }
      
                      return AnimationConfiguration.staggeredList(
                        position: index,
                        duration: const Duration(milliseconds: 375),
                        child: SlideAnimation(
                          verticalOffset: 50.0,
                          child: FadeInAnimation(
                            child: Card(
                              margin: const EdgeInsets.only(bottom: 12.0),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                leading: Hero(
                                  tag: 'user-avatar-${user['id']}',
                                  child: CircleAvatar(
                                    radius: 24,
                                    backgroundColor: statusColor.withAlpha(isDark ? 77 : 38),
                                    child: Text(
                                      userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                                      style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 18),
                                    ),
                                  ),
                                ),
                                title: Text(
                                  userName, 
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600, 
                                    color: theme.colorScheme.onSurface
                                  )
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text(
                                      'Joined: ${AppDateUtils.formatRelativeTime(joinDate)}',
                                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: statusColor.withAlpha(isDark ? 77 : 38),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        userStatus.tr(),
                                        style: TextStyle(
                                          color: statusColor,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: Container(
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primaryContainer.withAlpha(isDark ? 102 : 128),
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    icon: const Icon(Icons.arrow_forward_ios, size: 16),
                                    color: theme.colorScheme.primary,
                                    onPressed: () {
                                      HapticUtils.lightTap();
                                      AppLogger.d("Viewing user details: ${user['id']}");
                                    },
                                  ),
                                ),
                                onTap: () {
                                  HapticUtils.lightTap();
                                  AppLogger.d("Viewing user details: ${user['id']}");
                                },
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
            error: (error, stack) {
              AppLogger.e('Error loading user list: $error', stack);
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 60,
                      color: theme.colorScheme.error.withAlpha(128),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading users'.tr(),
                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 16)
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        ref.invalidate(usersListProvider);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                      ),
                      child: Text('Retry'.tr()),
                    ),
                  ],
                  ),
              );
            },
            loading: () => const Center(
              child: CircularProgressIndicator(),
            ),
                ),
        ),
      ],
    );
  }
} 
