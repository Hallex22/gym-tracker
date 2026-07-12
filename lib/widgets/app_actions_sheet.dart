import 'package:flutter/material.dart';

/// Un element individual din meniul de acțiuni
class SheetActionItem {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color? color;

  const SheetActionItem({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color,
  });
}

class AppActionsSheet extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<SheetActionItem> actions;

  const AppActionsSheet({
    super.key,
    required this.title,
    this.subtitle,
    required this.actions,
  });

  /// Metodă statică utilitară pentru a afișa foaia de acțiuni rapid de oriunde
  static void show({
    required BuildContext context,
    required String title,
    String? subtitle,
    required List<SheetActionItem> actions,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => AppActionsSheet(
        title: title,
        subtitle: subtitle,
        actions: actions,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.only(
        top: 12,
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment:
            CrossAxisAlignment.center, // 💡 Aliniere centrală pe axa secundară
        children: [
          // Indicatorul vizual de tragere (băra de sus)
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // 💡 Titlu centrat text
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
          ),

          // 💡 Subtitlu centrat text
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
            ),
          ],

          const SizedBox(height: 12),

          // 💡 Divider upgradat cu primary.withOpacity(0.2)
          Divider(color: theme.colorScheme.primary.withOpacity(0.2)),

          // Lista de acțiuni dinamice
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: actions.length,
            itemBuilder: (context, index) {
              final action = actions[index];

              // 💡 Implicit folosește theme.colorScheme.onSurfaceVariant dacă nu pasăm o culoare custom (cum e roșul de delete)
              final itemColor =
                  action.color ?? theme.colorScheme.onSurfaceVariant;

              return ListTile(
                leading: Icon(action.icon, color: itemColor),
                title: Text(
                  action.label,
                  style:
                      TextStyle(color: itemColor, fontWeight: FontWeight.w500, fontSize: 14),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                onTap: () {
                  Navigator.pop(context); // Închide mai întâi drawer-ul
                  action.onPressed(); // Rulează acțiunea cerută
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
