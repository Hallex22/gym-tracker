import 'package:flutter/material.dart';
import 'package:gym_tracker/enums/workout_status.dart';
import 'package:gym_tracker/screens/workout/workout_detail_page.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';
import 'calendar_page.dart'; // 💡 Importă corect pagina de calendar (ajustează calea dacă e diferită)

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  List<MapEntry<dynamic, WorkoutLog>> _finishedLogsWithKeys = [];

  @override
  void initState() {
    super.initState();
    _loadWorkoutHistory();
  }

  void _loadWorkoutHistory() {
    if (DatabaseService.logsBox.isOpen) {
      final List<MapEntry<dynamic, WorkoutLog>> allEntries = [];

      for (var entry in DatabaseService.logsBox.toMap().entries) {
        final log = WorkoutLog.fromMap(entry.value as Map);
        if (log.status == WorkoutStatus.finished) {
          allEntries.add(MapEntry(entry.key, log));
        }
      }

      allEntries.sort((a, b) => b.value.startTime.compareTo(a.value.startTime));

      setState(() {
        _finishedLogsWithKeys = allEntries;
      });
    }
  }

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
        title: const Text('Workout History'),
        centerTitle: false,
        actions: [
          // 💡 ICONIȚA DE CALENDAR ADAUGATĂ AICI
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined),
            tooltip: 'View Calendar',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CalendarPage(),
                ),
              );
              // Când utilizatorul vine înapoi din calendar, dăm un refresh la date
              _loadWorkoutHistory();
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadWorkoutHistory,
          )
        ],
      ),
      body: _finishedLogsWithKeys.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history,
                      size: 64,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(height: 16),
                  Text(
                    'No completed workouts yet.\nTime to hit the gym! 🏋️‍♂️',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 16),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                _buildGlobalStatsHeader(),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Past Sessions',
                      // style: Theme.of(context).textTheme.bodyMedium,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _finishedLogsWithKeys.length,
                    padding:
                        const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                    itemBuilder: (context, index) {
                      final entry = _finishedLogsWithKeys[index];
                      final logKey = entry.key;
                      final log = entry.value;

                      final String formattedDate =
                          _formatDateNative(log.startTime);

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8.0),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => WorkoutDetailPage(
                                  logKey: logKey,
                                  log: log,
                                ),
                              ),
                            );
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
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge,
                                      ),
                                    ),
                                    Icon(Icons.chevron_right,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                        size: 20),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  formattedDate,
                                  // style: Theme.of(context).textTheme.bodyMedium,
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'TIME',
                                        style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant,
                                            letterSpacing: 0.5),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        'VOLUME',
                                        style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant,
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
                                          Icon(Icons.access_time,
                                              size: 16,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurface),
                                          const SizedBox(width: 6),
                                          Text(
                                            log.endTime != null
                                                ? '${log.endTime!.difference(log.startTime).inMinutes} min'
                                                : '0 min',
                                            style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurface),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Icon(Icons.fitness_center,
                                              size: 16,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurface),
                                          const SizedBox(width: 6),
                                          Text(
                                            '${log.totalVolume.toStringAsFixed(0)} kg',
                                            style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurface),
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
        color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
        border: Border.all(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.15)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Column(
            children: [
              Text('Total Sessions',
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 4),
              Text('$totalWorkouts',
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold)),
            ],
          ),
          Container(
              width: 1,
              height: 35,
              color: Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant
                  .withOpacity(0.2)),
          Column(
            children: [
              Text('Total Volume Lifted',
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 4),
              Text('${globalVolume.toStringAsFixed(0)} kg',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.secondary)),
            ],
          ),
        ],
      ),
    );
  }
}
