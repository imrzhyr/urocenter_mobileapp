import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/haptic_utils.dart';
import '../../../core/theme/app_colors.dart';

class UserDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> userData;

  const UserDetailsScreen({
    super.key,
    required this.userData,
  });

  @override
  Widget build(BuildContext context) {
    final userName = userData['name'] as String;
    final email = userData['email'] as String;
    final phone = userData['phone'] as String;
    final joinDate = userData['joinDate'] as DateTime;
    final hasPaid = userData['paymentCompleted'] as bool;
    final hasCompletedOnboarding = userData['onboardingCompleted'] as bool;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    
    String userStatus;
    Color statusColor;
    
    if (hasPaid) {
      userStatus = 'common.paid'.tr();
      statusColor = isDarkMode ? AppColors.successDarkTheme : AppColors.success;
    } else if (hasCompletedOnboarding) {
      userStatus = 'common.active'.tr();
      statusColor = isDarkMode ? AppColors.warningDarkTheme : AppColors.warning;
    } else {
      userStatus = 'admin.new'.tr();
      statusColor = isDarkMode ? AppColors.primaryDarkTheme : theme.colorScheme.primary;
    }
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: theme.appBarTheme.backgroundColor,
        title: Text(
          'User Details'.tr(),
          style: theme.appBarTheme.titleTextStyle,
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.appBarTheme.iconTheme?.color),
          onPressed: () => Navigator.pop(context),
        ),
        systemOverlayStyle: isDarkMode ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // User profile header
            _buildProfileHeader(context, userName, email, phone, statusColor, userStatus),
            const SizedBox(height: 24),
            
            // User information section
            _buildInfoSection(context, 'Contact Information'.tr(), [
              if (email.isNotEmpty) _buildInfoItem(
                context,
                'Email'.tr(), 
                email, 
                Icons.email_outlined,
                onCopy: () => _copyToClipboard(context, email),
              ),
              if (phone.isNotEmpty) _buildInfoItem(
                context,
                'Phone'.tr(), 
                phone, 
                Icons.phone_outlined,
                onCopy: () => _copyToClipboard(context, phone),
              ),
              if (email.isEmpty && phone.isEmpty) _buildInfoItem(
                context,
                'Contact'.tr(),
                'No contact information available'.tr(),
                Icons.info_outline,
                textColor: Theme.of(context).colorScheme.error,
              ),
            ]),
            const SizedBox(height: 16),
            
            // Account information section
            _buildInfoSection(context, 'Account Information'.tr(), [
              _buildInfoItem(
                context,
                'User ID'.tr(),
                userData['id'] as String,
                Icons.perm_identity_outlined,
                onCopy: () => _copyToClipboard(context, userData['id'] as String),
              ),
              _buildInfoItem(
                context,
                'Joined'.tr(), 
                DateFormat('MMM d, yyyy').format(joinDate), 
                Icons.calendar_today_outlined,
              ),
              _buildInfoItem(
                context,
                'Payment Status'.tr(), 
                hasPaid ? 'Completed'.tr() : 'Pending'.tr(), 
                hasPaid ? Icons.check_circle_outline : Icons.pending_outlined,
                textColor: hasPaid 
                    ? (isDarkMode ? AppColors.successDarkTheme : AppColors.success)
                    : theme.colorScheme.error,
              ),
              _buildInfoItem(
                context,
                'Onboarding Status'.tr(), 
                hasCompletedOnboarding ? 'Completed'.tr() : 'Pending'.tr(), 
                hasCompletedOnboarding ? Icons.check_circle_outline : Icons.pending_outlined,
                textColor: hasCompletedOnboarding 
                    ? (isDarkMode ? AppColors.successDarkTheme : AppColors.success)
                    : (isDarkMode ? AppColors.warningDarkTheme : AppColors.warning),
              ),
              _buildInfoItem(
                context,
                'Account Status'.tr(),
                'common.active'.tr(),
                Icons.verified_user_outlined,
                textColor: statusColor,
              ),
              // Display sign-in method if available
              userData.containsKey('isGoogleUser') && userData['isGoogleUser'] == true
                ? _buildInfoItem(
                    context,
                    'Sign-in Method'.tr(),
                    'Google'.tr(),
                    Icons.login,
                    textColor: isDarkMode ? Colors.orangeAccent : Colors.orange,
                  )
                : userData.containsKey('providerId') && userData['providerId'] != null
                    ? _buildInfoItem(
                        context,
                        'Sign-in Method'.tr(),
                        userData['providerId'] == 'phone' ? 'Phone'.tr() : userData['providerId'],
                        userData['providerId'] == 'phone' ? Icons.phone_android : Icons.login,
                      )
                    : const SizedBox.shrink(),
            ]),
            const SizedBox(height: 16),
            
            // Medical information (mock data for demonstration)
            _buildInfoSection(context, 'Medical Information'.tr(), [
              _buildInfoItem(
                context,
                'Condition'.tr(),
                'Urological Consultation'.tr(),
                Icons.medical_services_outlined,
              ),
              _buildInfoItem(
                context,
                'Severity'.tr(),
                'Moderate'.tr(),
                Icons.priority_high_outlined,
                textColor: isDarkMode ? AppColors.warningDarkTheme : AppColors.warning,
              ),
              _buildInfoItem(
                context,
                'Treatment Stage'.tr(),
                'Initial Assessment'.tr(),
                Icons.timeline_outlined,
              ),
            ]),
            const SizedBox(height: 16),
            
            // Consultation history
            _buildConsultationHistory(context),
            const SizedBox(height: 16),
            
            // Payment details
            _buildPaymentDetails(context, hasPaid),
            const SizedBox(height: 24),
            
            // Action buttons
            _buildActionButtons(context),
          ],
        ),
      ),
    );
  }
  
  Widget _buildProfileHeader(BuildContext context, String name, String email, String phone, Color statusColor, String statusText) {
    final theme = Theme.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Column(
      children: [
        // Avatar
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                statusColor.withOpacity(isDarkMode ? 0.7 : 0.9),
                statusColor.withOpacity(isDarkMode ? 0.5 : 0.7),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : 'U',
              style: TextStyle(
                color: theme.colorScheme.onPrimary,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        
        // Name
        Text(
          name,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        
        // Email or Phone
        Text(
          email.isNotEmpty ? email : (phone.isNotEmpty ? phone : 'No contact information'.tr()),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        
        // Status badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(isDarkMode ? 0.2 : 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getStatusIcon(statusText),
                color: statusColor,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                statusText,
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  IconData _getStatusIcon(String status) {
    if (status == 'Paid'.tr()) {
      return Icons.check_circle;
    } else if (status == 'Active'.tr()) {
      return Icons.access_time;
    } else {
      return Icons.person_add;
    }
  }
  
  Widget _buildInfoSection(BuildContext context, String title, List<Widget> items) {
    final theme = Theme.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(isDarkMode ? 0.3 : 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          ...items,
        ],
      ),
    );
  }
  
  Widget _buildInfoItem(
    BuildContext context, 
    String label, 
    String value, 
    IconData icon, {
    Color? textColor,
    Function()? onCopy,
  }) {
    final theme = Theme.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final iconColor = textColor ?? (isDarkMode ? theme.colorScheme.primary : AppColors.primary);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(isDarkMode ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: textColor ?? theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          if (onCopy != null)
            IconButton(
              icon: Icon(
                Icons.copy,
                color: theme.colorScheme.onSurfaceVariant,
                size: 18,
              ),
              splashRadius: 20,
              onPressed: onCopy,
            ),
        ],
      ),
    );
  }
  
  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    HapticUtils.lightTap();
    
    final theme = Theme.of(context);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Copied to clipboard'.tr(),
          style: TextStyle(color: theme.colorScheme.onPrimary),
        ),
        backgroundColor: theme.colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }
  
  Widget _buildConsultationHistory(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(isDarkMode ? 0.3 : 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Consultation History'.tr(),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              TextButton(
                onPressed: () {
                  // View all consultations
                },
                child: Text(
                  'View All'.tr(),
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Consultation items
          _buildConsultationItem(
            context,
            'Dr. Ali Kamal',
            DateTime.now().subtract(const Duration(days: 2)),
            'Active',
          ),
          const Divider(),
          _buildConsultationItem(
            context,
            'Dr. Ali Kamal',
            DateTime.now().subtract(const Duration(days: 10)),
            'Completed',
          ),
        ],
      ),
    );
  }
  
  Widget _buildConsultationItem(
    BuildContext context,
    String doctorName,
    DateTime date,
    String status,
  ) {
    final theme = Theme.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    Color statusColor;
    if (status == 'Active') {
      statusColor = isDarkMode ? AppColors.primaryDarkTheme : theme.colorScheme.primary;
    } else if (status == 'Completed') {
      statusColor = isDarkMode ? AppColors.successDarkTheme : AppColors.success;
    } else {
      statusColor = isDarkMode ? AppColors.warningDarkTheme : AppColors.warning;
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: theme.colorScheme.primary.withOpacity(isDarkMode ? 0.3 : 0.1),
            child: Text(
              doctorName[0].toUpperCase(),
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doctorName,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  DateFormat('MMM d, yyyy').format(date),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(isDarkMode ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPaymentDetails(BuildContext context, bool hasPaid) {
    final theme = Theme.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(isDarkMode ? 0.3 : 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payment Details'.tr(),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          
          if (hasPaid) ...[
            _buildPaymentInfoItem(
              context,
              'Payment Status'.tr(),
              'Paid'.tr(),
              isDarkMode ? AppColors.successDarkTheme : AppColors.success,
            ),
            _buildPaymentInfoItem(
              context,
              'Amount'.tr(),
              'IQD 20,000,000',
              null,
            ),
            _buildPaymentInfoItem(
              context,
              'Date'.tr(),
              DateFormat('MMM d, yyyy').format(DateTime.now().subtract(const Duration(days: 5))),
              null,
            ),
            _buildPaymentInfoItem(
              context,
              'Method'.tr(),
              'Credit Card (Visa)',
              null,
            ),
          ] else ...[
            _buildPaymentInfoItem(
              context,
              'Payment Status'.tr(),
              'Pending'.tr(),
              isDarkMode ? AppColors.warningDarkTheme : AppColors.warning,
            ),
            _buildPaymentInfoItem(
              context,
              'Amount Due'.tr(),
              'IQD 20,000,000',
              null,
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildPaymentInfoItem(
    BuildContext context,
    String label,
    String value,
    Color? valueColor,
  ) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: valueColor ?? theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildActionButtons(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              // Open chat
              HapticUtils.lightTap();
            },
            icon: const Icon(Icons.chat_bubble_outline),
            label: Text('Message User'.tr()),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: 12),
        IconButton(
          icon: Icon(
            Icons.more_vert,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          onPressed: () {
            // Show more options menu
            _showActionsMenu(context);
          },
          style: IconButton.styleFrom(
            backgroundColor: isDarkMode ? theme.colorScheme.surfaceVariant : theme.colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: theme.colorScheme.outline.withOpacity(0.3),
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  void _showActionsMenu(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildActionItem(
                  context,
                  Icons.edit,
                  'Edit User'.tr(),
                  theme.colorScheme.primary,
                  () {
                    Navigator.pop(context);
                    // Edit user logic
                  },
                ),
                _buildActionItem(
                  context,
                  Icons.block,
                  'Block User'.tr(),
                  theme.colorScheme.error,
                  () {
                    Navigator.pop(context);
                    // Block user logic
                  },
                ),
                _buildActionItem(
                  context,
                  Icons.delete_outline,
                  'Delete User'.tr(),
                  theme.colorScheme.error,
                  () {
                    Navigator.pop(context);
                    // Delete user logic with confirmation
                    _showDeleteConfirmation(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildActionItem(
    BuildContext context,
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    final theme = Theme.of(context);
    
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Icon(
              icon,
              color: color,
              size: 24,
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: theme.textTheme.titleMedium?.copyWith(
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  void _showDeleteConfirmation(BuildContext context) {
    final theme = Theme.of(context);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete User?'.tr(),
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        content: Text(
          'This action cannot be undone. All user data will be permanently deleted.'.tr(),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel'.tr(),
              style: TextStyle(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Delete user logic
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            child: Text('Delete'.tr()),
          ),
        ],
      ),
    );
  }
} 