import 'package:flutter/material.dart';
import '../../enums/enums.dart';
import '../../main.dart';
import '../../models/models.dart';

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

  List<Exercise> _allAvailableExercises = [];
  String _searchQuery = '';
  MuscleGroup? _selectedMuscleFilter;

  bool get _isEditMode => widget.routine != null;

  @override
  void initState() {
    super.initState();
    _title = widget.routine?.title ?? '';
    _description = widget.routine?.description ?? '';
    if (widget.routine != null) {
      _selectedExercises.addAll(widget.routine!.exercises);
    }
    _loadAvailableExercises();
  }

  void _loadAvailableExercises() {
    final exercises =
        exercisesBox.values.map((e) => Exercise.fromMap(e as Map)).toList();
    setState(() {
      _allAvailableExercises = exercises;
    });
  }

  void _toggleExerciseSelection(Exercise exercise) {
    setState(() {
      final index =
          _selectedExercises.indexWhere((e) => e.name == exercise.name);
      if (index >= 0) {
        _selectedExercises.removeAt(index);
      } else {
        _selectedExercises.add(exercise);
      }
    });
  }

  bool _isExerciseSelected(Exercise exercise) {
    return _selectedExercises.any((e) => e.name == exercise.name);
  }

  // LOGICĂ ACTUAlIZATĂ: Filtrare inteligentă bazată pe listă
  List<Exercise> get _filteredExercises {
    return _allAvailableExercises.where((exercise) {
      final matchesSearch =
          exercise.name.toLowerCase().contains(_searchQuery.toLowerCase());

      // Verificăm dacă grupa selectată în chip se află în interiorul listei de grupe ale exercițiului
      final matchesMuscle = _selectedMuscleFilter == null ||
          exercise.muscleGroups.contains(_selectedMuscleFilter);

      return matchesSearch && matchesMuscle;
    }).toList();
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
              child: const Text('Cancel')),
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
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Routine' : 'Create Routine'),
        actions: [
          if (_isEditMode)
            IconButton(
                icon: const Icon(Icons.delete, color: Colors.redAccent),
                onPressed: _deleteRoutine),
          IconButton(
              icon: const Icon(Icons.save, color: Colors.blueAccent, size: 28),
              onPressed: _saveRoutine)
        ],
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextFormField(
                    initialValue: _title,
                    decoration: const InputDecoration(
                        labelText: 'Routine Title',
                        border: OutlineInputBorder()),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Title is required'
                        : null,
                    onSaved: (value) => _title = value!.trim(),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: _description,
                    decoration: const InputDecoration(
                        labelText: 'Description / Notes (Optional)',
                        border: OutlineInputBorder()),
                    onSaved: (value) => _description = value ?? '',
                  ),
                ],
              ),
            ),
            if (_selectedExercises.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Routine Structure (Hold & Drag to reorder):',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber)),
                ),
              ),
              Container(
                constraints: const BoxConstraints(maxHeight: 180),
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.amber.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.amber.withOpacity(0.02),
                ),
                child: ReorderableListView.builder(
                  shrinkWrap: true,
                  itemCount: _selectedExercises.length,
                  onReorderItem: (oldIndex, newIndex) {
                    setState(() {
                      final item = _selectedExercises.removeAt(oldIndex);
                      _selectedExercises.insert(newIndex, item);
                    });
                  },
                  itemBuilder: (context, index) {
                    final ex = _selectedExercises[index];

                    // MODIFICARE: Luăm prima grupă ca fiind cea principală + menționăm echipamentul
                    final primaryMuscle = ex.muscleGroups.isNotEmpty
                        ? ex.muscleGroups.first.name
                        : 'core';
                    final extraInfo =
                        '${primaryMuscle.toUpperCase()} • ${ex.equipment.name.toUpperCase()}';

                    return ListTile(
                      key: ValueKey('selected_vert_${ex.name}'),
                      dense: true,
                      leading:
                          const Icon(Icons.drag_handle, color: Colors.amber),
                      title: Text(ex.name,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(extraInfo,
                          style: const TextStyle(
                              fontSize: 10, color: Colors.grey)),
                      trailing: IconButton(
                        icon: const Icon(Icons.close,
                            color: Colors.redAccent, size: 18),
                        onPressed: () => _toggleExerciseSelection(ex),
                      ),
                    );
                  },
                ),
              ),
            ],
            const Divider(),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: Column(
                children: [
                  TextField(
                    decoration: InputDecoration(
                      labelText: 'Search Exercises...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () =>
                                  setState(() => _searchQuery = ''))
                          : null,
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    onChanged: (value) => setState(() => _searchQuery = value),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: MuscleGroup.values.map((muscle) {
                        final isSelected = _selectedMuscleFilter == null
                            ? false
                            : _selectedMuscleFilter == muscle;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6.0),
                          child: FilterChip(
                            label: Text(muscle.name.toUpperCase(),
                                style: const TextStyle(fontSize: 11)),
                            selected: isSelected,
                            selectedColor: Colors.blueAccent.withOpacity(0.3),
                            checkmarkColor: Colors.blueAccent,
                            onSelected: (bool selected) {
                              setState(() {
                                _selectedMuscleFilter =
                                    selected ? muscle : null;
                              });
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _filteredExercises.isEmpty
                  ? const Center(
                      child: Text('No exercises found matching filters.',
                          style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      itemCount: _filteredExercises.length,
                      itemBuilder: (context, index) {
                        final exercise = _filteredExercises[index];
                        final isSelected = _isExerciseSelected(exercise);

                        // MODIFICARE: Corectat subtitlul pentru a folosi grupa principală + echipament
                        final primaryMuscle = exercise.muscleGroups.isNotEmpty
                            ? exercise.muscleGroups.first.name
                            : 'core';
                        final subtitleText =
                            '${primaryMuscle.toUpperCase()} • ${exercise.equipment.name.toUpperCase()}';

                        return CheckboxListTile(
                          title: Text(exercise.name),
                          subtitle: Text(subtitleText,
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.blueGrey)),
                          value: isSelected,
                          onChanged: (bool? value) =>
                              _toggleExerciseSelection(exercise),
                          activeColor: Colors.blueAccent,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
