import 'package:flutter/material.dart';

/// Update this when releasing a new APK so we can tell builds apart.
const String kAppVersion = '1.0.8 (build 9)';

const Color kTeal = Color(0xFF0F766E);
const Color kTealDeep = Color(0xFF0B4F48);
const Color kTealBright = Color(0xFF14B8A6);
const Color kAmber = Color(0xFFF59E0B);
const Color kInk = Color(0xFF10201D);
const Color kPaper = Color(0xFFF6F7F6);

/// Brand teal adjusted for the current brightness: the deep teal is
/// unreadable on dark surfaces, so dark mode gets the bright variant.
/// This keeps the *same* Jakarta typeface — only its color adapts.
Color proTeal(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? kTealBright : kTeal;

/// Any accent color lifted toward white in dark mode for contrast.
Color vivid(BuildContext context, Color c) {
  if (Theme.of(context).brightness == Brightness.dark) {
    return Color.lerp(c, Colors.white, 0.3)!;
  }
  return c;
}

/// Secondary text that stays readable in both modes.
Color muted(BuildContext context) =>
    Theme.of(context).colorScheme.onSurfaceVariant;

/// Soft filled surfaces (bubbles, pills, placeholders) in both modes.
Color softBg(BuildContext context) =>
    Theme.of(context).colorScheme.surfaceContainerHighest;
