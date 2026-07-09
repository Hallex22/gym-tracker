import 'package:flutter/material.dart';
import 'package:gym_tracker/utils/date_utils.dart';
import '../../main.dart';
import '../../models/models.dart';

class WorkoutDetailPage extends StatelessWidget {
  final dynamic
      logKey; // Cheia unică din logsBox pentru a putea șterge/edita direct
  final WorkoutLog log;

  const WorkoutDetailPage({
    super.key,
    required this.logKey,
    required this.log,
  });

  // Funcție pentru ștergerea antrenamentului din Hive
  Future<void> _deleteWorkout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Workout? 🗑️'),
        content: const Text(
            'Are you sure you want to permanently delete this workout session from your history? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await logsBox.delete(logKey);
      if (!context.mounted) return;

      Navigator.pop(context); // Închide pagina de detalii
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Workout deleted successfully.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Calculăm durata în minute dacă avem endTime
    final duration = log.endTime != null
        ? log.endTime!.difference(log.startTime).inMinutes
        : 0;

    // Formatăm data frumos (ex: 24 Oct 2023, 18:30)
    final formattedDate = formatDateNative(log.startTime);

    // Calculăm numărul total de seturi efective din listă
    int totalSetsCount = 0;
    for (var ex in log.exercises) {
      totalSetsCount += ex.sets.length;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout Summary'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            tooltip: 'Delete Workout',
            onPressed: () => _deleteWorkout(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- HEADER: Titlu Rutină și Dată ---
            Text(
              log.routineTitle,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                const SizedBox(width: 6),
                Text(
                  formattedDate,
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // --- PANOU STATISTICI RAPIDE ---
            Card(
              elevation: 0,
              color: Theme.of(context).cardColor.withOpacity(0.6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.withOpacity(0.2)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(Icons.timer, '$duration min', 'Duration'),
                    _buildStatItem(Icons.fitness_center,
                        '${log.totalVolume.toStringAsFixed(0)} kg', 'Volume'),
                    _buildStatItem(Icons.format_list_numbered,
                        '$totalSetsCount', 'Total Sets'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // --- LISTA DE EXERCIȚII EFECTUATE ---
            const Text(
              'Exercises & Sets',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            if (log.exercises.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20.0),
                  child: Text('No exercises recorded in this session.',
                      style: TextStyle(color: Colors.grey)),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: log.exercises.length,
                itemBuilder: (context, exIndex) {
                  final exercise = log.exercises[exIndex];

                  return Card(
                    margin: const EdgeInsets.only(bottom: 14),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Nume Exercițiu
                          Text(
                            exercise.name,
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.blueAccent),
                          ),
                          const Divider(height: 16),

                          // Tabela de Seturi rulate pentru acest exercițiu
                          ...exercise.sets.asMap().entries.map((entry) {
                            int setIdx = entry.key;
                            final set = entry.value;

                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 4.0),
                              child: Row(
                                children: [
                                  // Număr Set
                                  CircleAvatar(
                                    radius: 10,
                                    backgroundColor:
                                        Colors.grey.withOpacity(0.2),
                                    child: Text(
                                      '${setIdx + 1}',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Theme.of(context).hintColor,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  // Greutate x Repetări
                                  Text(
                                    '${set.weight} kg',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w500),
                                  ),
                                  const Text('  ×  ',
                                      style: TextStyle(color: Colors.grey)),
                                  Text(
                                    '${set.reps} reps',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w500),
                                  ),
                                  const Spacer(),
                                  // Calcul Volum parțial per set (opțional, dă un aer premium)
                                  Text(
                                    '${(set.weight * set.reps).toStringAsFixed(0)} kg',
                                    style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 13),
                                  )
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.blueAccent, size: 24),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
}
