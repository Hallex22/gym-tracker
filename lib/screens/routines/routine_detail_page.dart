import 'package:flutter/material.dart';
import 'package:gym_tracker/screens/exercises/exercise_detail_page.dart';
import 'package:gym_tracker/screens/routines/routine_form_page.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';
import '../../widgets/app_actions_sheet.dart';
import '../workout/active_workout_page.dart';

class RoutineDetailPage extends StatefulWidget {
  final Routine routine;
  final dynamic
      routineKey; // Cheia din Hive pentru a o putea trimite mai departe la editare/ștergere

  const RoutineDetailPage({
    super.key,
    required this.routine,
    required this.routineKey,
  });

  @override
  State<RoutineDetailPage> createState() => _RoutineDetailPageState();
}

class _RoutineDetailPageState extends State<RoutineDetailPage> {
  // --- DRAWER-UL TĂU CUSTOM PREMIUM PENTRU OPȚIUNI ---
  void _showRoutineOptionsSheet(BuildContext context) {
    final theme = Theme.of(context);

    AppActionsSheet.show(
      context: context,
      title: 'Routine Options ⚙️',
      subtitle: widget.routine.title,
      actions: [
        // 1. Editare Rutină
        SheetActionItem(
          icon: Icons.edit_outlined,
          label: 'Edit Routine Structure',
          color: Colors.orangeAccent,
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => RoutineFormPage(
                  routine: widget.routine,
                  routineKey: widget.routineKey,
                ),
              ),
            );
            if (mounted) setState(() {});
          },
        ),

        // 2. Share Rutină
        SheetActionItem(
          icon: Icons.share_outlined,
          label: 'Share Routine Code',
          color: theme.colorScheme.primary,
          onPressed: () {
            final String shareCode = widget.routine.toShareCode();
            _showShareCodeDialog(context, shareCode);
          },
        ),

        // 3. Ștergere Rutină
        SheetActionItem(
          icon: Icons.delete_outline,
          label: 'Delete Routine',
          color: Colors.redAccent,
          onPressed: () {
            _showDeleteConfirmationDialog(context);
          },
        ),
      ],
    );
  }

  // --- DIALOG AFIȘARE COD SHARE ---
  void _showShareCodeDialog(BuildContext context, String code) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Routine Share Code 📋'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'Give this code to your friend. They can import it directly into their app:',
                style: TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
            SelectableText(
              code,
              style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: Colors.blueAccent),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // --- DIALOGUL DE CONFIRMARE PENTRU ȘTERGERE ---
  void _showDeleteConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Routine? 🚨'),
        content: Text(
            'Are you sure you want to delete "${widget.routine.title}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              await DatabaseService.routinesBox.delete(widget.routineKey);
              if (!context.mounted) return;

              Navigator.pop(context); // Închidem dialogul
              Navigator.pop(context); // Ne întoarcem pe HomePage

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('"${widget.routine.title}" deleted.')),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Routine Preview'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            tooltip: 'Options',
            onPressed: () => _showRoutineOptionsSheet(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // --- HEADER RUTINĂ ---
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                  child: Icon(Icons.layers, color: theme.colorScheme.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.routine.title,
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.routine.exercises.length} exercises included',
                        style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: theme.colorScheme.primary.withOpacity(0.2)),

          // --- LISTA DE EXERCIȚII DIN RUTINĂ ---
          Expanded(
            child: widget.routine.exercises.isEmpty
                ? Center(
                    child: Text('This routine has no exercises yet.',
                        style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant)),
                  )
                : ListView.builder(
                    itemCount: widget.routine.exercises.length,
                    padding: const EdgeInsets.all(16),
                    itemBuilder: (context, index) {
                      final routineExercise = widget.routine.exercises[index];

                      // Extragem obiectul full Exercise din cutia globală Hive
                      final rawExerciseData =
                          DatabaseService.exercisesBox.get(routineExercise.exerciseId);

                      Exercise? fullExercise;
                      String exerciseName = 'Unknown Exercise';
                      String muscleGroup = 'Core';
                      String equipmentName = 'Bodyweight';
                      String? coverImage;

                      if (rawExerciseData != null) {
                        if (rawExerciseData is Map) {
                          fullExercise = Exercise.fromMap(rawExerciseData);
                        } else {
                          fullExercise = rawExerciseData as Exercise;
                        }

                        exerciseName = fullExercise.name;
                        muscleGroup = fullExercise.primaryMuscles.isNotEmpty
                            ? fullExercise.primaryMuscles.first.group.name
                            : 'Target';
                        equipmentName =
                            fullExercise.equipment.name.toUpperCase();
                        coverImage = fullExercise.coverImage;
                      }

                      final isImageEmpty =
                          coverImage == null || coverImage.trim().isEmpty;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () {
                            if (fullExercise != null) {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ExerciseDetailPage(
                                        exercise: fullExercise!),
                                  ));
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Row(
                              children: [
                                // 1. Indexul numeric al exercițiului
                                SizedBox(
                                  width: 24,
                                  child: Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.onSurfaceVariant
                                          .withOpacity(0.6),
                                      fontSize: 14,
                                    ),
                                    textAlign: Alignment.center.x == 0
                                        ? TextAlign.center
                                        : TextAlign.start,
                                  ),
                                ),
                                const SizedBox(width: 8),

                                // 💡 2. NEW ELEMENT: Avatarul circular cu imaginea exercițiului
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor:
                                      theme.colorScheme.surfaceContainerHighest,
                                  backgroundImage: !isImageEmpty
                                      ? AssetImage('assets/$coverImage')
                                      : null,
                                  child: isImageEmpty
                                      ? Icon(
                                          Icons.image_not_supported,
                                          size: 14,
                                          color: theme
                                              .colorScheme.onSurfaceVariant,
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 14),

                                // 3. Informațiile text despre exercițiu (ocupă tot spațiul rămas liber)
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        exerciseName,
                                        style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: theme.colorScheme.onSurface),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '${muscleGroup.toUpperCase()} • $equipmentName',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: theme
                                                .colorScheme.onSurfaceVariant,
                                            fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),

                                // 💡 4. MUTAT ÎN CAPĂT: Badge-ul exclusiv cu numărul de seturi țintă
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary
                                        .withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                        color: theme.colorScheme.primary
                                            .withOpacity(0.15)),
                                  ),
                                  child: Text(
                                    '${routineExercise.targetSetsCount} SETS',
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.primary),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // --- BUTONUL MARE DE START WORKOUT ---
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                  ),
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ActiveWorkoutPage(routine: widget.routine),
                      ),
                    );
                  },
                  icon: const Icon(Icons.play_arrow, size: 24),
                  label: const Text(
                    'Start Workout',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
