import 'package:flutter/material.dart';
import '../../enums/enums.dart';
import '../../models/models.dart';

class ExerciseDetailPage extends StatelessWidget {
  final Exercise exercise;

  const ExerciseDetailPage({super.key, required this.exercise});

  @override
  Widget build(BuildContext context) {
    // Grupa principală este prima din listă, restul sunt secundare
    final primaryMuscle =
        exercise.muscleGroups.isNotEmpty ? exercise.muscleGroups.first : null;
    final secondaryMuscles = exercise.muscleGroups.skip(1).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(exercise.name),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- SECȚIUNEA ASSET (Imagine / Placeholder) ---
            if (exercise.assetImagePath != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  exercise.assetImagePath!,
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
                  color:
                      Theme.of(context).colorScheme.primary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.15)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.fitness_center,
                      size: 48,
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.4),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No preview image available',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),

            // --- INFO TAGS (Echipament, Mecanică, Grupa Principală) ---
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (primaryMuscle != null)
                  _buildInfoChip(
                    context: context,
                    label: 'Target: ${primaryMuscle.name.toUpperCase()}',
                    useSecondaryColor: false, // Va folosi Primary (Mov Vibrant)
                  ),
                _buildInfoChip(
                  context: context,
                  label: exercise.equipment.name.toUpperCase(),
                  useSecondaryColor:
                      true, // Va folosi Secondary (Mov Neon) pentru contrast
                ),
                _buildInfoChip(
                  context: context,
                  label: exercise.mechanics.name.toUpperCase(),
                  useSecondaryColor: false,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // --- GRUPE MUSCULARE SECUNDARE ---
            if (secondaryMuscles.isNotEmpty) ...[
              Text(
                'Secondary Muscles Covered',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant, // Muted text
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                children: secondaryMuscles.map((muscle) {
                  return Chip(
                    label: Text(
                      muscle.name.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    side: BorderSide(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant
                            .withOpacity(0.2)),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
            ],

            Divider(color: Theme.of(context).colorScheme.primary.withOpacity(0.2)),
            const SizedBox(height: 10),

            // --- INSTRUCȚIUNI PAS CU PAS ---
            Text(
              'Instructions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color:
                    Theme.of(context).colorScheme.onSurface, // Important (Alb)
              ),
            ),
            const SizedBox(height: 12),
            if (exercise.instructions.isEmpty)
              Text(
                'No instructions available for this exercise.',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
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
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.15),
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary, // Cifrele sunt mov
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            exercise.instructions[index],
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.4,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant, // Text normal (Muted)
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  // --- WIDGET HELPER CONFIGURAT PE TEMĂ ---
  Widget _buildInfoChip({
    required BuildContext context,
    required String label,
    required bool useSecondaryColor,
  }) {
    // Alegem între nuanța Primary (Mov Vibrant) sau Secondary (Mov Neon)
    final Color chosenColor = useSecondaryColor
        ? Theme.of(context).colorScheme.secondary
        : Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: chosenColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: chosenColor.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: chosenColor,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }
}
