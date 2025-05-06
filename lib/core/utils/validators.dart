import 'package:easy_localization/easy_localization.dart';
import 'string_utils.dart';
import '../constants/app_constants.dart';

/// Form validation utilities
class Validators {
  /// Validate required field
  static String? validateRequired(String? value, String fieldName) {
    if (StringUtils.isNullOrEmpty(value)) {
      // Use namedArgs for clarity
      return 'errors.field_required'.tr(namedArgs: {'field': fieldName});
    }
    return null;
  }
  
  /// Validate email field
  static String? validateEmail(String? value) {
    if (StringUtils.isNullOrEmpty(value)) {
      return 'errors.email_required'.tr();
    }
    
    if (!StringUtils.isValidEmail(value!)) {
      return 'errors.invalid_email'.tr();
    }
    
    return null;
  }
  
  /// Validate phone number field
  static String? validatePhone(String? value) {
    if (StringUtils.isNullOrEmpty(value)) {
      return 'errors.phone_required'.tr();
    }
    
    if (!StringUtils.isValidPhoneNumber(value!)) {
      return 'errors.invalid_phone'.tr();
    }
    
    return null;
  }
  
  /// Validate password field
  static String? validatePassword(String? value) {
    if (StringUtils.isNullOrEmpty(value)) {
      return 'errors.password_required'.tr();
    }
    
    if (value!.length < AppConstants.passwordMinLength) {
      return 'errors.password_min_length'.tr(namedArgs: {'length': AppConstants.passwordMinLength.toString()});
    }
    
    if (!StringUtils.isValidPassword(value)) {
      return 'errors.password_format'.tr();
    }
    
    return null;
  }
  
  /// Validate password match
  static String? validatePasswordMatch(String? password, String? confirmPassword) {
    if (StringUtils.isNullOrEmpty(confirmPassword)) {
      return 'errors.confirm_password_required'.tr();
    }
    
    if (password != confirmPassword) {
      return 'errors.passwords_dont_match'.tr();
    }
    
    return null;
  }
  
  /// Validate OTP code
  static String? validateOtp(String? value) {
    if (StringUtils.isNullOrEmpty(value)) {
      return 'errors.otp_required'.tr();
    }
    
    if (value!.length != AppConstants.otpLength) {
      return 'errors.otp_length'.tr(namedArgs: {'length': AppConstants.otpLength.toString()});
    }
    
    if (!RegExp(r'^\d+$').hasMatch(value)) {
      return 'errors.otp_format'.tr();
    }
    
    return null;
  }
  
  /// Validate age field
  static String? validateAge(String? value) {
    if (StringUtils.isNullOrEmpty(value)) {
      return 'errors.age_required'.tr();
    }
    
    final age = int.tryParse(value!);
    if (age == null) {
      return 'errors.invalid_age'.tr();
    }
    
    if (age < 18) {
      return 'errors.age_min'.tr(namedArgs: {'minAge': '18'});
    }
    
    if (age > 120) {
      return 'errors.invalid_age'.tr();
    }
    
    return null;
  }
  
  /// Validate height field (in cm)
  static String? validateHeight(String? value) {
    if (StringUtils.isNullOrEmpty(value)) {
      return 'errors.height_required'.tr();
    }
    
    final height = double.tryParse(value!);
    if (height == null) {
      return 'errors.invalid_height'.tr();
    }
    
    if (height < 50 || height > 250) {
      return 'errors.height_range'.tr(namedArgs: {'min': '50', 'max': '250'});
    }
    
    return null;
  }
  
  /// Validate weight field (in kg)
  static String? validateWeight(String? value) {
    if (StringUtils.isNullOrEmpty(value)) {
      return 'errors.weight_required'.tr();
    }
    
    final weight = double.tryParse(value!);
    if (weight == null) {
      return 'errors.invalid_weight'.tr();
    }
    
    if (weight < 30 || weight > 300) {
      return 'errors.weight_range'.tr(namedArgs: {'min': '30', 'max': '300'});
    }
    
    return null;
  }
  
  /// Validate text field with minimum length
  static String? validateMinLength(String? value, String fieldName, int minLength) {
    if (StringUtils.isNullOrEmpty(value)) {
      return 'errors.field_required'.tr(namedArgs: {'field': fieldName});
    }
    
    if (value!.length < minLength) {
      return 'errors.min_length'.tr(namedArgs: {'field': fieldName, 'length': minLength.toString()});
    }
    
    return null;
  }
  
  /// Validate text field with maximum length
  static String? validateMaxLength(String? value, String fieldName, int maxLength) {
    if (StringUtils.isNullOrEmpty(value)) {
      return 'errors.field_required'.tr(namedArgs: {'field': fieldName});
    }
    
    if (value!.length > maxLength) {
      return 'errors.max_length'.tr(namedArgs: {'field': fieldName, 'length': maxLength.toString()});
    }
    
    return null;
  }
  
  /// Validate text field with minimum and maximum length
  static String? validateLength(String? value, String fieldName, int minLength, int maxLength) {
    if (StringUtils.isNullOrEmpty(value)) {
      return 'errors.field_required'.tr(namedArgs: {'field': fieldName});
    }
    
    if (value!.length < minLength) {
      return 'errors.min_length'.tr(namedArgs: {'field': fieldName, 'length': minLength.toString()});
    }
    
    if (value.length > maxLength) {
      return 'errors.max_length'.tr(namedArgs: {'field': fieldName, 'length': maxLength.toString()});
    }
    
    return null;
  }
  
  /// Validate numeric field
  static String? validateNumeric(String? value, String fieldName) {
    if (StringUtils.isNullOrEmpty(value)) {
      return 'errors.field_required'.tr(namedArgs: {'field': fieldName});
    }
    
    if (!RegExp(r'^\d+$').hasMatch(value!)) {
      return 'errors.numeric_only'.tr(namedArgs: {'field': fieldName});
    }
    
    return null;
  }
  
  /// Validate name field (simple check for non-empty and basic characters)
  static String? validateName(String? value) {
    if (StringUtils.isNullOrEmpty(value)) {
      return 'errors.name_required'.tr();
    }
    // Allow letters, spaces, hyphens, apostrophes
    if (!RegExp(r"^[a-zA-Z '\-]+\$").hasMatch(value!)) {
      return 'errors.invalid_name'.tr();
    }
    if (value.length < 2) {
      return 'errors.name_min_length'.tr(namedArgs: {'length': '2'});
    }
    return null;
  }
} 