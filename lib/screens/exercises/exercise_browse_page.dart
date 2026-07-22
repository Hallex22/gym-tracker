import 'package:flutter/material.dart';
import '../../enums/enums.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';
import '../exercises/exercise_detail_page.dart'; // Import pentru navigare detalii

class ExerciseExplorePage extends StatefulWidget {
  const ExerciseExplorePage({super.key});

  @override
  State<ExerciseExplorePage> createState() => _ExerciseExplorePageState();
}

class _ExerciseExplorePageState extends State<ExerciseExplorePage> {
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
    // Încărcăm absolut toate exercițiile existente în cache
    setState(() {
      _allAvailableExercises =
          DatabaseService.exercisesBox.values.map((e) => Exercise.fromMap(e as Map)).toList();
    });
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
        title: const Text('Explore Exercises'),
        centerTitle: true,
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: Column(
          children: [
            // --- SECȚIUNE FILTRE (PĂSTRATĂ INTACTĂ) ---
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
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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

            // --- LISTA COMPLETĂ DE RĂSFOIRE (FĂRĂ CONTROL DE SELECȚIE) ---
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

                        final primaryMuscle = exercise.primaryMuscles.isNotEmpty
                            ? exercise.primaryMuscles.first.label
                            : 'Core';
                        final subtitleText =
                            '${primaryMuscle.toUpperCase()} • ${exercise.equipment.name.toUpperCase()}';

                        final coverImage = exercise.coverImage;
                        final isImageEmpty =
                            coverImage == null || coverImage.trim().isEmpty;

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          elevation: 1,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      ExerciseDetailPage(exercise: exercise),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Row(
                                children: [
                                  // Avatarul cu poza exercițiului
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundColor: theme
                                        .colorScheme.surfaceContainerHighest,
                                    backgroundImage: !isImageEmpty
                                        ? AssetImage('assets/$coverImage')
                                        : null,
                                    child: isImageEmpty
                                        ? Icon(Icons.image_not_supported,
                                            size: 16,
                                            color: theme
                                                .colorScheme.onSurfaceVariant)
                                        : null,
                                  ),
                                  const SizedBox(width: 14),

                                  // Titlul și Subtitlul exercițiului ocupă tot spațiul
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          exercise.name,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: theme.colorScheme.onSurface,
                                            fontSize: 15,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          subtitleText,
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: theme.colorScheme
                                                  .onSurfaceVariant),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Un chevron elegant în dreapta pentru a indica navigarea spre detalii
                                  Icon(
                                    Icons.chevron_right,
                                    color: theme.colorScheme.onSurfaceVariant
                                        .withOpacity(0.7),
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          ),
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
