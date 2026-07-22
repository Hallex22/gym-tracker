import 'package:flutter/material.dart';

enum MuscleGroup {
  abdominals,
  biceps,
  calves,
  chest,
  feet,
  forearms,
  glutes,
  groin,
  hamstrings,
  lats,
  lowerBack,
  neck,
  obliques,
  quads,
  shoulders,
  traps,
  trapsMidBack,
  triceps,
  unknown;

  /// Culoarea reprezentativă unică pentru fiecare grupă musculară
  Color get color {
    switch (this) {
      case MuscleGroup.chest:
        return const Color(0xFFEF4444); // Red
      case MuscleGroup.biceps:
        return const Color(0xFF6366F1); // Indigo
      case MuscleGroup.triceps:
        return const Color(0xFF8B5CF6); // Purple
      case MuscleGroup.shoulders:
        return const Color(0xFFF59E0B); // Amber / Orange
      case MuscleGroup.lats:
      case MuscleGroup.trapsMidBack:
        return const Color(0xFF3B82F6); // Blue
      case MuscleGroup.traps:
        return const Color(0xFF0EA5E9); // Sky Blue
      case MuscleGroup.lowerBack:
        return const Color(0xFF64748B); // Slate
      case MuscleGroup.quads:
        return const Color(0xFF10B981); // Emerald / Green
      case MuscleGroup.hamstrings:
        return const Color(0xFF059669); // Dark Emerald
      case MuscleGroup.glutes:
        return const Color(0xFFEC4899); // Pink
      case MuscleGroup.calves:
        return const Color(0xFF14B8A6); // Teal
      case MuscleGroup.abdominals:
      case MuscleGroup.obliques:
        return const Color(0xFFF97316); // Bright Orange
      case MuscleGroup.forearms:
        return const Color(0xFFA855F7); // Light Purple
      case MuscleGroup.neck:
      case MuscleGroup.feet:
      case MuscleGroup.groin:
        return const Color(0xFF78716C); // Stone / Neutral
      case MuscleGroup.unknown:
        return const Color(0xFF9CA3AF); // Gray
    }
  }

  /// Denumire formatată automat (ex: trapsMidBack -> Traps Mid Back)
  String get displayName {
    switch (this) {
      case MuscleGroup.lowerBack:
        return 'Lower Back';
      case MuscleGroup.trapsMidBack:
        return 'Mid Back';
      default:
        final raw = name;
        if (raw.isEmpty) return '';
        // Transformă camelCase în cuvinte separate cu majusculă
        final formatted = raw.replaceAllMapped(
          RegExp(r'([A-Z])'),
          (match) => ' ${match.group(1)}',
        );
        return formatted[0].toUpperCase() + formatted.substring(1);
    }
  }
}
