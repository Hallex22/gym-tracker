import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gym_tracker/enums/workout_status.dart';
import 'package:gym_tracker/screens/routines/routine_detail_page.dart';
import 'package:gym_tracker/screens/routines/routine_form_page.dart';
import 'package:gym_tracker/services/stats_service.dart';
import 'package:gym_tracker/widgets/top_toast.dart';
import '../models/models.dart';
import '../widgets/app_actions_sheet.dart';
import 'workout/active_workout_page.dart';
import 'package:gym_tracker/widgets/app_buttons.dart';
import '../services/database_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  List<RoutineFolder> _folders = [];
  List<MapEntry<dynamic, Routine>> _unassignedRoutines = [];
  Map<dynamic, Routine> _allRoutinesMap = {};

  // 💡 State pentru Expand/Collapse: { "id_folder": true/false }
  final Map<String, bool> _expandedFolders = {};

  WorkoutLog? _activeWorkout;
  Timer? _workoutTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _workoutTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadData();
    }
  }

  void _startTimer() {
    _workoutTimer?.cancel();
    if (_activeWorkout != null &&
        _activeWorkout!.status == WorkoutStatus.started) {
      _workoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) setState(() {});
      });
    }
  }

  void _showDiscardWorkoutDialog(dynamic logKey) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Active Workout ⏳'),
        content: const Text(
            'What would you like to do with the current workout session?'),
        actions: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  alignment: Alignment.centerLeft,
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                ),
                icon: const Icon(Icons.delete_forever_outlined),
                label: const Text('Discard Workout Session'),
                onPressed: () async {
                  await DatabaseService.logsBox.delete(logKey);
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  _loadData();
                  TopToast.show(context, 'Workout session discarded.',
                      type: ToastType.info);
                },
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.primary,
                  alignment: Alignment.centerLeft,
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                ),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Keep Running in Background'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _loadData() {
    final Map<dynamic, Routine> allRoutines = {};
    DatabaseService.routinesBox.toMap().forEach((key, value) {
      allRoutines[key] = Routine.fromMap(value as Map);
    });

    final List<RoutineFolder> folders =
        DatabaseService.routineFoldersBox.toMap().entries.map((entry) {
      return RoutineFolder.fromMap(entry.value as Map);
    }).toList();

    final List<dynamic> assignedKeys = [];
    for (var folder in folders) {
      assignedKeys.addAll(folder.routineKeys);
      // Inițializăm starea de expand implicit ca 'true' dacă folderul nu e deja în map
      _expandedFolders.putIfAbsent(folder.id, () => true);
    }

    final List<MapEntry<dynamic, Routine>> unassigned = [];
    allRoutines.forEach((key, routine) {
      if (!assignedKeys.contains(key)) {
        unassigned.add(MapEntry(key, routine));
      }
    });

    WorkoutLog? active;
    for (var value in DatabaseService.logsBox.values) {
      final log = WorkoutLog.fromMap(value as Map);
      if (log.status == WorkoutStatus.started) {
        active = log;
        break;
      }
    }

    setState(() {
      _allRoutinesMap = allRoutines;
      _folders = folders;
      _unassignedRoutines = unassigned;
      _activeWorkout = active;
    });

    _startTimer();
  }

  // --- CREARE FOLDER ---
  void _showCreateFolderDialog() {
    final TextEditingController folderNameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Folder 📁'),
        content: TextField(
          controller: folderNameController,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Folder name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = folderNameController.text.trim();
              if (name.isNotEmpty) {
                final newFolder = RoutineFolder(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: name,
                  createdAt: DateTime.now(),
                );
                await DatabaseService.routineFoldersBox
                    .put(newFolder.id, newFolder.toMap());
                if (!context.mounted) return;
                Navigator.pop(context);
                _loadData();
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  // --- 💡 ȘTERGERE FOLDER (EDGE CASE REPARAT: Rutinele nu mor, devin unassigned) ---
  void _showDeleteFolderDialog(RoutineFolder folder) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "${folder.name}"? 🚨'),
        content: const Text(
            'Are you sure? The routines inside this folder will NOT be deleted, they will be moved back to the general area.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              await DatabaseService.routineFoldersBox.delete(folder.id);
              if (!context.mounted) return;
              Navigator.pop(context);
              _loadData();
              TopToast.show(context, 'Folder deleted.',
                  type: ToastType.success);
            },
            child: const Text('Delete Folder',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --- 💡 MODAL MUTARE RUTINĂ ÎN FOLDER (Schimbare Folder) ---
  void _showChangeFolderDialog(dynamic routineKey) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Move to Folder 📁'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                // Opțiunea de a scoate rutina din orice folder (Mutare la General)
                ListTile(
                  leading:
                      const Icon(Icons.grid_view_rounded, color: Colors.grey),
                  title: const Text('General / Unassigned'),
                  onTap: () async {
                    await _moveRoutineToFolder(routineKey, null);
                    if (!context.mounted) return;
                    Navigator.pop(context);
                  },
                ),
                const Divider(),
                ..._folders.map((folder) {
                  final bool alreadyInside =
                      folder.routineKeys.contains(routineKey);
                  return ListTile(
                    leading: Icon(Icons.folder,
                        color: alreadyInside
                            ? Colors.green
                            : Theme.of(context).colorScheme.primary),
                    title: Text(folder.name),
                    trailing: alreadyInside
                        ? const Icon(Icons.check, color: Colors.green)
                        : null,
                    onTap: alreadyInside
                        ? null
                        : () async {
                            await _moveRoutineToFolder(routineKey, folder.id);
                            if (!context.mounted) return;
                            Navigator.pop(context);
                          },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  // ATOMIC MOVE LOGIC (Garantează că o rutină stă într-un singur folder odată)
  Future<void> _moveRoutineToFolder(
      dynamic routineKey, String? targetFolderId) async {
    // 1. O ștergem din absolut orice folder o mai fi fost înainte
    for (var f in _folders) {
      if (f.routineKeys.contains(routineKey)) {
        f.routineKeys.remove(routineKey);
        await DatabaseService.routineFoldersBox.put(f.id, f.toMap());
      }
    }

    // 2. O adăugăm în folderul destinație, dacă s-a ales unul
    if (targetFolderId != null) {
      final targetFolder = RoutineFolder.fromMap(
          DatabaseService.routineFoldersBox.get(targetFolderId) as Map);
      targetFolder.routineKeys.add(routineKey);
      await DatabaseService.routineFoldersBox
          .put(targetFolderId, targetFolder.toMap());
    }

    _loadData();
  }

  // --- ACTIONS DRAWER (ADĂUGAT OPȚIUNEA "CHANGE FOLDER") ---
  void _showRoutineOptionsSheet(
      BuildContext context, Routine routine, dynamic routineKey) {
    AppActionsSheet.show(
      context: context,
      title: routine.title,
      actions: [
        SheetActionItem(
          icon: Icons.visibility_outlined,
          label: 'View Routine',
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => RoutineDetailPage(
                      routine: routine, routineKey: routineKey)),
            );
            _loadData();
          },
        ),
        SheetActionItem(
          icon: Icons.edit_outlined,
          label: 'Edit Routine',
          color: Colors.orangeAccent,
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => RoutineFormPage(
                      routine: routine, routineKey: routineKey)),
            );
            _loadData();
          },
        ),
        // 💡 OPTIUNEA NOUĂ: Change Folder
        SheetActionItem(
          icon: Icons.folder_open_outlined,
          label: 'Change Folder',
          onPressed: () {
            _showChangeFolderDialog(routineKey);
          },
        ),
        SheetActionItem(
          icon: Icons.share_outlined,
          label: 'Share Routine (Copy Code)',
          onPressed: () async {
            final shareCode = routine.toShareCode();
            await Clipboard.setData(ClipboardData(text: shareCode));
            if (!context.mounted) return;
            TopToast.show(
                context, '"${routine.title}" code copied successfully! 🦾',
                type: ToastType.success);
          },
        ),
        SheetActionItem(
          icon: Icons.delete_outline,
          label: 'Delete Routine',
          color: Colors.redAccent,
          onPressed: () {
            _showDeleteConfirmationDialog(context, routineKey, routine.title);
          },
        ),
      ],
    );
  }

  // 💡 EDGE CASE REPARAT: Când se șterge rutina, o curățăm și din folderul ei!
  void _showDeleteConfirmationDialog(
      BuildContext context, dynamic routineKey, String title) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Routine? 🚨'),
        content: Text(
            'Are you sure you want to delete "$title"? This will not affect your workout history.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              // Curățăm din foldere mai întâi
              for (var folder in _folders) {
                if (folder.routineKeys.contains(routineKey)) {
                  folder.routineKeys.remove(routineKey);
                  await DatabaseService.routineFoldersBox
                      .put(folder.id, folder.toMap());
                }
              }
              // Ștergem rutina propriu-zisă
              await DatabaseService.routinesBox.delete(routineKey);
              if (!context.mounted) return;
              Navigator.pop(context);
              _loadData();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // RENDER CARD RUTINĂ
  Widget _buildRoutineCard(Routine routine, dynamic routineKey) {
    final String exercisesPreview = routine.exercises.isEmpty
        ? "No exercises added yet"
        : routine.exercises.map((e) {
            final rawExercise = DatabaseService.exercisesBox.get(e.exerciseId);
            String name = 'Unknown';
            if (rawExercise != null) {
              name = rawExercise is Map
                  ? (rawExercise['name'] ?? 'Unknown')
                  : rawExercise.name;
            }
            return "$name (${e.targetSetsCount}x)";
          }).join(', ');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => RoutineDetailPage(
                    routine: routine, routineKey: routineKey)),
          );
          _loadData();
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                      child: Text(routine.title,
                          style: Theme.of(context).textTheme.titleLarge)),
                  IconButton(
                    icon: const Icon(Icons.more_horiz),
                    onPressed: () =>
                        _showRoutineOptionsSheet(context, routine, routineKey),
                  ),
                ],
              ),
              Text(exercisesPreview,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 16),
              AppGhostButton(
                label: 'Start Workout',
                icon: Icons.play_arrow,
                onPressed: () => _tryStartWorkout(routine),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // METODE ACTIVE WORKOUT (Păstrate intacte din varianta ta)
  void _navigateToActiveWorkout(Routine routine) async {
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => ActiveWorkoutPage(routine: routine)));
    _loadData();
  }

  void _tryStartWorkout(Routine routine) {
    if (_activeWorkout != null) {
      _showActiveWorkoutAlert();
    } else {
      _navigateToActiveWorkout(routine);
    }
  }

  void _showActiveWorkoutAlert() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Workout in Progress ⚠️'),
        content: const Text(
            'You already have an active workout session. Please finish or cancel the current session before starting a new one.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          )
        ],
      ),
    );
  }

  void _startEmptyWorkout() {
    if (_activeWorkout != null) {
      _showActiveWorkoutAlert();
    } else {
      _navigateToActiveWorkout(Routine(
          title: 'Empty Workout',
          description: 'Custom session',
          exercises: []));
    }
  }

  String _getWorkoutDurationString(DateTime startTime) {
    final difference = DateTime.now().difference(startTime);
    final hours = difference.inHours;
    final minutes =
        difference.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds =
        difference.inSeconds.remainder(60).toString().padLeft(2, '0');

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  void _showImportRoutineSheet() {
    final TextEditingController codeController = TextEditingController();
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color:
                            theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    'Import Routine 📥',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Paste the code received from your friend to clone their routine structure.',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: codeController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Paste code here...',
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.all(12),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.assignment_returned_outlined),
                        onPressed: () async {
                          final data =
                              await Clipboard.getData(Clipboard.kTextPlain);
                          if (data?.text != null) {
                            codeController.text = data!.text!;
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text('Cancel',
                              style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppFilledButton(
                          label: 'Import',
                          onPressed: () async {
                            final code = codeController.text;
                            final importedRoutine = Routine.fromShareCode(code);

                            if (importedRoutine != null) {
                              await DatabaseService.routinesBox
                                  .add(importedRoutine.toMap());
                              if (!context.mounted) return;
                              Navigator.pop(context);
                              _loadData();
                              TopToast.show(context,
                                  'Successfully imported "${importedRoutine.title}"! 🏋️‍♂️',
                                  type: ToastType.success);
                            } else {
                              TopToast.show(context, 'Invalid share code. Please try again!', type: ToastType.error);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final int streakWeeks = StatsService.calculateWeeklyStreak();
    final bool isStreakActive = StatsService.isStreakActiveThisWeek();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'GymTracker',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
        actions: [
          if (streakWeeks > 0) ...[
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Tooltip(
                message: isStreakActive
                    ? 'Streak active for this week! 🔥'
                    : 'Log a workout to keep your streak alive! ⏳',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons
                          .local_fire_department, // Sau Icons.local_fire_department
                      size: 22,
                      color: isStreakActive
                          ? theme.colorScheme.secondary
                          // .shade700 // Portocaliu aprins când e activ
                          : theme.colorScheme.onSurface
                              .withOpacity(0.2), // Gri șters când e inactiv
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$streakWeeks',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isStreakActive
                            ? theme.colorScheme.onSurface
                            : theme.colorScheme.onSurface.withOpacity(0.4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. active_workout
              if (_activeWorkout != null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 6.0),
                  child: Card(
                    color: theme.colorScheme.secondary.withOpacity(0.2),
                    shape: RoundedRectangleBorder(
                        side: BorderSide(
                            color:
                                theme.colorScheme.secondary.withOpacity(0.7)),
                        borderRadius: BorderRadius.circular(10)),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => _navigateToActiveWorkout(Routine(
                          title: _activeWorkout!.routineTitle, exercises: [])),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14.0, vertical: 12.0),
                        child: Row(
                          children: [
                            Icon(Icons.lens,
                                color: theme.colorScheme.secondary
                                    .withOpacity(0.7),
                                size: 10),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      'Workout (${_getWorkoutDurationString(_activeWorkout!.startTime)})',
                                      style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.secondary
                                              .withOpacity(0.7))),
                                  const SizedBox(height: 2),
                                  Text(_activeWorkout!.routineTitle,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 20),
                              onPressed: () {
                                try {
                                  dynamic activeKey;

                                  for (var key
                                      in DatabaseService.logsBox.keys) {
                                    final val =
                                        DatabaseService.logsBox.get(key);
                                    if (val is Map) {
                                      final statusVal =
                                          val['status']?.toString();
                                      if (statusVal == 'started' ||
                                          statusVal ==
                                              'WorkoutStatus.started' ||
                                          statusVal ==
                                              WorkoutStatus.started.name) {
                                        activeKey = key;
                                        break;
                                      }
                                    }
                                  }

                                  if (activeKey != null) {
                                    print(
                                        "🚀 [X Button] Trimit cheia $activeKey către _showDiscardWorkoutDialog...");
                                    _showDiscardWorkoutDialog(activeKey);
                                  } else {
                                    print(
                                        "⚠️ [X Button] Nu am găsit niciun status 'started'. Încerc fallback pe ultima cheie.");
                                    if (DatabaseService.logsBox.isNotEmpty) {
                                      final lastKey =
                                          DatabaseService.logsBox.keys.last;
                                      print(
                                          "🚀 [X Button] Trimit ultima cheie ($lastKey) ca fallback...");
                                      _showDiscardWorkoutDialog(lastKey);
                                    } else {
                                      print(
                                          "❌ [X Button] logsBox este complet gol în Hive!");
                                    }
                                  }
                                } catch (e) {
                                  print("💥 [X Button] Crash în buclă: $e");
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],

              // 2. BUTTON START EMPTY WORKOUT
              if (_activeWorkout == null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  child: AppOutlinedButton(
                      label: 'Start Empty Workout',
                      icon: Icons.add,
                      onPressed: _startEmptyWorkout),
                ),
              ],

              // 3. ROUTINES LABEL & ACTION ROW
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Routines',
                        style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 13,
                            fontWeight: FontWeight.bold)),
                    IconButton(
                        icon: const Icon(Icons.create_new_folder_outlined),
                        tooltip: 'Create New Folder',
                        onPressed: _showCreateFolderDialog),
                  ],
                ),
              ),

              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: BorderSide(
                                color:
                                    theme.colorScheme.primary.withOpacity(0.5)),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10))),
                        icon: Icon(Icons.playlist_add,
                            color: theme.colorScheme.primary),
                        label: Text('New Routine',
                            style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold)),
                        onPressed: () async {
                          await Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) =>
                                      const RoutineFormPage()));
                          _loadData();
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: BorderSide(
                                color: theme.colorScheme.onSurfaceVariant
                                    .withOpacity(0.3)),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10))),
                        icon: Icon(Icons.folder_zip_outlined,
                            color: theme.colorScheme.onSurfaceVariant),
                        label: Text('Import',
                            style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600)),
                        onPressed: _showImportRoutineSheet,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 4. RANDĂRI LISTĂ BAZATĂ PE FOLDERE
              if (_folders.isEmpty && _unassignedRoutines.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Center(
                      child: Text(
                          'No routines found. Create your first one above!',
                          style: theme.textTheme.bodyMedium)),
                ),

              // A. FOLDERE CU DESIGN INTERACTIV (COLLAPSE / EXPAND / DELETE)
              ..._folders.map((folder) {
                final bool isExpanded = _expandedFolders[folder.id] ?? true;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 💡 ÎNTREGUL RÂND ESTE INTERACTIV ACUM (InkWell + Chevron controlat)
                    InkWell(
                      onTap: () {
                        setState(() {
                          _expandedFolders[folder.id] = !isExpanded;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 10.0),
                        child: Row(
                          children: [
                            // Chevron cu animație fină de rotație automată în funcție de stare
                            AnimatedRotation(
                              duration: const Duration(milliseconds: 200),
                              turns: isExpanded
                                  ? 0.25
                                  : 0.0, // 90 de grade rotație când e deschis
                              child: const Icon(Icons.chevron_right,
                                  size: 20, color: Colors.grey),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.folder,
                                size: 20, color: theme.colorScheme.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                folder.name,
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onSurface),
                              ),
                            ),
                            // Buton discret de ștergere folder în capătul rândului
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  size: 18, color: Colors.grey),
                              onPressed: () => _showDeleteFolderDialog(folder),
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Condiție pentru randarea rutinelor dacă folderul este Expanded
                    if (isExpanded) ...[
                      if (folder.routineKeys.isEmpty)
                        const Padding(
                          padding:
                              EdgeInsets.only(left: 44.0, bottom: 12.0, top: 4),
                          child: Text('Empty folder',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                  fontStyle: FontStyle.italic)),
                        )
                      else
                        ...folder.routineKeys.map((key) {
                          final routine = _allRoutinesMap[key];
                          if (routine == null) return const SizedBox.shrink();
                          return _buildRoutineCard(routine, key);
                        }),
                    ],
                  ],
                );
              }),

              // B. SECȚIUNEA GENERALĂ (UNASSIGNED)
              if (_unassignedRoutines.isNotEmpty) ...[
                Padding(
                  padding: EdgeInsets.only(left: 20.0, top: 20.0, bottom: 6.0),
                  child: Row(
                    children: [
                      Icon(Icons.grid_view_rounded,
                          size: 16,
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant),
                      SizedBox(width: 8),
                      Text('General Routines',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant)),
                    ],
                  ),
                ),
                ..._unassignedRoutines
                    .map((entry) => _buildRoutineCard(entry.value, entry.key)),
              ],

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
