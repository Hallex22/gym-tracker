import 'package:flutter/material.dart';
import 'package:gym_tracker/enums/workout_status.dart';
import 'package:gym_tracker/screens/exercises/exercise_detail_page.dart';
import 'package:gym_tracker/screens/exercises/exercise_selection_page.dart';
import 'package:gym_tracker/widgets/app_buttons.dart';
import 'package:gym_tracker/widgets/top_toast.dart';
import '../../models/models.dart';
import '../../enums/enums.dart';
import '../../services/database_service.dart';
import '../../widgets/app_actions_sheet.dart';

/// Pagina de editare pentru un antrenament DEJA FINALIZAT (status = finished).
/// Permite corectarea titlului, orei de start/final (deci a duratei), a
/// exercițiilor efectuate și a seturilor (weight/reps) - pentru cazul in care
/// utilizatorul a introdus date greșite sau a uitat să apese Finish la timp.
class WorkoutFormPage extends StatefulWidget {
  final dynamic logKey; // cheia din logsBox (Hive) pentru acest log
  final WorkoutLog workoutLog;

  const WorkoutFormPage({
    super.key,
    required this.logKey,
    required this.workoutLog,
  });

  @override
  State<WorkoutFormPage> createState() => _WorkoutFormPageState();
}

class _WorkoutFormPageState extends State<WorkoutFormPage> {
  late TextEditingController _titleController;
  late DateTime _startTime;
  late DateTime _endTime;
  late List<LoggedExercise> _exercises;

  bool _isDirty = false;

  // Cache exercitiu-complet indexat dupa id, la fel ca in ActiveWorkoutPage,
  // ca sa afisam numele/imaginea corecte pentru fiecare exercitiu logat.
  late Map<int, Exercise> _exerciseCache;

  @override
  void initState() {
    super.initState();
    _titleController =
        TextEditingController(text: widget.workoutLog.routineTitle);
    _startTime = widget.workoutLog.startTime;
    _endTime = widget.workoutLog.endTime ?? widget.workoutLog.startTime;

    // Copie mutabila (nu editam direct obiectul original, cat timp userul
    // nu apasa Save - daca da Cancel, nimic nu se salveaza).
    _exercises = widget.workoutLog.exercises
        .map((e) => LoggedExercise(
              exerciseId: e.exerciseId,
              sets: List<LoggedSet>.from(e.sets),
            ))
        .toList();

    _buildExerciseCache();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _buildExerciseCache() {
    _exerciseCache = {};
    for (var raw in DatabaseService.exercisesBox.values) {
      final ex = Exercise.fromMap(raw as Map);
      _exerciseCache[ex.id] = ex;
    }
  }

  Exercise? _resolveExercise(int exerciseId) => _exerciseCache[exerciseId];

  void _markDirty() {
    if (!_isDirty) setState(() => _isDirty = true);
  }

  String _formatDateTime(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year.toString();
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$d/$m/$y • $h:$min';
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final initial = isStart ? _startTime : _endTime;

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (pickedTime == null || !mounted) return;

    final merged = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    setState(() {
      if (isStart) {
        _startTime = merged;
      } else {
        _endTime = merged;
      }
    });
    _markDirty();
  }

  Map<String, dynamic> _computeStats() {
    double volume = 0;
    int setsCount = 0;

    for (var ex in _exercises) {
      for (var set in ex.sets) {
        if (set.reps > 0) {
          volume += set.weight * set.reps;
          setsCount++;
        }
      }
    }

    final rawMinutes = _endTime.difference(_startTime).inMinutes;

    return {
      'durationMin': rawMinutes < 0 ? 0 : rawMinutes,
      'volume': volume,
      'setsCount': setsCount,
      'exercisesCount': _exercises.length,
    };
  }

  Future<bool> _confirmDiscardIfNeeded() async {
    if (!_isDirty) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text(
            'You have unsaved changes. Are you sure you want to leave without saving?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  Future<void> _handleSave() async {
    if (_endTime.isBefore(_startTime)) {
      TopToast.show(context, 'End time must be after start time.',
          type: ToastType.error);
      return;
    }

    final title = _titleController.text.trim();

    final updatedLog = WorkoutLog(
      startTime: _startTime,
      endTime: _endTime,
      routineTitle: title.isEmpty ? 'Workout' : title,
      exercises: List.from(_exercises),
      status: WorkoutStatus.finished,
    );

    await DatabaseService.logsBox.put(widget.logKey, updatedLog.toMap());

    if (!mounted) return;
    Navigator.pop(context, true); // true = a fost salvat, caller poate reface
  }

  Future<void> _navigateToAddExercise() async {
    final existingIds = _exercises.map((e) => e.exerciseId).toList();

    final selectedExercises = await Navigator.push<List<Exercise>>(
      context,
      MaterialPageRoute(
        builder: (context) => ExerciseSelectionPage(
          existingExercisesIds: existingIds,
        ),
      ),
    );

    if (selectedExercises != null && selectedExercises.isNotEmpty && mounted) {
      setState(() {
        for (final ex in selectedExercises) {
          _exercises.add(
            LoggedExercise(
              exerciseId: ex.id,
              sets: [const LoggedSet(weight: 0.0, reps: 0)],
            ),
          );
        }
      });
      _markDirty();
    }
  }

  Widget _buildStatColumn(String label, String value, ThemeData theme,
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

  Widget _buildDateTimeTile({
    required String label,
    required DateTime value,
    required VoidCallback onTap,
    required ThemeData theme,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 4.0),
        child: Row(
          children: [
            Icon(Icons.event, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            Text(
              _formatDateTime(value),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.edit,
                size: 14, color: theme.colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stats = _computeStats();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldLeave = await _confirmDiscardIfNeeded();
        if (shouldLeave && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Edit Workout',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          leadingWidth: 80,
          leading: TextButton(
            onPressed: () async {
              final shouldLeave = await _confirmDiscardIfNeeded();
              if (shouldLeave && context.mounted) Navigator.pop(context);
            },
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
                  onPressed: _handleSave,
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
                      hintText: 'Workout title...',
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      suffixIcon: Icon(Icons.edit,
                          size: 16, color: theme.colorScheme.onSurfaceVariant),
                    ),
                    onChanged: (value) => _markDirty(),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  children: [
                    _buildDateTimeTile(
                      label: 'Started',
                      value: _startTime,
                      onTap: () => _pickDateTime(isStart: true),
                      theme: theme,
                    ),
                    Divider(
                        color: theme.dividerColor.withOpacity(0.3), height: 1),
                    _buildDateTimeTile(
                      label: 'Finished',
                      value: _endTime,
                      onTap: () => _pickDateTime(isStart: false),
                      theme: theme,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    vertical: 12.0, horizontal: 16.0),
                decoration: BoxDecoration(
                  color: theme.cardColor.withOpacity(0.4),
                  border: Border(
                    bottom: BorderSide(
                        color: theme.colorScheme.primary.withOpacity(0.2)),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatColumn(
                        'Duration', '${stats['durationMin']} min', theme),
                    _buildStatColumn(
                        'Volume',
                        '${(stats['volume'] as double).toStringAsFixed(0)} kg',
                        theme),
                    _buildStatColumn('Sets', '${stats['setsCount']}', theme),
                  ],
                ),
              ),
              Expanded(
                child: _exercises.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('🏋️', style: TextStyle(fontSize: 48)),
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
                                'Tap "Add Exercise" below to add one.',
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
                        itemCount: _exercises.length,
                        onReorder: (oldIndex, newIndex) {
                          setState(() {
                            if (newIndex > oldIndex) newIndex -= 1;
                            final item = _exercises.removeAt(oldIndex);
                            _exercises.insert(newIndex, item);
                          });
                          _markDirty();
                        },
                        itemBuilder: (context, exIndex) {
                          final exercise = _exercises[exIndex];
                          final sets = exercise.sets;

                          final fullExercise =
                              _resolveExercise(exercise.exerciseId);
                          final coverImage = fullExercise?.coverImage;
                          final isMissingData = fullExercise == null;
                          final isImageEmpty =
                              coverImage == null || coverImage.isEmpty;

                          final displayName = fullExercise?.name ??
                              'Unknown exercise (ID: ${exercise.exerciseId})';

                          return Card(
                            key: ValueKey(
                                'edit_ex_${exercise.exerciseId}_$exIndex'),
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
                                                        ? '[⚠️ Missing from exercisesBox]'
                                                        : '[⚠️ No cover image]',
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
                                      IconButton(
                                        icon: Icon(Icons.more_vert,
                                            color: theme
                                                .colorScheme.onSurfaceVariant),
                                        onPressed: () {
                                          AppActionsSheet.show(
                                            context: context,
                                            title: displayName,
                                            subtitle:
                                                'Manage exercise in this workout',
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
                                                  final confirmDelete =
                                                      await showDialog<bool>(
                                                    context: context,
                                                    builder: (context) =>
                                                        AlertDialog(
                                                      title: const Text(
                                                          'Remove Exercise? ⚠️'),
                                                      content: Text(
                                                          'Are you sure you want to remove "$displayName" and all its sets from this workout?'),
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
                                                                    .redAccent,
                                                          ),
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
                                                      _exercises
                                                          .removeAt(exIndex);
                                                    });
                                                    _markDirty();
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
                                            child: Text('Weight (kg)',
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
                                  ...sets.asMap().entries.map((entry) {
                                    final setIndex = entry.key;
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
                                              child: TextFormField(
                                                initialValue: set.weight == 0.0
                                                    ? ''
                                                    : set.weight.toString(),
                                                keyboardType:
                                                    const TextInputType
                                                        .numberWithOptions(
                                                        decimal: true),
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
                                                  final newWeight =
                                                      double.tryParse(value) ??
                                                          0.0;
                                                  exercise.sets[setIndex] =
                                                      LoggedSet(
                                                          weight: newWeight,
                                                          reps: set.reps);
                                                  _markDirty();
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
                                                  _markDirty();
                                                },
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                  const SizedBox(height: 10),
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
                                              final lastWeight = sets.isNotEmpty
                                                  ? sets.last.weight
                                                  : 0.0;
                                              final lastReps = sets.isNotEmpty
                                                  ? sets.last.reps
                                                  : 0;
                                              sets.add(LoggedSet(
                                                  weight: lastWeight,
                                                  reps: lastReps));
                                            });
                                            _markDirty();
                                          },
                                        ),
                                      ),
                                      if (sets.length > 1)
                                        TextButton(
                                          onPressed: () {
                                            setState(() {
                                              sets.removeLast();
                                            });
                                            _markDirty();
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
              label: 'Add Exercise',
              onPressed: _navigateToAddExercise,
              icon: Icons.fitness_center,
            ),
          ),
        ),
      ),
    );
  }
}
