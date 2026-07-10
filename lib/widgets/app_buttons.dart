import 'package:flutter/material.dart';

// --- 1. BUTON PLIN (FILLED) ---
class AppFilledButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final Color? backgroundColor;

  const AppFilledButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final style = ElevatedButton.styleFrom(
      backgroundColor: backgroundColor ?? Theme.of(context).colorScheme.primary,
      foregroundColor: Theme.of(context).colorScheme.onPrimary,
      minimumSize: const Size(double.infinity, 50),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
    );

    if (icon != null) {
      return ElevatedButton.icon(
        style: style,
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      );
    }

    return ElevatedButton(
      style: style,
      onPressed: onPressed,
      child: Text(label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
    );
  }
}

// --- 2. BUTON CU CONTUR (OUTLINED) ---
class AppOutlinedButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final IconData? icon;

  const AppOutlinedButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final style = OutlinedButton.styleFrom(
      minimumSize: const Size(double.infinity, 50),
      side: BorderSide(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.5)),
      foregroundColor: Theme.of(context).colorScheme.primary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );

    if (icon != null) {
      return OutlinedButton.icon(
        style: style,
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      );
    }

    return OutlinedButton(
      style: style,
      onPressed: onPressed,
      child: Text(label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
    );
  }
}

// --- 3. BUTON CU FUNDAL SEMI-TRANSPARENT (GHOST / TONAL) ---
class AppGhostButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final Color?
      customColor; // Opțional, dacă vrei altceva în afară de primary (ex: Colors.red pentru Delete)

  const AppGhostButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.customColor,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = customColor ?? Theme.of(context).colorScheme.primary;

    final style = TextButton.styleFrom(
      minimumSize: const Size(double.infinity, 50),
      backgroundColor: baseColor.withOpacity(0.12),
      foregroundColor: baseColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );

    if (icon != null) {
      return TextButton.icon(
        style: style,
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      );
    }

    return TextButton(
      style: style,
      onPressed: onPressed,
      child: Text(label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
    );
  }
}
