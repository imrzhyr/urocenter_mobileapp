import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/theme.dart';
import '../../../core/utils/haptic_utils.dart';
import '../screens/payment_screen.dart';

/// A sample card widget that demonstrates how to use the payment screen
class PaymentExampleCard extends ConsumerWidget {
  final String title;
  final String description;
  final double amount;
  
  const PaymentExampleCard({
    super.key,
    required this.title,
    required this.description,
    required this.amount,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: InkWell(
        onTap: () => _openPaymentScreen(context),
        borderRadius: BorderRadius.circular(16.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.payment_rounded,
                    color: theme.colorScheme.primary,
                    size: 26.0,
                  ),
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12.0),
              Text(
                description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16.0),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Amount: $amount IQD',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _openPaymentScreen(context),
                    icon: const Icon(Icons.arrow_forward_ios, size: 14.0),
                    label: Text('user.pay_now'.tr()),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  void _openPaymentScreen(BuildContext context) {
    HapticUtils.lightTap();
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PaymentScreen(
          amount: amount,
          description: description,
          onPaymentSuccess: () {
            // Handle successful payment here
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Payment of $amount IQD was successful!'),
                backgroundColor: AppColors.success,
              ),
            );
          },
        ),
      ),
    );
  }
} 