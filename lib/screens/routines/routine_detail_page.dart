import 'package:flutter/material.dart';
import 'package:gym_tracker/screens/exercises/exercise_detail_page.dart';
import 'package:gym_tracker/screens/routines/routine_form_page.dart';
import '../../main.dart'; // Importăm pentru a avea acces la routinesBox la ștergere
import '../../models/models.dart';
import '../workout/active_workout_page.dart';

class RoutineDetailPage extends StatefulWidget {
  final Routine routine;
  final dynamic
      routineKey; // Cheia din Hive pentru a o putea trimite mai departe la editare/ștergere

  const RoutineDetailPage({
    super.key,
    required this.routine,
    required this.routineKey,
  });

  @override
  State<RoutineDetailPage> createState() => _RoutineDetailPageState();
}

class _RoutineDetailPageState extends State<RoutineDetailPage> {
  // --- MODALA DE JOS PENTRU OPȚIUNI (ADAPTATĂ PENTRU DETALII) ---
  void _showRoutineOptionsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Mânerul estetic de sus
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  child: Text(
                    widget.routine.title,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ),
                const Divider(),

                // 1. Edit Routine
                ListTile(
                  leading: const Icon(Icons.edit_outlined,
                      color: Colors.orangeAccent),
                  title: const Text('Edit Routine'),
                  onTap: () async {
                    Navigator.pop(context); // Închidem modala

                    // Mergem la pagina de editare structură
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RoutineFormPage(
                          routine: widget.routine,
                          routineKey: widget.routineKey,
                        ),
                      ),
                    );

                    // Când se întoarce din editare, dacă s-a modificat ceva, reîmprospătăm ecranul actual
                    if (mounted) setState(() {});
                  },
                ),

                // 2. Share Routine (Inactiv)
                ListTile(
                  leading: const Icon(Icons.share_outlined, color: Colors.grey),
                  title: const Text('Share Routine'),
                  subtitle: const Text('Future feature 🚀',
                      style: TextStyle(fontSize: 11, color: Colors.grey)),
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text(
                              'Sharing will be available in a future update!')),
                    );
                  },
                ),
                const Divider(),

                // 3. Delete Routine (Cu dialog de confirmare)
                ListTile(
                  leading:
                      const Icon(Icons.delete_outline, color: Colors.redAccent),
                  title: const Text('Delete Routine',
                      style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w500)),
                  onTap: () {
                    Navigator.pop(context); // Închidem modala
                    _showDeleteConfirmationDialog(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- DIALOGUL DE CONFIRMARE PENTRU ȘTERGERE ---
  void _showDeleteConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Routine? 🚨'),
        content: Text(
            'Are you sure you want to delete "${widget.routine.title}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              // Ștergem rutina din Hive folosind cheia ei
              await routinesBox.delete(widget.routineKey);
              if (!context.mounted) return;

              Navigator.pop(context); // Închidem dialogul de pop-up
              Navigator.pop(
                  context); // Închidem și pagina de detalii, întorcându-ne pe HomePage

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('"${widget.routine.title}" deleted.')),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Routine Preview'),
        centerTitle: true,
        actions: [
          // Am înlocuit butonul text cu cele 3 puncte verticale premium
          IconButton(
            icon: const Icon(Icons.more_vert),
            tooltip: 'Options',
            onPressed: () => _showRoutineOptionsSheet(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // --- HEADER RUTINĂ ---
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor:
                      Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  child: Icon(Icons.layers,
                      color: Theme.of(context).colorScheme.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.routine.title,
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.routine.exercises.length} exercises included',
                        style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(
              height: 1,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.2)),

          // --- LISTA DE EXERCIȚII DIN RUTINĂ ---
          Expanded(
            child: widget.routine.exercises.isEmpty
                ? Center(
                    child: Text('This routine has no exercises yet.',
                        style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant)),
                  )
                : ListView.builder(
                    itemCount: widget.routine.exercises.length,
                    padding: const EdgeInsets.all(16),
                    itemBuilder: (context, index) {
                      final exercise = widget.routine.exercises[index];

                      final primaryMuscle = exercise.primaryMuscles.isNotEmpty
                          ? exercise.primaryMuscles.first.group.name
                          : 'Core';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      ExerciseDetailPage(exercise: exercise),
                                ));
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(14.0),
                            child: Row(
                              children: [
                                Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                      fontSize: 16),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        exercise.name,
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '$primaryMuscle • ${exercise.equipment.name.toUpperCase()}',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant,
                                            fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.chevron_right,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                    size: 18),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // --- BUTONUL MARE DE START WORKOUT ---
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                  ),
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ActiveWorkoutPage(routine: widget.routine),
                      ),
                    );
                  },
                  icon: const Icon(Icons.play_arrow, size: 24),
                  label: const Text(
                    'Start Workout',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
