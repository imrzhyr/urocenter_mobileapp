import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;

/// Date utilities for formatting and calculations
class AppDateUtils {
  /// Format date as "MMM d, yyyy" (e.g. "Jan 1, 2022")
  static String formatDate(DateTime date) {
    return DateFormat('MMM d, yyyy').format(date);
  }
  
  /// Format date as "MMM d, yyyy, h:mm a" (e.g. "Jan 1, 2022, 3:30 PM")
  static String formatDateWithTime(DateTime date) {
    return DateFormat('MMM d, yyyy, h:mm a').format(date);
  }
  
  /// Format time as "h:mm a" (e.g. "3:30 PM")
  static String formatTime(DateTime time) {
    return DateFormat('h:mm a').format(time);
  }
  
  /// Format date for chat display
  /// 
  /// - Today: shows time only (e.g. "3:30 PM")
  /// - This year: shows month and day (e.g. "Jan 1")
  /// - Previous years: shows month, day, and year (e.g. "Jan 1, 2021")
  static String formatChatTime(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(date.year, date.month, date.day);
    
    if (messageDate == today) {
      // Today, show only time
      return DateFormat('h:mm a').format(date);
    } else if (messageDate.year == today.year) {
      // This year, show month and day
      return DateFormat('MMM d').format(date);
    } else {
      // Previous years, show month, day, and year
      return DateFormat('MMM d, y').format(date);
    }
  }
  
  /// Format date as relative time (e.g. "5 minutes ago", "2 days ago")
  static String formatRelativeTime(DateTime date) {
    return timeago.format(date);
  }
  
  /// Format date as relative time in Arabic
  static String formatRelativeTimeAr(DateTime date) {
    return timeago.format(date, locale: 'ar');
  }
  
  /// Format date as relative time with a custom locale
  static String formatRelativeTimeLocalized(DateTime date, String locale) {
    return timeago.format(date, locale: locale);
  }
  
  /// Check if a date is today
  static bool isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }
  
  /// Check if a date is yesterday
  static bool isYesterday(DateTime date) {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    return date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day;
  }
  
  /// Calculate age based on birthdate
  static int calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    int age = now.year - birthDate.year;
    
    // Adjust age if birthday hasn't occurred yet this year
    final birthDateThisYear = DateTime(now.year, birthDate.month, birthDate.day);
    if (now.isBefore(birthDateThisYear)) {
      age--;
    }
    
    return age;
  }
  
  /// Get date range as formatted string
  static String getDateRangeString(DateTime startDate, DateTime endDate) {
    if (startDate.year == endDate.year && startDate.month == endDate.month) {
      // Same month and year
      return '${DateFormat('MMM d').format(startDate)} - ${DateFormat('d, y').format(endDate)}';
    } else if (startDate.year == endDate.year) {
      // Same year but different months
      return '${DateFormat('MMM d').format(startDate)} - ${DateFormat('MMM d, y').format(endDate)}';
    } else {
      // Different years
      return '${DateFormat('MMM d, y').format(startDate)} - ${DateFormat('MMM d, y').format(endDate)}';
    }
  }
  
  /// Check if a date is within the last 7 days
  static bool isWithinLastWeek(DateTime date) {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    return date.isAfter(weekAgo);
  }
  
  /// Format date as day name (e.g. "Monday")
  static String formatDayName(DateTime date) {
    return DateFormat('EEEE').format(date);
  }
  
  /// Format date as localized day name
  static String formatDayNameLocalized(DateTime date, String locale) {
    return DateFormat('EEEE', locale).format(date);
  }
  
  /// Initialize timeago for multiple languages
  static void initializeTimeagoLocales() {
    timeago.setLocaleMessages('ar', timeago.ArMessages());
    timeago.setLocaleMessages('en', timeago.EnMessages());
  }

  /// Format date as "Month Day, Year" (e.g. "January 1, 2023")
  static String formatFullDate(DateTime date) {
    return DateFormat.yMMMMd().format(date);
  }
  
  /// Format date as "Month Day" (e.g. "January 1")
  static String formatMonthDay(DateTime date) {
    return DateFormat.MMMMd().format(date);
  }
  
  /// Format date as "MM/DD/YYYY" (e.g. "01/01/2023")
  static String formatShortDate(DateTime date) {
    return DateFormat.yMd().format(date);
  }
  
  /// Format date and time as "Month Day, Year at Hour:Minute AM/PM" (e.g. "January 1, 2023 at 2:30 PM")
  static String formatFullDateTime(DateTime date) {
    return '${formatFullDate(date)} at ${formatTime(date)}';
  }
  
  /// Format date for chat messages with relative time if recent
  static String formatMessageTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 365) {
      // More than a year ago
      return formatFullDate(date);
    } else if (difference.inDays > 6) {
      // More than a week ago
      return formatShortDate(date);
    } else if (difference.inDays > 0) {
      // More than a day ago but less than a week
      final weekday = DateFormat.E().format(date);
      return '$weekday, ${formatTime(date)}';
    } else if (difference.inHours > 0) {
      // Today but more than an hour ago
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      // Less than an hour ago
      return '${difference.inMinutes}m ago';
    } else {
      // Just now
      return 'Just now';
    }
  }
} 