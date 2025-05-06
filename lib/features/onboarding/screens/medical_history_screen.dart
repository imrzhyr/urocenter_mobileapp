import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import FirebaseAuth
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
import 'package:easy_localization/easy_localization.dart'; // Import for translations
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/utils/utils.dart';
import '../../../app/routes.dart';
import '../widgets/onboarding_progress.dart';
import 'dart:math' as math;
import '../providers/onboarding_providers.dart';
import '../widgets/upload_document_tile.dart';
import 'dart:io';
import '../../../providers/service_providers.dart'; // Import service providers
import '../../../core/constants/app_constants.dart'; // Import for onboarding steps
import '../../../core/utils/haptic_utils.dart'; 
import 'package:urocenter/core/utils/logger.dart';

// Define icons for conditions and sections
final Map<String, IconData> _conditionIcons = {
  'Diabetes': Icons.water_drop_outlined,
  'Hypertension': Icons.monitor_heart_outlined,
  'Heart Disease': Icons.favorite_border,
  'Cancer': Icons.healing_outlined, // Changed from ribbon_outlined
  'Other Conditions': Icons.help_outline_rounded,
};

const IconData _medicationsIcon = Icons.medication_outlined;
const IconData _allergiesIcon = Icons.warning_amber_rounded;
const IconData _surgeryIcon = Icons.content_cut_rounded;

/// Medical history screen for onboarding
class MedicalHistoryScreen extends ConsumerStatefulWidget {
  const MedicalHistoryScreen({super.key});

  @override
  ConsumerState<MedicalHistoryScreen> createState() => _MedicalHistoryScreenState();
}

class _MedicalHistoryScreenState extends ConsumerState<MedicalHistoryScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _medicalConditionsController = TextEditingController();
  final _medicationsController = TextEditingController();
  final _allergiesController = TextEditingController();
  final _surgicalHistoryController = TextEditingController();
  
  // Focus Nodes
  final _otherConditionsFocus = FocusNode();
  final _medicationsFocus = FocusNode();
  final _allergiesFocus = FocusNode();
  final _surgicalHistoryFocus = FocusNode();

  Map<String, bool> _conditions = {
    'Diabetes': false,
    'Hypertension': false,
    'Heart Disease': false,
    'Cancer': false,
    'Other Conditions': false,
  };
  bool _isLoading = false;
  bool _isExiting = false;
  bool _isAttaching = false;
  UploadedDocument? _medicationDocument;
  
  // State flags for "None" selections
  bool _hasNoMedications = false;
  bool _hasNoAllergies = false;
  bool _hasNoSurgicalHistory = false;
  
  // Animation controllers
  late final List<AnimationController> _animControllers = [];
  late final List<Animation<Offset>> _slideAnimations = [];
  late final List<Animation<double>> _scaleAnimations = [];
  
  @override
  void initState() {
    super.initState();
    _setupAnimations();
    
    // Add listeners for text fields to update button state and clear "None" flags
    _medicationsController.addListener(_onMedicationsTextChanged);
    _allergiesController.addListener(_onAllergiesTextChanged);
    _surgicalHistoryController.addListener(_onSurgicalHistoryTextChanged);
    
    // Initialize button state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateButtonState(); 
    });
  }

  void _setupAnimations() {
    // Total animated elements: 6 (Headers, Conditions block, 3 text fields, Button)
    const int totalElements = 7; 
    
    for (int i = 0; i < totalElements; i++) {
      final controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 500),
      );
      
      final slideAnimation = Tween<Offset>(
        begin: const Offset(0, 0.3), // Start from bottom
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: controller,
        curve: Curves.easeOutQuad, // Smooth curve
      ));
      
      final scaleAnimation = Tween<double>(
        begin: 0.95, // Slight scale up
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: controller,
        curve: Curves.easeOutQuad,
      ));
      
      _animControllers.add(controller);
      _slideAnimations.add(slideAnimation);
      _scaleAnimations.add(scaleAnimation);
      
      // Stagger the animations
      Future.delayed(Duration(milliseconds: 150 * i), () {
        if (mounted) controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _medicalConditionsController.dispose();
    _medicationsController.removeListener(_onMedicationsTextChanged);
    _medicationsController.dispose();
    _allergiesController.removeListener(_onAllergiesTextChanged);
    _allergiesController.dispose();
    _surgicalHistoryController.removeListener(_onSurgicalHistoryTextChanged);
    _surgicalHistoryController.dispose();
    
    // Dispose focus nodes
    _otherConditionsFocus.dispose();
    _medicationsFocus.dispose();
    _allergiesFocus.dispose();
    _surgicalHistoryFocus.dispose();
    for (var controller in _animControllers) {
      controller.dispose();
    }
    super.dispose();
  }
  
  // --- Listener methods for text fields ---
  void _onMedicationsTextChanged() {
    if (_medicationsController.text.isNotEmpty && _hasNoMedications) {
      setState(() => _hasNoMedications = false);
    }
    _updateButtonState();
  }

  void _onAllergiesTextChanged() {
    if (_allergiesController.text.isNotEmpty && _hasNoAllergies) {
      setState(() => _hasNoAllergies = false);
    }
     _updateButtonState();
  }

  void _onSurgicalHistoryTextChanged() {
    if (_surgicalHistoryController.text.isNotEmpty && _hasNoSurgicalHistory) {
      setState(() => _hasNoSurgicalHistory = false);
    }
    _updateButtonState();
  }

  // --- Toggle methods for "None" buttons ---
  void _toggleNoMedications() {
    HapticUtils.lightTap();
    setState(() {
      _hasNoMedications = !_hasNoMedications;
      if (_hasNoMedications) _medicationsController.clear();
    });
    _updateButtonState();
  }
  
  void _toggleNoAllergies() {
    HapticUtils.lightTap();
    setState(() {
      _hasNoAllergies = !_hasNoAllergies;
      if (_hasNoAllergies) _allergiesController.clear();
    });
    _updateButtonState();
  }

  void _toggleNoSurgicalHistory() {
    HapticUtils.lightTap();
    setState(() {
      _hasNoSurgicalHistory = !_hasNoSurgicalHistory;
      if (_hasNoSurgicalHistory) _surgicalHistoryController.clear();
    });
    _updateButtonState();
  }
  
  // --- Check if form is valid for button state ---
  bool _isFormValidForButton() {
    final bool medicationsAnswered = _medicationsController.text.isNotEmpty 
                                  || _hasNoMedications 
                                  || _medicationDocument != null;
    final bool allergiesAnswered = _allergiesController.text.isNotEmpty || _hasNoAllergies;
    final bool surgicalHistoryAnswered = _surgicalHistoryController.text.isNotEmpty || _hasNoSurgicalHistory;
    // Add other validation if needed (e.g., conditions)
    return medicationsAnswered && allergiesAnswered && surgicalHistoryAnswered;
  }

  // Update button state via provider
  void _updateButtonState() {
    final isValid = _isFormValidForButton();
     WidgetsBinding.instance.addPostFrameCallback((_) { // Ensure provider update happens safely
       if (mounted) {
         ref.read(onboardingButtonProvider.notifier).state = OnboardingButtonState(
           text: 'common.continue'.tr(),
           onPressed: isValid ? _saveAndContinue : null, 
           isLoading: _isLoading,
         );
       }
     });
  }
  
  
  Future<void> _saveAndContinue() async {
    HapticUtils.lightTap();
    FocusScope.of(context).unfocus(); 
    
    // Form validation (includes required check for text fields if "None" is not checked)
    if (!_formKey.currentState!.validate()) return;

    // Double-check if each section is answered (though button state should handle this)
    if (!_isFormValidForButton()) { 
      // Maybe show a general snackbar if somehow validation passed but this failed
      NavigationUtils.showSnackBar(context, 'Please complete all sections', backgroundColor: AppColors.error);
      return;
    }
    
    setState(() => _isExiting = true);
    ref.read(onboardingButtonProvider.notifier).update((state) => state.copyWith(isLoading: true));
    
    await Future.delayed(const Duration(milliseconds: 300));

    if (!mounted) return; 

    try {
      // Get current user ID
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception("User not logged in during medical history setup.");
      }
      final userId = user.uid;

      // Prepare medical history data
      final List<String> selectedConditions = _conditions.entries
          .where((entry) => entry.key != 'Other Conditions' && entry.value)
          .map((entry) => entry.key)
          .toList();

      final medicalHistoryData = {
        'conditions': selectedConditions,
        'otherConditions': (_conditions['Other Conditions'] ?? false) ? _medicalConditionsController.text.trim() : null,
        'medications': _hasNoMedications ? 'None' : _medicationsController.text.trim(),
        'allergies': _hasNoAllergies ? 'None' : _allergiesController.text.trim(),
        'surgicalHistory': _hasNoSurgicalHistory ? 'None' : _surgicalHistoryController.text.trim(),
        // Placeholder for medication document - upload logic needed separately
        'medicationDocumentUrl': _medicationDocument?.downloadUrl,
      };

      // Determine the next onboarding step
      // Assuming AppConstants.onboardingSteps = [..., 'medical_history', 'document_upload', ...]
      final String nextOnboardingStep = AppConstants.onboardingSteps[2]; // 'document_upload'

      // Prepare the full data map to save
      final Map<String, dynamic> dataToSave = {
        'medicalHistory': medicalHistoryData, // Nested map
        'onboardingStep': nextOnboardingStep,
        'medicalHistoryCompleted': true,
        'profileLastUpdatedAt': FieldValue.serverTimestamp(),
      };

      // Get the service and save data
      final userProfileService = ref.read(userProfileServiceProvider);
      await userProfileService.saveUserProfile(userId: userId, data: dataToSave);
      AppLogger.d("Medical History Data Saved: $dataToSave");

      // Navigate on success
      context.goNamed(RouteNames.documentUpload);
    } catch (e) {
      if (mounted) {
        NavigationUtils.showSnackBar(
          context,
          ErrorHandler.handleError(e),
          backgroundColor: AppColors.error,
        );
        setState(() => _isExiting = false);
        ref.read(onboardingButtonProvider.notifier).update((state) => state.copyWith(isLoading: false));
      }
    }
  }

  Future<void> _pickMedicationPhoto() async {
    FocusScope.of(context).unfocus(); // Dismiss keyboard if photo picker is opened
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        File file = File(image.path);
        String fileName = image.name; // Get filename
        int fileSize = file.lengthSync();
        
        setState(() {
          _isAttaching = true; // Show indicator for this specific upload
          _medicationDocument = null; // Clear previous doc while uploading new one
        });

        String? downloadUrl;
        try {
          final userId = FirebaseAuth.instance.currentUser?.uid;
          if (userId == null) throw Exception("User not logged in.");
          
          final storageService = ref.read(storageServiceProvider);
          downloadUrl = await storageService.uploadFile(
            userId: userId,
            filePath: file.path,
            destinationFolder: 'medication_attachments', // Specific folder
            fileName: fileName, 
          );
          
          if (downloadUrl == null) {
            throw Exception("Failed to get download URL from storage.");
          }
          
          AppLogger.d("Medication photo uploaded: $downloadUrl");
          
          // Set the state ONLY after successful upload
          setState(() {
            _medicationDocument = UploadedDocument(
              name: fileName,
              size: fileSize,
              downloadUrl: downloadUrl, // Store the URL
              dateUploaded: DateTime.now(),
              type: DocumentType.image,
            );
          });
          _updateButtonState(); // Update main continue button state

        } catch (e) {
          AppLogger.e("Error uploading medication photo: $e");
          if(mounted) {
            NavigationUtils.showSnackBar(
              context,
              "Error uploading photo: ${ErrorHandler.handleError(e)}",
              backgroundColor: AppColors.error,
            );
          }
        } finally {
          // Hide indicator regardless of outcome
          if (mounted) {
            setState(() {
              _isAttaching = false; 
            });
          }
        }
      } else {
        AppLogger.d('No image selected.');
      }
    } catch (e) {
      AppLogger.e('Error picking image: $e');
      if (mounted) {
        NavigationUtils.showSnackBar(context, 'Could not pick image: $e', backgroundColor: AppColors.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
        children: [
          Expanded(
            child: Form(
              key: _formKey,
              child: ScrollableContent(
                padding: const EdgeInsets.fromLTRB(24.0, 0, 24.0, 24.0),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                   transitionBuilder: (Widget child, Animation<double> animation) {
                    final slideAnimation = Tween<Offset>(
                      begin: const Offset(0.0, 0.3),
                      end: Offset.zero,
                    ).animate(animation);
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(position: slideAnimation, child: child),
                    );
                  },
                  child: _isExiting
                      ? const SizedBox.shrink()
                      : Column(
                          key: const ValueKey('medical_content'),
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildAnimatedBlock(
                              index: 0,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'onboarding.tell_us_medical_history'.tr(),
                                    style: Theme.of(context).textTheme.titleLarge,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'onboarding.medical_history_description'.tr(),
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            
                            _buildAnimatedBlock(
                              index: 1,
                              child: Column(
                                 crossAxisAlignment: CrossAxisAlignment.start,
                                 children: [
                                   Text(
                                     'onboarding.any_conditions'.tr(),
                                     style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                       fontWeight: FontWeight.w600,
                                     ),
                                   ),
                                   const SizedBox(height: 16),
                                   ..._conditions.keys.map((condition) {
                                     return Padding(
                                       padding: const EdgeInsets.only(bottom: 8.0),
                                       child: AnimatedCheckboxTile(
                                         title: condition,
                                         icon: _conditionIcons[condition] ?? Icons.error, 
                                         value: _conditions[condition]!,
                                         onChanged: (value) {
                                           setState(() => _conditions[condition] = value ?? false);
                                           if (condition == 'Other Conditions' && (value ?? false)) {
                                             FocusScope.of(context).requestFocus(_otherConditionsFocus);
                                           } else if (condition == 'Other Conditions' && !(value ?? false)) {
                                              _medicalConditionsController.clear(); // Clear text if unchecked
                                           }
                                            _updateButtonState(); // Update button when conditions change too
                                         },
                                       ),
                                     );
                                   }).toList(),
                                 ]
                              ),
                            ),
                            
                            AnimatedSize(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                              child: _conditions['Other Conditions']!
                                  ? _buildAnimatedBlock(
                                      index: 1, 
                                      child: Padding(
                                        padding: const EdgeInsets.only(top: 16.0),
                                        child: CustomTextField(
                                          label: 'Other Medical Conditions',
                                          hint: 'Please specify any other conditions',
                                          controller: _medicalConditionsController,
                                          focusNode: _otherConditionsFocus,
                                          textInputAction: TextInputAction.next,
                                          onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_medicationsFocus),
                                          maxLines: 3,
                                          validator: (value) {
                                            if (_conditions['Other Conditions']! && (value == null || value.isEmpty)) {
                                              return 'Please specify your other conditions or uncheck "Other Conditions".';
                                            }
                                            return null;
                                          },
                                        ),
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                            
                            const SizedBox(height: 24),
                            
                            _buildAnimatedBlock(
                              index: 2,
                              child: _buildTextFieldSection(
                                context: context,
                                title: 'Current Medications',
                                subtitle: 'List any medications you are currently taking, or select none.',
                                controller: _medicationsController,
                                focusNode: _medicationsFocus,
                                textInputAction: TextInputAction.next,
                                onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_allergiesFocus),
                                hint: 'E.g., Aspirin, Metformin...',
                                maxLines: 3,
                                icon: _medicationsIcon,
                                iconColor: Colors.blueAccent,
                                isNoneSelected: _hasNoMedications,
                                onNoneTap: _toggleNoMedications,
                                isEnabled: !_hasNoMedications,
                                validator: (value) {
                                  if (!_hasNoMedications && _medicationDocument == null && (value == null || value.isEmpty)) {
                                    return 'Please list medications, upload a photo, or select "None".';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            
                            const SizedBox(height: 24),
                            
                            _buildAnimatedBlock(
                              index: 3,
                              child: _buildTextFieldSection(
                                context: context,
                                title: 'Allergies',
                                subtitle: 'List any allergies or select none.',
                                controller: _allergiesController,
                                focusNode: _allergiesFocus,
                                textInputAction: TextInputAction.next,
                                onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_surgicalHistoryFocus),
                                hint: 'E.g., Penicillin, Peanuts...',
                                maxLines: 2,
                                icon: _allergiesIcon,
                                iconColor: Colors.orangeAccent,
                                isNoneSelected: _hasNoAllergies,
                                onNoneTap: _toggleNoAllergies,
                                isEnabled: !_hasNoAllergies,
                                validator: (value) {
                                  if (!_hasNoAllergies && (value == null || value.isEmpty)) {
                                    return 'Please list allergies or select "None".';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            
                            const SizedBox(height: 24),
                            
                            _buildAnimatedBlock(
                              index: 4,
                              child: _buildTextFieldSection(
                                context: context,
                                title: 'Surgical History',
                                subtitle: 'List any past surgeries/procedures or select none.',
                                controller: _surgicalHistoryController,
                                focusNode: _surgicalHistoryFocus,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _saveAndContinue(),
                                hint: 'E.g., Appendix removal (2010)...',
                                maxLines: 3,
                                icon: _surgeryIcon,
                                iconColor: Colors.redAccent,
                                isNoneSelected: _hasNoSurgicalHistory,
                                onNoneTap: _toggleNoSurgicalHistory,
                                isEnabled: !_hasNoSurgicalHistory,
                                validator: (value) {
                                  if (!_hasNoSurgicalHistory && (value == null || value.isEmpty)) {
                                    return 'Please list surgical history or select "None".';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ],
      );
  }
  
  Widget _buildAnimatedBlock({required int index, required Widget child}) {
    // Ensure index is within bounds
    if (index < 0 || index >= _animControllers.length) {
      return child; // Return child directly if index is invalid
    }
    return AnimatedBuilder(
      animation: _animControllers[index],
      builder: (context, child) {
        return Transform.translate(
          offset: _slideAnimations[index].value,
          child: Transform.scale(
            scale: _scaleAnimations[index].value,
            child: child,
          ),
        );
      },
      child: child,
    );
  }
  
  Widget _buildTextFieldSection({
    required BuildContext context,
    required String title,
    required String subtitle,
    required TextEditingController controller,
    required String hint,
    FocusNode? focusNode,
    TextInputAction? textInputAction,
    ValueChanged<String>? onFieldSubmitted,
    int maxLines = 1,
    IconData? icon,
    Color? iconColor,
    required bool isNoneSelected,
    required VoidCallback onNoneTap,
    bool isEnabled = true,
    FormFieldValidator<String>? validator,
  }) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0.5,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: theme.colorScheme.surfaceContainer, 
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null)
                  Icon(icon, color: iconColor ?? theme.colorScheme.primary, size: 22),
                if (icon != null) const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: iconColor ?? theme.colorScheme.primary,
                    ),
                  ),
                ),
                ChoiceChip(
                  label: Text('medical_history.none'.tr(), style: TextStyle(color: isNoneSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant, fontSize: 12)),
                  selected: isNoneSelected,
                  onSelected: (selected) => onNoneTap(),
                  selectedColor: iconColor ?? theme.colorScheme.primary,
                  backgroundColor: theme.colorScheme.surfaceContainer, 
                  labelPadding: const EdgeInsets.symmetric(horizontal: 8.0),
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  side: isNoneSelected ? BorderSide.none : BorderSide(color: theme.colorScheme.outline),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            // Conditionally show subtitle only when the section is enabled
            if (isEnabled) ...[
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 16),
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: !isEnabled
                  ? const SizedBox.shrink() // Collapse when disabled (None selected)
                  : Column( // Use a column to hold the text field and medication button
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CustomTextField(
                          label: title,
                          hint: hint,
                          controller: controller,
                          focusNode: focusNode,
                          textInputAction: textInputAction,
                          onFieldSubmitted: onFieldSubmitted,
                          maxLines: maxLines,
                          fillColor: Colors.white, 
                          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                          enabled: true, 
                          readOnly: false,
                          validator: validator,
                        ),
                        // --- Medication Photo Upload/Display --- 
                        if (title == 'Current Medications') ...[
                          const SizedBox(height: 12),
                          // Display UploadDocumentTile if a document exists
                          if (_medicationDocument != null) 
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8.0), 
                              child: UploadDocumentTile(
                                document: _medicationDocument!,
                                onDelete: () {
                                  HapticUtils.lightTap();
                                  setState(() {
                                    _medicationDocument = null;
                                  });
                                  _updateButtonState();
                                },
                              ),
                            ),
                           
                          // Display Upload Button if NO document exists
                          if (_medicationDocument == null) 
                            // Show loading indicator or button
                            _isAttaching 
                              ? Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 10.0), 
                                  child: Row( 
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                                      const SizedBox(width: 12),
                                      Text('onboarding.uploading_photo'.tr()),
                                    ],
                                  ),
                                )
                              : OutlinedButton.icon(
                                  icon: const Icon(Icons.camera_alt_outlined, size: 20),
                                  label: Text('onboarding.upload_medication_photo'.tr()),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: theme.colorScheme.primary,
                                    side: BorderSide(color: theme.colorScheme.primary.withAlpha(128)),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8.0),
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                                  ),
                                  onPressed: () {
                                    HapticUtils.lightTap();
                                    _pickMedicationPhoto();
                                  },
                                ),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Custom Animated Checkbox Widget ---

class AnimatedCheckboxTile extends StatefulWidget {
  final String title;
  final IconData icon; // Add icon data
  final bool value;
  final ValueChanged<bool?> onChanged;

  const AnimatedCheckboxTile({
    super.key,
    required this.title,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  @override
  State<AnimatedCheckboxTile> createState() => _AnimatedCheckboxTileState();
}

class _AnimatedCheckboxTileState extends State<AnimatedCheckboxTile> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _checkAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack)
    );
    
    _checkAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine)
    );

    if (widget.value) {
      _controller.value = 1.0; // Start checked if initial value is true
    }
  }

  @override
  void didUpdateWidget(AnimatedCheckboxTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      if (widget.value) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    HapticUtils.lightTap();
    widget.onChanged(!widget.value);
    // Add a little bounce effect on tap
    _controller.forward().then((_) {
      if (!widget.value && mounted) {
         _controller.reverse();
      } else if (widget.value && mounted) {
         // Keep it forward if checked, maybe a slight reverse then forward for bounce
         _controller.reverse().then((_) {
            if (mounted) _controller.forward();
         });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); // Get theme
    // Use theme colors
    final Color activeColor = theme.colorScheme.primary;
    final Color inactiveColor = theme.colorScheme.onSurfaceVariant.withAlpha(128);

    return InkWell(
      onTap: _handleTap,
      borderRadius: BorderRadius.circular(8.0),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
        child: Row(
          children: [
            // Add Icon before checkbox
            Icon(widget.icon, size: 24, color: widget.value ? activeColor : inactiveColor.withAlpha(204)),
            const SizedBox(width: 12),
            // Checkbox itself
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Transform.scale(
                  scale: _scaleAnimation.value + (1.0 - _scaleAnimation.value) * 2 * _checkAnimation.value, // Bounce effect
                  child: Container(
                    width: 24.0,
                    height: 24.0,
                    decoration: BoxDecoration(
                      // Use theme colors for lerp
                      color: Color.lerp(theme.colorScheme.surfaceContainer, activeColor, _checkAnimation.value),
                      borderRadius: BorderRadius.circular(6.0),
                      border: Border.all(
                        // Use theme colors for lerp
                        color: Color.lerp(inactiveColor, activeColor, _checkAnimation.value)!,
                        width: 2.0,
                      ),
                    ),
                    child: Center(
                      child: AnimatedOpacity(
                        opacity: _checkAnimation.value,
                        duration: Duration.zero, // Opacity controlled by checkAnimation
                        child: Icon(
                          Icons.check,
                          size: 18.0 * _checkAnimation.value, // Animate size
                          // Use theme onPrimary color
                          color: theme.colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                widget.title,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  // Use theme colors for lerp
                  color: Color.lerp(theme.colorScheme.onSurface, activeColor, _checkAnimation.value * 0.7), 
                  fontWeight: widget.value ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 
