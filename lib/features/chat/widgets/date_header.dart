import 'package:flutter/material.dart';
import '../../../core/theme/theme.dart';

/// A widget that displays a date header for chat messages
class DateHeader extends StatelessWidget {
  final DateTime date;
  final String Function(DateTime) formatDate; // Function to format the date

  const DateHeader({
    super.key,
    required this.date,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 12.0),
          decoration: BoxDecoration(
            color: AppColors.accent.withAlpha(38),
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: Text(
            formatDate(date), // Use the passed formatting function
            style: const TextStyle(
              color: AppColors.accent,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
} 