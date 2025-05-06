import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart'; // For back navigation
import 'package:flutter_riverpod/flutter_riverpod.dart'; // <<< ADDED Riverpod
import 'package:firebase_auth/firebase_auth.dart'; // <<< ADDED Firebase Auth
import 'package:easy_localization/easy_localization.dart'; // Added for localization
import '../../../providers/service_providers.dart'; // <<< ADDED Service Providers
import '../../../app/routes.dart'; // <<< ADDED RouteNames import >>>
import 'package:urocenter/core/utils/logger.dart';
// import '../../../core/widgets/app_scaffold.dart'; // No longer needed
import '../../../core/theme/theme.dart';
import '../../../core/utils/error_handler.dart'; // <<< ADDED Error Handler
import '../../../core/utils/haptic_utils.dart';
import '../../../core/widgets/circular_loading_indicator.dart';

// Removed typedef, will use Map<String, dynamic>
// typedef MedicalHistoryData = Map<String, dynamic>; 

class MedicalHistoryViewScreen extends ConsumerStatefulWidget { // <<< CHANGED to Consumer
  const MedicalHistoryViewScreen({super.key});

  @override
  ConsumerState<MedicalHistoryViewScreen> createState() => _MedicalHistoryViewScreenState(); // <<< CHANGED to ConsumerState
}

class _MedicalHistoryViewScreenState extends ConsumerState<MedicalHistoryViewScreen> 
    with SingleTickerProviderStateMixin {
  
  // --- State Variables ---
  bool _isLoading = true;
  Map<String, dynamic>? _medicalHistoryData;
  String? _error;
  
  // Animation controller for staggered animations
  late AnimationController _animationController;
  
  @override
  void initState() {
    super.initState();
    
    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    // Use WidgetsBinding to load data after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMedicalHistory();
    });
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // --- Data Fetching ---
  Future<void> _loadMedicalHistory({bool isRefresh = false}) async {
    if (!mounted) return;
    // Keep previous data visible during refresh, only show loading initially
    if (!isRefresh) { 
       setState(() {
         _isLoading = true;
         _error = null;
         _medicalHistoryData = null; // Clear previous data on initial load
       });
    }

    try {
      final userProfileService = ref.read(userProfileServiceProvider);
      final userId = FirebaseAuth.instance.currentUser?.uid;

      if (userId == null) {
        throw Exception("User not logged in.");
      }
      
      AppLogger.d("Fetching profile for user: $userId");
      final profileData = await userProfileService.getUserProfile(userId);
      AppLogger.d("Fetched profile data: $profileData");

      Map<String, dynamic>? historyData;
      if (profileData != null && profileData.containsKey('medicalHistory')) {
        // Ensure the extracted data is actually a Map
        final potentialHistory = profileData['medicalHistory'];
        if (potentialHistory is Map) {
           historyData = Map<String, dynamic>.from(potentialHistory);
           AppLogger.d("Extracted medical history: $historyData");
        } else {
           AppLogger.d("Medical history field found but is not a Map: $potentialHistory");
           // Treat as no history found if format is wrong
        }
      } else {
         AppLogger.d("Profile data is null or does not contain medicalHistory key.");
      }

      if (mounted) {
        setState(() {
          _medicalHistoryData = historyData; // Assign extracted history data (or null)
          _isLoading = false;
          _error = null; // Clear error on successful fetch (even if data is null)
        });
        
        // Start animation when data is loaded
        if (historyData != null) {
          _animationController.forward();
        }
      }
    } catch (e) {
      AppLogger.e("Error loading medical history: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = ErrorHandler.handleError(e); // Use error handler
        });
      }
    }
  }
  // --- End Data Fetching ---

  @override
  Widget build(BuildContext context) {
    return Scaffold( // Use standard Scaffold
      // Use theme's scaffold background color
      backgroundColor: Theme.of(context).scaffoldBackgroundColor, 
      appBar: AppBar(
        title: Text('medical_history.title'.tr()), // Localized
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios), // Color inherited from iconTheme
          onPressed: () => context.pop(), // Use pop for back
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined), // Color inherited from actionsIconTheme
            tooltip: 'medical_history.edit'.tr(), // Localized
            onPressed: () {
              HapticUtils.lightTap();
              // TODO: Implement navigation to an edit screen (matching onboarding structure)
              AppLogger.d('Navigate to Edit Medical History Screen');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('medical_history.edit_coming_soon'.tr())) // Localized
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadMedicalHistory(isRefresh: true),
        child: _buildBodyContent(),
      ),
    );
  }

  // --- Body Content Builder ---
  Widget _buildBodyContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppColors.error, size: 48),
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: AppColors.error), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _loadMedicalHistory(),
                child: Text('common.retry'.tr()), // Localized
              ),
            ],
          ),
        ),
      );
    }

    if (_medicalHistoryData == null) {
      // Handle case where data is fetched but is null/empty (optional, based on backend logic)
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.info_outline, size: 64, color: AppColors.textSecondary),
              const SizedBox(height: 16),
              Text(
                'medical_history.no_history'.tr(), // Localized
                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
               const SizedBox(height: 16),
              ElevatedButton( // Maybe allow editing even if empty?
                onPressed: () { /* TODO: Navigate to edit */ AppLogger.d('Navigate to Edit Medical History'); },
                child: Text('medical_history.add_history'.tr()), // Localized
              ),
            ],
          ),
        ),
      );
    }

    // If data exists, display it
    return _buildMedicalHistoryDetails(_medicalHistoryData!);
  }
  // --- End Body Content Builder ---

  // --- Helper Icon Function (Class method, NOT static) ---
  IconData _getConditionIcon(String condition) {
    condition = condition.toLowerCase();
    
    if (condition.contains('heart') || condition.contains('cardiac')) {
      return Icons.favorite;
    } else if (condition.contains('diabetes') || condition.contains('blood sugar')) {
      return Icons.bloodtype;
    } else if (condition.contains('lung') || condition.contains('breath') || 
               condition.contains('asthma') || condition.contains('respiratory')) {
      return Icons.air;
    } else if (condition.contains('kidney') || condition.contains('renal')) {
      return Icons.water_drop;
    } else if (condition.contains('cancer') || condition.contains('tumor')) {
      return Icons.medical_services;
    } else if (condition.contains('surgery') || condition.contains('operation')) {
      return Icons.healing;
    } else if (condition.contains('injury') || condition.contains('fracture') || 
               condition.contains('broken')) {
      return Icons.healing;
    } else if (condition.contains('allergy') || condition.contains('allergic')) {
      return Icons.sick;
    }
    
    // Default icon
    return Icons.health_and_safety;
  }
  // --- End Helper Icon Function ---

  // --- Medical History Details Widget (UPDATED) ---
  Widget _buildMedicalHistoryDetails(Map<String, dynamic> data) {
    final textTheme = Theme.of(context).textTheme;
    
    // <<< UPDATED Data extraction >>>
    final List<String> conditions = List<String>.from(data['conditions'] ?? []);
    final String otherConditionsText = data['otherConditions'] ?? '';
    final String medications = data['medications'] ?? 'Not specified';
    final String allergies = data['allergies'] ?? 'Not specified';
    final String surgicalHistory = data['surgicalHistory'] ?? 'Not specified';
    final String? medicationDocumentUrl = data['medicationDocumentUrl'] as String?;
    // Note: lastUpdated is not in the saved data currently, can add later if needed
    // final lastUpdated = data['lastUpdated'] as DateTime?;

    // --- Start Helper Functions ---
    
    // Helper for simple text content (handles 'None' or empty)
    Widget buildTextContent(String text) {
       final bool isNone = text.trim().toLowerCase() == 'none';
       final bool isEmpty = text.trim().isEmpty;
       final bool isNotSpecified = text.trim().toLowerCase() == 'not specified';

      if (isEmpty || isNotSpecified) {
        return Text('medical_history.not_specified'.tr(), style: textTheme.bodyMedium?.copyWith(color: AppColors.textTertiary, fontStyle: FontStyle.italic)); // Localized
      }
      if (isNone) {
         return Text('medical_history.none'.tr(), style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w500)); // Localized
      }
      // REMOVED: Document Uploaded text handling (not applicable here)
      // if (text.startsWith('Document Uploaded:')) { ... }

      return Text(text, style: textTheme.bodyMedium?.copyWith(height: 1.5));
    }

    // Helper for list content (e.g., conditions) using Chips
    Widget buildChipListContent(List<String>? items) {
      if (items == null || items.isEmpty) {
        return Text('medical_history.none_specified'.tr(), style: textTheme.bodyMedium?.copyWith(color: AppColors.textTertiary, fontStyle: FontStyle.italic)); // Localized
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 10.0),
          child: Chip(
            label: Text(item),
            avatar: Icon(_getConditionIcon(item), size: 20, color: AppColors.primary),
            backgroundColor: AppColors.primaryLight.withAlpha(26), // 0.1 * 255 ~= 26
            labelStyle: textTheme.bodyMedium?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w500),
            side: BorderSide(color: AppColors.primary.withAlpha(51)), // 0.2 * 255 ~= 51
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            labelPadding: const EdgeInsets.symmetric(horizontal: 4),
          ),
        )).toList(),
      );
    }
    
    // --- End Helper Functions ---

    // --- Build the main layout ---
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Conditions Section ---
          _buildAnimatedCard(
            index: 0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                 Row(
                   children: [
                      const Icon(Icons.list_alt_outlined, color: AppColors.primary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'medical_history.reported_conditions'.tr(), // Localized
                        style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600, color: AppColors.primary),
                      ),
                   ],
                 ),
                const SizedBox(height: 12.0),
                Padding(
                   padding: const EdgeInsets.only(left: 28.0), // Indent content
                   // <<< UPDATED conditions check >>>
                   child: conditions.isEmpty && otherConditionsText.isEmpty 
                    ? Text('medical_history.none_specified'.tr(), style: textTheme.bodyMedium?.copyWith(color: AppColors.textTertiary, fontStyle: FontStyle.italic)) // Localized
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (conditions.isNotEmpty)
                             buildChipListContent(conditions),
                          if (otherConditionsText.isNotEmpty && conditions.isNotEmpty) 
                            const SizedBox(height: 12.0), // Add space if both exist
                          if (otherConditionsText.isNotEmpty) ...[
                             Text('medical_history.other_conditions'.tr(), style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)), // Localized
                             const SizedBox(height: 4.0),
                             buildTextContent(otherConditionsText), // Display the text entered for "Other"
                          ],
                        ],
                      ),
                ),
              ],
            ),
          ),
          // --- End Conditions Section ---

          _buildAnimatedCard(
            index: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader(
                  title: 'medical_history.current_medications'.tr(),
                  icon: Icons.medication_outlined,
                ),
                const SizedBox(height: 16),
                _buildTextContent(medications),
                
                if (medicationDocumentUrl != null && medicationDocumentUrl.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () {
                      HapticUtils.lightTap();
                      context.pushNamed(RouteNames.imageViewer, extra: {'imagePath': medicationDocumentUrl});
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12.0),
                          child: Image.network(
                            medicationDocumentUrl,
                            height: 120,
                            width: 120,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                height: 120,
                                width: 120,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surfaceVariant.withAlpha(26),
                                  borderRadius: BorderRadius.circular(12.0),
                                ),
                                child: const Center(
                                  child: CircularLoadingIndicator(
                                    strokeWidth: 2
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                height: 120,
                                width: 120,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surfaceVariant.withAlpha(26),
                                  borderRadius: BorderRadius.circular(12.0),
                                ),
                                child: const Icon(
                                  Icons.broken_image_outlined,
                                  color: AppColors.textSecondary,
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'medical_history.tap_photo'.tr(),
                          style: textTheme.bodySmall?.copyWith(color: AppColors.textTertiary),
                        ),
                      ],
                    ),
                  ),
                ]
              ],
            ),
          ),
          _buildAnimatedCard(
            index: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader(
                  title: 'medical_history.allergies'.tr(),
                  icon: Icons.warning_amber_rounded,
                ),
                const SizedBox(height: 16),
                _buildTextContent(allergies),
              ],
            ),
          ),
          _buildAnimatedCard(
            index: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader(
                  title: 'medical_history.surgical_history'.tr(),
                  icon: Icons.content_cut_rounded,
                ),
                const SizedBox(height: 16),
                _buildTextContent(surgicalHistory),
              ],
            ),
          ),
          
           // Optional: Display last updated time (if added later)
           // if (lastUpdated != null)
           //   ...
        ],
      ),
    );
  }
  
  // --- Helper Widgets ---
  
  // Animated card with staggered entry
  Widget _buildAnimatedCard({required int index, required Widget child}) {
    // Create staggered animation for this card
    final Animation<double> animation = CurvedAnimation(
      parent: _animationController,
      curve: Interval(
        0.1 * index, // Start delay based on index
        0.1 * index + 0.6, // End at 60% of the animation duration
        curve: Curves.easeOutQuart,
      ),
    );
    
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - animation.value)),
          child: Opacity(
            opacity: animation.value,
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withAlpha(77)),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).shadowColor.withAlpha(Theme.of(context).brightness == Brightness.light ? 26 : 51),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    HapticUtils.lightTap();
                    // Tap animation or expansion could be added here
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        );
      },
      child: child,
    );
  }
  
  // Section header with icon
  Widget _buildSectionHeader({required String title, required IconData icon}) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 24),
        const SizedBox(width: 12),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }
  
  // Text content with formatting
  Widget _buildTextContent(String text) {
    final bool isNone = text.trim().toLowerCase() == 'none';
    final bool isEmpty = text.trim().isEmpty;
    final bool isNotSpecified = text.trim().toLowerCase() == 'not specified';

    if (isEmpty || isNotSpecified) {
      return Text(
        'medical_history.not_specified'.tr(),
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColors.textTertiary,
          fontStyle: FontStyle.italic,
        ),
      );
    }
    
    if (isNone) {
      return Text(
        'medical_history.none'.tr(),
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w500,
        ),
      );
    }

    return Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
    );
  }
} 
