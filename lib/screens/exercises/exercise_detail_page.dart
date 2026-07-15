import 'package:flutter/material.dart';
import 'package:gym_tracker/services/database_service.dart';
import 'package:gym_tracker/services/stats_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../enums/enums.dart';
import '../../../models/models.dart';
import '../../widgets/top_toast.dart';

class ExerciseDetailPage extends StatelessWidget {
  final Exercise exercise;

  const ExerciseDetailPage({super.key, required this.exercise});

  // --- METODĂ DESCHIDERE URL (MUSCLE WIKI) ---
  Future<void> _launchSourceUrl(BuildContext context) async {
    final Uri url = Uri.parse(exercise.sourceUrl);
    try {
      await launchUrl(url, mode: LaunchMode.inAppBrowserView);
    } catch (e) {
      if (!context.mounted) return;
      TopToast.show(context, 'Could not open the link', type: ToastType.warning);
    }
  }

  // --- CULORI DINAMICE DIFICULTATE ---
  // TODO - de mutat in logica dificultatii culorile
  Color _getDifficultyColor(Difficulty diff, ThemeData theme) {
    switch (diff.name.toLowerCase()) {
      case 'beginner':
        return Colors.green;
      case 'intermediate':
        return Colors.orange;
      case 'advanced':
      case 'expert':
        return Colors.red;
      default:
        return theme.colorScheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unit = DatabaseService.globalUnit;
    final prs = StatsService.getPersonalRecords(exercise.id);

    return DefaultTabController(
      length: 3, // Cele 3 Tab-uri: About, Instructions, PRs
      child: Scaffold(
        appBar: AppBar(
          title: Text(exercise.name),
          centerTitle: true,
          actions: [
            IconButton(
              icon: Icon(Icons.open_in_new_rounded, color: theme.colorScheme.primary, size: 22),
              tooltip: 'Open in Muscle Wiki',
              onPressed: () => _launchSourceUrl(context),
            ),
          ],
          bottom: TabBar(
            indicatorColor: theme.colorScheme.primary,
            labelColor: theme.colorScheme.primary,
            unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
            indicatorSize: TabBarIndicatorSize.tab,
            tabs: const [
              Tab(text: 'About', icon: Icon(Icons.info_outline, size: 20)),
              Tab(text: 'Instructions', icon: Icon(Icons.format_list_numbered_rounded, size: 20)),
              Tab(text: 'History & PRs', icon: Icon(Icons.emoji_events_outlined, size: 20)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildAboutTab(context, theme),
            _buildInstructionsTab(theme),
            _buildHistoryAndPRsTab(theme, prs, unit),
          ],
        ),
      ),
    );
  }

  // ==================== TAB 1: ABOUT ====================
  Widget _buildAboutTab(BuildContext context, ThemeData theme) {
    final primaryMuscle = exercise.primaryMuscles.isNotEmpty ? exercise.primaryMuscles.first : null;
    final secondaryMuscles = exercise.secondaryMuscles;
    final tertiaryMuscles = exercise.tertiaryMuscles;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Imaginea sau Placeholder-ul sus
          _buildCoverImage(theme),
          const SizedBox(height: 20),

          // Informații structurate elegant pe rânduri
          Text(
            'Exercise Profile',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
          ),
          const SizedBox(height: 10),
          Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.3)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  if (primaryMuscle != null)
                    _buildProfileRow(
                      theme,
                      icon: Icons.adjust_rounded,
                      label: 'Target Muscle',
                      value: primaryMuscle.group.name.toUpperCase(),
                      valueColor: theme.colorScheme.primary,
                    ),
                  _buildProfileRow(
                    theme,
                    icon: Icons.fitness_center_rounded,
                    label: 'Equipment',
                    value: exercise.equipment.name.replaceAll('_', ' ').toUpperCase(),
                  ),
                  if (exercise.mechanic != null)
                    _buildProfileRow(
                      theme,
                      icon: Icons.settings_accessibility_rounded,
                      label: 'Mechanics',
                      value: exercise.mechanic!.name.toUpperCase(),
                    ),
                  if (exercise.force != null)
                    _buildProfileRow(
                      theme,
                      icon: Icons.bolt_rounded,
                      label: 'Force Type',
                      value: exercise.force!.name.toUpperCase(),
                    ),
                  _buildProfileRow(
                    theme,
                    icon: Icons.speed_rounded,
                    label: 'Difficulty',
                    value: exercise.difficulty.name.toUpperCase(),
                    valueColor: _getDifficultyColor(exercise.difficulty, theme),
                  ),
                  if (exercise.grips.isNotEmpty)
                    _buildProfileRow(
                      theme,
                      icon: Icons.front_hand_outlined,
                      label: 'Required Grip',
                      value: exercise.grips.map((g) => g.name.toUpperCase()).join(', '),
                      isLast: true,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Grupele musculare recrutate (Secundari & Terțiari)
          if (secondaryMuscles.isNotEmpty || tertiaryMuscles.isNotEmpty) ...[
            Text(
              'Anatomy & Muscle Recruitment',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
            ),
            const SizedBox(height: 10),
            if (secondaryMuscles.isNotEmpty) ...[
              Text(
                'Secondary Muscles:',
                style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: secondaryMuscles.map((muscle) {
                  return _buildMuscleBadge(context, muscle.label.toUpperCase(), isSecondary: true);
                }).toList(),
              ),
              const SizedBox(height: 14),
            ],
            if (tertiaryMuscles.isNotEmpty) ...[
              Text(
                'Stabilizers / Tertiary:',
                style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: tertiaryMuscles.map((muscle) {
                  return _buildMuscleBadge(context, muscle.label.toUpperCase(), isSecondary: false);
                }).toList(),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }

  // ==================== TAB 2: INSTRUCTIONS ====================
  Widget _buildInstructionsTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Step-by-Step Guide',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
          ),
          const SizedBox(height: 16),
          if (exercise.instructions.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40.0),
                child: Text(
                  'No instructions available for this exercise.',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: exercise.instructions.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: theme.colorScheme.primary.withOpacity(0.15),
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(fontSize: 12, color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          exercise.instructions[index],
                          style: TextStyle(fontSize: 14, height: 1.5, color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          const SizedBox(height: 12),
          Center(
            child: TextButton.icon(
              onPressed: () => _launchSourceUrl(theme as BuildContext), // Context bypass sau redirecționare sigură
              icon: const Icon(Icons.language, size: 16),
              label: const Text('Read full breakdown on MuscleWiki',
                  style: TextStyle(fontSize: 13, decoration: TextDecoration.underline)),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== TAB 3: PERSONAL RECORDS ====================
  Widget _buildHistoryAndPRsTab(ThemeData theme, ExercisePRs prs, UnitSystem unit) {
    String formatValue(double valueInKg) {
      if (valueInKg == 0.0) return '—';

      // Folosim metoda `convert` și `label` din UnitSystem
      final double displayValue = unit == UnitSystem.lbs ? valueInKg * 2.2046226218 : valueInKg;

      final formattedNum = displayValue % 1 == 0 ? displayValue.toStringAsFixed(0) : displayValue.toStringAsFixed(1);

      return '$formattedNum ${unit.label}';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Personal Records 🏆',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
          ),
          const SizedBox(height: 6),
          Text(
            'Your lifetime achievements for this exercise.',
            style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),

          // Grilă cu cele 4 Recorduri Personale cheie (PRs)
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.4,
            children: [
              _buildPRCard(
                theme: theme,
                title: 'Heaviest Weight',
                value: formatValue(prs.heaviestWeight),
                icon: Icons.fitness_center_rounded,
                color: Colors.redAccent,
              ),
              _buildPRCard(
                theme: theme,
                title: 'Best Est. 1RM',
                value: formatValue(prs.best1RM),
                icon: Icons.star_rounded,
                color: Colors.amber,
              ),
              _buildPRCard(
                theme: theme,
                title: 'Best Set Volume',
                value: formatValue(prs.bestSetVolume),
                icon: Icons.view_headline_rounded,
                color: Colors.blueAccent,
              ),
              _buildPRCard(
                theme: theme,
                title: 'Best Session Vol.',
                value: formatValue(prs.bestSessionVolume),
                icon: Icons.analytics_rounded,
                color: Colors.purpleAccent,
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Secțiune dedicată istoricului recent
          Text(
            'Recent Performance',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.history_toggle_off_rounded, color: Colors.grey),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Workout history logs will appear here once you complete sessions with this exercise.',
                    style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== WIDGETS HELPERS ====================

  Widget _buildCoverImage(ThemeData theme) {
    if (exercise.coverImage != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset(
          'assets/${exercise.coverImage}',
          height: 200,
          width: double.infinity,
          fit: BoxFit.cover,
        ),
      );
    }
    return Container(
      height: 160,
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.15)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.fitness_center, size: 48, color: theme.colorScheme.primary.withOpacity(0.4)),
          const SizedBox(height: 8),
          Text(
            'No preview image available',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileRow(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    bool isLast = false,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10.0),
          child: Row(
            children: [
              Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: valueColor ?? theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
        if (!isLast) Divider(height: 1, color: theme.colorScheme.outlineVariant.withOpacity(0.3)),
      ],
    );
  }

  Widget _buildPRCard({
    required ThemeData theme,
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style:
                      TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurfaceVariant),
                ),
                Icon(icon, size: 18, color: color),
              ],
            ),
            Text(
              value,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMuscleBadge(BuildContext context, String label, {required bool isSecondary}) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isSecondary
            ? theme.colorScheme.surfaceContainerLow
            : theme.colorScheme.surfaceContainerLowest.withOpacity(0.4),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
            color: isSecondary
                ? theme.colorScheme.onSurfaceVariant.withOpacity(0.15)
                : theme.colorScheme.onSurfaceVariant.withOpacity(0.05)),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 10,
            fontWeight: isSecondary ? FontWeight.w600 : FontWeight.normal,
            color: isSecondary ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant),
      ),
    );
  }
}
