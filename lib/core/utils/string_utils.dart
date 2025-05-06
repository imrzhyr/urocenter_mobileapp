/// String utilities for formatting and validation
class StringUtils {
  /// Check if a string is null or empty
  static bool isNullOrEmpty(String? str) {
    return str == null || str.trim().isEmpty;
  }
  
  /// Format phone number
  static String formatPhoneNumber(String phoneNumber) {
    // Remove any non-digit characters
    final digits = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    
    // If it doesn't start with +, assume it's a local number and add country code
    if (!phoneNumber.startsWith('+')) {
      return '+$digits';
    }
    
    return phoneNumber;
  }
  
  /// Format currency
  static String formatCurrency(num amount, {String currencySymbol = '\$'}) {
    return '$currencySymbol${amount.toStringAsFixed(2)}';
  }
  
  /// Format weight in kg
  static String formatWeight(double? weight) {
    if (weight == null) return 'N/A';
    return '${weight.toStringAsFixed(1)} kg';
  }
  
  /// Format height in cm
  static String formatHeight(double? height) {
    if (height == null) return 'N/A';
    return '${height.toStringAsFixed(1)} cm';
  }
  
  /// Format name (capitalize first letter of each word)
  static String formatName(String name) {
    if (isNullOrEmpty(name)) return '';
    
    return name.split(' ').map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }
  
  /// Get initials from a name (1-2 characters)
  static String getInitials(String name) {
    if (isNullOrEmpty(name)) return '?';
    
    final parts = name.trim().split(' ');
    if (parts.length == 1) {
      return parts[0].isNotEmpty ? parts[0][0].toUpperCase() : '?';
    }
    
    // Get first letter of first and last parts
    final firstInitial = parts.first.isNotEmpty ? parts.first[0].toUpperCase() : '';
    final lastInitial = parts.last.isNotEmpty ? parts.last[0].toUpperCase() : '';
    
    return '$firstInitial$lastInitial';
  }
  
  /// Format chat preview text (truncate and add ellipsis if needed)
  static String formatChatPreview(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }
  
  /// Validate email address
  static bool isValidEmail(String email) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email);
  }
  
  /// Validate password (min 8 chars, at least 1 letter and 1 number)
  static bool isValidPassword(String password) {
    if (password.length < 8) return false;
    
    final hasLetter = RegExp(r'[a-zA-Z]').hasMatch(password);
    final hasNumber = RegExp(r'[0-9]').hasMatch(password);
    
    return hasLetter && hasNumber;
  }
  
  /// Get password strength (0-4)
  static int getPasswordStrength(String password) {
    int strength = 0;
    
    if (password.length >= 8) strength++;
    if (RegExp(r'[a-z]').hasMatch(password)) strength++;
    if (RegExp(r'[A-Z]').hasMatch(password)) strength++;
    if (RegExp(r'[0-9]').hasMatch(password)) strength++;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) strength++;
    
    return strength;
  }
  
  /// Validate phone number
  static bool isValidPhoneNumber(String phoneNumber) {
    // Remove any non-digit characters
    final digits = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    
    // Special case for Iraqi numbers that might start with 0
    if (digits.startsWith('0')) {
      // Iraqi numbers starting with 0 should be 10-11 digits
      return digits.length >= 10 && digits.length <= 11;
    }
    
    // Basic check: should be at least 8 digits
    // (removed the requirement to start with + as it's already handled by the country code picker)
    return digits.length >= 8;
  }
  
  /// Format file size
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
  
  /// Format duration in seconds to mm:ss
  static String formatDuration(int seconds) {
    final minutes = (seconds / 60).floor();
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }
} 