import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/theme.dart';
import '../../../app/routes.dart';
import '../../../core/utils/dialog_utils.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/haptic_utils.dart';
import 'package:urocenter/core/utils/logger.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../core/services/call_service.dart';

// --- Imports for screen files ---
import 'admin_consultations_screen.dart';
import 'admin_data_screen.dart';
import 'admin_calls_screen.dart';
import '../../../core/widgets/navigation_bar_style2.dart';

// --- Callback Definition ---
typedef NavigateToTabCallback = void Function(int index);

/// Doctor dashboard screen with bottom navigation
class AdminDashboard extends ConsumerStatefulWidget {
  final Map<String, dynamic>? extraData;

  const AdminDashboard({super.key, this.extraData});

  @override
  ConsumerState<AdminDashboard> createState() => AdminDashboardState();
}

class AdminDashboardState extends ConsumerState<AdminDashboard> with SingleTickerProviderStateMixin {
  // Set consultations as default tab (index 0)
  int _selectedIndex = 0;
  late AnimationController _animationController;
  
  // Active call state
  Map<String, dynamic>? _activeCallParams;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animationController.forward();
    listenForIncomingCalls();
    _checkForActiveCall();
  }
  
  void _checkForActiveCall() {
    if (widget.extraData != null && widget.extraData!.containsKey('activeCall')) {
      setState(() {
        _activeCallParams = widget.extraData!['activeCall'] as Map<String, dynamic>?;
        AppLogger.d("[AdminDashboard] Found active call in extraData: ${_activeCallParams?['callId']}");
      });
    }
  }
  
  void _returnToActiveCall() {
    if (_activeCallParams != null) {
      HapticUtils.mediumTap();
      context.pushNamed(
        RouteNames.callScreen,
        extra: _activeCallParams,
      );
    }
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    // Stop listening for incoming calls when the screen is disposed
    final callService = ref.read(callServiceProvider);
    callService.stopListening();
    super.dispose();
  }
  
  void _onTabSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
    // Add a small haptic feedback for better interaction
    HapticUtils.lightTap();
  }

  void setTabIndex(int index) {
    if (index >= 0 && index < 3) {
      setState(() {
        _selectedIndex = index;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Monitor incoming calls to ensure they're properly detected
    final incomingCall = ref.watch(incomingCallProvider);
    if (incomingCall != null) {
      AppLogger.d("[AdminDashboard] Detected incoming call in dashboard from: ${incomingCall.callerName}");
    }
    
    // Define navigation items
    final List<NavigationItem> navigationItems = [
      NavigationItem(
        icon: Icons.chat_outlined,
        activeIcon: Icons.chat,
        label: 'consultations.title'.tr(),
      ),
      NavigationItem(
        icon: Icons.call_outlined,
        activeIcon: Icons.call,
        label: 'calls.title'.tr(),
      ),
      NavigationItem(
        icon: Icons.analytics_outlined,
        activeIcon: Icons.analytics,
        label: 'analytics.title'.tr(),
      ),
    ];
    
    return Scaffold(
      body: SafeArea(
        bottom: false, // Don't add bottom safe area as we have bottom navigation
        child: Stack(
          children: [
            IndexedStack(
              index: _selectedIndex,
              children: const [
                AdminConsultationsScreen(),
                AdminCallsScreen(),
                AdminDataScreen(),
              ],
            ),
            
            // Debug indicator for incoming calls - remove in production
            if (incomingCall != null)
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    'Incoming call from: ${incomingCall.callerName}',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBarStyle2(
        selectedIndex: _selectedIndex,
        items: navigationItems,
        onItemSelected: _onTabSelected,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () {
          HapticUtils.lightTap();
          // TODO: Show add user dialog/screen
        },
        heroTag: 'user_fab',
        child: const Icon(Icons.add),
      ),
    );
  }

  void listenForIncomingCalls() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      final currentUserId = currentUser.uid;
      AppLogger.d("[AdminDashboard] Setting up call listener for admin user: $currentUserId");
      
      final callService = ref.read(callServiceProvider);
      callService.listenForIncomingCalls(currentUserId);
      
      // Listen for incoming calls with admin as the callee ID
      // We need this explicitly because the admin dashboard is a different UI from the user one
      AppLogger.d("[AdminDashboard] Also listening for admin calls as recipient");
    } else {
      AppLogger.e("[AdminDashboard] Cannot listen for incoming calls: User not logged in");
    }
  }
}

/// Users tab of the admin dashboard
class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}
  
class _AdminUsersScreenState extends State<AdminUsersScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  String _searchQuery = '';
  late TabController _tabController;
  final List<String> _tabs = ['All Users', 'Patients', 'Doctors'];
  
  final TextEditingController _searchController = TextEditingController();
  
  // State variable for users list
  List<Map<String, dynamic>> _users = [];
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _loadUsers(); // Load users initially
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // Method to fetch users
  Future<void> _loadUsers({bool isRefresh = false}) async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
    });

    try {
      // TODO: Implement actual user fetching from backend based on current tab/search?
      // Example: final fetchedUsers = await AdminService.getUsers(tab: _tabs[_tabController.index], search: _searchQuery);
      // Simulate short delay if needed for real fetches
      // await Future.delayed(const Duration(milliseconds: 500));

      // MOCK DATA (REMOVE/REPLACE with actual data)
      final mockUsers = [
        {
          'id': 'U001', 'name': 'Ahmed Hassan', 'phone': '+966501234567',
          'role': 'Patient', 'status': 'Active', 'joinDate': DateTime(2023, 4, 21), 'avatar': 'A',
        },
        {
          'id': 'U002', 'name': 'Dr. Sarah Ahmed', 'phone': '+1234567890',
          'role': 'Doctor', 'specialty': 'Urologist', 'status': 'Active', 'joinDate': DateTime(2023, 3, 15), 'avatar': 'S',
        },
        // ... other mock users ...
      ];
      // END MOCK DATA

      if (mounted) {
        setState(() {
          _users = mockUsers; // Replace with fetchedUsers
        });
  }
    } catch (e) {
      // TODO: Handle error
      AppLogger.e("Error loading users: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onSearch(String query) {
    setState(() {
      _searchQuery = query;
      // TODO: Optionally trigger _loadUsers() here if search is backend-driven
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Users',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          indicatorSize: TabBarIndicatorSize.label,
          labelColor: AppColors.primary,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          unselectedLabelColor: Colors.grey,
          tabs: _tabs.map((String tab) => Tab(text: tab)).toList(),
          onTap: (index) {
            // Reload users when tab changes if filtering is backend-driven
            // _loadUsers();
          },
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
      child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(30),
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search users...',
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.grey),
                          onPressed: () {
                            _searchController.clear();
                            _onSearch('');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                ),
                onChanged: _onSearch, // Use the handler
              ),
            ),
          ),
          
          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Pass the same _buildUsersList for each tab, filtering happens inside
                _buildUsersList('all'),
                _buildUsersList('patients'),
                _buildUsersList('doctors'),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () {
          HapticUtils.lightTap();
          // TODO: Show add user dialog/screen
        },
        heroTag: 'user_fab',
        child: const Icon(Icons.add),
      ),
    );
  }
  
  Widget _buildUsersList(String userType) {
    // Use state variable _users
    // Filter logic remains mostly the same but operates on _users
    final filteredByType = userType == 'all'
        ? _users
        : userType == 'patients'
            ? _users.where((user) => user['role'] == 'Patient').toList()
            : _users.where((user) => user['role'] == 'Doctor').toList();
    
    final searchFilteredUsers = _searchQuery.isEmpty
        ? filteredByType
        : filteredByType.where((user) =>
            (user['name'] as String? ?? '').toLowerCase().contains(_searchQuery.toLowerCase()) ||
            (user['phone'] as String? ?? '').toLowerCase().contains(_searchQuery.toLowerCase()) ||
            (user['id'] as String? ?? '').toLowerCase().contains(_searchQuery.toLowerCase())
          ).toList();

    if (_isLoading && searchFilteredUsers.isEmpty) {
      // Show loading indicator if loading and list is empty
      return const Center(child: CircularProgressIndicator());
    }
    
    if (searchFilteredUsers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty 
                  ? 'No users match your search'
                  : 'No $userType found', // More specific message
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: () => _loadUsers(isRefresh: true), // Use the load method
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: searchFilteredUsers.length,
        itemBuilder: (context, index) {
          final user = searchFilteredUsers[index];
          // Use null-safe access and defaults
          final userName = user['name'] as String? ?? 'Unknown';
          final userPhone = user['phone'] as String? ?? '-';
          final userAvatar = user['avatar'] as String? ?? '?';
          final userRole = user['role'] as String? ?? 'Unknown';
          final userStatus = user['status'] as String? ?? 'Unknown';
          final userJoinDate = user['joinDate'] as DateTime? ?? DateTime.now();
          final userSpecialty = user['specialty'] as String?;

          // Determine colors based on role/status (adjust logic as needed)
          Color roleColor = userRole == 'Doctor' ? AppColors.primary : Colors.orange;
          Color statusColor = userStatus == 'Active' ? Colors.green : (userStatus == 'Pending' ? Colors.amber : Colors.grey);
          
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                          color: Colors.black.withValues(alpha: 20),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                      border: Border.all(
                        color: Colors.grey.withValues(alpha: 51),
                      ),
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  // TODO: Navigate to user details
                  AppLogger.d("Navigate to details for $userName");
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: roleColor.withValues(alpha: 38.0),
                            child: Text(
                              userAvatar,
                              style: TextStyle(
                                color: roleColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          if (userStatus == 'Pending')
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: statusColor, // Use derived status color
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          if (userStatus == 'Active')
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: statusColor, // Use derived status color
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                              ),
            ),
          ],
        ),
                      const SizedBox(width: 16),
                      Expanded(
        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    userName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
            Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
              decoration: BoxDecoration(
                                    color: roleColor.withValues(alpha: 38.0),
                                    borderRadius: BorderRadius.circular(50),
              ),
                                  child: Text(
                                    userRole,
                                    style: TextStyle(
                                      color: roleColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
            ),
                            const SizedBox(height: 4),
            Text(
                              userPhone,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  size: 14,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  // Ensure date is handled correctly
                                  'Joined: ${AppDateUtils.formatRelativeTime(userJoinDate)}',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                                if (userSpecialty != null)
                                  Row(
                                    children: [
                                      const SizedBox(width: 8),
                                      const CircleAvatar(
                                        radius: 2,
                                        backgroundColor: Colors.grey,
                                      ),
                                      const SizedBox(width: 8),
                                      Icon(
                                        Icons.medical_services_outlined,
                                        size: 14,
                                        color: Colors.grey[600],
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        userSpecialty,
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12,
              ),
            ),
          ],
        ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.more_vert),
                        color: Colors.grey[600],
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(20),
                              ),
                            ),
                            builder: (context) {
                              return _buildUserOptionsSheet(user);
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildUserOptionsSheet(Map<String, dynamic> user) {
    final userName = user['name'] as String? ?? 'this user';
    final userStatus = user['status'] as String? ?? '';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.person, color: AppColors.primary),
            title: const Text('View Profile'),
            onTap: () {
              Navigator.pop(context);
              // TODO: Implement View Profile navigation
              AppLogger.d('View Profile for $userName');
            },
          ),
          ListTile(
            leading: const Icon(Icons.edit, color: Colors.blue),
            title: const Text('Edit User'),
            onTap: () {
              Navigator.pop(context);
              // TODO: Implement Edit User navigation/dialog
              AppLogger.d('Edit User for $userName');
            },
          ),
          ListTile(
            leading: const Icon(Icons.block, color: Colors.orange),
            title: Text(
              userStatus == 'Active' ? 'Suspend User' : 'Activate User',
            ),
            onTap: () {
              Navigator.pop(context);
              // TODO: Implement Suspend/Activate user logic
              AppLogger.d('Toggle Suspend/Activate for $userName');
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text('Delete User'),
            onTap: () {
              Navigator.pop(context);
              // Use DialogUtils for consistency
              DialogUtils.showConfirmationDialog(
                context: context,
                title: 'Delete User',
                message: 'Are you sure you want to delete $userName? This action cannot be undone.',
                confirmText: 'Delete',
                confirmColor: AppColors.error,
              ).then((confirmed) {
                if (confirmed) {
                  // TODO: Implement actual user deletion logic
                  AppLogger.d('Delete User $userName confirmed');
                  // Optionally call _loadUsers() again after deletion
                }
              });
            },
          ),
        ],
      ),
    );
  }
} 

/// NEW: Admin Data Screen
// class _AdminDataScreenState extends State<AdminDataScreen> with TickerProviderStateMixin {
//   // ... ENTIRE CLASS DEFINITION REMOVED ...
// }

// --- Helper Widget: StatDisplayCard ---
// enum Trend { up, down, none }

// --- REMOVE StatDisplayCard Class Definition ---
/*
class StatDisplayCard extends StatelessWidget { 
  // ... ENTIRE WIDGET DEFINITION REMOVED ...
}
*/
// --- END REMOVAL ---

// --- END: StatDisplayCard ---

// enum TimePeriod { week, month, all } // Moved 

// --- REMOVED AdminSettingsScreen Class Definition ---
/*
</code_block_to_apply_changes_from>
*/
// --- END REMOVAL --- 
