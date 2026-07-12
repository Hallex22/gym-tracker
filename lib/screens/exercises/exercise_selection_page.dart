import 'package:flutter/material.dart';
import '../../enums/enums.dart';
import '../../main.dart'; // Pentru accesul la exercisesBox
import '../../models/models.dart';
import '../../widgets/app_buttons.dart';
import '../exercises/exercise_detail_page.dart'; // Import corect pentru navigare detalii

class ExerciseSelectionPage extends StatefulWidget {
  final List<int>? existingExercisesIds;

  const ExerciseSelectionPage({
    super.key,
    this.existingExercisesIds,
  });

  @override
  State<ExerciseSelectionPage> createState() => _ExerciseSelectionPageState();
}

class _ExerciseSelectionPageState extends State<ExerciseSelectionPage> {
  final List<Exercise> _newSelectedExercises = [];
  List<Exercise> _allAvailableExercises = [];
  String _searchQuery = '';

  MuscleGroup? _selectedMuscleFilter;
  Equipment? _selectedEquipmentFilter;

  @override
  void initState() {
    super.initState();
    _loadAvailableExercises();
  }

  void _loadAvailableExercises() {
    final exercises =
        exercisesBox.values.map((e) => Exercise.fromMap(e as Map)).toList();

    setState(() {
      if (widget.existingExercisesIds != null &&
          widget.existingExercisesIds!.isNotEmpty) {
        final excludedIds = widget.existingExercisesIds!.toSet();
        _allAvailableExercises =
            exercises.where((ex) => !excludedIds.contains(ex.id)).toList();
      } else {
        _allAvailableExercises = exercises;
      }
    });
  }

  void _toggleExerciseSelection(Exercise exercise) {
    setState(() {
      final index =
          _newSelectedExercises.indexWhere((e) => e.id == exercise.id);
      if (index >= 0) {
        _newSelectedExercises.removeAt(index);
      } else {
        _newSelectedExercises.add(exercise);
      }
    });
  }

  bool _isExerciseSelected(Exercise exercise) {
    return _newSelectedExercises.any((e) => e.id == exercise.id);
  }

  List<Exercise> get _filteredExercises {
    return _allAvailableExercises.where((exercise) {
      final matchesSearch =
          exercise.name.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesMuscle = _selectedMuscleFilter == null ||
          exercise.primaryMuscles.any((m) => m.group == _selectedMuscleFilter);
      final matchesEquipment = _selectedEquipmentFilter == null ||
          exercise.equipment == _selectedEquipmentFilter;
      return matchesSearch && matchesMuscle && matchesEquipment;
    }).toList();
  }

  void _clearAllFilters() {
    setState(() {
      _selectedMuscleFilter = null;
      _selectedEquipmentFilter = null;
      _searchQuery = '';
    });
  }

  void _showFilterSelector<T>({
    required String title,
    required List<T> values,
    required T? currentValue,
    required String Function(T) getName,
    required Function(T?) onSelected,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Container(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant
                        .withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                Divider(
                    height: 1,
                    color:
                        Theme.of(context).colorScheme.primary.withOpacity(0.2)),
                Expanded(
                  child: ListView.builder(
                    itemCount: values.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return ListTile(
                          title: const Text('ALL',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          trailing: currentValue == null
                              ? Icon(Icons.check,
                                  color: Theme.of(context).colorScheme.primary)
                              : null,
                          onTap: () {
                            onSelected(null);
                            Navigator.pop(context);
                          },
                        );
                      }
                      final item = values[index - 1];
                      final isSelected = currentValue == item;
                      return ListTile(
                        title: Text(getName(item).toUpperCase()),
                        trailing: isSelected
                            ? Icon(Icons.check,
                                color: Theme.of(context).colorScheme.primary)
                            : null,
                        onTap: () {
                          onSelected(item);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasActiveFilters = _selectedMuscleFilter != null ||
        _selectedEquipmentFilter != null ||
        _searchQuery.isNotEmpty;

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Exercises'),
        centerTitle: true,
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: Column(
          children: [
            // --- SECȚIUNE FILTRE ---
            Padding(
              padding: const EdgeInsets.all(16.0),
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
                                  setState(() => _searchQuery = ''),
                            )
                          : null,
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    onChanged: (value) => setState(() => _searchQuery = value),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            foregroundColor: _selectedMuscleFilter != null
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface,
                            side: BorderSide(
                                color: _selectedMuscleFilter != null
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurfaceVariant
                                        .withOpacity(0.3)),
                          ),
                          onPressed: () => _showFilterSelector<MuscleGroup>(
                            title: 'Select Muscle Group',
                            values: MuscleGroup.values,
                            currentValue: _selectedMuscleFilter,
                            getName: (m) => m.name,
                            onSelected: (val) =>
                                setState(() => _selectedMuscleFilter = val),
                          ),
                          icon: const Icon(Icons.fitness_center, size: 16),
                          label: Text(
                            _selectedMuscleFilter != null
                                ? _selectedMuscleFilter!.name.toUpperCase()
                                : 'ALL MUSCLES',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            foregroundColor: _selectedEquipmentFilter != null
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface,
                            side: BorderSide(
                                color: _selectedEquipmentFilter != null
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurfaceVariant
                                        .withOpacity(0.3)),
                          ),
                          onPressed: () => _showFilterSelector<Equipment>(
                            title: 'Select Equipment',
                            values: Equipment.values,
                            currentValue: _selectedEquipmentFilter,
                            getName: (e) => e.name,
                            onSelected: (val) =>
                                setState(() => _selectedEquipmentFilter = val),
                          ),
                          icon: const Icon(Icons.layers_outlined, size: 16),
                          label: Text(
                            _selectedEquipmentFilter != null
                                ? _selectedEquipmentFilter!.name.toUpperCase()
                                : 'ALL EQUIPMENT',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      if (hasActiveFilters) ...[
                        const SizedBox(width: 4),
                        IconButton(
                          icon: Icon(Icons.refresh,
                              color: theme.colorScheme.onSurfaceVariant),
                          tooltip: 'Clear Filters',
                          onPressed: _clearAllFilters,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: theme.colorScheme.primary.withOpacity(0.2)),

            // --- LISTA DE EXERCIȚII REZULTATE ---
            Expanded(
              child: _filteredExercises.isEmpty
                  ? Center(
                      child: Text(
                        'No exercises found matching filters.',
                        style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filteredExercises.length,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      itemBuilder: (context, index) {
                        final exercise = _filteredExercises[index];
                        final isSelected = _isExerciseSelected(exercise);

                        final primaryMuscle = exercise.primaryMuscles.isNotEmpty
                            ? exercise.primaryMuscles.first.label
                            : 'Core';
                        final subtitleText =
                            '${primaryMuscle.toUpperCase()} • ${exercise.equipment.name.toUpperCase()}';

                        // Logică imagine (la fel ca în ActiveWorkoutPage)
                        final coverImage = exercise.coverImage;
                        final isImageEmpty =
                            coverImage == null || coverImage.trim().isEmpty;

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          elevation: 0,
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                              children: [
                                // 💡 ZONA CLICKABILĂ PENTRU DETALII (Imagine + Text)
                                Expanded(
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(8),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              ExerciseDetailPage(
                                                  exercise: exercise),
                                        ),
                                      );
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(4.0),
                                      child: Row(
                                        children: [
                                          // Avatarul cu poza exercițiului
                                          CircleAvatar(
                                            radius: 24,
                                            backgroundColor: theme.colorScheme
                                                .surfaceContainerHighest,
                                            backgroundImage: !isImageEmpty
                                                ? AssetImage(
                                                    'assets/$coverImage')
                                                : null,
                                            child: isImageEmpty
                                                ? Icon(
                                                    Icons.image_not_supported,
                                                    size: 16,
                                                    color: theme.colorScheme
                                                        .onSurfaceVariant)
                                                : null,
                                          ),
                                          const SizedBox(width: 12),

                                          // Titlul și Subtitlul exercițiului
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  exercise.name,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: theme
                                                        .colorScheme.onSurface,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  subtitleText,
                                                  style: TextStyle(
                                                      fontSize: 10,
                                                      color: theme.colorScheme
                                                          .onSurfaceVariant),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),

                                // 💡 CERCUL CUSTOM PENTRU SELECȚIE (Fie cerc cu plus, fie bifat)
                                Padding(
                                  padding: const EdgeInsets.only(
                                      left: 8.0, right: 4.0),
                                  child: InkWell(
                                    onTap: () =>
                                        _toggleExerciseSelection(exercise),
                                    borderRadius: BorderRadius.circular(100),
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 200),
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isSelected
                                            ? theme.colorScheme.primary
                                            : theme.colorScheme
                                                .surfaceContainerHighest,
                                        border: Border.all(
                                          color: isSelected
                                              ? theme.colorScheme.primary
                                              : theme
                                                  .colorScheme.primary.withOpacity(0.2),
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Icon(
                                        isSelected ? Icons.check : Icons.add,
                                        size: 18,
                                        color: isSelected
                                            ? theme.colorScheme.onPrimary
                                            : theme.colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // --- BUTONUL DE SALVARE FIXAT JOS ---
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: AppFilledButton(
                  label: _newSelectedExercises.isEmpty
                      ? 'Add Exercises'
                      : 'Add Selected Exercises (${_newSelectedExercises.length})',
                  onPressed: _newSelectedExercises.isEmpty
                      ? () => Navigator.pop(context)
                      : () => Navigator.pop(context, _newSelectedExercises),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
