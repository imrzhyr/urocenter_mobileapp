import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../app/routes.dart';
import '../../../core/theme/theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/models/user_model.dart' as UserModel;
import '../../../core/utils/haptic_utils.dart';
import 'package:urocenter/core/utils/logger.dart';
import 'package:easy_localization/easy_localization.dart';
import 'admin_dashboard.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/shimmer_loading.dart';

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

  factory ChatSession.fromSnapshot(DocumentSnapshot doc, UserModel.User otherUserDetails) {
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

final adminConsultationsProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, status) {
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
  
  return query.snapshots().asyncMap((snapshot) async {
    final List<Map<String, dynamic>> consultations = [];
    
    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final participants = List<String>.from(data['participants'] ?? []);
      
      if (participants.isEmpty) continue;
      
      // Assuming one participant is the patient, could be enhanced to explicitly identify roles
      String patientId = '';
      String doctorId = '';
      
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
          'doctorName': 'Dr. Admin', // This should come from the doctor document
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
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey = GlobalKey<RefreshIndicatorState>();
  
  // Animation controllers
  late AnimationController _fadeController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChange);
    
    // Initialize animation controllers
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeController.forward();
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      _fadeController.reset();
      _fadeController.forward();
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _searchController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
    // Just rebuild widget via state change to trigger stream refresh
    setState(() {});
    
    // Reset animations
    _fadeController.reset();
    _fadeController.forward();
    
    // Add a small delay for visual feedback
    await Future.delayed(const Duration(milliseconds: 300));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Consultations'.tr(),
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
            Tab(text: 'Active'.tr()),
            Tab(text: 'Completed'.tr()),
            Tab(text: 'All'.tr()),
          ],
        ),
      ),
      body: Column(
        children: [
          AnimationConfiguration.synchronized(
            duration: const Duration(milliseconds: 400),
            child: SlideAnimation(
              verticalOffset: 50.0,
              child: FadeInAnimation(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(color: theme.colorScheme.onSurface),
                    decoration: InputDecoration(
                      hintText: 'Search consultations...'.tr(),
                      hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                      prefixIcon: Icon(Icons.search, color: theme.colorScheme.onSurfaceVariant),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear, color: theme.colorScheme.onSurfaceVariant),
                              onPressed: () {
                                HapticUtils.lightTap();
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              key: _refreshIndicatorKey,
              color: AppColors.primary,
              backgroundColor: Colors.white,
              onRefresh: _refreshData,
              child: TabBarView(
                controller: _tabController,
                children: [
                  FadeTransition(
                    opacity: _fadeController,
                    child: _buildConsultationsList('active'),
                  ),
                  FadeTransition(
                    opacity: _fadeController,
                    child: _buildConsultationsList('completed'),
                  ),
                  FadeTransition(
                    opacity: _fadeController,
                    child: _buildConsultationsList('all'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConsultationsList(String status) {
    final consultationsAsync = ref.watch(adminConsultationsProvider(status));
    
    return consultationsAsync.when(
      data: (consultations) {
        // Filter results based on search query
        final filteredConsultations = _searchQuery.isEmpty 
            ? consultations 
            : consultations.where((consultation) {
                final query = _searchQuery.toLowerCase();
                final patientName = (consultation['patientName'] as String).toLowerCase();
                final doctorName = (consultation['doctorName'] as String).toLowerCase();
                final id = consultation['id'] as String;
                
                return patientName.contains(query) || 
                       doctorName.contains(query) || 
                       id.contains(query);
              }).toList();
        
        if (filteredConsultations.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.search_off,
                  size: 60,
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  _searchQuery.isEmpty 
                      ? 'admin.no_consultations_found'.tr()
                      : 'admin.no_consultations_match'.tr(namedArgs: {'query': _searchQuery}),
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 16)
                ),
              ],
            ),
          );
        }
        
        return AnimationLimiter(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
            itemCount: filteredConsultations.length,
            itemBuilder: (context, index) {
              final consultation = filteredConsultations[index];
              
              return AnimationConfiguration.staggeredList(
                position: index,
                duration: const Duration(milliseconds: 375),
                child: SlideAnimation(
                  verticalOffset: 50.0,
                  child: FadeInAnimation(
                    child: _buildConsultationCard(consultation),
                  ),
                ),
              );
            },
          ),
        );
      },
      error: (error, stack) {
        AppLogger.e('Error loading consultations: $error');
        return _buildErrorView('Error loading consultations'.tr());
      },
      loading: () => _buildLoadingShimmer(),
    );
  }
  
  Widget _buildConsultationCard(Map<String, dynamic> consultation) {
    final theme = Theme.of(context);
    final chatId = consultation['id'] as String;
    final patientName = consultation['patientName'] as String;
    final lastMessageTime = consultation['lastMessageTime'] as DateTime;
    final unreadMessages = consultation['unreadCount'] as int;
    final status = consultation['status'] as String;
    final isUrgent = consultation['isUrgent'] as bool;
    final isDark = theme.brightness == Brightness.dark;

    final statusColor = status == 'active' 
        ? Colors.green 
        : (status == 'completed' ? theme.colorScheme.primary : Colors.orange);
    final urgentColor = Colors.red;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          HapticUtils.lightTap();
          AppLogger.d("Viewing consultation: $chatId");
          context.pushNamed(
            RouteNames.userChat,
            extra: {
              'chatId': chatId,
              'otherUserId': consultation['patientId'],
              'otherUserName': patientName,
            },
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Hero(
                    tag: 'patient-avatar-$chatId',
                    child: CircleAvatar(
                      radius: 24,
                      backgroundColor: theme.colorScheme.primaryContainer.withOpacity(isDark ? 0.7 : 0.5),
                      child: Text(
                        patientName.isNotEmpty ? patientName[0].toUpperCase() : 'P',
                        style: TextStyle(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                patientName,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: theme.colorScheme.onSurface,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              AppDateUtils.formatRelativeTime(lastMessageTime),
                              style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          consultation['lastMessageContent'] as String? ?? 'No message'.tr(),
                          style: TextStyle(
                            color: unreadMessages > 0 
                              ? theme.colorScheme.onSurface 
                              : theme.colorScheme.onSurfaceVariant,
                            fontSize: 14,
                            fontWeight: unreadMessages > 0 
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withAlpha(26),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      status.capitalize(),
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  if (isUrgent)
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: urgentColor.withAlpha(26),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.priority_high,
                              color: urgentColor,
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Urgent'.tr(),
                              style: TextStyle(
                                color: urgentColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (unreadMessages > 0)
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$unreadMessages new',
                          style: TextStyle(
                            color: theme.colorScheme.onPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildLoadingShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: ShimmerLoading(
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        );
      }
    );
  }
  
  Widget _buildErrorView(String message) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 60,
            color: theme.colorScheme.error.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 16),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh),
            label: Text('Try Again'.tr()),
            onPressed: _refreshData,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }
} 
