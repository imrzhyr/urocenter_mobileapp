import 'package:flutter/material.dart';
import '../../../core/theme/theme.dart';
import '../../../core/utils/haptic_utils.dart';

/// Model representing a payment method
class PaymentMethod {
  final String id;
  final String name;
  final IconData icon;
  final Color color;

  PaymentMethod({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
  });
}

/// Widget displaying a selectable payment method card
class PaymentMethodCard extends StatelessWidget {
  final PaymentMethod method;
  final bool isSelected;
  final VoidCallback onSelect;

  const PaymentMethodCard({
    super.key,
    required this.method,
    required this.isSelected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        HapticUtils.selection();
        onSelect();
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? method.color : AppColors.divider,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: method.color.withValues(alpha: 26.0),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            // Payment method icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: method.color.withValues(alpha: 26.0),
                shape: BoxShape.circle,
              ),
              child: Icon(
                method.icon,
                color: method.color,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            
            // Payment method name
            Expanded(
              child: Text(
                method.name,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
            
            // Selected indicator
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: method.color,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }
} 