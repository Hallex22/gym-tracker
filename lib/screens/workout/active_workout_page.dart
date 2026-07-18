import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:gym_tracker/extensions/string_extension.dart';
import 'package:gym_tracker/screens/exercises/exercise_detail_page.dart';
import 'package:gym_tracker/screens/exercises/exercise_selection_page.dart';
import 'package:gym_tracker/services/stats_service.dart';
import 'package:gym_tracker/theme/app_theme.dart';
import 'package:gym_tracker/widgets/app_buttons.dart';
import 'package:gym_tracker/widgets/rest_timer_banner.dart';
import 'package:gym_tracker/widgets/top_toast.dart';
import '../../../models/models.dart';
import '../../enums/enums.dart';
import '../../models/app_settings.dart';
import '../../services/database_service.dart';
import '../../services/rest_timer_service.dart';
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
  late Map<int, Exercise> _exerciseCache;

  // 🆕 Unitatea de masura preferata global (din Settings), incarcata o data.
  late UnitSystem _globalUnit;
  bool _globalAutoTimer = false;
  int _globalTimerDuration = 90;

  // 🆕 Override temporar, DOAR pentru sesiunea curenta, per exercitiu.
  final Map<int, UnitSystem> _exerciseUnitOverride = {};

  // 🆕 Override pentru timer per exercitiu (daca e activ/inactiv pe parcursul sesiunii)
  final Map<int, bool> _exerciseTimerOverride = {};
  final Map<int, int> _exerciseTimerDuration = {};

  // Mapare pentru a retine daca un exercitiu intreg a fost completat in sesiunea curenta
  final Map<int, bool> _exerciseCompletedStatus = {};

  // Generăm o listă de secunde din 5 în 5, de la 5 secunde până la 10 minute (600 secunde)
  final List<int> _wheelTimerOptions = List.generate(120, (index) => (index + 1) * 5);

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.routine.title);
    _loadGlobalSettings();
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

  void _loadGlobalSettings() {
    final Map? rawSettings = DatabaseService.settingsBox.get('appSettings') as Map?;
    final AppSettings settings = rawSettings != null ? AppSettings.fromMap(rawSettings) : const AppSettings();
    _globalUnit = settings.unitSystem;

    try {
      _globalAutoTimer = settings.enableAutoRestTimer;
      _globalTimerDuration = settings.defaultRestTimerDuration;
    } catch (_) {
      debugPrint("Ceva nu a functionat la incarcarea setarilor");
      _globalAutoTimer = false;
      _globalTimerDuration = 90;
    }
  }

  // Determină dacă rest timer-ul este activ pentru exercițiul selectat
  bool _isTimerEnabledFor(int exerciseId) => _exerciseTimerOverride[exerciseId] ?? _globalAutoTimer;

  // Determină durata activă a rest timer-ului pentru exercițiul curent
  int _timerDurationFor(int exerciseId) => _exerciseTimerDuration[exerciseId] ?? _globalTimerDuration;

  // Unitatea activa pentru un exercitiu: override local daca exista, altfel cea globala.
  UnitSystem _unitFor(int exerciseId) => _exerciseUnitOverride[exerciseId] ?? _globalUnit;

  void _toggleUnitOverride(int exerciseId) {
    setState(() {
      if (_exerciseUnitOverride.containsKey(exerciseId)) {
        _exerciseUnitOverride.remove(exerciseId);
      } else {
        _exerciseUnitOverride[exerciseId] = _globalUnit == UnitSystem.kg ? UnitSystem.lbs : UnitSystem.kg;
      }
    });
  }

  String _formatWeight(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(1);
  }

  Future<void> _updateExerciseNotesPersistent(Exercise exercise, String notes) async {
    final updatedExercise = exercise.copyWith(notes: notes.trim().isEmpty ? null : notes.trim());
    _exerciseCache[exercise.id] = updatedExercise;
    await DatabaseService.exercisesBox.put(exercise.id, updatedExercise.toMap());
  }

  // Afișează Bottom Sheet-ul personalizat cu rotița verticală (Stil Mouse/iOS Picker) din 5 în 5 secunde
  void _showTimerSetupBottomSheet(int exerciseId, String exerciseName) {
    final theme = Theme.of(context);
    bool localEnabled = _isTimerEnabledFor(exerciseId);
    int localDuration = _timerDurationFor(exerciseId);

    // Identificăm indexul inițial în listă pentru durata curentă a exercițiului
    int initialSelectedIndex = _wheelTimerOptions.indexOf(localDuration);
    if (initialSelectedIndex == -1) {
      initialSelectedIndex = _wheelTimerOptions.indexOf(90); // default fallback la 90s dacă nu se potrivește fix
      if (initialSelectedIndex == -1) initialSelectedIndex = 17;
    }

    // Controller special de la Flutter/Cupertino pentru setarea poziției inițiale în rotiță
    final FixedExtentScrollController wheelController = FixedExtentScrollController(initialItem: initialSelectedIndex);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Rest Timer ⏱️',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                  ),
                  Text(
                    'Set instantaneous rest timer or activate auto rest for $exerciseName',
                    style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Enable Rest Timer', style: TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: const Text('Auto start when checking off a completed set'),
                    value: localEnabled,
                    onChanged: (val) {
                      setModalState(() => localEnabled = val);
                    },
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      'Duration: $localDuration seconds',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Zona de Rotiță Verticală 3D (Tip Mouse Scroll / Cupertino)
                  SizedBox(
                    height: 180,
                    child: CupertinoPicker(
                      scrollController: wheelController,
                      itemExtent: 40,
                      magnification: 1.22,
                      squeeze: 1.2,
                      useMagnifier: true,
                      onSelectedItemChanged: (int index) {
                        setModalState(() {
                          localDuration = _wheelTimerOptions[index];
                        });
                      },
                      children: _wheelTimerOptions.map((duration) {
                        final minutes = duration ~/ 60;
                        final seconds = duration % 60;
                        final labelString = minutes > 0 ? '$minutes min $seconds s' : '$seconds sec';
                        return Center(
                          child: Text(
                            labelString,
                            style: TextStyle(
                              fontSize: 16,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: AppFilledButton(
                      label: 'Done',
                      onPressed: () {
                        setState(() {
                          _exerciseTimerOverride[exerciseId] = localEnabled;
                          _exerciseTimerDuration[exerciseId] = localDuration;
                        });
                        Navigator.pop(context);
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showSetTypeSheet(LoggedExercise exercise, int setIndex, LoggedSet currentSet) {
    final List<SheetActionItem> actions = SetType.values.map((type) {
      return SheetActionItem(
        icon: type.icon,
        label: type.label,
        color: type == currentSet.type ? Theme.of(context).colorScheme.primary : null,
        onPressed: () {
          setState(() {
            exercise.sets[setIndex] = LoggedSet(
              weight: currentSet.weight,
              reps: currentSet.reps,
              type: type,
              isCompleted: currentSet.isCompleted,
            );
          });
          _updateLiveProgress();
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
            _updateLiveProgress();
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

  void _buildExerciseCache() {
    _exerciseCache = {};
    for (var raw in DatabaseService.exercisesBox.values) {
      final ex = Exercise.fromMap(raw as Map);
      _exerciseCache[ex.id] = ex;
    }
  }

  Exercise? _resolveExercise(int exerciseId) => _exerciseCache[exerciseId];

  void _startLiveTimer() {
    _liveTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  void _loadOrInitializeWorkout() {
    MapEntry<dynamic, dynamic>? existingActiveEntry;

    for (var entry in DatabaseService.logsBox.toMap().entries) {
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
        final targetSets = routineExercise.targetSetsCount > 0 ? routineExercise.targetSetsCount : 1;
        final initialSets = List<LoggedSet>.generate(
          targetSets,
          (index) => const LoggedSet(weight: 0.0, reps: 0),
          growable: true,
        );

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
    _currentLogKey = await DatabaseService.logsBox.add(initialLog.toMap());
  }

  Future<void> _updateLiveProgress() async {
    if (_currentLogKey == null) return;
    final currentLog = WorkoutLog(
      startTime: _sessionStart,
      routineTitle: _titleController.text.trim(),
      exercises: List.from(_activeExercises),
      status: WorkoutStatus.started,
    );
    await DatabaseService.logsBox.put(_currentLogKey, currentLog.toMap());
  }

  void _adjustLiveWorkoutDuration(int targetMinutes) {
    setState(() {
      _sessionStart = DateTime.now().subtract(Duration(minutes: targetMinutes));
    });

    _updateLiveProgress();

    if (!mounted) return;

    TopToast.show(context, 'Duration updated to $targetMinutes min! ⏱️', type: ToastType.info);
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
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
      endTime: DateTime.now(),
      routineTitle: _titleController.text.trim(),
      exercises: List.from(_activeExercises),
      status: WorkoutStatus.started,
    );

    final difference = DateTime.now().difference(_sessionStart);
    final hours = difference.inHours;
    final minutes = difference.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = difference.inSeconds.remainder(60).toString().padLeft(2, '0');

    String durationString =
        hours > 0 ? '${hours.toString().padLeft(2, '0')}:${minutes}:${seconds}' : '${minutes}:${seconds}';

    return {
      'durationStr': durationString,
      'durationMin': difference.inMinutes,
      'exercisesCount': _activeExercises.length,
      'volume': currentSnapshotLog.totalVolume,
      'volumeStr': '${_formatWeight(_globalUnit.toDisplay(currentSnapshotLog.totalVolume))} ${_globalUnit.label}',
      'setsCount': currentSnapshotLog.completedSetsCount
    };
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
                    _buildStatRow(Icons.timer, 'Duration:', '${stats['durationMin']} min'),
                    Divider(color: theme.colorScheme.primary.withOpacity(0.2)),
                    _buildStatRow(Icons.fitness_center, 'Total Volume:', stats['volumeStr']),
                    Divider(color: theme.colorScheme.primary.withOpacity(0.2)),
                    _buildStatRow(Icons.format_list_numbered, 'Completed Sets:', '${stats['setsCount']}'),
                    Divider(color: theme.colorScheme.primary.withOpacity(0.2)),
                    _buildStatRow(Icons.format_list_bulleted, 'Exercises:', '${stats['exercisesCount']}'),
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          const Spacer(),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
        ],
      ),
    );
  }

  Future<void> _executeFinish() async {
    if (_currentLogKey == null) return;

    final endTime = DateTime.now();
    String finalTitle = _titleController.text.trim();
    if (finalTitle.isEmpty) {
      finalTitle = _activeExercises.isNotEmpty ? 'Custom Workout (${_activeExercises.length} ex)' : 'Empty Workout';
    }

    final finalLog = WorkoutLog(
      startTime: _sessionStart,
      endTime: endTime,
      routineTitle: finalTitle,
      exercises: List.from(_activeExercises),
      status: WorkoutStatus.finished,
    );

    await DatabaseService.logsBox.put(_currentLogKey, finalLog.toMap());
    final duration = endTime.difference(_sessionStart).inMinutes;

    if (!mounted) return;
    Navigator.pop(context);
    TopToast.show(context, 'Workout saved! ⏱️ Duration: $duration min. 💪', type: ToastType.success);
  }

  Future<void> _cancelWorkout() async {
    if (_currentLogKey != null) {
      await DatabaseService.logsBox.delete(_currentLogKey);
    }
    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _navigateToSelectExercise() async {
    final List<int> existingIds = _activeExercises.map((e) => e.exerciseId).toList();

    final List<Exercise>? selectedExercises = await Navigator.push<List<Exercise>>(
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
          _activeExercises.add(
            LoggedExercise(
              exerciseId: ex.id,
              sets: [const LoggedSet(weight: 0.0, reps: 0)],
            ),
          );
        }
      });
      _updateLiveProgress();
    }
  }

  Widget _buildLiveStatColumn(String label, String value, ThemeData theme, {VoidCallback? onTap}) {
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
            content: const Text('You can keep this workout running in the background, or cancel it entirely.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, 'keep'), child: const Text('Keep in Background')),
              TextButton(
                  onPressed: () => Navigator.pop(context, 'cancel'),
                  child: const Text('Cancel Workout', style: TextStyle(color: Colors.redAccent))),
              TextButton(
                  onPressed: () => Navigator.pop(context, 'stay'),
                  child: const Text('Stay Here', style: TextStyle(color: Colors.grey))),
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
          title: TextField(
            controller: _titleController,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
            decoration: const InputDecoration(
              hintText: 'Workout Title...',
              border: InputBorder.none,
              focusedBorder: InputBorder.none,
              enabledBorder: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
            onChanged: (value) => _updateLiveProgress(),
          ),
          leadingWidth: 80,
          leading: TextButton(
            onPressed: () => Navigator.maybePop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600),
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
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Theme.of(context).colorScheme.primary.withOpacity(0.2))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildLiveStatColumn('Duration', stats['durationStr'], theme,
                        onTap: _showEditWorkoutDurationDialog),
                    _buildLiveStatColumn('Volume', stats['volumeStr'], theme),
                    _buildLiveStatColumn('Sets', '${stats['setsCount']}', theme),
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
                              const Text(
                                '🏋️',
                                style: TextStyle(fontSize: 48),
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

                          final fullExercise = _resolveExercise(exercise.exerciseId);
                          final coverImage = fullExercise?.coverImage;

                          final isMissingData = fullExercise == null;
                          final isImageEmpty = coverImage == null || coverImage.isEmpty;

                          final displayName = fullExercise?.name ?? 'Exercițiu necunoscut (ID: ${exercise.exerciseId})';
                          final isBodyWeight = fullExercise?.equipment == Equipment.bodyweight;

                          final unit = _unitFor(exercise.exerciseId);
                          final hasOverride = _exerciseUnitOverride.containsKey(exercise.exerciseId);

                          final timerActive = _isTimerEnabledFor(exercise.exerciseId);
                          final timerSeconds = _timerDurationFor(exercise.exerciseId);

                          // Starea curentă a checkmark-ului (isCompleted) pentru întreg cardul
                          final isExerciseFinished = _exerciseCompletedStatus[exercise.exerciseId] ?? false;

                          return Card(
                            key: ValueKey('active_ex_${exercise.exerciseId}_$exIndex'),
                            clipBehavior: Clip.antiAlias,
                            margin: const EdgeInsets.all(12),
                            // 🆕 Efect vizual: Dacă exercițiul este gata, cardul primește un fundal verde-opac fin
                            color: isExerciseFinished ? Colors.green.withOpacity(0.06) : theme.cardColor,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // --- PRIMUL RÂND: DRAG, AVATAR, TITLU ȘI DOTS + CHECKMARK ---
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Icon(Icons.drag_handle, color: theme.colorScheme.onSurfaceVariant),
                                        const SizedBox(width: 8),
                                        if (!isMissingData && !isImageEmpty) ...[
                                          CircleAvatar(
                                            radius: 20,
                                            backgroundColor: theme.colorScheme.surfaceContainerHighest,
                                            backgroundImage: AssetImage('assets/$coverImage'),
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
                                                    builder: (context) => ExerciseDetailPage(exercise: fullExercise),
                                                  ),
                                                );
                                              } else {
                                                TopToast.show(context,
                                                    'Eroare: Lipsesc detaliile pentru ID "${exercise.exerciseId}"!',
                                                    type: ToastType.error);
                                              }
                                            },
                                            borderRadius: BorderRadius.circular(4),
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Flexible(
                                                        child: Text(
                                                          displayName,
                                                          style: TextStyle(
                                                            fontSize: 16,
                                                            fontWeight: FontWeight.bold,
                                                            color: theme.colorScheme.onSurface,
                                                            // Tăiem textul discret dacă exercițiul e finalizat
                                                            decoration:
                                                                isExerciseFinished ? TextDecoration.lineThrough : null,
                                                          ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                      if (hasOverride) ...[
                                                        const SizedBox(width: 6),
                                                        Container(
                                                          padding:
                                                              const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                                          decoration: BoxDecoration(
                                                            color: theme.colorScheme.primary.withOpacity(0.15),
                                                            borderRadius: BorderRadius.circular(6),
                                                          ),
                                                          child: Text(
                                                            unit.label,
                                                            style: TextStyle(
                                                              fontSize: 10,
                                                              fontWeight: FontWeight.bold,
                                                              color: theme.colorScheme.primary,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                  if (isMissingData || isImageEmpty)
                                                    Text(
                                                      isMissingData
                                                          ? '[⚠️ Nu există în exercisesBox]'
                                                          : '[⚠️ Imaginea este goală în DB]',
                                                      style: const TextStyle(
                                                          fontSize: 11,
                                                          color: Colors.redAccent,
                                                          fontWeight: FontWeight.bold),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: Icon(Icons.more_horiz, color: theme.colorScheme.onSurfaceVariant),
                                          onPressed: () {
                                            AppActionsSheet.show(
                                              context: context,
                                              title: displayName,
                                              subtitle: 'Manage active exercise session',
                                              actions: [
                                                SheetActionItem(
                                                  icon: SetType.warmup.icon,
                                                  label: 'Add Warmup Set',
                                                  onPressed: () {
                                                    setState(() {
                                                      double firstWeight = sets.isNotEmpty ? sets.first.weight : 0.0;
                                                      int firstReps = sets.isNotEmpty ? sets.first.reps : 0;
                                                      sets.insert(
                                                        0,
                                                        LoggedSet(
                                                          weight: firstWeight,
                                                          reps: firstReps,
                                                          type: SetType.warmup,
                                                          isCompleted: false,
                                                        ),
                                                      );
                                                    });
                                                    _updateLiveProgress();
                                                  },
                                                ),
                                                SheetActionItem(
                                                  icon: Icons.info_outline,
                                                  label: 'View Exercise Details',
                                                  onPressed: () {
                                                    if (fullExercise != null) {
                                                      Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder: (context) =>
                                                              ExerciseDetailPage(exercise: fullExercise),
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
                                                    onPressed: () => _toggleUnitOverride(exercise.exerciseId),
                                                  ),
                                                SheetActionItem(
                                                  icon: Icons.delete_outline,
                                                  label: 'Remove Exercise',
                                                  color: Colors.redAccent,
                                                  onPressed: () async {
                                                    final bool? confirmDelete = await showDialog<bool>(
                                                      context: context,
                                                      builder: (BuildContext context) => AlertDialog(
                                                        title: const Text('Remove Exercise? ⚠️'),
                                                        content: Text(
                                                            'Are you sure you want to remove "$displayName" and all its completed sets from this workout?'),
                                                        actions: [
                                                          TextButton(
                                                            onPressed: () => Navigator.pop(context, false),
                                                            child: const Text('Cancel',
                                                                style: TextStyle(color: Colors.grey)),
                                                          ),
                                                          ElevatedButton(
                                                            style: ElevatedButton.styleFrom(
                                                                backgroundColor: Colors.redAccent),
                                                            onPressed: () => Navigator.pop(context, true),
                                                            child: const Text('Remove',
                                                                style: TextStyle(color: Colors.white)),
                                                          ),
                                                        ],
                                                      ),
                                                    );

                                                    if (confirmDelete == true) {
                                                      setState(() {
                                                        _activeExercises.removeAt(exIndex);
                                                        _exerciseUnitOverride.remove(exercise.exerciseId);
                                                        _exerciseTimerOverride.remove(exercise.exerciseId);
                                                        _exerciseTimerDuration.remove(exercise.exerciseId);
                                                        _exerciseCompletedStatus.remove(exercise.exerciseId);
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
                                  ),

                                  // 🆕 REZOLVARE CERINȚĂ 2: Input-ul de notițe complet curat, fără borders/prefix icons
                                  if (!isMissingData)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                                      child: TextFormField(
                                        initialValue: fullExercise.notes,
                                        style: TextStyle(
                                            fontSize: 13,
                                            color: context.text.withOpacity(0.8),
                                            fontStyle: FontStyle.normal),
                                        maxLines: null,
                                        decoration: InputDecoration(
                                          hintText: 'Add exercise notes here...',
                                          hintStyle: TextStyle(
                                              fontSize: 12,
                                              color: context.textMuted.withOpacity(0.5),
                                              fontStyle: FontStyle.normal),
                                          isDense: true,
                                          contentPadding: const EdgeInsets.symmetric(vertical: 4),
                                          border: InputBorder.none,
                                          focusedBorder: InputBorder.none,
                                          enabledBorder: InputBorder.none,
                                          errorBorder: InputBorder.none,
                                          disabledBorder: InputBorder.none,
                                        ),
                                        onChanged: (text) => _updateExerciseNotesPersistent(fullExercise, text),
                                      ),
                                    ),

                                  // --- AL TREILEA RÂND: BUTON ACTION PENTRU REST TIMER OVERRIDE (ROTIȚĂ DIN 5 ÎN 5) ---
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(8),
                                      onTap: () => _showTimerSetupBottomSheet(exercise.exerciseId, displayName),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: timerActive
                                              ? theme.colorScheme.primary.withOpacity(0.08)
                                              : theme.colorScheme.onSurface.withOpacity(0.04),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(
                                              color: timerActive
                                                  ? theme.colorScheme.primary.withOpacity(0.3)
                                                  : theme.colorScheme.onSurfaceVariant.withOpacity(0.15)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.hourglass_empty_rounded,
                                                size: 14,
                                                color: timerActive
                                                    ? theme.colorScheme.primary
                                                    : theme.colorScheme.onSurfaceVariant),
                                            const SizedBox(width: 6),
                                            Text(
                                              timerActive ? 'Rest: $timerSeconds s' : 'Rest: Off',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: timerActive
                                                      ? theme.colorScheme.primary
                                                      : theme.colorScheme.onSurfaceVariant),
                                            ),
                                            const SizedBox(width: 4),
                                            Icon(Icons.arrow_drop_down_rounded,
                                                size: 16,
                                                color: timerActive
                                                    ? theme.colorScheme.primary
                                                    : theme.colorScheme.onSurfaceVariant),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),

                                  Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      child: Divider(color: theme.colorScheme.primary.withOpacity(0.2))),

                                  // --- HEADER COLOANE ---
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                            width: 50,
                                            child: Text('Set',
                                                style: TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 12,
                                                    color: theme.colorScheme.onSurfaceVariant),
                                                textAlign: TextAlign.center)),
                                        SizedBox(
                                            width: 100,
                                            child: Text('Previous',
                                                style: TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 12,
                                                    color: theme.colorScheme.onSurfaceVariant),
                                                textAlign: TextAlign.center)),
                                        Expanded(
                                          child: isBodyWeight
                                              ? Text(
                                                  'Body Weight',
                                                  style: TextStyle(
                                                      fontWeight: FontWeight.w600,
                                                      fontSize: 12,
                                                      color: theme.colorScheme.onSurfaceVariant),
                                                  textAlign: TextAlign.center,
                                                )
                                              : Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      Icons.fitness_center,
                                                      size: 12,
                                                      color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      unit.label.capitalize(),
                                                      style: TextStyle(
                                                          fontWeight: FontWeight.w600,
                                                          fontSize: 12,
                                                          color: theme.colorScheme.onSurfaceVariant),
                                                    ),
                                                  ],
                                                ),
                                        ),
                                        Expanded(
                                            child: Text('Reps',
                                                style: TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 12,
                                                    color: theme.colorScheme.onSurfaceVariant),
                                                textAlign: TextAlign.center)),
                                        Expanded(
                                          child: Center(
                                            child: Icon(
                                              Icons.check_rounded,
                                              size: 16,
                                              color: theme.colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // --- RANDURI SETURI ---
                                  ...sets.asMap().entries.map((entry) {
                                    int setIndex = entry.key;
                                    final set = entry.value;

                                    final rowColor = setIndex % 2 == 0
                                        ? Colors.transparent
                                        : theme.colorScheme.secondary.withOpacity(0.06);

                                    final displayWeight = unit.toDisplay(set.weight);

                                    final weightController = TextEditingController(
                                      text: set.weight == 0.0 ? '' : _formatWeight(displayWeight),
                                    );
                                    final repsController = TextEditingController(
                                      text: set.reps == 0 ? '' : set.reps.toString(),
                                    );
                                    weightController.selection = TextSelection.fromPosition(
                                      TextPosition(offset: weightController.text.length),
                                    );
                                    repsController.selection = TextSelection.fromPosition(
                                      TextPosition(offset: repsController.text.length),
                                    );

                                    final (prevWeightInKg, prevReps) = StatsService.getPreviousSetRaw(
                                        exerciseId: exercise.exerciseId,
                                        setIndex: setIndex,
                                        currentType: set.type,
                                        activeExercises: _activeExercises);

                                    final hasHistory = prevWeightInKg > 0.0 || prevReps > 0;
                                    String prevText = '—';

                                    if (hasHistory) {
                                      if (isBodyWeight) {
                                        prevText = 'BW x $prevReps';
                                      } else {
                                        final displayPrevWeight = unit.toDisplay(prevWeightInKg);
                                        prevText = '${_formatWeight(displayPrevWeight)} ${unit.label} × $prevReps';
                                      }
                                    }

                                    return Container(
                                      color: set.type == SetType.normal ? rowColor : null,
                                      margin: const EdgeInsets.symmetric(vertical: 1.0),
                                      padding: const EdgeInsets.symmetric(vertical: 1.0, horizontal: 0),
                                      decoration: set.type != SetType.normal
                                          ? BoxDecoration(
                                              color: set.type.color != null
                                                  ? set.type.color!.withOpacity(0.08)
                                                  : theme.cardColor,
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border(
                                                left: BorderSide(
                                                  color: set.type.color ?? theme.colorScheme.primary,
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
                                              borderRadius: BorderRadius.circular(6),
                                              onTap: () => _showSetTypeSheet(exercise, setIndex, set),
                                              child: Padding(
                                                padding: const EdgeInsets.symmetric(vertical: 2.0),
                                                child: Column(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                        set.type != SetType.normal
                                                            ? set.type.shortLabel
                                                            : '${setIndex + 1}',
                                                        style: TextStyle(
                                                          fontSize: 16,
                                                          fontWeight: FontWeight.bold,
                                                          color: set.type.color ?? theme.colorScheme.onSurface,
                                                        )),
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
                                                borderRadius: BorderRadius.circular(6),
                                                onTap: prevText == '—'
                                                    ? null
                                                    : () {
                                                        setState(() {
                                                          exercise.sets[setIndex] = LoggedSet(
                                                            weight: prevWeightInKg,
                                                            reps: prevReps,
                                                            type: set.type,
                                                            isCompleted: set.isCompleted,
                                                          );
                                                        });
                                                        _updateLiveProgress();
                                                      },
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: prevText == '—'
                                                        ? Colors.transparent
                                                        : theme.colorScheme.onSurface.withOpacity(0.04),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    prevText,
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.w500,
                                                      color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                                                    ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                              child: isBodyWeight
                                                  ? Container(
                                                      alignment: Alignment.center,
                                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                                      child: Text(
                                                        'BW',
                                                        style: TextStyle(
                                                            fontWeight: FontWeight.w600,
                                                            color: theme.colorScheme.onSurface),
                                                      ),
                                                    )
                                                  : TextFormField(
                                                      controller: weightController,
                                                      textAlign: TextAlign.center,
                                                      keyboardType:
                                                          const TextInputType.numberWithOptions(decimal: true),
                                                      style: TextStyle(
                                                          fontWeight: FontWeight.w600,
                                                          color: theme.colorScheme.onSurface),
                                                      decoration: InputDecoration(
                                                          border: InputBorder.none,
                                                          enabledBorder: InputBorder.none,
                                                          focusedBorder: InputBorder.none,
                                                          disabledBorder: InputBorder.none,
                                                          errorBorder: InputBorder.none,
                                                          focusedErrorBorder: InputBorder.none,
                                                          contentPadding:
                                                              const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                          hintText: prevWeightInKg > 0.0
                                                              ? _formatWeight(unit.toDisplay(prevWeightInKg))
                                                              : '0',
                                                          hintStyle: TextStyle(
                                                              fontWeight: FontWeight.normal,
                                                              color:
                                                                  theme.colorScheme.onSurfaceVariant.withOpacity(0.8))),
                                                      onChanged: (value) {
                                                        final typedDisplay = double.tryParse(value) ?? 0.0;
                                                        final weightInKg = unit.toStorage(typedDisplay);
                                                        exercise.sets[setIndex] = LoggedSet(
                                                          weight: weightInKg,
                                                          reps: set.reps,
                                                          type: set.type,
                                                          isCompleted: set.isCompleted,
                                                        );
                                                        _updateLiveProgress();
                                                      },
                                                    ),
                                            ),
                                          ),
                                          Expanded(
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                              child: TextFormField(
                                                controller: repsController,
                                                textAlign: TextAlign.center,
                                                keyboardType: TextInputType.number,
                                                style: TextStyle(
                                                    fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface),
                                                decoration: InputDecoration(
                                                    border: InputBorder.none,
                                                    enabledBorder: InputBorder.none,
                                                    focusedBorder: InputBorder.none,
                                                    disabledBorder: InputBorder.none,
                                                    errorBorder: InputBorder.none,
                                                    focusedErrorBorder: InputBorder.none,
                                                    contentPadding:
                                                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                    hintText: prevReps > 0 ? '$prevReps' : '0',
                                                    hintStyle: TextStyle(
                                                        fontWeight: FontWeight.normal,
                                                        color: theme.colorScheme.onSurfaceVariant.withOpacity(0.8))),
                                                onChanged: (value) {
                                                  final newReps = int.tryParse(value) ?? 0;
                                                  exercise.sets[setIndex] = LoggedSet(
                                                    weight: set.weight,
                                                    reps: newReps,
                                                    type: set.type,
                                                    isCompleted: set.isCompleted,
                                                  );
                                                  _updateLiveProgress();
                                                },
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            child: Center(
                                              child: IconButton(
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                                icon: Icon(
                                                  set.isCompleted ? Icons.check_circle : Icons.circle_outlined,
                                                  color: set.isCompleted
                                                      ? context.primary
                                                      : theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                                                  size: 22,
                                                ),
                                                onPressed: () {
                                                  final bool turningOn =
                                                      !set.isCompleted; // Va fi true dacă userul bifează setul acum

                                                  setState(() {
                                                    exercise.sets[setIndex] = LoggedSet(
                                                      weight: set.weight,
                                                      reps: set.reps,
                                                      type: set.type,
                                                      isCompleted: turningOn,
                                                    );
                                                  });

                                                  _updateLiveProgress();

                                                  if (turningOn && timerActive) {
                                                    RestTimerService().startTimer(seconds: timerSeconds);
                                                  }
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
                                  Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: AppGhostButton(
                                              label: 'Add Set',
                                              icon: Icons.add,
                                              onPressed: () {
                                                setState(() {
                                                  double lastWeight = sets.isNotEmpty ? sets.last.weight : 0.0;
                                                  int lastReps = sets.isNotEmpty ? sets.last.reps : 0;
                                                  sets.add(LoggedSet(weight: lastWeight, reps: lastReps));
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
                                                  style: TextStyle(color: Colors.redAccent, fontSize: 13)),
                                            )
                                        ],
                                      )),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              const RestTimerBanner(),
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
