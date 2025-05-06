import 'package:flutter/material.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/animated_card.dart';
// import '../../../core/utils/localization.dart'; // REMOVED Localization import
import '../../../core/utils/haptic_utils.dart';

/// Gender selection widget for onboarding flow
class GenderSelection extends StatelessWidget {
  /// The currently selected gender (male/female)
  final String? selectedGender;
  
  /// Callback for when gender is selected
  final void Function(String gender) onGenderSelected;

  /// Creates a gender selection widget
  const GenderSelection({
    super.key,
    required this.selectedGender,
    required this.onGenderSelected,
  });

  @override
  Widget build(BuildContext context) {
    // final tr = AppLocalizations.of(context); // REMOVED localization object
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          // tr.translate('onboarding.gender_selection.question'),
          'Select your gender', // TODO: Localize
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: _GenderOption(
                // title: tr.translate('gender.male'),
                title: 'Male', // TODO: Localize
                icon: Icons.male,
                isSelected: selectedGender == 'male',
                onTap: () => onGenderSelected('male'),
                color: const Color(0xFFD6EAFF), // Light blue for male
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _GenderOption(
                // title: tr.translate('gender.female'),
                title: 'Female', // TODO: Localize
                icon: Icons.female,
                isSelected: selectedGender == 'female',
                onTap: () => onGenderSelected('female'),
                color: const Color(0xFFFCE4EC), // Light pink for female
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _GenderOption extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final Color color;

  const _GenderOption({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticUtils.selection();
        onTap();
      },
      child: AnimatedCard(
        padding: const EdgeInsets.symmetric(vertical: 24),
        backgroundColor: isSelected ? color : AppColors.card,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 48,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(height: 12),
            Text(
              title, // Now uses the hardcoded title passed in
              style: TextStyle(
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
} 