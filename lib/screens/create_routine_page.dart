import 'package:flutter/material.dart';
import '../main.dart';
import '../models/models.dart';

class CreateRoutinePage extends StatefulWidget {
  const CreateRoutinePage({super.key});

  @override
  State<CreateRoutinePage> createState() => _CreateRoutinePageState();
}

class _CreateRoutinePageState extends State<CreateRoutinePage> {
  final _formKey = GlobalKey<FormState>();
  String _title = '';
  String _description = '';

  List<Exercise> _allAvailableExercises = [];
  final List<Exercise> _selectedExercises = [];

  @override
  void initState() {
    super.initState();
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
      if (_selectedExercises.contains(exercise)) {
        _selectedExercises.remove(exercise);
      } else {
        _selectedExercises.add(exercise);
      }
    });
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

    final newRoutine = Routine(
      title: _title,
      description: _description.isEmpty ? null : _description,
      exercises: _selectedExercises,
    );

    // Salvare directă în Hive routinesBox
    await routinesBox.add(newRoutine.toMap());

    if (!mounted) return;
    Navigator.pop(context); // Ne întoarcem pe ecranul de home
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Routine'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save, color: Colors.blueAccent, size: 28),
            onPressed: _saveRoutine,
          )
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
                    decoration: const InputDecoration(
                      labelText: 'Routine Title (e.g., Push Day)',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Title is required'
                        : null,
                    onSaved: (value) => _title = value!.trim(),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Description / Notes (Optional)',
                      border: OutlineInputBorder(),
                    ),
                    onSaved: (value) => _description = value ?? '',
                  ),
                ],
              ),
            ),
            const Divider(),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Select Exercises:',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey)),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _allAvailableExercises.length,
                itemBuilder: (context, index) {
                  final exercise = _allAvailableExercises[index];
                  final isSelected = _selectedExercises.contains(exercise);

                  return CheckboxListTile(
                    title: Text(exercise.name),
                    subtitle: Text(exercise.muscleGroup.name.toUpperCase(),
                        style: const TextStyle(
                            fontSize: 11, color: Colors.blueGrey)),
                    value: isSelected,
                    onChanged: (bool? value) {
                      _toggleExerciseSelection(exercise);
                    },
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
