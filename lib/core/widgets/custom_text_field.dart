import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/theme.dart';
import '../utils/haptic_utils.dart';

/// A custom text field with fixed placeholder and external error messages
class CustomTextField extends StatefulWidget {
  final String? label;
  final String hint;
  final String? errorText;
  final bool obscureText;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onFieldSubmitted;
  final List<TextInputFormatter>? inputFormatters;
  final Widget? prefix;
  final Widget? suffix;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixIconTap;
  final int? maxLength;
  final int? maxLines;
  final bool autofocus;
  final bool enabled;
  final FocusNode? focusNode;
  final FormFieldValidator<String>? validator;
  final VoidCallback? onTap;
  final Color? fillColor;
  final EdgeInsets? contentPadding;
  final bool readOnly;

  const CustomTextField({
    super.key,
    this.label,
    required this.hint,
    this.errorText,
    this.obscureText = false,
    required this.controller,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.onChanged,
    this.onSubmitted,
    this.inputFormatters,
    this.prefix,
    this.suffix,
    this.suffixIcon,
    this.onSuffixIconTap,
    this.maxLength,
    this.maxLines = 1,
    this.autofocus = false,
    this.enabled = true,
    this.focusNode,
    this.validator,
    this.onTap,
    this.fillColor,
    this.contentPadding,
    this.readOnly = false,
    this.onFieldSubmitted,
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  late FocusNode _focusNode;
  bool _hasFocus = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _handleFocusChange() {
    if (mounted) {
      setState(() {
        _hasFocus = _focusNode.hasFocus;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasError = widget.errorText != null && widget.errorText!.isNotEmpty || _errorMessage != null;
    final displayedError = widget.errorText ?? _errorMessage;
    
    // Animation values
    final Color borderColor = _hasFocus 
        ? AppColors.primary 
        : hasError 
            ? AppColors.error 
            : Colors.transparent;
    
    final Color fillColor = widget.fillColor ?? AppColors.inputBackground;

    // Build the suffix icon if provided
    Widget? suffixWidget = widget.suffix;
    if (widget.suffixIcon != null) {
      suffixWidget = IconButton(
        icon: Icon(widget.suffixIcon, color: AppColors.textSecondary), 
        onPressed: () {
          if (widget.onSuffixIconTap != null) {
            HapticUtils.lightTap();
            widget.onSuffixIconTap!();
          }
        },
        splashRadius: 20, // Make tap area reasonable
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: fillColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: borderColor,
              width: 1.5,
            ),
          ),
          child: TextFormField(
            controller: widget.controller,
            obscureText: widget.obscureText,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            focusNode: _focusNode,
            onChanged: widget.onChanged,
            onFieldSubmitted: widget.onFieldSubmitted,
            inputFormatters: widget.inputFormatters,
            maxLength: widget.maxLength,
            maxLines: widget.maxLines,
            autofocus: widget.autofocus,
            enabled: widget.enabled,
            readOnly: widget.readOnly,
            validator: (value) {
              // Clear previous error when validating again
              // setState(() { _errorMessage = null; });
              if (widget.validator != null) {
                final error = widget.validator!(value);
                // Use a post-frame callback to avoid setting state during build
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && _errorMessage != error) {
                     setState(() {
                       _errorMessage = error;
                     });
                  }
                });
                return error;
              }
              return null;
            },
            onTap: widget.onTap,
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: widget.hint,
              counter: const SizedBox.shrink(),
              contentPadding: widget.contentPadding ?? 
                  const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              prefixIcon: widget.prefix,
              suffixIcon: suffixWidget == null ? null : Center(
                widthFactor: 1.0,
                heightFactor: 1.0,
                child: suffixWidget,
              ),
              hintStyle: TextStyle(
                color: AppColors.textSecondary.withValues(alpha: 179.0),
                fontSize: 16,
                fontWeight: FontWeight.normal,
              ),
              errorStyle: const TextStyle(height: 0, fontSize: 0),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              filled: false,
              floatingLabelBehavior: FloatingLabelBehavior.never,
            ),
          ),
        ),
        // External error message with animation
        if (hasError) 
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 12),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: hasError ? 1.0 : 0.0,
              child: Text(
                displayedError ?? '',
                style: const TextStyle(
                  color: AppColors.error,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
      ],
    );
  }
} 