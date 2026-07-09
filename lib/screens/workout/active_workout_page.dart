import 'package:flutter/material.dart';
import 'package:gym_tracker/enums/workout_status.dart';
import 'package:gym_tracker/screens/exercise_detail_page.dart';
import '../../../main.dart';
import '../../../models/models.dart';
import '../../enums/enums.dart';

class ActiveWorkoutPage extends StatefulWidget {
  final Routine routine;
  const ActiveWorkoutPage({super.key, required this.routine});

  @override
  State<ActiveWorkoutPage> createState() => _ActiveWorkoutPageState();
}

class _ActiveWorkoutPageState extends State<ActiveWorkoutPage> {
  // ACUM: Folosim direct modelul Dart în loc de Map raw
  final List<LoggedExercise> _activeExercises = [];
  dynamic _currentLogKey;
  late DateTime _sessionStart;

  late TextEditingController _titleController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.routine.title);
    _loadOrInitializeWorkout();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
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

      // FĂRĂ JSON DECODE: Hive ne dă direct lista de obiecte mapate în WorkoutLog
      setState(() {
        _activeExercises.addAll(activeLog.exercises);
      });
    } else {
      _sessionStart = DateTime.now();
      for (var exercise in widget.routine.exercises) {
        _activeExercises.add(
          LoggedExercise(
            name: exercise.name,
            sets: [const LoggedSet(weight: 0.0, reps: 0)],
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

  // Folosește direct getter-ul optimizat din WorkoutLog sau calculează pe loc curat
  Map<String, dynamic> _calculateCurrentStats() {
    double totalVolume = 0;
    int totalSets = 0;

    for (var ex in _activeExercises) {
      for (var set in ex.sets) {
        if (set.reps > 0) {
          totalVolume += set.weight * set.reps;
          totalSets++;
        }
      }
    }

    final currentDuration = DateTime.now().difference(_sessionStart).inMinutes;

    return {
      'duration': currentDuration,
      'volume': totalVolume,
      'setsCount': totalSets,
      'exercisesCount': _activeExercises.length,
    };
  }

  Future<void> _showFinishConfirmationDialog() async {
    final stats = _calculateCurrentStats();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Finish Workout? 🏆',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'Are you sure you want to complete this workout session? Here is your summary:'),
            const SizedBox(height: 16),
            Card(
              color: Colors.blueAccent.withOpacity(0.05),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  children: [
                    _buildStatRow(
                        Icons.timer, 'Duration:', '${stats['duration']} min'),
                    const Divider(),
                    _buildStatRow(Icons.fitness_center, 'Total Volume:',
                        '${stats['volume'].toStringAsFixed(0)} kg'),
                    const Divider(),
                    _buildStatRow(Icons.format_list_numbered, 'Completed Sets:',
                        '${stats['setsCount']}'),
                    const Divider(),
                    _buildStatRow(Icons.format_list_bulleted, 'Exercises:',
                        '${stats['exercisesCount']}'),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Resume', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save Workout',
                style: TextStyle(color: Colors.white)),
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
          Icon(icon, size: 18, color: Colors.blueGrey),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.blueAccent)),
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

  void _addNewExerciseDynamically() {
    final allExercises =
        exercisesBox.values.map((e) => Exercise.fromMap(e as Map)).toList();

    String modalSearchQuery = '';
    MuscleGroup? modalSelectedMuscle;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            final filteredExercises = allExercises.where((ex) {
              final matchesSearch = ex.name
                  .toLowerCase()
                  .contains(modalSearchQuery.toLowerCase());
              final matchesMuscle = modalSelectedMuscle == null ||
                  ex.muscleGroups.contains(modalSelectedMuscle);
              return matchesSearch && matchesMuscle;
            }).toList();

            return Container(
              padding: EdgeInsets.only(
                top: 12,
                left: 16,
                right: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Add Alternative Exercise',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Search exercise...',
                      prefixIcon: const Icon(Icons.search),
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      suffixIcon: modalSearchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () =>
                                  setModalState(() => modalSearchQuery = ''),
                            )
                          : null,
                    ),
                    onChanged: (value) =>
                        setModalState(() => modalSearchQuery = value),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 38,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: MuscleGroup.values.map((muscle) {
                        final isSelected = modalSelectedMuscle == muscle;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6.0),
                          child: FilterChip(
                            label: Text(muscle.name.toUpperCase(),
                                style: const TextStyle(fontSize: 11)),
                            selected: isSelected,
                            selectedColor: Colors.blueAccent.withOpacity(0.2),
                            checkmarkColor: Colors.blueAccent,
                            onSelected: (bool selected) {
                              setModalState(() {
                                modalSelectedMuscle = selected ? muscle : null;
                              });
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Divider(),
                  Expanded(
                    child: filteredExercises.isEmpty
                        ? const Center(
                            child: Text('No exercises found.',
                                style: TextStyle(color: Colors.grey)))
                        : ListView.builder(
                            itemCount: filteredExercises.length,
                            itemBuilder: (context, index) {
                              final exercise = filteredExercises[index];
                              final primaryMuscle =
                                  exercise.muscleGroups.isNotEmpty
                                      ? exercise.muscleGroups.first.name
                                      : 'core';
                              final infoText =
                                  '${primaryMuscle.toUpperCase()} • ${exercise.equipment.name.toUpperCase()}';

                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 2),
                                title: Text(exercise.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w500)),
                                subtitle: Text(infoText,
                                    style: const TextStyle(
                                        fontSize: 11, color: Colors.blueGrey)),
                                trailing: const Icon(Icons.add_circle_outline,
                                    color: Colors.blueAccent),
                                onTap: () {
                                  setState(() {
                                    // Utilizăm noul constructor tipizat
                                    _activeExercises.add(
                                      LoggedExercise(
                                        name: exercise.name,
                                        sets: [
                                          const LoggedSet(weight: 0.0, reps: 0)
                                        ],
                                      ),
                                    );
                                  });
                                  _updateLiveProgress();
                                  Navigator.pop(context);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
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
          title: TextField(
            controller: _titleController,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            decoration: const InputDecoration(
              hintText: 'Workout Title...',
              border: InputBorder.none,
              suffixIcon: Icon(Icons.edit, size: 16, color: Colors.grey),
            ),
            onChanged: (value) => _updateLiveProgress(),
          ),
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.redAccent),
            onPressed: () => Navigator.maybePop(context),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.check, color: Colors.green, size: 30),
              onPressed: _showFinishConfirmationDialog,
            )
          ],
        ),
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => FocusScope.of(context).unfocus(),
          child: ReorderableListView.builder(
            itemCount: _activeExercises.length,
            onReorderItem: (oldIndex, newIndex) {
              setState(() {
                final item = _activeExercises.removeAt(oldIndex);
                _activeExercises.insert(newIndex, item);
              });
              _updateLiveProgress();
            },
            itemBuilder: (context, exIndex) {
              final exercise = _activeExercises[exIndex];
              final sets = exercise.sets;

              return Card(
                key: ValueKey('active_ex_${exercise.name}_$exIndex'),
                margin: const EdgeInsets.all(12),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Icon(Icons.drag_handle, color: Colors.blueGrey),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(exercise.name,
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold)),
                          ),
                          IconButton(
                            icon: const Icon(Icons.info_outline,
                                color: Colors.blueAccent),
                            onPressed: () {
                              final rawData = exercisesBox.get(exercise.name);
                              if (rawData != null) {
                                final fullExercise =
                                    Exercise.fromMap(rawData as Map);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ExerciseDetailPage(
                                        exercise: fullExercise),
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Exercise details not found ⚠️')),
                                );
                              }
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete,
                                color: Colors.redAccent),
                            onPressed: () {
                              setState(() {
                                _activeExercises.removeAt(exIndex);
                              });
                              _updateLiveProgress();
                            },
                          )
                        ],
                      ),
                      const Divider(),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          children: [
                            SizedBox(
                                width: 50,
                                child: Text('Set',
                                    style: TextStyle(color: Colors.grey))),
                            Expanded(
                                child: Text('Weight (kg)',
                                    style: TextStyle(color: Colors.grey),
                                    textAlign: TextAlign.center)),
                            Expanded(
                                child: Text('Reps',
                                    style: TextStyle(color: Colors.grey),
                                    textAlign: TextAlign.center)),
                          ],
                        ),
                      ),
                      ...sets.asMap().entries.map((entry) {
                        int setIndex = entry.key;
                        final set = entry.value;

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            children: [
                              SizedBox(
                                  width: 50,
                                  child: Text('${setIndex + 1}',
                                      style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold))),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8.0),
                                  child: TextFormField(
                                    initialValue: set.weight == 0.0
                                        ? ''
                                        : set.weight.toString(),
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    decoration: const InputDecoration(
                                        border: OutlineInputBorder(),
                                        contentPadding: EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        hintText: '0'),
                                    onChanged: (value) {
                                      // Pentru că LoggedSet are proprietăți finale, înlocuim setul în listă
                                      final newWeight =
                                          double.tryParse(value) ?? 0.0;
                                      exercise.sets[setIndex] = LoggedSet(
                                          weight: newWeight, reps: set.reps);
                                      _updateLiveProgress();
                                    },
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8.0),
                                  child: TextFormField(
                                    initialValue: set.reps == 0
                                        ? ''
                                        : set.reps.toString(),
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                        border: OutlineInputBorder(),
                                        contentPadding: EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        hintText: '0'),
                                    onChanged: (value) {
                                      final newReps = int.tryParse(value) ?? 0;
                                      exercise.sets[setIndex] = LoggedSet(
                                          weight: set.weight, reps: newReps);
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                double lastWeight =
                                    sets.isNotEmpty ? sets.last.weight : 0.0;
                                int lastReps =
                                    sets.isNotEmpty ? sets.last.reps : 0;
                                sets.add(LoggedSet(
                                    weight: lastWeight, reps: lastReps));
                              });
                              _updateLiveProgress();
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Add Set'),
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
                      )
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
              onPressed: _addNewExerciseDynamically,
              icon: const Icon(Icons.fitness_center),
              label: const Text('Add Alternative Exercise'),
            ),
          ),
        ),
      ),
    );
  }
}
