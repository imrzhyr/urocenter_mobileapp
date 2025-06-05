import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart'; // Import for date formatting
import 'package:dropdown_button2/dropdown_button2.dart'; // Import the package
import 'package:firebase_auth/firebase_auth.dart'; // Import FirebaseAuth
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore for FieldValue
import 'package:easy_localization/easy_localization.dart'; // Import for translations
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/utils/utils.dart';
import '../../../core/utils/haptic_utils.dart';
import '../../../app/routes.dart';
import '../widgets/onboarding_progress.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/animated_button.dart';
import '../providers/onboarding_providers.dart';
import '../../../providers/service_providers.dart'; // Import service providers
import '../../../core/data/countries_cities.dart'; // Import country/city data
import '../../../core/constants/app_constants.dart'; // Import for onboarding steps constants
import '../../../core/utils/logger.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/models/models.dart';

/// Profile setup screen for onboarding
class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

// Helper function to get flag emoji (simple version)
String getCountryFlagEmoji(String countryName) {
  switch (countryName) {
    case 'Iraq': return '🇮🇶';
    case 'Egypt': return '🇪🇬';
    case 'Saudi Arabia': return '🇸🇦';
    case 'United Arab Emirates': return '🇦🇪';
    case 'Jordan': return '🇯🇴';
    default: return '🏳️'; // Default flag
  }
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final TextEditingController _countrySearchController = TextEditingController(); // Search controller
  final TextEditingController _citySearchController = TextEditingController();    // Search controller
  
  String _selectedGender = '';
  String? _selectedCountry;
  String? _selectedCity;
  List<String> _sortedCountryList = [];
  List<String> _citiesForSelectedCountry = [];
  
  bool _isLoading = false;
  bool _isExiting = false;
  
  // Focus Nodes
  final _nameFocus = FocusNode();
  final _ageFocus = FocusNode();
  final _heightFocus = FocusNode();
  final _weightFocus = FocusNode();
  
  // Animation controllers
  late final List<AnimationController> _animControllers = [];
  late final List<Animation<Offset>> _slideAnimations = [];
  late final List<Animation<double>> _scaleAnimations = [];
  
  // Update gender options to use translations
  late final List<String> _genderOptions = ['onboarding.male'.tr(), 'onboarding.female'.tr()];
  
  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _prepareCountryList(); // Prepare sorted country list
    
    // Add listeners to controllers to update button state
    _nameController.addListener(_updateButtonState);
    _ageController.addListener(_updateButtonState);
    _heightController.addListener(_updateButtonState);
    _weightController.addListener(_updateButtonState);

    // Add focus listeners for scrolling
    _nameFocus.addListener(() => _ensureVisibleOnFocus(_nameFocus));
    _heightFocus.addListener(() => _ensureVisibleOnFocus(_heightFocus));
    _weightFocus.addListener(() => _ensureVisibleOnFocus(_weightFocus));

    // Initialize button state (will be disabled initially)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateButtonState();
    });
  }
  
  void _setupAnimations() {
    // Update count: Name, Age, Gender, Height/Weight, Country/City
    const numberOfAnimatedFields = 5; 
    for (int i = 0; i < numberOfAnimatedFields; i++) {
      final controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      );
      
      final slideAnimation = Tween<Offset>(
        begin: const Offset(0.5, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: controller,
        curve: Curves.elasticOut,
      ));
      
      final scaleAnimation = Tween<double>(
        begin: 0.8,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: controller,
        curve: Curves.elasticOut,
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Update gender options when language changes
    _genderOptions.clear();
    _genderOptions.addAll(['onboarding.male'.tr(), 'onboarding.female'.tr()]);
  }
  
  @override
  void dispose() {
    // Remove listeners
    _nameController.removeListener(_updateButtonState);
    _ageController.removeListener(_updateButtonState);
    _heightController.removeListener(_updateButtonState);
    _weightController.removeListener(_updateButtonState);
    _nameFocus.removeListener(() => _ensureVisibleOnFocus(_nameFocus));
    _heightFocus.removeListener(() => _ensureVisibleOnFocus(_heightFocus));
    _weightFocus.removeListener(() => _ensureVisibleOnFocus(_weightFocus));
    
    // Dispose controllers & focus nodes
    _nameController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _countrySearchController.dispose(); // Dispose search controller
    _citySearchController.dispose();    // Dispose search controller
    _nameFocus.dispose();
    _ageFocus.dispose();
    _heightFocus.dispose();
    _weightFocus.dispose();
    for (var controller in _animControllers) {
      controller.dispose();
    }
    super.dispose();
  }
  
  void _selectGender(String gender) {
    setState(() {
      _selectedGender = gender;
    });
    _updateButtonState(); // Update button state
    HapticUtils.mediumTap();
    FocusScope.of(context).unfocus();
  }
  
  void _handleBack() {
    HapticUtils.lightTap();
    NavigationUtils.safeGoBack(context, previousRouteName: RouteNames.welcome);
  }

  // Check if all required fields are valid for enabling the button
  bool _isFormValidForButton() {
    // Check basic field completion (Age instead of DOB)
    final bool nameValid = _nameController.text.trim().isNotEmpty;
    final bool ageValid = _ageController.text.isNotEmpty;
    final bool genderValid = _selectedGender.isNotEmpty;
    final bool heightValid = _heightController.text.isNotEmpty; 
    final bool weightValid = _weightController.text.isNotEmpty;
    final bool locationValid = _selectedCountry != null && _selectedCity != null;
    
    // Don't call _formKey.currentState.validate() here!
    return nameValid && ageValid && genderValid && heightValid && weightValid && locationValid;
  }

  // Update the button provider state based on basic field completion
  void _updateButtonState() {
    final isValid = _isFormValidForButton();
    try {
       ref.read(onboardingButtonProvider.notifier).state = OnboardingButtonState(
         text: 'common.continue'.tr(),
         onPressed: isValid ? _saveAndContinue : null, 
         isLoading: _isLoading,
       );
    } catch (e) {
       AppLogger.e("Error updating button provider state: $e");
    }
  }
  
  Future<void> _saveAndContinue() async {
    HapticUtils.lightTap();
    FocusScope.of(context).unfocus(); 
    final theme = Theme.of(context); // Get theme
    
    // Explicitly validate the form on submit
    if (!_formKey.currentState!.validate()) {
       return;
    }
    // Additional checks 
    if (_selectedGender.isEmpty) {
       NavigationUtils.showSnackBar(context, 'onboarding.select_gender_error'.tr(), backgroundColor: theme.colorScheme.error);
       return;
    } 
    if (_selectedCountry == null || _selectedCity == null) {
       NavigationUtils.showSnackBar(context, 'onboarding.select_location_error'.tr(), backgroundColor: theme.colorScheme.error);
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
        // Should not happen in this flow, but handle defensively
        throw Exception("errors.user_not_logged_in".tr());
      }
      final userId = user.uid;

      // Determine the next onboarding step
      final String nextOnboardingStep = AppConstants.onboardingSteps[1]; // 'medical_history'

      // Convert gender from localized string back to a standard format
      String standardGender = _selectedGender == 'onboarding.male'.tr() ? 'male' : 'female';

      // Construct profile data map
      final profileData = {
        'fullName': _nameController.text.trim(),
        'age': int.tryParse(_ageController.text.trim()), // Store age as integer
        'gender': standardGender,
        'height': int.tryParse(_heightController.text.trim()), // Store height as integer
        'weight': double.tryParse(_weightController.text.trim()), // Store weight as double
        'country': _selectedCountry,
        'city': _selectedCity,
        // Add a timestamp for when the profile was created/updated
        'profileCreatedAt': FieldValue.serverTimestamp(), 
        'profileLastUpdatedAt': FieldValue.serverTimestamp(),
        // Explicitly set onboarding step to the *next* step
        'onboardingStep': nextOnboardingStep,
        'onboardingCompleted': false, // Still false until final step
        // Keep placeholders or set defaults
        'medicalHistoryCompleted': false,
        'documentsUploaded': false,
      };
      
      // Get the service and save data
      final userProfileService = ref.read(userProfileServiceProvider);
      await userProfileService.saveUserProfile(userId: userId, data: profileData);
      
      // Navigate on success
      context.goNamed(RouteNames.medicalHistory);
    } catch (e) {
      final theme = Theme.of(context);
      if (mounted) {
        NavigationUtils.showSnackBar(
          context,
          ErrorHandler.handleError(e),
          backgroundColor: theme.colorScheme.error,
        );
        setState(() => _isExiting = false);
        ref.read(onboardingButtonProvider.notifier).update((state) => state.copyWith(isLoading: false));
      }
    }
  }

  // Helper function to scroll field into view on focus
  void _ensureVisibleOnFocus(FocusNode node) {
    if (node.hasFocus && node.context != null) {
      // Delay slightly to allow keyboard animation
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && node.context != null) {
           Scrollable.ensureVisible(
             node.context!, 
             duration: const Duration(milliseconds: 250),
             curve: Curves.easeOut,
             alignment: 0.1, // Align near top (0.0 = top, 1.0 = bottom)
           );
        }
      });
    }
  }

  // Prepare sorted country list with Iraq first
  void _prepareCountryList() {
    List<String> countries = countryData.keys.toList();
    // Sort alphabetically
    countries.sort(); 
    // Ensure Iraq is at the top
    if (countries.contains(defaultCountry)) {
      countries.remove(defaultCountry);
      countries.insert(0, defaultCountry);
    }
    _sortedCountryList = countries;
  }

  // Prepare sorted city list for the selected country
  void _prepareCityList(String? country) {
     if (country == null) {
      _citiesForSelectedCountry = [];
      return;
    }
    List<String> cities = List<String>.from(cityData[country] ?? []); // Create a modifiable copy
    cities.sort();
    // Prioritize default city if it exists in the list
    if (country == defaultCountry && cities.contains(defaultCity)) {
      cities.remove(defaultCity);
      cities.insert(0, defaultCity);
    }
     _citiesForSelectedCountry = cities;
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height; // Get screen height
    final theme = Theme.of(context); // Get theme
    
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
                      begin: const Offset(0.0, 0.3), end: Offset.zero
                    ).animate(animation);
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(position: slideAnimation, child: child),
                    );
                  },
                  child: _isExiting 
                      ? const SizedBox.shrink()
                      : Column( 
                          key: const ValueKey('profile_content'), 
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'onboarding.profile_setup_subtitle'.tr(), 
                              style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.onSurface),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'onboarding.personal_details'.tr(), 
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            // --- Full Name (now index 0) ---
                            _buildAnimatedFormField(
                              index: 0,
                              title: 'onboarding.full_name'.tr(),
                              icon: Icons.person_outline_rounded,
                              iconColor: theme.colorScheme.secondary,
                              child: CustomTextField(
                                label: 'onboarding.full_name'.tr(),
                                hint: 'onboarding.enter_full_name'.tr(),
                                controller: _nameController,
                                focusNode: _nameFocus,
                                keyboardType: TextInputType.name,
                                textInputAction: TextInputAction.next,
                                onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_ageFocus),
                                validator: (value) => Validators.validateRequired(value, 'onboarding.full_name'.tr()),
                              ),
                            ),
                            const SizedBox(height: 24),
                            
                            // --- Age (now index 1) ---
                            _buildAnimatedFormField(
                              index: 1,
                              title: 'onboarding.age'.tr(),
                              icon: Icons.cake,
                              iconColor: theme.colorScheme.primary,
                              child: CustomTextField(
                                label: 'onboarding.age'.tr(),
                                hint: 'onboarding.enter_age'.tr(),
                                controller: _ageController,
                                focusNode: _ageFocus,
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.next,
                                onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_heightFocus),
                                validator: Validators.validateAge,
                              ),
                            ),
                            const SizedBox(height: 24),
                            
                            // --- Gender selection (now index 2) ---
                            _buildAnimatedFormField(
                              index: 2,
                              title: 'onboarding.gender'.tr(),
                              icon: Icons.people_alt_rounded,
                              iconColor: theme.colorScheme.tertiary,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
                                    child: Text(
                                      'onboarding.select_gender'.tr(),
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                  Row(
                                    children: _genderOptions.map((gender) {
                                      final isSelected = _selectedGender == gender;
                                      return Expanded(
                                        child: GestureDetector(
                                          onTap: () => _selectGender(gender),
                                          child: Container(
                                            margin: const EdgeInsets.symmetric(horizontal: 4.0),
                                            padding: const EdgeInsets.symmetric(vertical: 12.0),
                                            decoration: BoxDecoration(
                                              color: isSelected 
                                                  ? theme.colorScheme.primaryContainer.withValues(alpha: 128.0) 
                                                  : theme.colorScheme.surface,
                                              borderRadius: BorderRadius.circular(8.0),
                                              border: Border.all(
                                                color: isSelected ? theme.colorScheme.primary : theme.dividerColor.withValues(alpha: 128.0),
                                                width: isSelected ? 2 : 1,
                                              ),
                                            ),
                                            alignment: Alignment.center,
                                            child: Text(
                                              gender,
                                              style: TextStyle(
                                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                                color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            
                            // --- Height & Weight (now index 3) ---
                            _buildAnimatedFormField(
                              index: 3,
                              title: 'onboarding.physical_details'.tr(),
                              icon: Icons.accessibility_new_rounded,
                              iconColor: theme.colorScheme.error,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start, // Align labels to the top
                                children: [
                                  // --- Height Column ---
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 8.0, left: 4.0), // Add padding for label
                                          child: Text(
                                            'onboarding.height'.tr(),
                                            style: TextStyle(
                                              color: theme.colorScheme.onSurfaceVariant,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        CustomTextField(
                                          // label: 'onboarding.height'.tr(), // Removed label
                                          hint: 'onboarding.height_hint'.tr(),
                                          controller: _heightController,
                                          focusNode: _heightFocus,
                                          keyboardType: TextInputType.number,
                                          textInputAction: TextInputAction.next,
                                          onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_weightFocus),
                                          validator: (value) => Validators.validateRequired(value, 'onboarding.height'.tr()),
                                          suffix: Text(
                                            'cm',
                                            style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 14),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  // --- Weight Column ---
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 8.0, left: 4.0), // Add padding for label
                                          child: Text(
                                            'onboarding.weight'.tr(),
                                            style: TextStyle(
                                              color: theme.colorScheme.onSurfaceVariant,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        CustomTextField(
                                          // label: 'onboarding.weight'.tr(), // Removed label
                                          hint: 'onboarding.weight_hint'.tr(),
                                          controller: _weightController,
                                          focusNode: _weightFocus,
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          textInputAction: TextInputAction.done,
                                          validator: (value) => Validators.validateRequired(value, 'onboarding.weight'.tr()),
                                          suffix: Text(
                                            'kg',
                                            style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 14),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            
                            // --- Country & City (now index 4) ---
                            _buildAnimatedFormField(
                              index: 4,
                              title: 'onboarding.location'.tr(),
                              icon: Icons.location_on_outlined,
                              iconColor: theme.colorScheme.tertiary,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Country dropdown
                                  DropdownButtonHideUnderline(
                                    child: DropdownButton2<String>(
                                      isExpanded: true,
                                      hint: Row(
                                        children: [
                                          Icon(
                                            Icons.public,
                                            size: 16,
                                            color: theme.colorScheme.onSurfaceVariant,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'onboarding.select_country'.tr(),
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: theme.colorScheme.onSurfaceVariant,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      value: _selectedCountry,
                                      items: _sortedCountryList.map((String country) {
                                        return DropdownMenuItem<String>(
                                          value: country,
                                          child: Row(
                                            children: [
                                              Text(
                                                getCountryFlagEmoji(country),
                                                style: const TextStyle(fontSize: 16),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(country),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (String? value) {
                                        if (value != null && value != _selectedCountry) {
                                          HapticUtils.selection();
                                          setState(() {
                                            _selectedCountry = value;
                                            _selectedCity = null; // Reset city when country changes
                                            _prepareCityList(value);
                                          });
                                          _updateButtonState();
                                        }
                                      },
                                      dropdownSearchData: DropdownSearchData(
                                        searchController: _countrySearchController,
                                        searchInnerWidgetHeight: 60,
                                        searchInnerWidget: Container(
                                          height: 60,
                                          padding: const EdgeInsets.all(8),
                                          child: TextField(
                                            controller: _countrySearchController,
                                            decoration: InputDecoration(
                                              hintText: 'onboarding.search_country'.tr(),
                                              hintStyle: const TextStyle(fontSize: 14),
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                            ),
                                          ),
                                        ),
                                        searchMatchFn: (item, searchValue) {
                                          return (item.value.toString().toLowerCase().contains(searchValue.toLowerCase()));
                                        },
                                      ),
                                      buttonStyleData: ButtonStyleData(
                                        height: 50,
                                        padding: const EdgeInsets.symmetric(horizontal: 16),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: theme.dividerColor.withValues(alpha: 204.0)),
                                        ),
                                      ),
                                      dropdownStyleData: DropdownStyleData(
                                        maxHeight: 300,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                      menuItemStyleData: const MenuItemStyleData(
                                        height: 40,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  
                                  // City dropdown (only enabled if country selected)
                                  DropdownButtonHideUnderline(
                                    child: DropdownButton2<String>(
                                      isExpanded: true,
                                      hint: Row(
                                        children: [
                                          Icon(
                                            Icons.location_city,
                                            size: 16,
                                            color: theme.colorScheme.onSurfaceVariant,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'onboarding.select_city'.tr(),
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: theme.colorScheme.onSurfaceVariant,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      value: _selectedCity,
                                      items: _citiesForSelectedCountry.map((String city) {
                                        return DropdownMenuItem<String>(
                                          value: city,
                                          child: Text(city),
                                        );
                                      }).toList(),
                                      onChanged: _selectedCountry == null ? null : (String? value) {
                                        if (value != null) {
                                          HapticUtils.selection();
                                          setState(() {
                                            _selectedCity = value;
                                          });
                                          _updateButtonState();
                                        }
                                      },
                                      dropdownSearchData: DropdownSearchData(
                                        searchController: _citySearchController,
                                        searchInnerWidgetHeight: 60,
                                        searchInnerWidget: Container(
                                          height: 60,
                                          padding: const EdgeInsets.all(8),
                                          child: TextField(
                                            controller: _citySearchController,
                                            decoration: InputDecoration(
                                              hintText: 'onboarding.search_city'.tr(),
                                              hintStyle: const TextStyle(fontSize: 14),
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                            ),
                                          ),
                                        ),
                                        searchMatchFn: (item, searchValue) {
                                          return (item.value.toString().toLowerCase().contains(searchValue.toLowerCase()));
                                        },
                                      ),
                                      buttonStyleData: ButtonStyleData(
                                        height: 50,
                                        padding: const EdgeInsets.symmetric(horizontal: 16),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: _selectedCountry == null 
                                                ? theme.colorScheme.outline.withValues(alpha: 77.0)
                                                : theme.dividerColor.withValues(alpha: 204.0),
                                          ),
                                        ),
                                      ),
                                      dropdownStyleData: DropdownStyleData(
                                        maxHeight: 300,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                      menuItemStyleData: const MenuItemStyleData(
                                        height: 40,
                                      ),
                                    ),
                                  ),
                                ],
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
  
  // Helper for building animated form fields
  Widget _buildAnimatedFormField({
    required int index,
    required String title,
    required IconData icon,
    required Widget child,
    Color iconColor = Colors.blue,
  }) {
    final theme = Theme.of(context); // Get theme
    // Determine container color based on iconColor (which is now a theme color)
    Color iconContainerColor;
    if (iconColor == theme.colorScheme.primary) {
      iconContainerColor = theme.colorScheme.primaryContainer;
    } else if (iconColor == theme.colorScheme.secondary) {
      iconContainerColor = theme.colorScheme.secondaryContainer;
    } else if (iconColor == theme.colorScheme.tertiary) {
      iconContainerColor = theme.colorScheme.tertiaryContainer;
    } else if (iconColor == theme.colorScheme.error) {
      iconContainerColor = theme.colorScheme.errorContainer;
    } else { // Fallback
      iconContainerColor = theme.colorScheme.surfaceContainerHighest;
    }

    return AnimatedBuilder(
      animation: _animControllers[index],
      builder: (context, _) {
        return SlideTransition(
          position: _slideAnimations[index],
          child: ScaleTransition(
            scale: _scaleAnimations[index],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Section title with icon
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: iconContainerColor.withValues(alpha: 102.0),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        icon,
                        color: iconColor,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Actual form field/widget
                child,
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A new button widget for selecting gender with distinct styles
class GenderSelectionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const GenderSelectionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Define styles based on selection
    final theme = Theme.of(context); // Get theme
    final bgColor = isSelected ? color : theme.inputDecorationTheme.fillColor ?? theme.colorScheme.surfaceContainerHighest;
    final contentColor = isSelected ? theme.colorScheme.onPrimary : color;
    final Border? border = isSelected
        ? null
        : Border.all(color: theme.dividerColor, width: 1.5);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.0),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12.0),
          border: border,
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: theme.shadowColor.withValues(alpha: 77.0),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: contentColor,
              size: 28,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: contentColor,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
} 
