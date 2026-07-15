import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gym_tracker/extensions/string_extension.dart';
import 'package:gym_tracker/screens/exercises/exercise_detail_page.dart';
import 'package:gym_tracker/screens/exercises/exercise_selection_page.dart';
import 'package:gym_tracker/services/stats_service.dart';
import 'package:gym_tracker/widgets/app_buttons.dart';
import 'package:gym_tracker/widgets/top_toast.dart';
import '../../../models/models.dart';
import '../../enums/enums.dart';
import '../../models/app_settings.dart';
import '../../services/database_service.dart';
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

  // 🆕 Unitatea de masura preferata global (din Settings), incarcata o data.
  late UnitSystem _globalUnit;

  // 🆕 Override temporar, DOAR pentru sesiunea curenta, per exercitiu.
  // Nu se salveaza nicaieri - la iesirea din pagina dispare, revine la preferinta globala.
  final Map<int, UnitSystem> _exerciseUnitOverride = {};

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.routine.title);
    _loadUnitPreference();
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

  void _loadUnitPreference() {
    final Map? rawSettings = DatabaseService.settingsBox.get('appSettings') as Map?;
    final AppSettings settings = rawSettings != null ? AppSettings.fromMap(rawSettings) : const AppSettings();
    _globalUnit = settings.unitSystem;
  }

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

  // Formatare curata: 100.0 -> "100", 45.5 -> "45.5" (fara zecimale inutile).
  String _formatWeight(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(1);
  }

  // Drawer-ul de selectie a tipului de set, deschis la tap pe eticheta setului.
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
          icon: Icons.delete_sweep_outlined, // O iconiță sugestivă de ștergere
          label: 'Delete Set #${setIndex + 1}',
          color: Colors.redAccent, // Culoare roșie pentru a avertiza că este o acțiune distructivă
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

  // Helper unic de lookup - foloseste-l peste tot in loc de exercisesBox.get(...)
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
      endTime: DateTime.now(), // setăm temporar acum ca să funcționeze gettere-le duratei
      routineTitle: _titleController.text.trim(),
      exercises: List.from(_activeExercises),
      status: WorkoutStatus.started,
    );

    final difference = DateTime.now().difference(_sessionStart);
    final hours = difference.inHours;
    final minutes = difference.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = difference.inSeconds.remainder(60).toString().padLeft(2, '0');

    String durationString = hours > 0 ? '${hours.toString().padLeft(2, '0')}:$minutes:$seconds' : '$minutes:$seconds';

    return {
      'durationStr': durationString,
      'durationMin': difference.inMinutes,
      'exercisesCount': _activeExercises.length,
      // 🔧 Volumul e stocat mereu in kg. Pentru afisare, il convertim pe baza
      // unitatii GLOBALE (default din Settings) - nu pe overrides per-exercitiu,
      // acelea sunt doar pentru completarea inputurilor individuale.
      'volume': currentSnapshotLog.totalVolume,
      'volumeStr': '${_formatWeight(_globalUnit.toDisplay(currentSnapshotLog.totalVolume))} ${_globalUnit.label}',
      'setsCount': currentSnapshotLog.completedSetsCount
    };
  }

  LoggedExercise? _getPreviousLogForExercise(int exerciseId) {
    final allLogs = DatabaseService.logsBox.values.map((e) => WorkoutLog.fromMap(e as Map)).toList().reversed;

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
    // Colectăm ID-urile lightweight de la exercițiile deja active
    final List<int> existingIds = _activeExercises.map((e) => e.exerciseId).toList();

    // 💡 SCHIMBARE: Schimbăm tipul generic din <Exercise> în <List<Exercise>>
    final List<Exercise>? selectedExercises = await Navigator.push<List<Exercise>>(
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
            decoration: InputDecoration(
              hintText: 'Workout Title...',
              hintStyle: TextStyle(
                  fontWeight: FontWeight.normal, fontSize: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
              border: InputBorder.none,
              focusedBorder: InputBorder.none,
              enabledBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
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
                    // 🆕 Tap pe "Duration" deschide modala de editare a duratei/start time-ului.
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
                          final fullExercise = _resolveExercise(exercise.exerciseId);
                          final coverImage = fullExercise?.coverImage;

                          final isMissingData = fullExercise == null;
                          final isImageEmpty = coverImage == null || coverImage.isEmpty;

                          final displayName = fullExercise?.name ?? 'Exercițiu necunoscut (ID: ${exercise.exerciseId})';

                          final isBodyWeight = fullExercise?.equipment == Equipment.bodyweight;

                          // 🆕 Unitatea activa pentru acest exercitiu (global sau override local).
                          final unit = _unitFor(exercise.exerciseId);
                          final hasOverride = _exerciseUnitOverride.containsKey(exercise.exerciseId);

                          return Card(
                            key: ValueKey('active_ex_${exercise.exerciseId}_$exIndex'),
                            clipBehavior: Clip.antiAlias,
                            margin: const EdgeInsets.all(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
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
                                        // Titlul înfășurat în InkWell pentru detalii
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
                                                              color: theme.colorScheme.onSurface),
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                      // 🆕 Chip mic care arata cand unitatea
                                                      // e diferita de cea globala (override activ).
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
                                        // Meniul de opțiuni rapid (AppActionsSheet)
                                        IconButton(
                                          icon: Icon(Icons.more_vert, color: theme.colorScheme.onSurfaceVariant),
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
                                                      // Preluăm prima valoare existentă ca punct de pornire, sau 0.0 / 0 dacă lista e goală
                                                      double firstWeight = sets.isNotEmpty ? sets.first.weight : 0.0;
                                                      int firstReps = sets.isNotEmpty ? sets.first.reps : 0;

                                                      // Inserăm setul de warmup direct la indexul 0 (la începutul listei)
                                                      sets.insert(
                                                        0,
                                                        LoggedSet(
                                                          weight: firstWeight,
                                                          reps: firstReps,
                                                          type: SetType.warmup, // Forțăm tipul de warmup
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
                                                // 🆕 Toggle temporar de unitate DOAR pentru
                                                // acest exercitiu, doar daca nu e bodyweight
                                                // (BW nu are input numeric de greutate).
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
                                                        // curatam si eventualul override, ca sa nu ramana orfan
                                                        _exerciseUnitOverride.remove(exercise.exerciseId);
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
                                  Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 12),
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
                                                  mainAxisAlignment: MainAxisAlignment
                                                      .center, // Îl centram frumos pe mijlocul coloanei
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      Icons.fitness_center, // 👈 Gantera ta mică
                                                      size: 12, // Dimensiune potrivită, discretă
                                                      color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                                                    ),
                                                    const SizedBox(width: 4), // Mic spațiu între iconiță și text
                                                    Text(
                                                      unit.label.capitalize(), // Va afișa "Kg" sau "Lbs"
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
                                          // 1. Coloana: Numar Set (Tappable)
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
                                                      set.type != SetType.normal ? set.type.shortLabel : '${setIndex + 1}',
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

                                          // 2. 🆕 Coloana: Previous (Cu Autocomplete la apăsare)
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
                                                          // Copiem datele direct în setul curent din UI
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
                                                      // fontSize: 12,
                                                      fontWeight: FontWeight.w500,
                                                      color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                                                    ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),

                                          // 3. Coloana: Input Greutate (Weight)
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

                                          // 4. Reps
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
                                        ],
                                      ),
                                    );
                                  }),

                                  const SizedBox(height: 10),

                                  // --- ACȚIUNI SET (ADD/REMOVE) ---
                                  Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 12),
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
                                                  style: TextStyle(color: Colors.redAccent)),
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
