import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../core/widgets/app_bar_style2.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/shimmer_loading.dart';
import 'admin_data_screen.dart';

class DetailedMetricsScreen extends ConsumerWidget {
  const DetailedMetricsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    // Watch user growth data
    final userGrowthAsync = ref.watch(userGrowthProvider);
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          // App Bar
          SliverToBoxAdapter(
            child: AppBarStyle2(
              title: "Detailed Metrics",
              showSearch: false,
              showFilters: false,
              showBackButton: true,
              showActionButtons: false,
            ),
          ),
          
          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User Growth Chart Section
                  Text(
                    "User Growth Trend",
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onBackground,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Monthly new user registrations",
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Main chart card - larger version
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: theme.shadowColor.withOpacity(isDarkMode ? 0.2 : 0.06),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Stats section at top of chart
                        userGrowthAsync.when(
                          data: (spots) {
                            // Calculate average monthly growth
                            double totalUsers = 0;
                            for (var spot in spots) {
                              totalUsers += spot.y;
                            }
                            final avgUsers = spots.isEmpty ? 0 : totalUsers / spots.length;
                            
                            // Find highest month
                            double highestValue = 0;
                            int highestMonth = 0;
                            
                            for (int i = 0; i < spots.length; i++) {
                              if (spots[i].y > highestValue) {
                                highestValue = spots[i].y;
                                highestMonth = i;
                              }
                            }
                            
                            // Get month name for the highest month
                            final now = DateTime.now();
                            final highestMonthDate = DateTime(now.year, now.month - 5 + highestMonth, 1);
                            final highestMonthName = DateFormat('MMMM').format(highestMonthDate);
                            
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildStatItem(
                                  title: "Average Monthly",
                                  value: avgUsers.toStringAsFixed(1),
                                  theme: theme,
                                ),
                                _buildStatItem(
                                  title: "Highest Month",
                                  value: "$highestMonthName (${highestValue.toInt()})",
                                  theme: theme,
                                ),
                                _buildStatItem(
                                  title: "Total Users",
                                  value: totalUsers.toInt().toString(),
                                  theme: theme,
                                ),
                              ],
                            );
                          },
                          loading: () => const ShimmerLoading(
                            child: SizedBox(height: 50, width: double.infinity),
                          ),
                          error: (_, __) => Center(
                            child: Text(
                              "Error loading data",
                              style: TextStyle(color: theme.colorScheme.error),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Larger chart
                        SizedBox(
                          height: 300, // Taller chart for more detail
                          child: userGrowthAsync.when(
                            data: (spots) => LineChart(
                              LineChartData(
                                minY: 0,
                                gridData: FlGridData(
                                  show: true,
                                  drawVerticalLine: true, // Show vertical grid lines too
                                  horizontalInterval: 1,
                                  verticalInterval: 1,
                                  getDrawingHorizontalLine: (value) => FlLine(
                                    color: theme.colorScheme.outline.withOpacity(0.2),
                                    strokeWidth: 1,
                                  ),
                                  getDrawingVerticalLine: (value) => FlLine(
                                    color: theme.colorScheme.outline.withOpacity(0.1),
                                    strokeWidth: 1,
                                  ),
                                ),
                                titlesData: FlTitlesData(
                                  show: true,
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      interval: 1,
                                      reservedSize: 40,
                                      getTitlesWidget: (value, meta) {
                                        if (value == value.roundToDouble()) {
                                          return Text(
                                            value.toInt().toString(),
                                            style: theme.textTheme.bodySmall?.copyWith(
                                              color: theme.colorScheme.onSurfaceVariant,
                                            ),
                                          );
                                        }
                                        return const SizedBox();
                                      },
                                    ),
                                  ),
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      interval: 1,
                                      getTitlesWidget: (value, meta) {
                                        final now = DateTime.now();
                                        final monthLabels = List.generate(6, (index) {
                                          final month = DateTime(now.year, now.month - 5 + index, 1);
                                          return DateFormat('MMM').format(month);
                                        });
                                        
                                        if (value.toInt() >= 0 && value.toInt() < monthLabels.length) {
                                          return Padding(
                                            padding: const EdgeInsets.only(top: 8.0),
                                            child: Text(
                                              monthLabels[value.toInt()],
                                              style: theme.textTheme.bodySmall?.copyWith(
                                                color: theme.colorScheme.onSurfaceVariant,
                                              ),
                                            ),
                                          );
                                        }
                                        return const SizedBox();
                                      },
                                    ),
                                  ),
                                  rightTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                  topTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                ),
                                borderData: FlBorderData(show: false),
                                lineBarsData: [
                                  LineChartBarData(
                                    spots: spots,
                                    isCurved: false,
                                    color: theme.colorScheme.primary,
                                    barWidth: 3,
                                    isStrokeCapRound: true,
                                    dotData: FlDotData(
                                      show: true,
                                      getDotPainter: (spot, percent, barData, index) {
                                        return FlDotCirclePainter(
                                          radius: 5,
                                          color: theme.colorScheme.primary,
                                          strokeWidth: 2,
                                          strokeColor: theme.colorScheme.surface,
                                        );
                                      },
                                    ),
                                    belowBarData: BarAreaData(
                                      show: true,
                                      color: theme.colorScheme.primary.withOpacity(0.2),
                                      cutOffY: 0,
                                      applyCutOffY: true,
                                    ),
                                  ),
                                ],
                                lineTouchData: LineTouchData(
                                  touchTooltipData: LineTouchTooltipData(
                                    getTooltipColor: (touchedSpot) => isDarkMode 
                                        ? theme.colorScheme.surfaceContainerHighest 
                                        : theme.colorScheme.background,
                                    getTooltipItems: (touchedSpots) {
                                      return touchedSpots.map((touchedSpot) {
                                        final now = DateTime.now();
                                        final month = DateTime(
                                          now.year, 
                                          now.month - 5 + touchedSpot.x.toInt(), 
                                          1
                                        );
                                        final monthName = DateFormat('MMMM').format(month);
                                        
                                        return LineTooltipItem(
                                          "$monthName: ${touchedSpot.y.toInt()}",
                                          TextStyle(
                                            color: theme.colorScheme.onSurface,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        );
                                      }).toList();
                                    },
                                  ),
                                ),
                              ),
                            ),
                            loading: () => const ShimmerLoading(
                              child: SizedBox.expand(),
                            ),
                            error: (_, __) => Center(
                              child: Text(
                                "Failed to load chart data",
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.error,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Explanation section
                  Text(
                    "Analytics Insights",
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onBackground,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  _buildInsightCard(
                    title: "User Growth Analysis",
                    content: "This chart shows the number of new user registrations each month for the past 6 months. The trend helps identify growth patterns and can be correlated with marketing campaigns or feature releases.",
                    icon: Icons.insights,
                    theme: theme,
                    isDarkMode: isDarkMode,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  _buildInsightCard(
                    title: "Growth Recommendations",
                    content: "To improve user growth, consider implementing user referral programs, optimizing onboarding processes, or creating targeted marketing campaigns based on peak registration periods.",
                    icon: Icons.trending_up,
                    theme: theme,
                    isDarkMode: isDarkMode,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatItem({
    required String title,
    required String value,
    required ThemeData theme,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
  
  Widget _buildInsightCard({
    required String title,
    required String content,
    required IconData icon,
    required ThemeData theme,
    required bool isDarkMode,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(isDarkMode ? 0.2 : 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: theme.colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
} 