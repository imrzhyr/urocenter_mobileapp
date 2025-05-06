import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/theme.dart';
import '../../../core/models/user_model.dart';

/// Widget for displaying recent users in admin dashboard
class AdminRecentUsers extends StatefulWidget {
  const AdminRecentUsers({super.key});

  @override
  State<AdminRecentUsers> createState() => _AdminRecentUsersState();
}

class _AdminRecentUsersState extends State<AdminRecentUsers> {
  final List<User> _recentUsers = [];
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadRecentUsers();
  }
  
  Future<void> _loadRecentUsers() async {
    // TODO: Implement actual data loading
    await Future.delayed(const Duration(milliseconds: 800));
    
    if (mounted) {
      setState(() {
        _recentUsers.addAll([
          User(
            id: '1',
            fullName: 'Ahmed Ali',
            phoneNumber: '+966501234567',
            isVerified: true,
            onboardingCompleted: true,
            age: 45,
            gender: 'Male',
            createdAt: DateTime.now().subtract(const Duration(days: 2)),
          ),
          User(
            id: '2',
            fullName: 'Sarah Johnson',
            phoneNumber: '+1234567890',
            isVerified: true,
            onboardingCompleted: true,
            age: 38,
            gender: 'Female',
            createdAt: DateTime.now().subtract(const Duration(days: 3)),
          ),
          User(
            id: '3',
            fullName: 'Mohammed Hassan',
            phoneNumber: '+966505551234',
            isVerified: false,
            onboardingCompleted: false,
            age: 52,
            gender: 'Male',
            createdAt: DateTime.now().subtract(const Duration(days: 5)),
          ),
          User(
            id: '4',
            fullName: 'John Smith',
            phoneNumber: '+1987654321',
            isVerified: true,
            onboardingCompleted: true,
            age: 41,
            gender: 'Male',
            createdAt: DateTime.now().subtract(const Duration(days: 7)),
          ),
        ]);
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    
    if (_recentUsers.isEmpty) {
      return const Center(
        child: Text('No recent users found'),
      );
    }
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor.withValues(alpha: 13),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Table header
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: Text(
                    'Name',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Phone',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Status',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Joined',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
              ],
            ),
          ),
          
          const Divider(height: 1),
          
          // Table rows
          ...List.generate(_recentUsers.length, (index) {
            final user = _recentUsers[index];
            return _buildUserRow(context, user);
          }),
        ],
      ),
    );
  }
  
  Widget _buildUserRow(BuildContext context, User user) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: AppColors.divider,
            width: 1,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.primary.withValues(alpha: 26),
            child: Text(
              user.fullName.substring(0, 1).toUpperCase(),
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          
          // Name
          Expanded(
            flex: 3,
            child: Text(
              user.fullName,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          
          // Phone
          Expanded(
            flex: 2,
            child: Text(
              user.phoneNumber,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          
          // Status
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: user.isVerified 
                    ? AppColors.success.withValues(alpha: 26)
                    : AppColors.warning.withValues(alpha: 26),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                user.isVerified ? 'Verified' : 'Pending',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: user.isVerified ? AppColors.success : AppColors.warning,
                ),
              ),
            ),
          ),
          
          // Joined date
          Expanded(
            flex: 2,
            child: Text(
              DateFormat('MMM d, yyyy').format(user.createdAt),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          
          // Actions
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
            onSelected: (value) {
              // TODO: Implement actions
              if (value == 'view') {
                // View user details
              } else if (value == 'edit') {
                // Edit user
              } else if (value == 'delete') {
                // Delete user
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'view',
                child: Row(
                  children: [
                    Icon(Icons.visibility, size: 18),
                    SizedBox(width: 8),
                    Text('View'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit, size: 18),
                    SizedBox(width: 8),
                    Text('Edit'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, size: 18, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
} 