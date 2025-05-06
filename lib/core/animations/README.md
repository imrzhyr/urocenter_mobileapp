# UroCenter Modern Animation System

A collection of advanced animation components for creating fluid, engaging user experiences.

## Animation Components

### AnimatedTransitions
Advanced page transitions for moving between screens:
- Perspective transitions
- Blur slide transitions 
- Bounce transitions
- Card flip transitions

### LiquidProgress
A modern, fluid progress indicator for stepped workflows:
- Smooth step transitions
- Animated progress bar
- Customizable dots and labels
- Subtle glow effects

### PulseButton
Interactive buttons with tactile feedback:
- Subtle pulse animation for primary actions
- Haptic-like visual feedback on press
- State-based animations (hover, press, loading)
- Customizable with icons and styles

### AnimatedContent
Components for choreographed content entrances:
- Staggered animations for lists
- Fade and slide entrances
- Zoom and bounce options
- Delayed animation sequences

## Usage Examples

### Modern Onboarding Flow

```dart
// Inside your onboarding screens
return StaggeredAnimatedList(
  entryType: AnimationEntryType.fadeSlideUp,
  staggerDelay: const Duration(milliseconds: 100),
  children: [
    Text('Welcome to UroCenter'),
    FeatureHighlight(),
    ActionButton(),
  ],
);
```

### Dynamic Verification UI

```dart
// Animated form fields with validation feedback
AnimatedBuilder(
  animation: _animationController,
  builder: (context, child) {
    final dx = hasError ? math.sin(_animationController.value * 4 * math.pi) * 10 : 0.0;
    return Transform.translate(
      offset: Offset(dx, 0),
      child: child,
    );
  },
  child: YourFormField(),
);
```

### Liquid Step Progress

```dart
LiquidProgress(
  currentStep: 2,
  totalSteps: 5,
  height: 6.0,
  indicatorSize: 16.0,
  showLabels: true,
)
```

### Interactive Buttons

```dart
PulseButton(
  text: 'Continue',
  onPressed: handleContinue,
  icon: Icons.arrow_forward,
  isLoading: isProcessing,
)
```

## Design Inspiration

These components are inspired by modern mobile design patterns from leading applications:
- Smooth transitions from Airbnb
- Playful interactions from Duolingo
- Subtle feedback from Phantom Wallet
- Fluid animations from top health apps 