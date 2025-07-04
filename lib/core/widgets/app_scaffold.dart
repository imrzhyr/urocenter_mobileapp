import 'package:flutter/material.dart';

/// A consistent scaffold implementation for the app
/// 
/// This scaffold handles safe area and provides a consistent layout
/// across all screens.
class AppScaffold extends StatelessWidget {
  /// The body of the scaffold
  final Widget body;
  
  /// The app bar to display at the top of the scaffold
  final PreferredSizeWidget? appBar;
  
  /// The bottom navigation bar
  final Widget? bottomNavigationBar;
  
  /// A persistent button displayed at the bottom of the scaffold.
  final Widget? persistentFooterButton;
  
  /// The background color of the scaffold
  final Color? backgroundColor;
  
  /// Whether to use a safe area for the body
  final bool useSafeArea;
  
  /// Whether to resize to avoid the bottom inset
  final bool resizeToAvoidBottomInset;
  
  /// The padding to apply to the body
  final EdgeInsets? padding;
  
  /// Creates an AppScaffold
  const AppScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.bottomNavigationBar,
    this.persistentFooterButton,
    this.backgroundColor,
    this.useSafeArea = true,
    this.resizeToAvoidBottomInset = true,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = body;
    
    if (padding != null) {
      content = Padding(
        padding: padding!,
        child: content,
      );
    }
    
    if (useSafeArea) {
      // Adjust SafeArea based on whether a persistent button or bottom nav bar exists
      // final bool hasBottomContent = persistentFooterButton != null || bottomNavigationBar != null;
      content = SafeArea(
        top: true,
        // bottom: !hasBottomContent, // CHANGE: Always disable bottom SafeArea padding
        bottom: false, 
        maintainBottomViewPadding: true,
        child: content,
      );
    }
    
    // Prepare footer buttons list with padding
    List<Widget>? footerButtons;
    if (persistentFooterButton != null) {
      footerButtons = [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: persistentFooterButton!,
        )
      ];
    }
    
    return Scaffold(
      appBar: appBar,
      backgroundColor: backgroundColor ?? Theme.of(context).colorScheme.surface,
      body: content,
      bottomNavigationBar: bottomNavigationBar,
      persistentFooterButtons: footerButtons,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
    );
  }
} 