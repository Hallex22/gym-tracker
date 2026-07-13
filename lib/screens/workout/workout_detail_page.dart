import 'package:flutter/material.dart';
import 'package:gym_tracker/utils/date_utils.dart';
import '../../main.dart';
import '../../models/models.dart';
import '../../widgets/app_actions_sheet.dart';
import '../exercises/exercise_detail_page.dart'; // 💡 Import adăugat pentru detalii
import 'workout_form_page.dart';

class WorkoutDetailPage extends StatefulWidget {
  final dynamic
      logKey; // Cheia unică din logsBox pentru a putea șterge/edita direct
  final WorkoutLog log;

  const WorkoutDetailPage({
    super.key,
    required this.logKey,
    required this.log,
  });

  @override
  State<WorkoutDetailPage> createState() => _WorkoutDetailPageState();
}

class _WorkoutDetailPageState extends State<WorkoutDetailPage> {
  late WorkoutLog _currentLog;

  @override
  void initState() {
    super.initState();
    _currentLog = widget.log;
  }

  void _refreshLogData() {
    final updatedData = logsBox.get(widget.logKey);
    if (updatedData != null) {
      setState(() {
        _currentLog = WorkoutLog.fromMap(updatedData as Map);
      });
    }
  }

  void _showOptionsDrawer(BuildContext context) {
    AppActionsSheet.show(
      context: context,
      title: 'Workout Options ⚙️',
      subtitle: _currentLog.routineTitle,
      actions: [
        SheetActionItem(
          icon: Icons.edit_outlined,
          label: 'Edit Workout Log',
          onPressed: () async {
            final bool? wasEdited = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (context) => WorkoutFormPage(
                  workoutLog: _currentLog,
                  logKey: widget.logKey,
                ),
              ),
            );

            if (wasEdited == true) {
              _refreshLogData();
            }
          },
        ),
        SheetActionItem(
          icon: Icons.delete_outline,
          label: 'Delete Workout',
          color: Colors.redAccent,
          onPressed: () {
            _deleteWorkout(context);
          },
        ),
      ],
    );
  }

  Future<void> _deleteWorkout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Workout? 🗑️'),
        content: const Text(
            'Are you sure you want to permanently delete this workout session from your history? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await logsBox.delete(widget.logKey);
      if (!context.mounted) return;

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Workout deleted successfully.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate = formatDateNative(_currentLog.startTime);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout Summary'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, size: 26),
            tooltip: 'Workout Options',
            onPressed: () => _showOptionsDrawer(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- HEADER: Titlu Rutină și Dată ---
            Text(
              _currentLog.routineTitle,
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.calendar_today,
                    size: 14, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(
                  formattedDate,
                  style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // --- PANOU STATISTICI RAPIDE ---
            Card(
              elevation: 0,
              color: theme.cardColor.withOpacity(0.6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                    color: theme.colorScheme.primary.withOpacity(0.2)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(
                        Icons.timer, _currentLog.formattedDuration, 'Duration'),
                    _buildStatItem(
                        Icons.fitness_center,
                        '${_currentLog.totalVolume.toStringAsFixed(0)} kg',
                        'Volume'),
                    _buildStatItem(Icons.format_list_numbered,
                        '${_currentLog.totalSetsCount}', 'Total Sets'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // --- LISTA DE EXERCIȚII EFECTUATE ---
            Text(
              'Exercises & Sets',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),

            if (_currentLog.exercises.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20.0),
                  child: Text('No exercises recorded in this session.',
                      style: TextStyle(color: Colors.grey)),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _currentLog.exercises.length,
                itemBuilder: (context, exIndex) {
                  final loggedExercise = _currentLog.exercises[exIndex];
                  final rawExerciseData =
                      exercisesBox.get(loggedExercise.exerciseId);

                  Exercise? fullExercise;
                  String exerciseName = 'Unknown Exercise';
                  String? coverImage;

                  if (rawExerciseData != null) {
                    if (rawExerciseData is Map) {
                      fullExercise = Exercise.fromMap(rawExerciseData);
                    } else {
                      fullExercise = rawExerciseData as Exercise;
                    }
                    exerciseName = fullExercise.name;
                    coverImage = fullExercise.coverImage;
                  }

                  final isImageEmpty =
                      coverImage == null || coverImage.trim().isEmpty;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 14),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 💡 ZONĂ INKWELL PENTRU DETALII EXERCIȚIU
                          InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () {
                              if (fullExercise != null) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ExerciseDetailPage(
                                        exercise: fullExercise!),
                                  ),
                                );
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 4.0, horizontal: 2.0),
                              child: Row(
                                children: [
                                  // Avatarul circular cu poza exercițiului
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: theme
                                        .colorScheme.surfaceContainerHighest,
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
                                  const SizedBox(width: 12),

                                  // Numele exercițiului
                                  Expanded(
                                    child: Text(
                                      exerciseName,
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.onSurface),
                                    ),
                                  ),

                                  // Mic indicator să sugereze click-ul (chevron discret)
                                  Icon(
                                    Icons.chevron_right,
                                    color: theme.colorScheme.onSurfaceVariant
                                        .withOpacity(0.5),
                                    size: 18,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Divider(
                            height: 16,
                            color: theme.colorScheme.primary.withOpacity(0.2),
                          ),

                          // Rândurile cu seturi
                          ...loggedExercise.sets.asMap().entries.map((entry) {
                            int setIdx = entry.key;
                            final set = entry.value;

                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 4.0),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 10,
                                    backgroundColor: theme.colorScheme.primary
                                        .withOpacity(0.2),
                                    child: Text(
                                      '${setIdx + 1}',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: theme.hintColor,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Text('${set.weight} kg',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w500)),
                                  const Text('  ×  ',
                                      style: TextStyle(color: Colors.grey)),
                                  Text('${set.reps} reps',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w500)),
                                  const Spacer(),
                                  Text(
                                    '${(set.weight * set.reps).toStringAsFixed(0)} kg',
                                    style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 13),
                                  )
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary, size: 24),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
