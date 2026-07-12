import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart'; // 💡 Necesar pentru deschiderea link-ului Muscle Wiki
import '../../../enums/enums.dart';
import '../../../models/models.dart';

class ExerciseDetailPage extends StatelessWidget {
  final Exercise exercise;

  const ExerciseDetailPage({super.key, required this.exercise});

  // --- METODĂ DESCHIDERE URL (MUSCLE WIKI) ---
  Future<void> _launchSourceUrl(BuildContext context) async {
    final Uri url = Uri.parse(exercise.sourceUrl);
    try {
      // 💡 Folosim inAppBrowserView pentru o experiență mult mai integrată și fluidă
      await launchUrl(url, mode: LaunchMode.inAppBrowserView);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the link. 🌐')),
      );
    }
  }

  // --- HELPER DIFICULTATE (CULORI DINAMICE STYLE HEAVY) ---
  Color _getDifficultyColor(Difficulty diff, ThemeData theme) {
    switch (diff.name.toLowerCase()) {
      case 'beginner':
        return Colors.lightGreenAccent;
      case 'intermediate':
        return Colors.orangeAccent;
      case 'advanced':
      case 'expert':
        return Colors.redAccent;
      default:
        return theme.colorScheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final primaryMuscle = exercise.primaryMuscles.isNotEmpty
        ? exercise.primaryMuscles.first
        : null;
    final secondaryMuscles = exercise.secondaryMuscles;
    final tertiaryMuscles = exercise.tertiaryMuscles;

    return Scaffold(
      appBar: AppBar(
        title: Text(exercise.name),
        centerTitle: false, // Forțat elegant la stânga pentru consistență
        actions: [
          // 💡 WEB LINK CĂTRE MUSCLE WIKI IN APP BAR
          IconButton(
            icon: Icon(Icons.open_in_new_rounded,
                color: theme.colorScheme.primary, size: 22),
            tooltip: 'Open in Muscle Wiki',
            onPressed: () => _launchSourceUrl(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- SECȚIUNEA ASSET (Imagine / Placeholder) ---
            if (exercise.coverImage != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/${exercise.coverImage}',
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              )
            else
              Container(
                height: 160,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: theme.colorScheme.primary.withOpacity(0.15)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.fitness_center,
                        size: 48,
                        color: theme.colorScheme.primary.withOpacity(0.4)),
                    const SizedBox(height: 8),
                    Text(
                      'No preview image available',
                      style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 13),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),

            // --- INFO TAGS COMPREHENSIVE (Echipament, Mecanică, Forță, Dificultate) ---
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (primaryMuscle != null)
                  _buildInfoChip(
                    context: context,
                    label: 'TARGET: ${primaryMuscle.group.name.toUpperCase()}',
                    color: theme.colorScheme.primary,
                  ),
                _buildInfoChip(
                  context: context,
                  label: exercise.equipment.name.toUpperCase(),
                  color: theme.colorScheme.secondary,
                ),
                if (exercise.mechanic != null)
                  _buildInfoChip(
                    context: context,
                    label: exercise.mechanic!.name.toUpperCase(),
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                // 💡 NOU: Tipul de Forță (Push / Pull / Static)
                if (exercise.force != null)
                  _buildInfoChip(
                    context: context,
                    label: 'FORCE: ${exercise.force!.name.toUpperCase()}',
                    color: theme.colorScheme.tertiary,
                  ),
                // 💡 NOU: Dificultate inteligentă (Color-coded)
                _buildInfoChip(
                  context: context,
                  label: exercise.difficulty.name.toUpperCase(),
                  color: _getDifficultyColor(exercise.difficulty, theme),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // --- 💡 NOU: SECȚIUNE TIPURI DE PRIZĂ (GRIPS) ---
            if (exercise.grips.isNotEmpty) ...[
              Row(
                children: [
                  Icon(Icons.front_hand_outlined,
                      size: 16, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text(
                    'Required Grip: ',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurfaceVariant),
                  ),
                  Text(
                    exercise.grips.map((g) => g.name.toUpperCase()).join(', '),
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],

            // --- TARGET MUSCULAR (SECUNDAR & TERȚIAR) ---
            if (secondaryMuscles.isNotEmpty || tertiaryMuscles.isNotEmpty) ...[
              Text(
                'Muscles Recruited',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface),
              ),
              const SizedBox(height: 8),

              // Mușchi Secundari
              if (secondaryMuscles.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: secondaryMuscles.map((muscle) {
                      return _buildMuscleBadge(
                          context, muscle.label.toUpperCase(),
                          isSecondary: true);
                    }).toList(),
                  ),
                ),

              // 💡 NOU: Mușchi Terțiari (Afișați mai subtil / opacity mai mică)
              if (tertiaryMuscles.isNotEmpty)
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: tertiaryMuscles.map((muscle) {
                    return _buildMuscleBadge(
                        context, muscle.label.toUpperCase(),
                        isSecondary: false);
                  }).toList(),
                ),
              const SizedBox(height: 24),
            ],

            Divider(color: theme.colorScheme.primary.withOpacity(0.2)),
            const SizedBox(height: 10),

            // --- INSTRUCȚIUNI PAS CU PAS ---
            Text(
              'Instructions',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface),
            ),
            const SizedBox(height: 12),
            if (exercise.instructions.isEmpty)
              Text(
                'No instructions available for this exercise.',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: exercise.instructions.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 11,
                          backgroundColor:
                              theme.colorScheme.primary.withOpacity(0.15),
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                                fontSize: 11,
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            exercise.instructions[index],
                            style: TextStyle(
                                fontSize: 14,
                                height: 1.4,
                                color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

            // --- 💡 NOU: FOOTER DE TIP BUTON LINK SPRE SURSĂ EXTENDED ---
            const SizedBox(height: 16),
            Center(
              child: TextButton.icon(
                onPressed: () => _launchSourceUrl(context),
                icon: const Icon(Icons.language, size: 16),
                label: const Text('Read full breakdown on MuscleWiki',
                    style: TextStyle(
                        fontSize: 13, decoration: TextDecoration.underline)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGET HELPER INTEGRAT PE DETALII DE CULOARE ---
  Widget _buildInfoChip({
    required BuildContext context,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(
        label,
        style:
            TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11),
      ),
    );
  }

  // --- HELPER BADGE CONTEXTUAL PENTRU MUSCHI SECUNDARI/TERȚIARI ---
  Widget _buildMuscleBadge(BuildContext context, String label,
      {required bool isSecondary}) {
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
            color: isSecondary
                ? theme.colorScheme.onSurface
                : theme.colorScheme.onSurfaceVariant),
      ),
    );
  }
}
