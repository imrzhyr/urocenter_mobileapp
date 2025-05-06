import 'package:flutter/material.dart';
import '../../../core/theme/theme.dart';

// Moved enum here as it's only used by this widget
enum Trend { up, down, none }

/// A Card widget to display a statistic with an icon and optional trend indicator.
class StatDisplayCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final Trend trend;

  const StatDisplayCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.trend = Trend.none,
  });

  @override
  Widget build(BuildContext context) {
    IconData trendIcon = Icons.remove;
    Color trendColor = Colors.grey;
    if (trend == Trend.up) {
       trendIcon = Icons.arrow_upward;
       trendColor = Colors.green;
    } else if (trend == Trend.down) {
       trendIcon = Icons.arrow_downward;
       trendColor = Colors.red;
    }
    
    // --- Refined Layout Revamp ---
    return Card(
      elevation: 2.0, 
      shadowColor: Colors.black.withValues(alpha: 20.0),
      clipBehavior: Clip.antiAlias, // Ensures border respects card's rounded corners
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Container(
        decoration: BoxDecoration(
          // Keep the accent border
          border: Border(
            left: BorderSide(color: color, width: 6.0), // Made border thicker
          ),
          color: Colors.white, // Solid white background inside the border
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0), // Adjusted padding
          child: Row( // Change main layout to Row
            children: [
              // Icon on the left
              CircleAvatar(
                radius: 22, // Slightly larger icon circle
                backgroundColor: color.withValues(alpha: 38.0),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 16.0), // Spacing between icon and text
              // Title and Value stacked vertically
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center, // Center vertically
                  children: [
                    // Title Text
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14, // Slightly smaller title
                        color: AppColors.textSecondary, 
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6), // Spacing between title and value
                    // Value Text + Trend
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center, // Align value and trend icon
                      children: [
                        Flexible( // Allow value text to wrap if needed (unlikely here)
                          child: Text(
                            value,
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith( 
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                              height: 1.1, 
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (trend != Trend.none)
                          Padding(
                            padding: const EdgeInsets.only(left: 6.0), // Adjusted padding
                            child: Icon(trendIcon, color: trendColor, size: 16), // Slightly smaller trend icon
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    // --- End Refined Layout Revamp ---
  }
} 