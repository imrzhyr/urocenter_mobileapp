# Verification Framework

This directory contains a unified verification framework designed to streamline verification processes across the application.

## Structure

- **verification.dart**: Main export file that makes it easy to import all verification components
- **verification_base.dart**: Contains the base classes and mixins for verification screens
- **verification_service.dart**: Central service for handling verification operations
- **otp_field.dart**: Reusable OTP input field component
- **resend_button.dart**: Reusable button for resending verification codes

## Usage

### Using VerificationBase (Recommended)

For most verification screens, extend `VerificationBase` to get access to all verification functionality:

```dart
class _MyVerificationScreenState extends VerificationBase<MyVerificationScreen> {
  @override
  void navigateAfterVerification(String routeName, {Object? extra}) {
    // Implement navigation logic
  }
  
  // Access to these methods:
  // - startResendTimer()
  // - cancelTimer()
  // - showError() and showSuccess()
  // - setLoading() and setVerified()
}
```

### Using VerificationAware Mixin

For screens that can't extend `VerificationBase`, use the `VerificationAware` mixin:

```dart
class _MyCustomScreenState extends State<MyCustomScreen> with VerificationAware {
  @override
  void navigateAfterVerification(String routeName, {Object? extra}) {
    // Implement navigation logic
  }
}
```

### Using the Verification Service

The `VerificationService` offers a centralized way to handle verification operations:

```dart
final verificationService = VerificationService();

// Phone verification
await verificationService.verifyPhoneNumber(
  phoneNumber: phoneNumber,
  verificationCompleted: _onVerificationCompleted,
  verificationFailed: _onVerificationFailed,
  codeSent: _onCodeSent,
  codeAutoRetrievalTimeout: _onCodeAutoRetrievalTimeout,
);

// OTP verification
await verificationService.verifyOtp(
  verificationId: verificationId,
  otp: otp,
);
```

### Using the UI Components

```dart
// OTP Input Field
OtpField(
  controller: otpController,
  onCompleted: handleOtpComplete,
  onChanged: handleOtpChange,
)

// Resend Button with Timer
ResendButton(
  remainingSeconds: remainingSeconds,
  onResend: handleResend,
)
```

## Best Practices

1. Keep verification logic in the service layer
2. Handle errors consistently
3. Always check mounted state before updating UI
4. Cancel timers properly when navigating away
5. Provide clear user feedback during verification 