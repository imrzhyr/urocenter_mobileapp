import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/payment/fib_payment_service.dart';
import '../../../core/theme/theme.dart';
import '../../../core/utils/haptic_utils.dart';
import '../../../core/widgets/animated_button.dart';

/// Screen for handling payments through FIB
class PaymentScreen extends ConsumerStatefulWidget {
  final double amount;
  final String description;
  final VoidCallback? onPaymentSuccess;
  
  const PaymentScreen({
    super.key, 
    required this.amount, 
    required this.description,
    this.onPaymentSuccess,
  });

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  final FibPaymentService _paymentService = FibPaymentService();
  String? _paymentId;
  bool _isLoading = false;
  bool _isPolling = false;
  Timer? _pollingTimer;
  PaymentStatusType? _paymentStatus;
  String? _errorMessage;

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _initiatePayment() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final paymentId = await _paymentService.initiatePayment(
        amount: widget.amount,
        currencyCode: 'IQD',
        description: widget.description,
        redirectUri: 'urocenter://payment/callback',
      );
      
      if (paymentId != null) {
        setState(() {
          _paymentId = paymentId;
          _isLoading = false;
          _isPolling = true;
          _paymentStatus = PaymentStatusType.pending;
        });
        
        _startPollingForStatus(paymentId);
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to initiate payment. Please try again.';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'An error occurred: $e';
      });
    }
  }

  void _startPollingForStatus(String paymentId) {
    // Cancel any existing timer
    _pollingTimer?.cancel();
    
    // Start polling for payment status every 3 seconds
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      try {
        final status = await _paymentService.checkPaymentStatus(paymentId);
        
        if (!mounted) return;
        
        setState(() {
          _paymentStatus = status;
        });
        
        if (status == PaymentStatusType.completed) {
          timer.cancel();
          _handlePaymentSuccess();
        } else if (status == PaymentStatusType.failed || status == PaymentStatusType.canceled) {
          timer.cancel();
          setState(() {
            _isPolling = false;
            _errorMessage = status == PaymentStatusType.canceled 
                ? 'Payment was canceled.'
                : 'Payment failed. Please try again.';
          });
        }
      } catch (e) {
        timer.cancel();
        if (mounted) {
          setState(() {
            _isPolling = false;
            _errorMessage = 'Failed to check payment status: $e';
          });
        }
      }
    });
  }

  Future<void> _cancelPayment() async {
    if (_paymentId == null) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final success = await _paymentService.cancelPayment(_paymentId!);
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isPolling = false;
          _paymentStatus = success ? PaymentStatusType.canceled : _paymentStatus;
          if (success) {
            _errorMessage = 'Payment was canceled.';
          }
        });
      }
      
      _pollingTimer?.cancel();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to cancel payment: $e';
        });
      }
    }
  }

  void _handlePaymentSuccess() {
    if (!mounted) return;
    
    // Show success state in UI
    setState(() {
      _isPolling = false;
    });
    
    // Notify parent about successful payment
    if (widget.onPaymentSuccess != null) {
      widget.onPaymentSuccess!();
    }
    
    // Show success dialog and navigate back
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('onboarding.payment_successful'.tr()),
        content: Text('Your payment of ${widget.amount} IQD was successful.'),
        actions: [
          TextButton(
            onPressed: () {
              HapticUtils.lightTap();
              Navigator.pop(context); // Close dialog
              context.pop(); // Go back to previous screen
            },
            child: Text('common.done'.tr()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('onboarding.confirm_consultation'.tr()),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () {
            HapticUtils.lightTap();
            context.pop();
          },
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Payment information card
              Card(
                margin: const EdgeInsets.only(bottom: 24.0),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'onboarding.amount_due'.tr(),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${widget.amount} IQD',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        widget.description,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Payment status indicator (if payment is in progress)
              if (_paymentStatus != null) ...[
                Card(
                  margin: const EdgeInsets.only(bottom: 24.0),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _getStatusIcon(_paymentStatus!),
                            const SizedBox(width: 12),
                            Text(
                              'Payment Status: ${_getStatusText(_paymentStatus!)}',
                              style: theme.textTheme.titleMedium,
                            ),
                          ],
                        ),
                        if (_isPolling) ...[
                          const SizedBox(height: 16),
                          LinearProgressIndicator(
                            backgroundColor: theme.colorScheme.primary.withValues(alpha: 51.0),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Checking payment status...',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
              
              // Error message (if any)
              if (_errorMessage != null) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 24.0),
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.error.withValues(alpha: 26.0),
                    borderRadius: BorderRadius.circular(8.0),
                    border: Border.all(
                      color: theme.colorScheme.error.withValues(alpha: 128.0),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: theme.colorScheme.error,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              const Spacer(),
              
              // Terms agreement text
              Text(
                'onboarding.terms_agreement_prefix'.tr(),
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () {
                      // Navigate to terms and conditions
                    },
                    child: Text(
                      'onboarding.terms_conditions'.tr(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    'common.and'.tr(),
                    style: theme.textTheme.bodySmall,
                  ),
                  TextButton(
                    onPressed: () {
                      // Navigate to privacy policy
                    },
                    child: Text(
                      'onboarding.privacy_policy'.tr(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Action buttons
              if (_isPolling) ...[
                AnimatedButton(
                  text: 'common.cancel'.tr(),
                  onPressed: _cancelPayment,
                  isLoading: _isLoading,
                  isOutlined: true,
                ),
              ] else ...[
                AnimatedButton(
                  text: _paymentStatus == PaymentStatusType.completed 
                      ? 'common.done'.tr() 
                      : 'onboarding.pay_amount'.tr(args: ['${widget.amount}']),
                  onPressed: _paymentStatus == PaymentStatusType.completed
                      ? () => context.pop()
                      : _initiatePayment,
                  isLoading: _isLoading,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _getStatusIcon(PaymentStatusType status) {
    final theme = Theme.of(context);
    
    switch (status) {
      case PaymentStatusType.completed:
        return Icon(Icons.check_circle, color: theme.colorScheme.primary);
      case PaymentStatusType.pending:
        return const Icon(Icons.pending, color: AppColors.warning);
      case PaymentStatusType.failed:
      case PaymentStatusType.canceled:
        return Icon(Icons.cancel, color: theme.colorScheme.error);
      default:
        return Icon(Icons.help, color: theme.colorScheme.onSurfaceVariant);
    }
  }
  
  String _getStatusText(PaymentStatusType status) {
    switch (status) {
      case PaymentStatusType.completed:
        return 'Completed';
      case PaymentStatusType.pending:
        return 'Pending';
      case PaymentStatusType.failed:
        return 'Failed';
      case PaymentStatusType.canceled:
        return 'Canceled';
      default:
        return 'Unknown';
    }
  }
} 