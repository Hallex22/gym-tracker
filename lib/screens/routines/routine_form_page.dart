import 'package:flutter/material.dart';
import 'package:gym_tracker/widgets/top_toast.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';
import '../../widgets/app_buttons.dart'; // Importul butoanelor reutilizabile
import '../exercises/exercise_selection_page.dart';

class RoutineFormPage extends StatefulWidget {
  final Routine? routine; // Dacă e null -> Creare. Dacă are valoare -> Editare.
  final dynamic routineKey; // Opțional, doar pentru editare.

  const RoutineFormPage({super.key, this.routine, this.routineKey});

  @override
  State<RoutineFormPage> createState() => _RoutineFormPageState();
}

class _RoutineFormPageState extends State<RoutineFormPage> {
  final _formKey = GlobalKey<FormState>();

  late String _title;
  late String _description;

  // 💡 SCHIMBAT: Acum lucrăm cu RoutineExercise în loc de Exercise
  final List<RoutineExercise> _selectedRoutineExercises = [];

  bool get _isEditMode => widget.routine != null;

  @override
  void initState() {
    super.initState();
    _title = widget.routine?.title ?? '';
    _description = widget.routine?.description ?? '';
    if (widget.routine != null) {
      // Copiem exercițiile existente (creăm instanțe noi pentru a nu muta direct referințele din Hive)
      for (var ex in widget.routine!.exercises) {
        _selectedRoutineExercises.add(RoutineExercise(
          exerciseId: ex.exerciseId,
          targetSetsCount: ex.targetSetsCount,
        ));
      }
    }
  }

  // --- DIALOG CONFIRMARE SCOATERE EXERCIȚIU DIN LISTĂ ---
  Future<void> _confirmRemoveExercise(
      RoutineExercise routineEx, String exerciseName) async {
    final bool confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Remove Exercise? 📝'),
            content: Text(
                'Are you sure you want to remove "$exerciseName" from this routine?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Remove',
                    style: TextStyle(color: Colors.redAccent)),
              ),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      setState(() {
        _selectedRoutineExercises
            .removeWhere((e) => e.exerciseId == routineEx.exerciseId);
      });
    }
  }

  Future<void> _saveRoutine() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedRoutineExercises.isEmpty) {
      TopToast.show(context, 'Please select at least one exercise!',
          type: ToastType.warning);
      return;
    }

    _formKey.currentState!.save();

    // Construim obiectul de tip Routine cu noua structură de List<RoutineExercise>
    final routineData = Routine(
      title: _title,
      description: _description.isEmpty ? null : _description,
      exercises: _selectedRoutineExercises,
    );

    if (_isEditMode) {
      await DatabaseService.routinesBox
          .put(widget.routineKey, routineData.toMap());
    } else {
      await DatabaseService.routinesBox.add(routineData.toMap());
    }

    if (!mounted) return;
    Navigator.pop(context);

    TopToast.show(
        context,
        _isEditMode
            ? 'Routine updated successfully!'
            : 'Routine created successfully!',
        type: ToastType.success);
  }

  Future<void> _deleteRoutine() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Routine? 🗑️'),
        content: const Text(
            'Are you sure you want to delete this routine permanently?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child:
                const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DatabaseService.routinesBox.delete(widget.routineKey);
      if (!mounted) return;
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final inputDecorationTheme = InputDecoration(
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide:
            BorderSide(color: theme.colorScheme.primary.withOpacity(0.2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Routine' : 'Create Routine'),
        actions: [
          if (_isEditMode)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.redAccent),
              onPressed: _deleteRoutine,
            ),
          IconButton(
            icon: Icon(Icons.save, color: theme.colorScheme.primary, size: 28),
            onPressed: _saveRoutine,
          )
        ],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // --- SECȚIUNEA INTRODUCERE DATE ---
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    TextFormField(
                      initialValue: _title,
                      decoration: inputDecorationTheme.copyWith(
                          labelText: 'Routine Title'),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Title is required'
                              : null,
                      onSaved: (value) => _title = value!.trim(),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: _description,
                      decoration: inputDecorationTheme.copyWith(
                          labelText: 'Description / Notes (Optional)'),
                      onSaved: (value) => _description = value ?? '',
                    ),
                  ],
                ),
              ),

              // --- STRUCTURA RUTINEI (AFIȘARE DINAMICĂ CU NUMĂR DE SETURI) ---
              if (_selectedRoutineExercises.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 4.0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Routine Structure (Hold & Drag to reorder):',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: ReorderableListView.builder(
                      itemCount: _selectedRoutineExercises.length,
                      // 🔧 FIX: parametrul corect e `onReorder`, nu `onReorderItem`
                      // (altfel nu compilează / crapă la reordonare).
                      onReorder: (oldIndex, newIndex) {
                        setState(() {
                          if (newIndex > oldIndex) newIndex -= 1;
                          final item =
                              _selectedRoutineExercises.removeAt(oldIndex);
                          _selectedRoutineExercises.insert(newIndex, item);
                        });
                      },
                      itemBuilder: (context, index) {
                        final routineEx = _selectedRoutineExercises[index];

                        // 💡 Obținem datele complete ale exercițiului global din Hive pentru UI
                        final rawEx = DatabaseService.exercisesBox
                            .get(routineEx.exerciseId);

                        String exerciseName = 'Unknown Exercise';
                        String extraInfo = 'CORE • BODYWEIGHT';

                        if (rawEx != null) {
                          final exInstance = rawEx is Map
                              ? Exercise.fromMap(rawEx)
                              : rawEx as Exercise;
                          exerciseName = exInstance.name;
                          final primaryMuscle =
                              exInstance.primaryMuscles.isNotEmpty
                                  ? exInstance.primaryMuscles.first.group
                                  : null;
                          final muscleName = primaryMuscle != null
                              ? primaryMuscle.name.toUpperCase()
                              : 'CORE';
                          extraInfo =
                              '$muscleName • ${exInstance.equipment.name.toUpperCase()}';
                        }

                        // 🔧 REFACTOR LAYOUT: in loc de un singur ListTile care inghesuia
                        // totul pe un rand (drag handle + titlu + subtitlu + counter + X),
                        // acum avem 2 randuri explicite:
                        //   Rand 1: drag handle + titlu ..................... X (dreapta cardului)
                        //   Rand 2: muschi/echipament ......... -  3x  +
                        return Card(
                          key: ValueKey(
                              'selected_routine_ex_${routineEx.exerciseId}_$index'),
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          elevation: 0,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // --- Rand 1: drag handle + titlu + buton X ---
                                Row(
                                  children: [
                                    Icon(Icons.drag_handle,
                                        color: theme.colorScheme.primary),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        exerciseName,
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: theme.colorScheme.onSurface),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.close,
                                          color: Colors.redAccent, size: 20),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () => _confirmRemoveExercise(
                                          routineEx, exerciseName),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                // --- Rand 2: muschi/echipament + contor seturi ---
                                Row(
                                  children: [
                                    // ofsetam textul cat sa se alinieze sub titlu, nu sub drag handle
                                    const SizedBox(width: 34),
                                    Expanded(
                                      child: Text(
                                        extraInfo,
                                        style: TextStyle(
                                            fontSize: 10,
                                            color: theme
                                                .colorScheme.onSurfaceVariant),
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.remove_circle_outline,
                                          size: 18,
                                          color: theme
                                              .colorScheme.onSurfaceVariant),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () {
                                        if (routineEx.targetSetsCount > 1) {
                                          setState(() {
                                            routineEx.targetSetsCount--;
                                          });
                                        }
                                      },
                                    ),
                                    Container(
                                      constraints:
                                          const BoxConstraints(minWidth: 32),
                                      alignment: Alignment.center,
                                      child: Text(
                                        '${routineEx.targetSetsCount}x',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: theme.colorScheme.primary,
                                            fontSize: 12),
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.add_circle_outline,
                                          size: 18,
                                          color: theme.colorScheme.primary),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () {
                                        setState(() {
                                          routineEx.targetSetsCount++;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ] else ...[
                Expanded(
                  child: Center(
                    child: Text(
                      'No exercises added yet.\nTap below to start building! 🛠️',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 15),
                    ),
                  ),
                ),
              ],

              // --- BUTONUL DE ADĂUGARE EXERCIȚII ---
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: AppOutlinedButton(
                    label: 'Add Exercises',
                    icon: Icons.add,
                    onPressed: () async {
                      // Pasăm ID-urile deja selectate pentru a le marca/bloca în ecranul următor
                      final List<int> currentActiveIds =
                          _selectedRoutineExercises
                              .map((e) => e.exerciseId)
                              .toList();

                      final List<Exercise>? result =
                          await Navigator.push<List<Exercise>>(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ExerciseSelectionPage(
                            existingExercisesIds: currentActiveIds,
                          ),
                        ),
                      );

                      // Când primim înapoi lista de obiecte Exercise, le convertim în structuri RoutineExercise
                      if (result != null && result.isNotEmpty) {
                        setState(() {
                          for (var newEx in result) {
                            _selectedRoutineExercises.add(RoutineExercise(
                              exerciseId: newEx.id,
                              targetSetsCount:
                                  3, // Încep direct cu default de 3 seturi
                            ));
                          }
                        });
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
