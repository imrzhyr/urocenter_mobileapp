import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/haptic_utils.dart';
import '../../../core/utils/date_utils.dart' as app_date_utils;
import '../../../core/widgets/app_bar_style2.dart' show AppBarStyle2, FilterOption;
import '../../../core/widgets/chat_list_item_style2.dart';
import '../../../core/widgets/empty_state_style2.dart';
import '../../../core/widgets/animated_item_list_style2.dart';
import '../../../core/widgets/shimmer_loading_list_style2.dart';
import '../../../providers/call_history_provider.dart';

/// Admin Calls Screen - displays call history and statistics
class AdminCallsScreen extends ConsumerStatefulWidget {
  const AdminCallsScreen({super.key});

  @override
  ConsumerState<AdminCallsScreen> createState() => _AdminCallsScreenState();
}

class _AdminCallsScreenState extends ConsumerState<AdminCallsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _showFilters = false;
  String _selectedFilter = 'all';

  @override
  void dispose() {
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
    });
    HapticUtils.lightTap();
  }
  
  void _onSearch(String query) {
    setState(() {
      _searchQuery = query;
    });
  }

  @override
  Widget build(BuildContext context) {
    final callHistoryAsync = ref.watch(callHistoryProvider);
    final theme = Theme.of(context);
    
    // Define filter options
    final List<FilterOption> filterOptions = [
      const FilterOption(value: 'all', label: 'All'),
      const FilterOption(value: 'completed', label: 'Completed'),
      const FilterOption(value: 'missed', label: 'Missed'),
      const FilterOption(value: 'rejected', label: 'Rejected'),
      const FilterOption(value: 'today', label: 'Today'),
    ];
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          // Use the AppBarStyle2 component
          AppBarStyle2(
            title: "Call History",
            showSearch: true,
            showFilters: true,
            filtersExpanded: _showFilters,
            searchController: _searchController,
            onSearchChanged: _onSearch,
            onFilterToggle: _toggleFilters,
            filterOptions: filterOptions,
            selectedFilter: _selectedFilter,
            onFilterSelected: _applyFilter,
            searchHint: "Search calls",
          ),
          
          const SizedBox(height: 16),
          
          // Call history list
          Expanded(
            child: callHistoryAsync.when(
              data: (calls) => _buildCallsList(calls),
              loading: () => const ShimmerLoadingListStyle2(
                itemCount: 10,
                itemHeight: 90,
                padding: EdgeInsets.all(16),
              ),
              error: (error, stack) => EmptyStateStyle2(
                icon: Icons.error_outline,
                message: 'Error loading calls',
                suggestion: error.toString(),
                buttonText: 'Try Again',
                buttonIcon: Icons.refresh,
                onButtonPressed: () {
                  // Use refresh result to clear unused_result warning
                  final _ = ref.refresh(callHistoryProvider);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCallsList(List<Map<String, dynamic>> calls) {
    // Filter calls based on search query
    var filteredCalls = calls;
    
    if (_searchQuery.isNotEmpty) {
      filteredCalls = calls.where((call) {
        final callerName = call['callerName'] as String;
        final calleeName = call['calleeName'] as String;
        final searchLower = _searchQuery.toLowerCase();
        return callerName.toLowerCase().contains(searchLower) || 
               calleeName.toLowerCase().contains(searchLower);
      }).toList();
    }
    
    // Apply filters
    if (_selectedFilter != 'all') {
      if (_selectedFilter == 'completed') {
        filteredCalls = filteredCalls.where((call) => call['status'] == 'completed').toList();
      } else if (_selectedFilter == 'missed') {
        filteredCalls = filteredCalls.where((call) => 
            call['status'] == 'missed' || call['status'] == 'no_answer').toList();
      } else if (_selectedFilter == 'rejected') {
        filteredCalls = filteredCalls.where((call) => call['status'] == 'rejected').toList();
      } else if (_selectedFilter == 'today') {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        filteredCalls = filteredCalls.where((call) {
          final callTime = call['startTime'] as DateTime;
          final callDate = DateTime(callTime.year, callTime.month, callTime.day);
          return callDate.isAtSameMomentAs(today);
        }).toList();
      }
    }
    
    if (filteredCalls.isEmpty) {
      return EmptyStateStyle2(
        icon: Icons.call_end_rounded,
        message: 'No calls found',
        suggestion: _searchQuery.isNotEmpty || _selectedFilter != 'all'
            ? 'Try changing your search or filter'
            : 'New calls will appear here',
        buttonText: _searchQuery.isNotEmpty || _selectedFilter != 'all' ? 'Clear Filters' : null,
        buttonIcon: _searchQuery.isNotEmpty || _selectedFilter != 'all' ? Icons.clear : null,
        onButtonPressed: _searchQuery.isNotEmpty || _selectedFilter != 'all' ? () {
          _searchController.clear();
          setState(() {
            _searchQuery = '';
            _selectedFilter = 'all';
            _showFilters = false;
          });
        } : null,
      );
    }
    
    return AnimatedItemListStyle2<Map<String, dynamic>>(
      items: filteredCalls,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, call, index) {
        return _buildCallItem(call);
      },
    );
  }
  
  Widget _buildCallItem(Map<String, dynamic> call) {
    final theme = Theme.of(context);
    final callStatus = call['status'] as String;
    final callTime = call['startTime'] as DateTime;
    final formattedTime = app_date_utils.AppDateUtils.formatDateWithTime(callTime);
    final callType = call['type'] as String? ?? 'audio';
    
    // Additional info for completed calls with duration
    Widget? additionalWidget;
    if (callStatus == 'completed' && call['duration'] != null) {
      final callDuration = _formatDuration(call['duration'] as int);
      additionalWidget = Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.blue.withAlpha(25),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.timelapse,
              size: 14,
              color: Colors.blue,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Duration: $callDuration',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
        ],
      );
    }
    
    final nameParts = '${call['callerName']} → ${call['calleeName']}';
    
    return ChatListItemStyle2(
      name: nameParts,
      lastMessage: formattedTime,
      timeString: callType == 'video' ? 'Video Call' : 'Audio Call',
      status: callStatus,
      additionalInfo: additionalWidget,
      onTap: () {
        // Handle call item tap
        HapticUtils.lightTap();
      },
    );
  }
  
  String _formatDuration(int seconds) {
    final Duration duration = Duration(seconds: seconds);
    
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m ${duration.inSeconds.remainder(60)}s';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds.remainder(60)}s';
    } else {
      return '${duration.inSeconds}s';
    }
  }
} 