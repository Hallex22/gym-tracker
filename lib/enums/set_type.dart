import 'package:flutter/material.dart';

enum SetType {
  normal(
      label: 'Normal',
      shortLabel: '',
      icon: Icons.check_circle_outline,
      color: null),
  warmup(
      label: 'Warmup',
      shortLabel: 'W',
      icon: Icons.whatshot_outlined,
      color: Colors.orangeAccent),
  failure(
      label: 'Failure',
      shortLabel: 'F',
      icon: Icons.warning_amber_rounded,
      color: Colors.redAccent),
  dropSet(
      label: 'Drop Set',
      shortLabel: 'D',
      icon: Icons.trending_down,
      color: Colors.purpleAccent);

  final String label;
  final String shortLabel;
  final IconData icon;
  final Color? color;

  const SetType(
      {required this.label,
      required this.shortLabel,
      required this.icon,
      this.color});
}
