import 'package:flutter/material.dart';
import 'package:gym_tracker/utils/date_utils.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';
import '../../widgets/app_actions_sheet.dart';
import '../exercises/exercise_detail_page.dart';
import 'workout_form_page.dart';

class WorkoutDetailPage extends StatefulWidget {
  final dynamic logKey;
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
    final updatedData = DatabaseService.logsBox.get(widget.logKey);
    if (updatedData != null) {
      setState(() {
        _currentLog = WorkoutLog.fromMap(updatedData as Map);
      });
    }
  }

// --- 💡 LOGICA DE CALCUL OPTIMIZATĂ PENTRU STRUCTURA MODELULUI TĂU ---
  Map<String, double> _calculateMuscleDistribution() {
    final Map<String, double> muscleScores = {};
    double totalScore = 0.0;

    for (var loggedExercise in _currentLog.exercises) {
      final rawExerciseData =
          DatabaseService.exercisesBox.get(loggedExercise.exerciseId);
      if (rawExerciseData == null) continue;

      Exercise? exercise;
      if (rawExerciseData is Map) {
        exercise = Exercise.fromMap(rawExerciseData);
      } else if (rawExerciseData is Exercise) {
        exercise = rawExerciseData;
      }

      if (exercise == null) continue;

      final int setsCount = loggedExercise.sets.length;
      if (setsCount == 0) continue;

      // 1. Procesăm mușchii primari (Pondere 100%)
      for (var target in exercise.primaryMuscles) {
        final String name = target.group.name
            .toUpperCase(); // Poți folosi și target.label dacă vrei detalii
        final double score = setsCount * 1.0;
        muscleScores[name] = (muscleScores[name] ?? 0.0) + score;
        totalScore += score;
      }

      // 2. Procesăm mușchii secundari (Pondere 50%)
      for (var target in exercise.secondaryMuscles) {
        final String name = target.group.name.toUpperCase();
        final double score = setsCount * 0.5;
        muscleScores[name] = (muscleScores[name] ?? 0.0) + score;
        totalScore += score;
      }

      // 3. Procesăm mușchii terțiari (Pondere 25%)
      for (var target in exercise.tertiaryMuscles) {
        final String name = target.group.name.toUpperCase();
        final double score = setsCount * 0.25;
        muscleScores[name] = (muscleScores[name] ?? 0.0) + score;
        totalScore += score;
      }
    }

    if (totalScore == 0.0) return {};

    // Transformăm scorurile brute în procente (0.0 - 1.0) pentru UI
    return muscleScores
        .map((muscle, score) => MapEntry(muscle, score / totalScore));
  }

  // --- WIDGET FINISAT PENTRU RELEASING REPEDE (ALINIAT ȘI CURAT) ---
  Widget _buildMuscleDistributionSection(ThemeData theme) {
    final distribution = _calculateMuscleDistribution();

    if (distribution.isEmpty) return const SizedBox.shrink();

    // Sortăm descrescător după importanță
    final sortedEntries = distribution.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Muscle Group Split',
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          color: theme.cardColor.withOpacity(0.4),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: sortedEntries.length,
              itemBuilder: (context, index) {
                final entry = sortedEntries[index];
                final percentage = entry.value;
                final percentageString =
                    '${(percentage * 100).toStringAsFixed(0)}%';

                // Înfrumusețăm textul din Enum (ex: "CHEST", "BICEPS", "LOWER_BACK")
                final displayMuscleName = entry.key.replaceAll('_', ' ');

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: Row(
                    children: [
                      // Numele grupei musculare cu lungime fixă
                      SizedBox(
                        width: 100,
                        child: Text(
                          displayMuscleName,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Bara nativă cu LinearProgressIndicator
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: percentage,
                            minHeight: 10,
                            backgroundColor:
                                theme.colorScheme.surfaceContainerHighest,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              theme.colorScheme.primary.withOpacity(0.85),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Procentul afișat în dreapta
                      SizedBox(
                        width: 35,
                        child: Text(
                          percentageString,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
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
      await DatabaseService.logsBox.delete(widget.logKey);
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
            // --- HEADER ---
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

            // --- PANOU STATISTICI ---
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

            // 💡 ACUM SE RANDAZĂ MINI-GRAFICUL DE DISTRIBUȚIE MUSCULARĂ
            _buildMuscleDistributionSection(theme),

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
                  final rawExerciseData = DatabaseService.exercisesBox
                      .get(loggedExercise.exerciseId);

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
                                  Expanded(
                                    child: Text(
                                      exerciseName,
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.onSurface),
                                    ),
                                  ),
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
