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
                  color: Colors.blueAccent.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blueAccent.withOpacity(0.2)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.fitness_center,
                        size: 48, color: Colors.blueAccent.withOpacity(0.5)),
                    const SizedBox(height: 8),
                    Text(
                      'No preview image available',
                      style:
                          TextStyle(color: Colors.grey.shade500, fontSize: 13),
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
                    label: 'Target: ${primaryMuscle.name.toUpperCase()}',
                    color: Colors.blueAccent,
                  ),
                _buildInfoChip(
                  label: exercise.equipment.name.toUpperCase(),
                  color: Colors.amber.shade700,
                ),
                _buildInfoChip(
                  label: exercise.mechanics.name.toUpperCase(),
                  color: Colors.purpleAccent,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // --- GRUPE MUSCULARE SECUNDARE ---
            if (secondaryMuscles.isNotEmpty) ...[
              const Text(
                'Secondary Muscles Covered',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                children: secondaryMuscles.map((muscle) {
                  return Chip(
                    label: Text(muscle.name.toUpperCase(),
                        style: const TextStyle(fontSize: 11)),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    backgroundColor: Colors.blueGrey.withOpacity(0.1),
                    side: BorderSide.none,
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
            ],

            const Divider(),
            const SizedBox(height: 10),

            // --- INSTRUCȚIUNI PAS CU PAS ---
            const Text(
              'Instructions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (exercise.instructions.isEmpty)
              const Text('No instructions available for this exercise.',
                  style: TextStyle(color: Colors.grey))
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
                          backgroundColor: Colors.blueAccent.withOpacity(0.2),
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                                fontSize: 11,
                                color: Colors.blueAccent,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            exercise.instructions[index],
                            style: const TextStyle(fontSize: 14, height: 1.4),
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

  Widget _buildInfoChip({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style:
            TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11),
      ),
    );
  }
}
