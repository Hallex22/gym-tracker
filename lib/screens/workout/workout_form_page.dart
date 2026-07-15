import 'package:flutter/material.dart';
import 'package:gym_tracker/enums/workout_status.dart';
import 'package:gym_tracker/extensions/string_extension.dart';
import 'package:gym_tracker/screens/exercises/exercise_detail_page.dart';
import 'package:gym_tracker/screens/exercises/exercise_selection_page.dart';
import 'package:gym_tracker/services/stats_service.dart';
import 'package:gym_tracker/widgets/app_buttons.dart';
import 'package:gym_tracker/widgets/top_toast.dart';
import '../../models/models.dart';
import '../../enums/enums.dart';
import '../../models/app_settings.dart';
import '../../services/database_service.dart';
import '../../widgets/app_actions_sheet.dart';

/// Pagina de editare pentru un antrenament DEJA FINALIZAT (status = finished).
class WorkoutFormPage extends StatefulWidget {
  final dynamic logKey;
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

  late Map<int, Exercise> _exerciseCache;
  late UnitSystem _globalUnit;
  final Map<int, UnitSystem> _exerciseUnitOverride = {};

  @override
  void initState() {
    super.initState();
    _titleController =
        TextEditingController(text: widget.workoutLog.routineTitle);
    _startTime = widget.workoutLog.startTime;
    _endTime = widget.workoutLog.endTime ?? widget.workoutLog.startTime;

    _exercises = widget.workoutLog.exercises
        .map((e) => LoggedExercise(
              exerciseId: e.exerciseId,
              sets: List<LoggedSet>.from(e.sets),
            ))
        .toList();

    _loadUnitPreference();
    _buildExerciseCache();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _loadUnitPreference() {
    final Map? rawSettings =
        DatabaseService.settingsBox.get('appSettings') as Map?;
    final AppSettings settings = rawSettings != null
        ? AppSettings.fromMap(rawSettings)
        : const AppSettings();
    _globalUnit = settings.unitSystem;
  }

  UnitSystem _unitFor(int exerciseId) =>
      _exerciseUnitOverride[exerciseId] ?? _globalUnit;

  void _toggleUnitOverride(int exerciseId) {
    setState(() {
      if (_exerciseUnitOverride.containsKey(exerciseId)) {
        _exerciseUnitOverride.remove(exerciseId);
      } else {
        _exerciseUnitOverride[exerciseId] =
            _globalUnit == UnitSystem.kg ? UnitSystem.lbs : UnitSystem.kg;
      }
    });
  }

  String _formatWeight(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(1);
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

  void _showSetTypeSheet(
      LoggedExercise exercise, int setIndex, LoggedSet currentSet) {
    final List<SheetActionItem> actions = SetType.values.map((type) {
      return SheetActionItem(
        icon: type.icon,
        label: type.label,
        color: type == currentSet.type
            ? Theme.of(context).colorScheme.primary
            : null,
        onPressed: () {
          setState(() {
            exercise.sets[setIndex] = LoggedSet(
              weight: currentSet.weight,
              reps: currentSet.reps,
              type: type,
              isCompleted: currentSet.isCompleted,
            );
          });
          _markDirty();
        },
      );
    }).toList();

    if (exercise.sets.length > 1) {
      actions.add(
        SheetActionItem(
          icon: Icons.delete_sweep_outlined,
          label: 'Delete Set #${setIndex + 1}',
          color: Colors.redAccent,
          onPressed: () {
            setState(() {
              exercise.sets.removeAt(setIndex);
            });
            _markDirty();
          },
        ),
      );
    }

    AppActionsSheet.show(
      context: context,
      title: 'Set Options',
      subtitle: 'Manage set #${setIndex + 1}',
      actions: actions,
    );
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
    final snapshotLog = WorkoutLog(
      startTime: _startTime,
      endTime: _endTime,
      routineTitle: _titleController.text.trim(),
      exercises: List.from(_exercises),
      status: WorkoutStatus.finished,
    );

    final rawMinutes = _endTime.difference(_startTime).inMinutes;

    return {
      'durationMin': rawMinutes < 0 ? 0 : rawMinutes,
      'volume': snapshotLog.totalVolume,
      'volumeStr':
          '${_formatWeight(_globalUnit.toDisplay(snapshotLog.totalVolume))} ${_globalUnit.label}',
      'setsCount': snapshotLog.completedSetsCount,
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
    Navigator.pop(context, true);
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
          title: TextField(
            controller: _titleController,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
            decoration: InputDecoration(
              hintText: 'Workout title...',
              hintStyle: TextStyle(
                fontWeight: FontWeight.normal,
                fontSize: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              border: InputBorder.none,
              focusedBorder: InputBorder.none,
              enabledBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
            onChanged: (value) => _markDirty(),
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
                        color: theme.primaryColor.withOpacity(0.2), height: 1),
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
                    _buildStatColumn('Volume', stats['volumeStr'], theme),
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

                          final isBodyWeight =
                              fullExercise?.equipment == Equipment.bodyweight;

                          final unit = _unitFor(exercise.exerciseId);
                          final hasOverride = _exerciseUnitOverride
                              .containsKey(exercise.exerciseId);

                          return Card(
                            key: ValueKey(
                                'edit_ex_${exercise.exerciseId}_$exIndex'),
                            clipBehavior: Clip.antiAlias,
                            margin: const EdgeInsets.all(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding:
                                        const EdgeInsets.symmetric(horizontal: 12),
                                    child: Row(
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
                                            backgroundImage: AssetImage(
                                                'assets/$coverImage'),
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
                                              padding: const EdgeInsets
                                                  .symmetric(vertical: 4.0),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Flexible(
                                                        child: Text(
                                                          displayName,
                                                          style: TextStyle(
                                                              fontSize: 16,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color: theme
                                                                  .colorScheme
                                                                  .onSurface),
                                                          maxLines: 1,
                                                          overflow:
                                                              TextOverflow
                                                                  .ellipsis,
                                                        ),
                                                      ),
                                                      if (hasOverride) ...[
                                                        const SizedBox(
                                                            width: 6),
                                                        Container(
                                                          padding: const EdgeInsets
                                                              .symmetric(
                                                              horizontal: 6,
                                                              vertical: 1),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: theme
                                                                .colorScheme
                                                                .primary
                                                                .withOpacity(
                                                                    0.15),
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        6),
                                                          ),
                                                          child: Text(
                                                            unit.label,
                                                            style: TextStyle(
                                                              fontSize: 10,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color: theme
                                                                  .colorScheme
                                                                  .primary,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                  if (isMissingData ||
                                                      isImageEmpty)
                                                    Text(
                                                      isMissingData
                                                          ? '[⚠️ Missing from exercisesBox]'
                                                          : '[⚠️ No cover image]',
                                                      style: const TextStyle(
                                                          fontSize: 11,
                                                          color: Colors
                                                              .redAccent,
                                                          fontWeight:
                                                              FontWeight
                                                                  .bold),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: Icon(Icons.more_vert,
                                              color: theme.colorScheme
                                                  .onSurfaceVariant),
                                          onPressed: () {
                                            AppActionsSheet.show(
                                              context: context,
                                              title: displayName,
                                              subtitle:
                                                  'Manage exercise in this workout',
                                              actions: [
                                                SheetActionItem(
                                                  icon: SetType.warmup.icon,
                                                  label: 'Add Warmup Set',
                                                  onPressed: () {
                                                    setState(() {
                                                      final firstWeight =
                                                          sets.isNotEmpty
                                                              ? sets.first
                                                                  .weight
                                                              : 0.0;
                                                      final firstReps =
                                                          sets.isNotEmpty
                                                              ? sets.first
                                                                  .reps
                                                              : 0;
                                                      sets.insert(
                                                        0,
                                                        LoggedSet(
                                                          weight: firstWeight,
                                                          reps: firstReps,
                                                          type:
                                                              SetType.warmup,
                                                          isCompleted: false,
                                                        ),
                                                      );
                                                    });
                                                    _markDirty();
                                                  },
                                                ),
                                                SheetActionItem(
                                                  icon: Icons.info_outline,
                                                  label:
                                                      'View Exercise Details',
                                                  onPressed: () {
                                                    if (fullExercise !=
                                                        null) {
                                                      Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder:
                                                              (context) =>
                                                                  ExerciseDetailPage(
                                                                      exercise:
                                                                          fullExercise),
                                                        ),
                                                      );
                                                    }
                                                  },
                                                ),
                                                if (!isBodyWeight)
                                                  SheetActionItem(
                                                    icon: Icons.swap_horiz,
                                                    label: hasOverride
                                                        ? 'Reset to ${_globalUnit.label} (default)'
                                                        : 'Switch to ${(_globalUnit == UnitSystem.kg ? UnitSystem.lbs : UnitSystem.kg).label} for this exercise',
                                                    onPressed: () =>
                                                        _toggleUnitOverride(
                                                            exercise
                                                                .exerciseId),
                                                  ),
                                                SheetActionItem(
                                                  icon: Icons.delete_outline,
                                                  label: 'Remove Exercise',
                                                  color: Colors.redAccent,
                                                  onPressed: () async {
                                                    final confirmDelete =
                                                        await showDialog<
                                                            bool>(
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

                                                    if (confirmDelete ==
                                                        true) {
                                                      setState(() {
                                                        _exercises.removeAt(
                                                            exIndex);
                                                        _exerciseUnitOverride
                                                            .remove(exercise
                                                                .exerciseId);
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
                                  ),
                                  Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12),
                                      child: Divider(
                                          color: theme.colorScheme.primary
                                              .withOpacity(0.2))),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 4.0),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                            width: 50,
                                            child: Text('Set',
                                                style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.w600,
                                                    fontSize: 12,
                                                    color: theme.colorScheme
                                                        .onSurfaceVariant),
                                                textAlign: TextAlign.center)),
                                        SizedBox(
                                            width: 100,
                                            child: Text('Previous',
                                                style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.w600,
                                                    fontSize: 12,
                                                    color: theme.colorScheme
                                                        .onSurfaceVariant),
                                                textAlign: TextAlign.center)),
                                        Expanded(
                                          child: isBodyWeight
                                              ? Text(
                                                  'Body Weight',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 12,
                                                      color: theme.colorScheme
                                                          .onSurfaceVariant),
                                                  textAlign: TextAlign.center,
                                                )
                                              : Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .center,
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      Icons.fitness_center,
                                                      size: 12,
                                                      color: theme.colorScheme
                                                          .onSurfaceVariant
                                                          .withOpacity(0.7),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      unit.label.capitalize(),
                                                      style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          fontSize: 12,
                                                          color: theme
                                                              .colorScheme
                                                              .onSurfaceVariant),
                                                    ),
                                                  ],
                                                ),
                                        ),
                                        Expanded(
                                            child: Text('Reps',
                                                style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.w600,
                                                    fontSize: 12,
                                                    color: theme.colorScheme
                                                        .onSurfaceVariant),
                                                textAlign: TextAlign.center)),
                                      ],
                                    ),
                                  ),
                                  ...sets.asMap().entries.map((entry) {
                                    final setIndex = entry.key;
                                    final set = entry.value;

                                    final rowColor = setIndex % 2 == 0
                                        ? Colors.transparent
                                        : theme.colorScheme.secondary
                                            .withOpacity(0.06);

                                    final displayWeight =
                                        unit.toDisplay(set.weight);

                                    final weightController =
                                        TextEditingController(
                                      text: set.weight == 0.0
                                          ? ''
                                          : _formatWeight(displayWeight),
                                    );
                                    final repsController =
                                        TextEditingController(
                                      text: set.reps == 0
                                          ? ''
                                          : set.reps.toString(),
                                    );
                                    weightController.selection =
                                        TextSelection.fromPosition(
                                      TextPosition(
                                          offset:
                                              weightController.text.length),
                                    );
                                    repsController.selection =
                                        TextSelection.fromPosition(
                                      TextPosition(
                                          offset: repsController.text.length),
                                    );

                                    final (prevWeightInKg, prevReps) =
                                        StatsService.getPreviousSetRaw(
                                            exerciseId: exercise.exerciseId,
                                            setIndex: setIndex,
                                            currentType: set.type,
                                            activeExercises: _exercises);

                                    final hasHistory =
                                        prevWeightInKg > 0.0 || prevReps > 0;
                                    String prevText = '-';

                                    if (hasHistory) {
                                      if (isBodyWeight) {
                                        prevText = 'BW x $prevReps';
                                      } else {
                                        final displayPrevWeight =
                                            unit.toDisplay(prevWeightInKg);
                                        prevText =
                                            '${_formatWeight(displayPrevWeight)} ${unit.label} × $prevReps';
                                      }
                                    }

                                    return Container(
                                      color: set.type == SetType.normal
                                          ? rowColor
                                          : null,
                                      margin: const EdgeInsets.symmetric(
                                          vertical: 1.0),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 1.0, horizontal: 0),
                                      decoration: set.type != SetType.normal
                                          ? BoxDecoration(
                                              color: set.type.color != null
                                                  ? set.type.color!
                                                      .withOpacity(0.08)
                                                  : theme.cardColor,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              border: Border(
                                                left: BorderSide(
                                                  color: set.type.color ??
                                                      theme.colorScheme
                                                          .primary,
                                                  width: 3,
                                                ),
                                              ),
                                            )
                                          : null,
                                      child: Row(
                                        children: [
                                          SizedBox(
                                            width: 50,
                                            child: InkWell(
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              onTap: () => _showSetTypeSheet(
                                                  exercise, setIndex, set),
                                              child: Padding(
                                                padding: const EdgeInsets
                                                    .symmetric(vertical: 2.0),
                                                child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      set.type !=
                                                              SetType.normal
                                                          ? set.type
                                                              .shortLabel
                                                          : '${setIndex + 1}',
                                                      style: TextStyle(
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: set.type
                                                                .color ??
                                                            theme.colorScheme
                                                                .onSurface,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                          SizedBox(
                                            width: 100,
                                            child: Align(
                                              alignment: Alignment.center,
                                              child: InkWell(
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                onTap: hasHistory
                                                    ? () {
                                                        setState(() {
                                                          exercise.sets[
                                                                  setIndex] =
                                                              LoggedSet(
                                                            weight:
                                                                prevWeightInKg,
                                                            reps: prevReps,
                                                            type: set.type,
                                                            isCompleted:
                                                                set.isCompleted,
                                                          );
                                                        });
                                                        _markDirty();
                                                      }
                                                    : null,
                                                child: Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 6,
                                                      vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: hasHistory
                                                        ? theme.colorScheme
                                                            .onSurface
                                                            .withOpacity(0.04)
                                                        : Colors.transparent,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            6),
                                                  ),
                                                  child: Text(
                                                    prevText,
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color: theme.colorScheme
                                                          .onSurfaceVariant
                                                          .withOpacity(0.6),
                                                    ),
                                                    textAlign:
                                                        TextAlign.center,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            child: Padding(
                                              padding: const EdgeInsets
                                                  .symmetric(horizontal: 4.0),
                                              child: isBodyWeight
                                                  ? Container(
                                                      alignment:
                                                          Alignment.center,
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          vertical: 10),
                                                      child: Text(
                                                        'BW',
                                                        style: TextStyle(
                                                            fontWeight:
                                                                FontWeight
                                                                    .w600,
                                                            color: theme
                                                                .colorScheme
                                                                .onSurface),
                                                      ),
                                                    )
                                                  : TextFormField(
                                                      controller:
                                                          weightController,
                                                      textAlign:
                                                          TextAlign.center,
                                                      keyboardType:
                                                          const TextInputType
                                                              .numberWithOptions(
                                                              decimal: true),
                                                      style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: theme
                                                              .colorScheme
                                                              .onSurface),
                                                      decoration:
                                                          InputDecoration(
                                                        border:
                                                            InputBorder.none,
                                                        enabledBorder:
                                                            InputBorder.none,
                                                        focusedBorder:
                                                            InputBorder.none,
                                                        disabledBorder:
                                                            InputBorder.none,
                                                        errorBorder:
                                                            InputBorder.none,
                                                        focusedErrorBorder:
                                                            InputBorder.none,
                                                        contentPadding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal: 8,
                                                                vertical: 4),
                                                        hintText: prevWeightInKg >
                                                                0.0
                                                            ? _formatWeight(unit
                                                                .toDisplay(
                                                                    prevWeightInKg))
                                                            : '0',
                                                        hintStyle: TextStyle(
                                                            fontWeight:
                                                                FontWeight
                                                                    .normal,
                                                            color: theme
                                                                .colorScheme
                                                                .onSurfaceVariant
                                                                .withOpacity(
                                                                    0.8)),
                                                      ),
                                                      onChanged: (value) {
                                                        final typedDisplay =
                                                            double.tryParse(
                                                                    value) ??
                                                                0.0;
                                                        final weightInKg = unit
                                                            .toStorage(
                                                                typedDisplay);
                                                        exercise.sets[
                                                            setIndex] = LoggedSet(
                                                          weight: weightInKg,
                                                          reps: set.reps,
                                                          type: set.type,
                                                          isCompleted:
                                                              set.isCompleted,
                                                        );
                                                        _markDirty();
                                                      },
                                                    ),
                                            ),
                                          ),
                                          Expanded(
                                            child: Padding(
                                              padding: const EdgeInsets
                                                  .symmetric(horizontal: 4.0),
                                              child: TextFormField(
                                                controller: repsController,
                                                textAlign: TextAlign.center,
                                                keyboardType:
                                                    TextInputType.number,
                                                style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.w600,
                                                    color: theme.colorScheme
                                                        .onSurface),
                                                decoration: InputDecoration(
                                                  border: InputBorder.none,
                                                  enabledBorder:
                                                      InputBorder.none,
                                                  focusedBorder:
                                                      InputBorder.none,
                                                  disabledBorder:
                                                      InputBorder.none,
                                                  errorBorder:
                                                      InputBorder.none,
                                                  focusedErrorBorder:
                                                      InputBorder.none,
                                                  contentPadding:
                                                      const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 8,
                                                          vertical: 4),
                                                  hintText: prevReps > 0
                                                      ? '$prevReps'
                                                      : '0',
                                                  hintStyle: TextStyle(
                                                      fontWeight:
                                                          FontWeight.normal,
                                                      color: theme.colorScheme
                                                          .onSurfaceVariant
                                                          .withOpacity(0.8)),
                                                ),
                                                onChanged: (value) {
                                                  final newReps =
                                                      int.tryParse(value) ?? 0;
                                                  exercise.sets[setIndex] =
                                                      LoggedSet(
                                                    weight: set.weight,
                                                    reps: newReps,
                                                    type: set.type,
                                                    isCompleted:
                                                        set.isCompleted,
                                                  );
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
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: AppGhostButton(
                                            label: 'Add Set',
                                            icon: Icons.add,
                                            onPressed: () {
                                              setState(() {
                                                final lastWeight =
                                                    sets.isNotEmpty
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
                                            child: const Text(
                                                'Remove Last Set',
                                                style: TextStyle(
                                                    color: Colors.redAccent)),
                                          )
                                      ],
                                    ),
                                  ),
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