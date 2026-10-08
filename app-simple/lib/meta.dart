import 'package:flutter/material.dart';
import 'api.dart';

/// Trades + cities served by GET /api/meta, cached for pickers and chips.
class MetaCache {
  static List<Map<String, dynamic>> trades = [];
  static List<String> cities = [];
  static bool loaded = false;

  static Future<void> ensure(ApiClient api) async {
    if (loaded) return;
    try {
      final m = await api.meta();
      trades = ((m['trades'] as List?) ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      cities = ((m['cities'] as List?) ?? []).map((e) => '$e').toList();
    } catch (_) {
      // Offline: pickers fall back to free text.
    }
    loaded = true;
  }

  static String label(String slug) {
    for (final t in trades) {
      if (t['slug'] == slug) return (t['label'] ?? slug) as String;
    }
    return slug;
  }
}

IconData tradeIcon(String key) {
  switch (key) {
    case 'brush':
      return Icons.brush_outlined;
    case 'plumbing':
      return Icons.plumbing_outlined;
    case 'bolt':
      return Icons.electrical_services_outlined;
    case 'hammer':
      return Icons.handyman_outlined;
    case 'wall':
      return Icons.foundation_outlined;
    case 'grid':
      return Icons.grid_on_outlined;
    case 'spark':
      return Icons.flash_on_outlined;
    case 'wrench':
      return Icons.build_outlined;
    case 'ruler':
      return Icons.architecture_outlined;
    case 'spray':
      return Icons.cleaning_services_outlined;
    case 'leaf':
      return Icons.yard_outlined;
    case 'scissors':
      return Icons.content_cut_outlined;
    case 'window':
      return Icons.window_outlined;
    default:
      return Icons.work_outline;
  }
}
