import 'package:flutter/material.dart';
import 'package:gym_tracker/enums/workout_status.dart';
import 'package:gym_tracker/screens/workout/workout_detail_page.dart'; // Importăm noua pagină creată
import '../../main.dart'; // Accesul direct la logsBox-ul tău din Hive
import '../../models/models.dart'; // Modelul tău WorkoutLog și WorkoutStatus

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // Schimbăm structura listei pentru a salva atât cheia din Hive, cât și logul complet
  List<MapEntry<dynamic, WorkoutLog>> _finishedLogsWithKeys = [];

  @override
  void initState() {
    super.initState();
    _loadWorkoutHistory();
  }

  void _loadWorkoutHistory() {
    if (logsBox.isOpen) {
      // Păstrăm MapEntry pentru a nu pierde cheia unică (folositoare la ștergere/editare)
      final List<MapEntry<dynamic, WorkoutLog>> allEntries = [];

      for (var entry in logsBox.toMap().entries) {
        final log = WorkoutLog.fromMap(entry.value as Map);
        if (log.status == WorkoutStatus.finished) {
          allEntries.add(MapEntry(entry.key, log));
        }
      }

      // Sortăm descrescător după data de început
      allEntries.sort((a, b) => b.value.startTime.compareTo(a.value.startTime));

      setState(() {
        _finishedLogsWithKeys = allEntries;
      });
    }
  }

  // Funcție simplă și nativă Dart pentru a formata data
  String _formatDateNative(DateTime dt) {
    final luni = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final luna = luni[dt.month - 1];
    final ziua = dt.day.toString().padLeft(2, '0');
    final ora = dt.hour.toString().padLeft(2, '0');
    final minut = dt.minute.toString().padLeft(2, '0');

    return '$ziua $luna ${dt.year} • $ora:$minut';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout History',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadWorkoutHistory,
          )
        ],
      ),
      body: _finishedLogsWithKeys.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No completed workouts yet.\nTime to hit the gym! 🏋️‍♂️',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Header-ul cu statistici globale
                _buildGlobalStatsHeader(),

                const Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Past Sessions',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey),
                    ),
                  ),
                ),

                // Lista de antrenamente extrase din Hive
                Expanded(
                  child: ListView.builder(
                    itemCount: _finishedLogsWithKeys.length,
                    padding:
                        const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                    itemBuilder: (context, index) {
                      final entry = _finishedLogsWithKeys[index];
                      final logKey = entry.key; // Cheia din Hive
                      final log = entry.value; // Obiectul WorkoutLog

                      final String formattedDate =
                          _formatDateNative(log.startTime);

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8.0),
                        elevation: 1,
                        // MODIFICARE PRINCIPALĂ: Folosim InkWell pentru a adăuga efectul de apăsare și acțiunea onTap
                        child: InkWell(
                          borderRadius: BorderRadius.circular(
                              12), // păstrează colțurile rotunjite ale cardului la apăsare
                          onTap: () async {
                            // Deschidem pagina de detalii și trimitem cheia + logul
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => WorkoutDetailPage(
                                  logKey: logKey,
                                  log: log,
                                ),
                              ),
                            );
                            // Când utilizatorul revine înapoi (sau șterge antrenamentul), reîmprospătăm automat lista!
                            _loadWorkoutHistory();
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        log.routineTitle,
                                        style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blueAccent),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const Icon(Icons.chevron_right,
                                        color: Colors.grey,
                                        size:
                                            20), // Schimbat în săgeată pentru sugestie de click
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  formattedDate,
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.grey),
                                ),
                                const SizedBox(height: 16),
                                const Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'TIME',
                                        style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blueGrey,
                                            letterSpacing: 0.5),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        'VOLUME',
                                        style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blueGrey,
                                            letterSpacing: 0.5),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          const Icon(Icons.access_time,
                                              size: 16, color: Colors.grey),
                                          const SizedBox(width: 6),
                                          // Folosim calculul pe bază de durată nativă din startTime și endTime dacă log.durationInMinutes nu e disponibil direct
                                          Text(
                                            log.endTime != null
                                                ? '${log.endTime!.difference(log.startTime).inMinutes} min'
                                                : '0 min',
                                            style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: Row(
                                        children: [
                                          const Icon(Icons.fitness_center,
                                              size: 16, color: Colors.grey),
                                          const SizedBox(width: 6),
                                          Text(
                                            '${log.totalVolume.toStringAsFixed(0)} kg',
                                            style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ],
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
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildGlobalStatsHeader() {
    final int totalWorkouts = _finishedLogsWithKeys.length;
    double globalVolume = 0;

    for (var entry in _finishedLogsWithKeys) {
      globalVolume += entry.value.totalVolume;
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.blueAccent.withOpacity(0.05),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.15)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Column(
            children: [
              const Text('Total Sessions',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 4),
              Text('$totalWorkouts',
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold)),
            ],
          ),
          Container(width: 1, height: 35, color: Colors.grey.withOpacity(0.3)),
          Column(
            children: [
              const Text('Total Volume Lifted',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 4),
              Text('${globalVolume.toStringAsFixed(0)} kg',
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueAccent)),
            ],
          ),
        ],
      ),
    );
  }
}
