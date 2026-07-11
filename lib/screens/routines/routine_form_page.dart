import 'package:flutter/material.dart';
import '../../enums/enums.dart';
import '../../main.dart'; // Pentru accesul la routinesBox
import '../../models/models.dart';
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
  final List<Exercise> _selectedExercises = [];

  bool get _isEditMode => widget.routine != null;

  @override
  void initState() {
    super.initState();
    _title = widget.routine?.title ?? '';
    _description = widget.routine?.description ?? '';
    if (widget.routine != null) {
      _selectedExercises.addAll(widget.routine!.exercises);
    }
  }

  // --- DIALOG CONFIRMARE SCOATERE EXERCIȚIU DIN LISTĂ ---
  Future<void> _confirmRemoveExercise(Exercise exercise) async {
    final bool confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Remove Exercise? 📝'),
            content: Text(
                'Are you sure you want to remove "${exercise.name}" from this routine?'),
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
        _selectedExercises.removeWhere((e) => e.name == exercise.name);
      });
    }
  }

  Future<void> _saveRoutine() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedExercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select at least one exercise! ⚠️')),
      );
      return;
    }

    _formKey.currentState!.save();

    final routineData = Routine(
      title: _title,
      description: _description.isEmpty ? null : _description,
      exercises: _selectedExercises,
    );

    if (_isEditMode) {
      await routinesBox.put(widget.routineKey, routineData.toMap());
    } else {
      await routinesBox.add(routineData.toMap());
    }

    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isEditMode
            ? 'Routine updated successfully! 📝'
            : 'Routine created successfully! 🎉'),
      ),
    );
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
      await routinesBox.delete(widget.routineKey);
      if (!mounted) return;
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Definirea stilului comun pentru borduri inteligente
    final inputDecorationTheme = InputDecoration(
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.primary,
          width: 1.5,
        ),
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
            icon: Icon(Icons.save,
                color: Theme.of(context).colorScheme.primary, size: 28),
            onPressed: _saveRoutine,
          )
        ],
      ),
      // Adăugat GestureDetector pentru închiderea tastatului la apăsare în exterior
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // --- SECȚIUNEA INTRODUCERE DATE (TITLU & DESCRIERE) ---
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    TextFormField(
                      initialValue: _title,
                      decoration: inputDecorationTheme.copyWith(
                        labelText: 'Routine Title',
                      ),
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
                        labelText: 'Description / Notes (Optional)',
                      ),
                      onSaved: (value) => _description = value ?? '',
                    ),
                  ],
                ),
              ),

              // --- STRUCTURA RUTINEI (AFIȘARE EXERCIȚII SELECTATE) ---
              if (_selectedExercises.isNotEmpty) ...[
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
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: ReorderableListView.builder(
                      itemCount: _selectedExercises.length,
                      onReorderItem: (oldIndex, newIndex) {
                        setState(() {
                          final item = _selectedExercises.removeAt(oldIndex);
                          _selectedExercises.insert(newIndex, item);
                        });
                      },
                      itemBuilder: (context, index) {
                        final ex = _selectedExercises[index];
                        final primaryMuscle = ex.primaryMuscles.isNotEmpty
                            ? ex.primaryMuscles.first.group
                            : 'Core';
                        final extraInfo =
                            '${primaryMuscle} • ${ex.equipment.name.toUpperCase()}';

                        return Card(
                          key: ValueKey('selected_vert_${ex.name}'),
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          elevation: 0,
                          child: ListTile(
                            dense: true,
                            leading: Icon(Icons.drag_handle,
                                color: Theme.of(context).colorScheme.primary),
                            title: Text(
                              ex.name,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            subtitle: Text(
                              extraInfo,
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.close,
                                  color: Colors.redAccent, size: 18),
                              onPressed: () => _confirmRemoveExercise(ex),
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
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 15),
                    ),
                  ),
                ),
              ],

              // --- COMPONENTA REUTILIZABILĂ CURENTĂ DE ADĂUGARE ---
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: AppOutlinedButton(
                    label: 'Add Exercises',
                    icon: Icons.add,
                    onPressed: () async {
                      final List<Exercise>? result =
                          await Navigator.push<List<Exercise>>(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ExerciseSelectionPage(
                            existingExercises: _selectedExercises,
                          ),
                        ),
                      );

                      if (result != null && result.isNotEmpty) {
                        setState(() {
                          _selectedExercises.addAll(result);
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
