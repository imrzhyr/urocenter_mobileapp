import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/models/user_model.dart' as user_model;
import '../../../core/utils/haptic_utils.dart';
import 'package:urocenter/core/utils/logger.dart';
import '../../../core/widgets/app_bar_style2.dart' show AppBarStyle2, FilterOption;
import '../../../core/widgets/chat_list_item_style2.dart';
import '../../../core/widgets/empty_state_style2.dart';
import '../../../core/widgets/animated_item_list_style2.dart';
import '../../../core/widgets/shimmer_loading_list_style2.dart';
import '../../../app/routes.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// For date formatting
class DateTimeFormatter {
  static String formatChatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays == 0) {
      // Today: show time in 12h format
      return DateFormat('h:mm a').format(dateTime); // 12-hour with AM/PM
    } else if (difference.inDays == 1) {
      // Yesterday
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      // Within a week
      return DateFormat('EEEE').format(dateTime); // Day name
    } else {
      // Older
      return DateFormat('MM/dd/yy').format(dateTime); // MM/DD/YY format
    }
  }
}

// --- Moved Models/Enums specific to this screen ---

enum ChatStatus { active, resolved }

class ChatSession {
  final String chatId;
  final String otherUserId;
  final String otherUserName;
  final String? otherUserAvatar;
  final String lastMessage;
  final DateTime timestamp;
  final String lastMessageType;
  final String lastSenderId;
  final ChatStatus status;

  ChatSession({
    required this.chatId,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserAvatar,
    required this.lastMessage,
    required this.timestamp,
    required this.lastMessageType,
    required this.lastSenderId,
    required this.status,
  });

  factory ChatSession.fromSnapshot(DocumentSnapshot doc, user_model.User otherUserDetails) {
    final data = doc.data() as Map<String, dynamic>;
    const status = ChatStatus.active;
    
    return ChatSession(
      chatId: doc.id,
      otherUserId: otherUserDetails.id,
      otherUserName: otherUserDetails.fullName,
      otherUserAvatar: null,
      lastMessage: data['lastMessageContent'] ?? '',
      timestamp: (data['lastMessageTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastMessageType: data['lastMessageType'] ?? 'text',
      lastSenderId: data['lastSenderId'] ?? '',
      status: status,
    );
  }
}

// --- End Moved Models/Enums ---

// Add cached data provider for consultations with a better update mechanism
final consultationCacheProvider = StateProvider<Map<String, List<Map<String, dynamic>>>>((ref) => {});

final adminConsultationsProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, status) {
  // Get the cache map
  final cacheMap = ref.read(consultationCacheProvider);
  
  // Base query for chats
  Query query = FirebaseFirestore.instance
      .collection('chats')
      .orderBy('lastMessageTime', descending: true);
      
  // Apply status filter
  if (status != 'all') {
    // Map UI 'completed' status to Firestore 'resolved' status
    final firestoreStatus = (status == 'completed') ? 'resolved' : status;
    query = query.where('status', isEqualTo: firestoreStatus);
  }

  // Return stream from Firestore
  return query.snapshots().asyncMap((snapshot) async {
    final List<Map<String, dynamic>> consultations = [];
    
    // Check if we should use cache first (only if snapshot is empty)
    if (snapshot.docs.isEmpty && cacheMap.containsKey(status)) {
      AppLogger.d('Using cached data for status: $status');
      return cacheMap[status]!;
    }
    
    // Log for debugging empty results
    AppLogger.d('Firestore query returned ${snapshot.docs.length} documents');
    
    if (snapshot.docs.isEmpty) {
      AppLogger.d('No chats found in Firestore');
      return [];
    }
    
    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final participants = List<String>.from(data['participants'] ?? []);
      
      if (participants.isEmpty) continue;
      
      // Assuming one participant is the patient, could be enhanced to explicitly identify roles
      String patientId = '';
      
      // Simple logic to identify patient/doctor - could be improved with proper role identification
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      
      for (var id in participants) {
        if (id != currentUserId) {
          patientId = id;
          break;
        }
      }
      
      if (patientId.isEmpty) continue;
      
      try {
        // Get patient details
        final patientDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(patientId)
            .get();
            
        if (!patientDoc.exists) continue;
        final patientData = patientDoc.data() ?? {};
        
        final lastMessageTime = (data['lastMessageTime'] as Timestamp?)?.toDate() ?? DateTime.now();
        final lastMessageContent = data['lastMessageContent'] as String? ?? '';
        final lastSenderId = data['lastSenderId'] as String? ?? '';
        final unreadCount = data['unreadCount'] as int? ?? 0;
        final chatStatus = data['status'] as String? ?? 'active';
        final isUrgent = data['isUrgent'] as bool? ?? false;
        
        consultations.add({
          'id': doc.id,
          'patientId': patientId,
          'patientName': patientData['fullName'] as String? ?? 'Unknown Patient',
          'otherUserId': patientId, // This is required for chat navigation
          'otherUserName': patientData['fullName'] as String? ?? 'Unknown Patient', // This is required for chat navigation
          'lastMessageTime': lastMessageTime,
          'lastMessageContent': lastMessageContent,
          'lastSenderId': lastSenderId,
          'unreadCount': unreadCount,
          'status': chatStatus,
          'isUrgent': isUrgent,
        });
      } catch (e) {
        AppLogger.e('Error fetching patient details for chat ${doc.id}: $e');
      }
    }
    
    // Update cache non-reactively, only if we got data from Firestore
    if (consultations.isNotEmpty) {
      final newCache = Map<String, List<Map<String, dynamic>>>.from(cacheMap);
      newCache[status] = consultations;
      ref.read(consultationCacheProvider.notifier).state = newCache;
    }
    
    return consultations;
  });
});

/// Consultations tab of the admin dashboard
class AdminConsultationsScreen extends ConsumerStatefulWidget {
  const AdminConsultationsScreen({super.key});

  @override
  ConsumerState<AdminConsultationsScreen> createState() => _AdminConsultationsScreenState();
}

class _AdminConsultationsScreenState extends ConsumerState<AdminConsultationsScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _showFilters = false;
  String _selectedFilter = 'all';
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      // Only trigger if the tab change is user-initiated
      if (!_tabController.indexIsChanging) {
      setState(() {
          // Clear filters when switching tabs
          _showFilters = false;
          _selectedFilter = 'all';
          _searchQuery = '';
          _searchController.clear();
        });
        }
      });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _toggleFilters() {
    setState(() {
      _showFilters = !_showFilters;
    });
    HapticUtils.lightTap();
  }
  
  void _applyFilter(String filter) {
    setState(() {
      _selectedFilter = filter;
      // Don't hide filters when a filter is selected
    });
    HapticUtils.lightTap();
  }
  
  void _onSearch(String query) {
    setState(() {
      _searchQuery = query;
    });
  }
  
  String _getConsultationStatus() {
    // Map tab index to status
    if (_tabController.index == 0) {
      return 'active';
    } else {
      return 'completed';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    
    // Define filter options for the AppBarStyle2
    final List<FilterOption> filterOptions = [
      const FilterOption(value: 'all', label: 'All'),
      const FilterOption(value: 'urgent', label: 'Urgent'),
      const FilterOption(value: 'unread', label: 'Unread'),
      const FilterOption(value: 'today', label: 'Today'),
      const FilterOption(value: 'this_week', label: 'This Week'),
    ];
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          // Use the AppBarStyle2 component
          AppBarStyle2(
            title: "Consultations",
            showSearch: true,
            showFilters: true,
            filtersExpanded: _showFilters,
            searchController: _searchController,
            onSearchChanged: _onSearch,
            onFilterToggle: _toggleFilters,
            filterOptions: filterOptions,
            selectedFilter: _selectedFilter,
            onFilterSelected: _applyFilter,
            searchHint: "Search consultations",
          ),
          
          const SizedBox(height: 16),
          
          // Tab bar for Active/Completed consultations
          TabBar(
            controller: _tabController,
            labelColor: theme.colorScheme.primary,
            unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
            indicatorColor: theme.colorScheme.primary,
            indicatorSize: TabBarIndicatorSize.label,
            tabs: [
              Tab(text: "Active".tr()),
              Tab(text: "Completed".tr()),
            ],
          ),
          
          // Tab content with StreamBuilder
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Active consultations tab
                _buildConsultationsList(context, 'active', isDarkMode),
                
                // Completed consultations tab
                _buildConsultationsList(context, 'completed', isDarkMode),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConsultationsList(BuildContext context, String status, bool isDarkMode) {
    // Get the consultations stream
    final consultationsStream = ref.watch(adminConsultationsProvider(status));
        
    return consultationsStream.when(
          data: (consultations) {
        // Filter consultations based on search and filters
        var filteredConsultations = _filterConsultations(consultations, _searchQuery, _selectedFilter);
            
            if (filteredConsultations.isEmpty) {
          return _buildEmptyState(context, status, _searchQuery, _selectedFilter);
        }
        
        return AnimatedItemListStyle2<Map<String, dynamic>>(
          items: filteredConsultations,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          itemBuilder: (context, consultation, index) {
            return _buildConsultationCard(context, consultation, isDarkMode);
                },
            );
          },
      loading: () => const ShimmerLoadingListStyle2(
        itemCount: 6,
        itemHeight: 90,
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16),
      ),
      error: (error, stack) {
        AppLogger.e('Error loading consultations: $error');
        return _buildErrorState(error.toString());
      },
    );
  }
  
  Widget _buildConsultationCard(BuildContext context, Map<String, dynamic> consultation, bool isDarkMode) {
    final lastMessageTime = consultation['lastMessageTime'] as DateTime;
    final formattedTime = DateTimeFormatter.formatChatTime(lastMessageTime);
    final unreadCount = consultation['unreadCount'] as int;
    final isUrgent = consultation['isUrgent'] as bool;
    final status = consultation['status'] as String;
    
    return ChatListItemStyle2(
      name: consultation['patientName'],
      lastMessage: consultation['lastMessageContent'],
      timeString: formattedTime,
      unreadCount: unreadCount,
      isUrgent: isUrgent,
      status: status,
      statusDisplay: status == 'active' ? 'Active' : 'Completed',
      routeName: RouteNames.userChat,
      routeExtra: consultation,
    );
  }
  
  Widget _buildEmptyState(BuildContext context, String status, String searchQuery, String selectedFilter) {
    final bool isSearching = searchQuery.isNotEmpty || selectedFilter != 'all';
    
    final String message = isSearching 
      ? 'No consultations match your search'
      : status == 'active'
          ? 'No active consultations'
          : 'No completed consultations';
    
    final String suggestion = isSearching 
      ? 'Try changing your search or filter'
      : status == 'active'
          ? 'New consultations will appear here'
          : 'Completed consultations will appear here';
    
    final IconData icon = isSearching 
        ? Icons.search_off
        : status == 'active' 
            ? Icons.chat_bubble_outline
            : Icons.check_circle_outline;
    
    return EmptyStateStyle2(
      icon: icon,
      message: message,
      suggestion: suggestion,
      buttonText: isSearching ? 'Clear Filters' : null,
      buttonIcon: isSearching ? Icons.clear : null,
      onButtonPressed: isSearching ? () {
        _searchController.clear();
        setState(() {
          _searchQuery = '';
          _selectedFilter = 'all';
          _showFilters = false;
        });
      } : null,
    );
  }
  
  Widget _buildErrorState(String errorMessage) {
    return EmptyStateStyle2(
      icon: Icons.error_outline,
      message: 'Something went wrong',
      suggestion: errorMessage,
      buttonText: 'Try Again',
      buttonIcon: Icons.refresh,
      onButtonPressed: () {
        // Refresh the data with proper handling of the result
        final _ = ref.refresh(adminConsultationsProvider(_getConsultationStatus()));
      },
    );
  }

  List<Map<String, dynamic>> _filterConsultations(
    List<Map<String, dynamic>> consultations, 
    String searchQuery, 
    String filterType
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final startOfWeek = DateTime(weekStart.year, weekStart.month, weekStart.day);
    
    // First apply search query
    var result = searchQuery.isEmpty 
        ? consultations 
        : consultations.where((c) {
            final patientName = c['patientName'].toString().toLowerCase();
            final lastMessage = c['lastMessageContent'].toString().toLowerCase();
            final searchLower = searchQuery.toLowerCase();
            
            return patientName.contains(searchLower) || 
                   lastMessage.contains(searchLower);
          }).toList();
    
    // Then apply filter
    switch (filterType) {
      case 'urgent':
        return result.where((c) => c['isUrgent'] == true).toList();
      case 'unread':
        return result.where((c) => (c['unreadCount'] as int) > 0).toList();
      case 'today':
        return result.where((c) {
          final messageTime = c['lastMessageTime'] as DateTime;
          return messageTime.isAfter(today);
        }).toList();
      case 'this_week':
        return result.where((c) {
          final messageTime = c['lastMessageTime'] as DateTime;
          return messageTime.isAfter(startOfWeek);
        }).toList();
      case 'all':
      default:
        return result;
    }
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }
} 
