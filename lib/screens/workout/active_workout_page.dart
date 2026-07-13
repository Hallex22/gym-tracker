import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gym_tracker/enums/workout_status.dart';
import 'package:gym_tracker/screens/exercises/exercise_detail_page.dart';
import 'package:gym_tracker/screens/exercises/exercise_selection_page.dart';
import 'package:gym_tracker/widgets/app_buttons.dart';
import '../../../main.dart';
import '../../../models/models.dart';
import '../../enums/enums.dart';
import '../../widgets/app_actions_sheet.dart';

class ActiveWorkoutPage extends StatefulWidget {
  final Routine routine;
  const ActiveWorkoutPage({super.key, required this.routine});

  @override
  State<ActiveWorkoutPage> createState() => _ActiveWorkoutPageState();
}

class _ActiveWorkoutPageState extends State<ActiveWorkoutPage> {
  final List<LoggedExercise> _activeExercises = [];
  dynamic _currentLogKey;
  late DateTime _sessionStart;
  Timer? _liveTimer;

  late TextEditingController _titleController;

  // 🔧 Cache exercitiu-complet indexat dupa id (Exercise.id -> Exercise).
  // Construit o singura data, nu mai depinde de schema de chei din Hive
  late Map<int, Exercise> _exerciseCache;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.routine.title);
    _buildExerciseCache();
    _loadOrInitializeWorkout();
    _startLiveTimer();
  }

  @override
  void dispose() {
    _liveTimer?.cancel();
    _titleController.dispose();
    super.dispose();
  }

  void _buildExerciseCache() {
    _exerciseCache = {};
    for (var raw in exercisesBox.values) {
      final ex = Exercise.fromMap(raw as Map);
      _exerciseCache[ex.id] = ex;
    }
  }

  // Helper unic de lookup - foloseste-l peste tot in loc de exercisesBox.get(...)
  Exercise? _resolveExercise(int exerciseId) => _exerciseCache[exerciseId];

  void _startLiveTimer() {
    _liveTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  void _loadOrInitializeWorkout() {
    MapEntry<dynamic, dynamic>? existingActiveEntry;

    for (var entry in logsBox.toMap().entries) {
      final log = WorkoutLog.fromMap(entry.value as Map);
      if (log.status == WorkoutStatus.started) {
        existingActiveEntry = entry;
        break;
      }
    }

    if (existingActiveEntry != null) {
      final activeLog = WorkoutLog.fromMap(existingActiveEntry.value as Map);
      _currentLogKey = existingActiveEntry.key;
      _sessionStart = activeLog.startTime;
      _titleController.text = activeLog.routineTitle;

      setState(() {
        _activeExercises.addAll(activeLog.exercises);
      });
    } else {
      _sessionStart = DateTime.now();
      for (var routineExercise in widget.routine.exercises) {
        final exerciseId = routineExercise.exerciseId;
        final prevLog = _getPreviousLogForExercise(exerciseId);
        final targetSets = routineExercise.targetSetsCount > 0
            ? routineExercise.targetSetsCount
            : 1;

        final initialSets = List<LoggedSet>.generate(targetSets, (index) {
          if (prevLog != null && prevLog.sets.isNotEmpty) {
            if (index < prevLog.sets.length) {
              final prevSet = prevLog.sets[index];
              return LoggedSet(weight: prevSet.weight, reps: prevSet.reps);
            } else {
              final lastSetFromPast = prevLog.sets.last;
              return LoggedSet(
                  weight: lastSetFromPast.weight, reps: lastSetFromPast.reps);
            }
          }
          return const LoggedSet(weight: 0.0, reps: 0);
        });

        _activeExercises.add(
          LoggedExercise(
            exerciseId: exerciseId,
            sets: initialSets,
          ),
        );
      }
      _createActiveWorkoutLog();
    }
  }

  Future<void> _createActiveWorkoutLog() async {
    final initialLog = WorkoutLog(
      startTime: _sessionStart,
      routineTitle: _titleController.text.trim(),
      exercises: List.from(_activeExercises),
      status: WorkoutStatus.started,
    );
    _currentLogKey = await logsBox.add(initialLog.toMap());
  }

  Future<void> _updateLiveProgress() async {
    if (_currentLogKey == null) return;
    final currentLog = WorkoutLog(
      startTime: _sessionStart,
      routineTitle: _titleController.text.trim(),
      exercises: List.from(_activeExercises),
      status: WorkoutStatus.started,
    );
    await logsBox.put(_currentLogKey, currentLog.toMap());
  }

  void _adjustLiveWorkoutDuration(int targetMinutes) {
    setState(() {
      _sessionStart = DateTime.now().subtract(Duration(minutes: targetMinutes));
    });

    _updateLiveProgress();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Duration updated to $targetMinutes min! ⏱️'),
      ),
    );
  }

  Future<void> _showEditWorkoutDurationDialog() async {
    final currentMinutes = DateTime.now().difference(_sessionStart).inMinutes;
    final controller = TextEditingController(text: currentMinutes.toString());
    final theme = Theme.of(context);

    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Edit workout duration',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Use this if you forgot to hit Start on time. The session's start time will be recalculated automatically.",
              style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Duration (minutes)',
                border: OutlineInputBorder(),
                suffixText: 'min',
              ),
            ),
          ],
        ),
        actions: [
          Row(
            children: [
              TextButton(
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppFilledButton(
                  label: 'Save',
                  onPressed: () {
                    final parsedMinutes = int.tryParse(controller.text.trim());
                    Navigator.pop(context, parsedMinutes);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (result != null && result >= 0) {
      _adjustLiveWorkoutDuration(result);
    }
  }

  Map<String, dynamic> _calculateCurrentStats() {
    final currentSnapshotLog = WorkoutLog(
      startTime: _sessionStart,
      endTime: DateTime
          .now(), // setăm temporar acum ca să funcționeze gettere-le duratei
      routineTitle: _titleController.text.trim(),
      exercises: List.from(_activeExercises),
      status: WorkoutStatus.started,
    );

    final difference = DateTime.now().difference(_sessionStart);
    final hours = difference.inHours;
    final minutes =
        difference.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds =
        difference.inSeconds.remainder(60).toString().padLeft(2, '0');

    String durationString = hours > 0
        ? '${hours.toString().padLeft(2, '0')}:$minutes:$seconds'
        : '$minutes:$seconds';

    return {
      'durationStr': durationString,
      'durationMin': difference.inMinutes,
      'exercisesCount': _activeExercises.length,
      'volume': currentSnapshotLog.totalVolume,
      'setsCount': currentSnapshotLog.completedSetsCount
    };
  }

  LoggedExercise? _getPreviousLogForExercise(int exerciseId) {
    final allLogs = logsBox.values
        .map((e) => WorkoutLog.fromMap(e as Map))
        .toList()
        .reversed;

    for (var log in allLogs) {
      if (log.status == WorkoutStatus.finished) {
        for (var ex in log.exercises) {
          if (ex.exerciseId == exerciseId) {
            return ex;
          }
        }
      }
    }
    return null;
  }

  Future<void> _showFinishConfirmationDialog() async {
    final stats = _calculateCurrentStats();
    final theme = Theme.of(context);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Finish Workout? 🏆',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to complete this workout session? Here is your summary:',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            Card(
              color: theme.colorScheme.primary.withOpacity(0.05),
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  children: [
                    _buildStatRow(Icons.timer, 'Duration:',
                        '${stats['durationMin']} min'),
                    Divider(color: theme.colorScheme.primary.withOpacity(0.2)),
                    _buildStatRow(Icons.fitness_center, 'Total Volume:',
                        '${stats['volume']} kg'),
                    Divider(color: theme.colorScheme.primary.withOpacity(0.2)),
                    _buildStatRow(Icons.format_list_numbered, 'Completed Sets:',
                        '${stats['setsCount']}'),
                    Divider(color: theme.colorScheme.primary.withOpacity(0.2)),
                    _buildStatRow(Icons.format_list_bulleted, 'Exercises:',
                        '${stats['exercisesCount']}'),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          Row(
            children: [
              TextButton(
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'Resume',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppFilledButton(
                  label: 'Save Workout',
                  onPressed: () => Navigator.pop(context, true),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (confirm == true) {
      _executeFinish();
    }
  }

  Widget _buildStatRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon,
              size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          const Spacer(),
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary)),
        ],
      ),
    );
  }

  Future<void> _executeFinish() async {
    if (_currentLogKey == null) return;

    final endTime = DateTime.now();
    String finalTitle = _titleController.text.trim();
    if (finalTitle.isEmpty) {
      finalTitle = _activeExercises.isNotEmpty
          ? 'Custom Workout (${_activeExercises.length} ex)'
          : 'Empty Workout';
    }

    final finalLog = WorkoutLog(
      startTime: _sessionStart,
      endTime: endTime,
      routineTitle: finalTitle,
      exercises: List.from(_activeExercises),
      status: WorkoutStatus.finished,
    );

    await logsBox.put(_currentLogKey, finalLog.toMap());
    final duration = endTime.difference(_sessionStart).inMinutes;

    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Workout saved! ⏱️ Duration: $duration min. 💪')),
    );
  }

  Future<void> _cancelWorkout() async {
    if (_currentLogKey != null) {
      await logsBox.delete(_currentLogKey);
    }
    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _navigateToSelectExercise() async {
    // Colectăm ID-urile lightweight de la exercițiile deja active
    final List<int> existingIds =
        _activeExercises.map((e) => e.exerciseId).toList();

    // 💡 SCHIMBARE: Schimbăm tipul generic din <Exercise> în <List<Exercise>>
    final List<Exercise>? selectedExercises =
        await Navigator.push<List<Exercise>>(
      context,
      MaterialPageRoute(
        builder: (context) => ExerciseSelectionPage(
          existingExercisesIds: existingIds,
        ),
      ),
    );

    // 💡 SCHIMBARE: Dacă utilizatorul a selectat unul sau mai multe exerciții, le adăugăm pe toate
    if (selectedExercises != null && selectedExercises.isNotEmpty && mounted) {
      setState(() {
        for (final ex in selectedExercises) {
          _activeExercises.add(
            LoggedExercise(
              exerciseId: ex.id,
              // Fiecare exercițiu nou pleacă cu un set gol implicit
              sets: [const LoggedSet(weight: 0.0, reps: 0)],
            ),
          );
        }
      });
      _updateLiveProgress();
    }
  }

  Widget _buildLiveStatColumn(String label, String value, ThemeData theme,
      {VoidCallback? onTap}) {
    final content = Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
      ],
    );

    // 🔧 Expanded trebuie sa ramana copil direct al Row-ului parinte.
    // GestureDetector-ul (daca exista) merge INAUNTRU lui Expanded, nu in jurul lui,
    // altfel apare "Incorrect use of ParentDataWidget" la fiecare rebuild.
    return Expanded(
      child: onTap != null
          ? GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: content,
            )
          : content,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stats = _calculateCurrentStats();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final action = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Leave Workout Session?'),
            content: const Text(
                'You can keep this workout running in the background, or cancel it entirely.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, 'keep'),
                  child: const Text('Keep in Background')),
              TextButton(
                  onPressed: () => Navigator.pop(context, 'cancel'),
                  child: const Text('Cancel Workout',
                      style: TextStyle(color: Colors.redAccent))),
              TextButton(
                  onPressed: () => Navigator.pop(context, 'stay'),
                  child: const Text('Stay Here',
                      style: TextStyle(color: Colors.grey))),
            ],
          ),
        );

        if (action == 'keep' && context.mounted) {
          Navigator.pop(context);
        } else if (action == 'cancel' && context.mounted) {
          _cancelWorkout();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'You`re Goated',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          leadingWidth: 80,
          leading: TextButton(
            onPressed: () => Navigator.maybePop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(
                  color: Colors.redAccent, fontWeight: FontWeight.w600),
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: SizedBox(
                width: 100,
                height: 50,
                child: AppFilledButton(
                  label: 'Save',
                  onPressed: _showFinishConfirmationDialog,
                ),
              ),
            ),
          ],
        ),
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => FocusScope.of(context).unfocus(),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextField(
                    controller: _titleController,
                    textAlign: TextAlign.left,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      hintText: 'Titlu antrenament...',
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      suffixIcon: Icon(Icons.edit,
                          size: 16,
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                    onChanged: (value) => _updateLiveProgress(),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    vertical: 12.0, horizontal: 16.0),
                decoration: BoxDecoration(
                  color: theme.cardColor.withOpacity(0.4),
                  border: Border(
                      bottom: BorderSide(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.2))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    // 🆕 Tap pe "Duration" deschide modala de editare a duratei/start time-ului.
                    _buildLiveStatColumn(
                        'Duration', stats['durationStr'], theme,
                        onTap: _showEditWorkoutDurationDialog),
                    _buildLiveStatColumn('Volume',
                        '${stats['volume'].toStringAsFixed(0)} kg', theme),
                    _buildLiveStatColumn(
                        'Sets', '${stats['setsCount']}', theme),
                  ],
                ),
              ),
              Expanded(
                child: _activeExercises.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '🏋️',
                                style: const TextStyle(fontSize: 48),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No exercises yet',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Tap "Add Alternative Exercise" below to get started.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ReorderableListView.builder(
                        itemCount: _activeExercises.length,
                        // 🔧 FIX: parametrul corect este `onReorder`, nu `onReorderItem`,
                        // si trebuie ajustat newIndex cand se muta in jos in lista.
                        onReorder: (oldIndex, newIndex) {
                          setState(() {
                            if (newIndex > oldIndex) newIndex -= 1;
                            final item = _activeExercises.removeAt(oldIndex);
                            _activeExercises.insert(newIndex, item);
                          });
                          _updateLiveProgress();
                        },
                        itemBuilder: (context, exIndex) {
                          final exercise = _activeExercises[exIndex];
                          final sets = exercise.sets;

                          // 🔧 Reconstruim exercitiul original din cache, dupa id.
                          final fullExercise =
                              _resolveExercise(exercise.exerciseId);
                          final coverImage = fullExercise?.coverImage;

                          final isMissingData = fullExercise == null;
                          final isImageEmpty =
                              coverImage == null || coverImage.isEmpty;

                          // 🔧 Nume afisat: fallback clar daca exercitiul nu mai exista
                          // in exercisesBox (a fost sters/redenumit intre timp).
                          final displayName = fullExercise?.name ??
                              'Exercițiu necunoscut (ID: ${exercise.exerciseId})';

                          final isBodyWeight =
                              fullExercise?.equipment == Equipment.bodyweight;

                          return Card(
                            key: ValueKey(
                                'active_ex_${exercise.exerciseId}_$exIndex'),
                            margin: const EdgeInsets.all(12),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Icon(Icons.drag_handle,
                                          color: theme
                                              .colorScheme.onSurfaceVariant),
                                      const SizedBox(width: 8),
                                      if (!isMissingData && !isImageEmpty) ...[
                                        CircleAvatar(
                                          radius: 20,
                                          backgroundColor: theme.colorScheme
                                              .surfaceContainerHighest,
                                          backgroundImage:
                                              AssetImage('assets/$coverImage'),
                                        ),
                                        const SizedBox(width: 12),
                                      ],
                                      // Titlul înfășurat în InkWell pentru detalii
                                      Expanded(
                                        child: InkWell(
                                          onTap: () {
                                            if (fullExercise != null) {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) =>
                                                      ExerciseDetailPage(
                                                          exercise:
                                                              fullExercise),
                                                ),
                                              );
                                            } else {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                      'Eroare: Lipsesc detaliile pentru ID "${exercise.exerciseId}"! ⚠️'),
                                                  backgroundColor:
                                                      Colors.redAccent,
                                                ),
                                              );
                                            }
                                          },
                                          borderRadius:
                                              BorderRadius.circular(4),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 4.0),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  displayName,
                                                  style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: theme.colorScheme
                                                          .onSurface),
                                                ),
                                                if (isMissingData ||
                                                    isImageEmpty)
                                                  Text(
                                                    isMissingData
                                                        ? '[⚠️ Nu există în exercisesBox]'
                                                        : '[⚠️ Imaginea este goală în DB]',
                                                    style: const TextStyle(
                                                        fontSize: 11,
                                                        color: Colors.redAccent,
                                                        fontWeight:
                                                            FontWeight.bold),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      // Meniul de opțiuni rapid (AppActionsSheet)
                                      IconButton(
                                        icon: Icon(Icons.more_vert,
                                            color: theme
                                                .colorScheme.onSurfaceVariant),
                                        onPressed: () {
                                          AppActionsSheet.show(
                                            context: context,
                                            title: displayName,
                                            subtitle:
                                                'Manage active exercise session',
                                            actions: [
                                              SheetActionItem(
                                                icon: Icons.info_outline,
                                                label: 'View Exercise Details',
                                                onPressed: () {
                                                  if (fullExercise != null) {
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (context) =>
                                                            ExerciseDetailPage(
                                                                exercise:
                                                                    fullExercise),
                                                      ),
                                                    );
                                                  }
                                                },
                                              ),
                                              SheetActionItem(
                                                icon: Icons.delete_outline,
                                                label: 'Remove Exercise',
                                                color: Colors.redAccent,
                                                onPressed: () async {
                                                  final bool? confirmDelete =
                                                      await showDialog<bool>(
                                                    context: context,
                                                    builder: (BuildContext
                                                            context) =>
                                                        AlertDialog(
                                                      title: const Text(
                                                          'Remove Exercise? ⚠️'),
                                                      content: Text(
                                                          'Are you sure you want to remove "$displayName" and all its completed sets from this workout?'),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () =>
                                                              Navigator.pop(
                                                                  context,
                                                                  false),
                                                          child: const Text(
                                                              'Cancel',
                                                              style: TextStyle(
                                                                  color: Colors
                                                                      .grey)),
                                                        ),
                                                        ElevatedButton(
                                                          style: ElevatedButton
                                                              .styleFrom(
                                                                  backgroundColor:
                                                                      Colors
                                                                          .redAccent),
                                                          onPressed: () =>
                                                              Navigator.pop(
                                                                  context,
                                                                  true),
                                                          child: const Text(
                                                              'Remove',
                                                              style: TextStyle(
                                                                  color: Colors
                                                                      .white)),
                                                        ),
                                                      ],
                                                    ),
                                                  );

                                                  if (confirmDelete == true) {
                                                    setState(() {
                                                      _activeExercises
                                                          .removeAt(exIndex);
                                                    });
                                                    _updateLiveProgress();
                                                  }
                                                },
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                  Divider(
                                      color: theme.colorScheme.primary
                                          .withOpacity(0.2)),

                                  // --- HEADER COLOANE ---
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 4.0),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                            width: 50,
                                            child: Text('Set',
                                                style: TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    color: theme.colorScheme
                                                        .onSurfaceVariant))),
                                        Expanded(
                                            child: Text(
                                                isBodyWeight
                                                    ? 'Weight'
                                                    : 'Weight (kg)',
                                                style: TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    color: theme.colorScheme
                                                        .onSurfaceVariant),
                                                textAlign: TextAlign.center)),
                                        Expanded(
                                            child: Text('Reps',
                                                style: TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    color: theme.colorScheme
                                                        .onSurfaceVariant),
                                                textAlign: TextAlign.center)),
                                      ],
                                    ),
                                  ),

                                  // --- RÂNDURILE CU INPUTURILE DE SETURI ---
                                  ...sets.asMap().entries.map((entry) {
                                    int setIndex = entry.key;
                                    final set = entry.value;

                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 4.0),
                                      child: Row(
                                        children: [
                                          SizedBox(
                                              width: 50,
                                              child: Text('${setIndex + 1}',
                                                  style: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.bold))),
                                          Expanded(
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8.0),
                                              child: isBodyWeight
                                                  ? Container(
                                                      alignment:
                                                          Alignment.center,
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          vertical: 10),
                                                      decoration: BoxDecoration(
                                                        color: theme.colorScheme
                                                            .surfaceContainerHighest
                                                            .withOpacity(0.5),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(4),
                                                        border: Border.all(
                                                            color: theme
                                                                .colorScheme
                                                                .outlineVariant),
                                                      ),
                                                      child: Text(
                                                        'BW 🧍',
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: theme
                                                              .colorScheme
                                                              .onSurfaceVariant,
                                                          fontSize: 14,
                                                        ),
                                                      ),
                                                    )
                                                  : TextFormField(
                                                      initialValue:
                                                          set.weight == 0.0
                                                              ? ''
                                                              : set.weight
                                                                  .toString(),
                                                      keyboardType:
                                                          const TextInputType
                                                              .numberWithOptions(
                                                              decimal: true),
                                                      decoration: const InputDecoration(
                                                          border:
                                                              OutlineInputBorder(),
                                                          contentPadding:
                                                              EdgeInsets
                                                                  .symmetric(
                                                                      horizontal:
                                                                          8,
                                                                      vertical:
                                                                          4),
                                                          hintText: '0'),
                                                      onChanged: (value) {
                                                        final newWeight =
                                                            double.tryParse(
                                                                    value) ??
                                                                0.0;
                                                        exercise.sets[
                                                                setIndex] =
                                                            LoggedSet(
                                                                weight:
                                                                    newWeight,
                                                                reps: set.reps);
                                                        _updateLiveProgress();
                                                      },
                                                    ),
                                            ),
                                          ),
                                          Expanded(
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8.0),
                                              child: TextFormField(
                                                initialValue: set.reps == 0
                                                    ? ''
                                                    : set.reps.toString(),
                                                keyboardType:
                                                    TextInputType.number,
                                                decoration:
                                                    const InputDecoration(
                                                        border:
                                                            OutlineInputBorder(),
                                                        contentPadding:
                                                            EdgeInsets
                                                                .symmetric(
                                                                    horizontal:
                                                                        8,
                                                                    vertical:
                                                                        4),
                                                        hintText: '0'),
                                                onChanged: (value) {
                                                  final newReps =
                                                      int.tryParse(value) ?? 0;
                                                  exercise.sets[setIndex] =
                                                      LoggedSet(
                                                          weight: set.weight,
                                                          reps: newReps);
                                                  _updateLiveProgress();
                                                },
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                  const SizedBox(height: 10),

                                  // --- ACȚIUNI SET (ADD/REMOVE) ---
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: AppGhostButton(
                                          label: 'Add Set',
                                          icon: Icons.add,
                                          onPressed: () {
                                            setState(() {
                                              double lastWeight =
                                                  sets.isNotEmpty
                                                      ? sets.last.weight
                                                      : 0.0;
                                              int lastReps = sets.isNotEmpty
                                                  ? sets.last.reps
                                                  : 0;
                                              sets.add(LoggedSet(
                                                  weight: lastWeight,
                                                  reps: lastReps));
                                            });
                                            _updateLiveProgress();
                                          },
                                        ),
                                      ),
                                      if (sets.length > 1)
                                        TextButton(
                                          onPressed: () {
                                            setState(() {
                                              sets.removeLast();
                                            });
                                            _updateLiveProgress();
                                          },
                                          child: const Text('Remove Last Set',
                                              style: TextStyle(
                                                  color: Colors.redAccent)),
                                        )
                                    ],
                                  )
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: AppOutlinedButton(
              label: "Add Alternative Exercise",
              onPressed: _navigateToSelectExercise,
              icon: Icons.fitness_center,
            ),
          ),
        ),
      ),
    );
  }
}
