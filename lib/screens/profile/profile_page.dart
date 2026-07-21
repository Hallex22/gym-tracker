import 'package:flutter/material.dart';
import 'package:gym_tracker/screens/profile/settings_page.dart';
import 'package:gym_tracker/screens/workout/workout_detail_page.dart';
import 'package:gym_tracker/widgets/charts/weekly_activity_chart.dart';
import '../../enums/enums.dart';
import '../../models/app_settings.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';
import '../../utils/date_utils.dart';
import 'calendar_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  List<MapEntry<dynamic, WorkoutLog>> _finishedLogsWithKeys = [];
  late UnitSystem _globalUnit;
  final double myBodyWeight = DatabaseService.getLatestBodyweightInKg();

  @override
  void initState() {
    super.initState();
    _loadUnitPreference();
    _loadWorkoutHistory();
  }

  void _loadUnitPreference() {
    final Map? rawSettings = DatabaseService.settingsBox.get('appSettings') as Map?;
    final AppSettings settings = rawSettings != null ? AppSettings.fromMap(rawSettings) : const AppSettings();

    setState(() {
      _globalUnit = settings.unitSystem;
    });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout History'),
        centerTitle: false,
        actions: [
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
              _loadWorkoutHistory();
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsPage(),
                ),
              );
              _loadUnitPreference();
            },
          ),
        ],
      ),
      body: _finishedLogsWithKeys.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(height: 16),
                  Text(
                    'No completed workouts yet.\nTime to hit the gym! 🏋️‍♂️',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 16),
                  ),
                ],
              ),
            )
          : ListView.builder(
              // 💡 Săptămâna + Titlul secundar + Istoricul de sesiuni = Lungimea totală a listei
              itemCount: _finishedLogsWithKeys.length + 2,
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 24),
              itemBuilder: (context, index) {
                // 1. Primul element din listă (Index 0) -> Graficul
                if (index == 0) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12.0),
                    child: WeeklyActivityChart(weeksCount: 8),
                  );
                }

                // 2. Al doilea element din listă (Index 1) -> Textul "Past Sessions"
                if (index == 1) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0, bottom: 12.0),
                    child: Text(
                      'Past Sessions',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }

                // 3. Toate elementele următoare -> Cardurile cu antrenamente
                // Ajustăm indexul cu -2 din cauza celor două elemente de header de mai sus
                final entry = _finishedLogsWithKeys[index - 2];
                final logKey = entry.key;
                final log = entry.value;
                final String formattedDate = formatDateNative(log.startTime);

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
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  log.routineTitle,
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                              ),
                              Icon(
                                Icons.chevron_right,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                size: 20,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formattedDate,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  'VOLUME',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    letterSpacing: 0.5,
                                  ),
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
                                    Icon(
                                      Icons.access_time,
                                      size: 16,
                                      color: Theme.of(context).colorScheme.onSurface,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      log.endTime != null ? log.formattedDuration : '0 min',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).colorScheme.onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.fitness_center,
                                      size: 16,
                                      color: Theme.of(context).colorScheme.onSurface,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _globalUnit.toFullDisplay(log.totalVolume),
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).colorScheme.onSurface,
                                      ),
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
    );
  }
}
