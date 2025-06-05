import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../core/utils/haptic_utils.dart';
import '../../../core/utils/date_utils.dart' as app_date_utils;
import '../../../core/widgets/app_bar_style2.dart' show AppBarStyle2, FilterOption;
import '../../../core/widgets/chat_list_item_style2.dart';
import '../../../core/widgets/empty_state_style2.dart';
import '../../../core/widgets/animated_item_list_style2.dart';
import '../../../core/widgets/shimmer_loading_list_style2.dart';
import '../../../providers/call_history_provider.dart';

/// User Call Screen - displays call history for regular users
class UserCallScreen extends ConsumerStatefulWidget {
  const UserCallScreen({super.key});

  @override
  ConsumerState<UserCallScreen> createState() => _UserCallScreenState();
}

class _UserCallScreenState extends ConsumerState<UserCallScreen> {
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
      FilterOption(value: 'all', label: 'All'.tr()),
      FilterOption(value: 'completed', label: 'Completed'.tr()),
      FilterOption(value: 'missed', label: 'Missed'.tr()),
      FilterOption(value: 'rejected', label: 'Rejected'.tr()),
      FilterOption(value: 'today', label: 'Today'.tr()),
    ];
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBarStyle2(
        title: 'Call History'.tr(),
        showSearch: true,
        showFilters: true,
        filtersExpanded: _showFilters,
        searchController: _searchController,
        onSearchChanged: _onSearch,
        onFilterToggle: _toggleFilters,
        filterOptions: filterOptions,
        selectedFilter: _selectedFilter,
        onFilterSelected: _applyFilter,
        searchHint: 'Search calls'.tr(),
      ),
      body: Column(
        children: [
          // Call history list
          Expanded(
            child: callHistoryAsync.when(
              data: (calls) => _buildCallsList(calls.map((call) => call.toMap()).toList()),
              loading: () => const ShimmerLoadingListStyle2(
                itemCount: 10,
                itemHeight: 90,
                padding: EdgeInsets.all(16),
              ),
              error: (error, stack) => EmptyStateStyle2(
                icon: Icons.error_outline,
                message: 'Error loading calls'.tr(),
                suggestion: error.toString(),
                buttonText: 'common.try_again'.tr(),
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
    final theme = Theme.of(context);
    
    // Filter calls based on search query and selected filter
    final filteredCalls = _filterCalls(calls);
    
    if (filteredCalls.isEmpty) {
      return EmptyStateStyle2(
        icon: Icons.phone_missed,
        message: 'No calls found'.tr(),
        suggestion: _searchQuery.isNotEmpty || _selectedFilter != 'all'
            ? 'Try Again'.tr()
            : 'New calls will appear here'.tr(),
        buttonText: _searchQuery.isNotEmpty || _selectedFilter != 'all' ? 'common.clear'.tr() : null,
        buttonIcon: Icons.filter_alt_off,
        onButtonPressed: _searchQuery.isNotEmpty || _selectedFilter != 'all' ? () {
          setState(() {
            _searchQuery = '';
            _selectedFilter = 'all';
            _searchController.clear();
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
    
    // Additional info for calls with duration
    Widget? additionalWidget;
    
    // Always include call duration, even if zero
    final int durationValue = call['duration'] as int? ?? 0;
    final callDuration = _formatDuration(durationValue);
    
    // Create widget for call duration
    Color durationColor = Colors.blue;
    if (callStatus == 'completed') {
      durationColor = Colors.green;
    } else if (callStatus == 'missed' || callStatus == 'rejected') {
      durationColor = Colors.red;
    } else if (callStatus == 'ended') {
      durationColor = durationValue > 0 ? Colors.green : Colors.grey;
    }
    
    additionalWidget = Row(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: durationColor.withAlpha(25),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.timelapse,
            size: 14,
            color: durationColor,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'Duration: $callDuration'.tr(),
          style: TextStyle(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 13,
          ),
        ),
      ],
    );
    
    final nameParts = '${call['callerName']} → ${call['calleeName']}';
    
    return ChatListItemStyle2(
      name: nameParts,
      lastMessage: formattedTime,
      timeString: callType == 'video' ? 'Video Call'.tr() : 'Audio Call'.tr(),
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
      return '${duration.inHours}:${(duration.inMinutes % 60).toString().padLeft(2, '0')}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
    } else {
      return '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
    }
  }

  // Filter calls based on search query and selected filter
  List<Map<String, dynamic>> _filterCalls(List<Map<String, dynamic>> calls) {
    var filteredCalls = calls;
    
    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filteredCalls = calls.where((call) {
        final callerName = call['callerName'] as String;
        final calleeName = call['calleeName'] as String;
        final searchLower = _searchQuery.toLowerCase();
        return callerName.toLowerCase().contains(searchLower) || 
              calleeName.toLowerCase().contains(searchLower);
      }).toList();
    }
    
    // Apply status/time filters
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
    
    return filteredCalls;
  }
} 