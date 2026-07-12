import 'package:flutter/material.dart';
import 'package:gym_tracker/utils/date_utils.dart';
import '../../main.dart';
import '../../models/models.dart';
import '../../widgets/app_actions_sheet.dart';
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
  // Păstrăm o referință locală modificabilă pentru log-ul curent
  late WorkoutLog _currentLog;

  @override
  void initState() {
    super.initState();
    _currentLog = widget.log;
  }

  // --- REÎNCĂRCARE DATE DUPĂ EDITARE ---
  void _refreshLogData() {
    final updatedData = logsBox.get(widget.logKey);
    if (updatedData != null) {
      setState(() {
        _currentLog = WorkoutLog.fromMap(updatedData as Map);
      });
    }
  }

  // --- DRAWER CU OPȚIUNI (MODAL BOTTOM SHEET) ---
  void _showOptionsDrawer(BuildContext context) {
    final theme = Theme.of(context);

    AppActionsSheet.show(
      context: context,
      title: 'Workout Options ⚙️',
      subtitle:
          _currentLog.routineTitle, // Pasăm numele antrenamentului ca subtitlu
      actions: [
        // Acțiunea 1: EDITARE
        SheetActionItem(
          icon: Icons.edit_outlined,
          label: 'Edit Workout Log',
          onPressed: () async {
            // Navigăm către pagina de editare
            final bool? wasEdited = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (context) => WorkoutFormPage(
                  workoutLog: _currentLog,
                  logKey: widget.logKey,
                ),
              ),
            );

            // Dacă s-a salvat cu succes, împrospătăm datele pe ecran
            if (wasEdited == true) {
              _refreshLogData();
            }
          },
        ),

        // Acțiunea 2: ȘTERGERE
        SheetActionItem(
          icon: Icons.delete_outline,
          label: 'Delete Workout',
          color: Colors.redAccent,
          onPressed: () {
            _deleteWorkout(context); // Declanșăm dialogul securizat de ștergere
          },
        ),
      ],
    );
  }

  // --- DIALOG CONFIRMARE ȘTERGERE (MODALĂ SECURIZATĂ) ---
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

      Navigator.pop(context); // Închide pagina de detalii definitiv
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Workout deleted successfully.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate = formatDateNative(_currentLog.startTime);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout Summary'),
        centerTitle:
            false, // Titlu aliniat la stânga pentru consistență premium
        actions: [
          // Butonul cu 3 puncte verticale solicitat
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
                  color: Theme.of(context).colorScheme.onSurface),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.calendar_today,
                    size: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(
                  formattedDate,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // --- PANOU STATISTICI RAPIDE ---
            Card(
              elevation: 0,
              color: Theme.of(context).cardColor.withOpacity(0.6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                    color:
                        Theme.of(context).colorScheme.primary.withOpacity(0.2)),
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
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
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
                  final exercise = _currentLog.exercises[exIndex];
                  final rawExerciseData = exercisesBox.get(exercise.exerciseId);

                  String exerciseName = 'Unknown Exercise';
                  if (rawExerciseData != null) {
                    exerciseName = rawExerciseData is Map
                        ? (rawExerciseData['name'] ?? 'Unknown Exercise')
                        : (rawExerciseData.name ?? 'Unknown Exercise');
                  }

                  return Card(
                    margin: const EdgeInsets.only(bottom: 14),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            exerciseName,
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface),
                          ),
                          Divider(
                            height: 16,
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.2),
                          ),
                          ...exercise.sets.asMap().entries.map((entry) {
                            int setIdx = entry.key;
                            final set = entry.value;

                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 4.0),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 10,
                                    backgroundColor: Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withOpacity(0.2),
                                    child: Text(
                                      '${setIdx + 1}',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Theme.of(context).hintColor,
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
