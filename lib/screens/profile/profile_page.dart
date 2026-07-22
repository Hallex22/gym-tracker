import 'package:flutter/material.dart';
import 'package:gym_tracker/screens/profile/settings_page.dart';
import 'package:gym_tracker/screens/workout/workout_detail_page.dart';
import 'package:gym_tracker/widgets/charts/weekly_activity_chart.dart';
import 'package:gym_tracker/widgets/charts/muscle_split_chart.dart'; // 💡 Importăm noul chart
import '../../enums/enums.dart';
import '../../models/app_settings.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';
import '../../utils/date_utils.dart';
import '../../widgets/charts/total_volume_chart.dart';
import 'calendar_page.dart';

// Enum pentru tipul de grafic selectat în profil
enum ProfileChartType { consistency, muscleSplit, totalVolume }

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  List<MapEntry<dynamic, WorkoutLog>> _finishedLogsWithKeys = [];
  late UnitSystem _globalUnit;
  final double myBodyWeight = DatabaseService.getLatestBodyweightInKg();

  // 💡 Starea pentru graficul activ selectat prin chip-uri
  ProfileChartType _selectedChart = ProfileChartType.consistency;

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

  Widget _buildPillChip({
    required BuildContext context,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            // Primary plin dacă e selectat, Primary cu opacitate de 12% dacă e inactiv
            color: isSelected ? primaryColor : primaryColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(100),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              // Text Alb dacă e selectat, Culoarea Primary dacă e inactiv
              color: isSelected ? Colors.white : primaryColor,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                  Icon(Icons.history, size: 64, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(height: 16),
                  Text(
                    'No completed workouts yet.\nTime to hit the gym! 🏋️‍♂️',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 16),
                  ),
                ],
              ),
            )
          : ListView.builder(
              // Index 0: Chip-urile de selecție
              // Index 1: Graficul activ selectat
              // Index 2: Textul "Past Sessions"
              // Index 3+: Listă antrenamente
              itemCount: _finishedLogsWithKeys.length + 3,
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 24),
              itemBuilder: (context, index) {
                // 1. Selectorul de chip-uri derulabil pe orizontală
                if (index == 0) {
                  final primaryColor = theme.colorScheme.primary;

                  return Container(
                    height: 48,
                    margin: const EdgeInsets.only(top: 8.0, bottom: 4.0),
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      // Păstrăm padding-ul aliniat cu marginile ecranului
                      padding: EdgeInsets.zero,
                      children: [
                        // --- CHIP 1: Weekly Consistency ---
                        _buildPillChip(
                          context: context,
                          label: 'Weekly Consistency',
                          isSelected: _selectedChart == ProfileChartType.consistency,
                          onTap: () {
                            setState(() => _selectedChart = ProfileChartType.consistency);
                          },
                        ),

                        const SizedBox(width: 8),

                        // --- CHIP 2: Muscle Split ---
                        _buildPillChip(
                          context: context,
                          label: 'Muscle Split',
                          isSelected: _selectedChart == ProfileChartType.muscleSplit,
                          onTap: () {
                            setState(() => _selectedChart = ProfileChartType.muscleSplit);
                          },
                        ),

                        // 💡 Dacă adaugi al 3-lea grafic în viitor, adaugi doar un alt SizedBox + _buildPillChip aici!
                        const SizedBox(width: 8),
                        _buildPillChip(
                          context: context,
                          label: 'Total Volume',
                          isSelected: _selectedChart == ProfileChartType.totalVolume,
                          onTap: () {
                            setState(() => _selectedChart = ProfileChartType.totalVolume);
                          },
                        ),
                      ],
                    ),
                  );
                }

                // 2. Randarea dinamică a graficului selectat
                if (index == 1) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: () {
                        switch (_selectedChart) {
                          case ProfileChartType.consistency:
                            return const WeeklyActivityChart(
                              key: ValueKey('consistency_chart'),
                              initialWeeksCount: 8,
                            );
                          case ProfileChartType.muscleSplit:
                            return const MuscleSplitChart(
                              key: ValueKey('muscle_split_chart'),
                              initialDaysRange: 30,
                            );
                          case ProfileChartType.totalVolume:
                            return const TotalVolumeChart(
                              key: ValueKey('total_volume_chart'),
                            );
                        }
                      }(),
                    ),
                  );
                }

                // 3. Textul secundar "Past Sessions"
                if (index == 2) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 12.0, bottom: 8.0),
                    child: Text(
                      'Past Sessions',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }

                // 4. Cardurile cu sesiunile anterioare (ajustate cu index - 3)
                final entry = _finishedLogsWithKeys[index - 3];
                final logKey = entry.key;
                final log = entry.value;
                final String formattedDate = formatDateNative(log.startTime);

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
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
                                  style: theme.textTheme.titleLarge,
                                ),
                              ),
                              Icon(
                                Icons.chevron_right,
                                color: theme.colorScheme.onSurfaceVariant,
                                size: 20,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formattedDate,
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
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
                                    color: theme.colorScheme.onSurfaceVariant,
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
                                    color: theme.colorScheme.onSurfaceVariant,
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
                                      color: theme.colorScheme.onSurface,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      log.endTime != null ? log.formattedDuration : '0 min',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.onSurface,
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
                                      color: theme.colorScheme.onSurface,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _globalUnit.toFullDisplay(log.totalVolume),
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.onSurface,
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
