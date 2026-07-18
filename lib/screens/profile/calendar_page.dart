import 'package:flutter/material.dart';
import 'package:gym_tracker/enums/workout_status.dart';
import 'package:gym_tracker/theme/app_theme.dart';
import 'package:gym_tracker/utils/date_utils.dart';
import 'package:gym_tracker/widgets/top_toast.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';
import '../workout/workout_detail_page.dart';

enum CalendarViewMode { month, year }

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  CalendarViewMode _viewMode = CalendarViewMode.month;

  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  
  // Reținem anul selectat curent
  int _selectedYear = DateTime.now().year;

  // { Data: [Lista de antrenamente] }
  Map<DateTime, List<dynamic>> _workoutsByDay = {};

  @override
  void initState() {
    super.initState();
    final acum = DateTime.now();
    _selectedDay = DateTime(acum.year, acum.month, acum.day);
    _loadWorkoutsHistory();
  }

  void _loadWorkoutsHistory() {
    final Map<DateTime, List<dynamic>> groupedWorkouts = {};

    for (var value in DatabaseService.logsBox.values) {
      final workout = WorkoutLog.fromMap(value as Map);

      if (workout.endTime != null && workout.status == WorkoutStatus.finished) {
        final dateKey = DateTime(
          workout.endTime!.year,
          workout.endTime!.month,
          workout.endTime!.day,
        );

        if (groupedWorkouts[dateKey] == null) {
          groupedWorkouts[dateKey] = [];
        }
        groupedWorkouts[dateKey]!.add(workout);
      }
    }

    setState(() {
      _workoutsByDay = groupedWorkouts;
    });
  }

  List<dynamic> _getWorkoutsForDay(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    return _workoutsByDay[normalizedDay] ?? [];
  }

  // 🆕 Calculează câte antrenamente au fost finalizate în anul selectat
  int _getWorkoutsCountForYear(int year) {
    int count = 0;
    _workoutsByDay.forEach((date, list) {
      if (date.year == year) {
        count += list.length;
      }
    });
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedEvents = _getWorkoutsForDay(_selectedDay ?? _focusedDay);

    // 🆕 Generăm o listă mai compactă de ani (de la acum 3 ani până la anul curent)
    final int currentYear = DateTime.now().year;
    final List<int> availableYears = List.generate(4, (index) => (currentYear - 3) + index);

    final int workoutsCompletedThisYear = _getWorkoutsCountForYear(_selectedYear);

    return Scaffold(
      appBar: AppBar(
        title: Theme(
          data: theme.copyWith(
            hoverColor: Colors.transparent,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _selectedYear,
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: theme.colorScheme.primary,
                size: 20,
              ),
              elevation: 3,
              // 🆕 Limităm înălțimea meniului pentru a forța scroll-ul în loc să acopere ecranul
              menuMaxHeight: 200,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
              dropdownColor: theme.colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
              onChanged: (int? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedYear = newValue;
                    _focusedDay = DateTime(_selectedYear, 1, 1);
                    _selectedDay = DateTime(_selectedYear, 1, 1);
                  });
                }
              },
              items: availableYears.map<DropdownMenuItem<int>>((int year) {
                return DropdownMenuItem<int>(
                  value: year,
                  child: Text('$year  '),
                );
              }).toList(),
            ),
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(_viewMode == CalendarViewMode.month ? Icons.grid_view_rounded : Icons.calendar_month_outlined),
            tooltip: _viewMode == CalendarViewMode.month ? 'Switch to Year View' : 'Switch to Month View',
            onPressed: () {
              setState(() {
                _viewMode = _viewMode == CalendarViewMode.month ? CalendarViewMode.year : CalendarViewMode.month;
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 🆕 Statistică dinamică afișată elegant deasupra gridului
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: context.bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.borderMuted),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.emoji_events_outlined, color: context.text, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Workouts completed in $_selectedYear',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: context.text,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '$workoutsCompletedThisYear 🔥',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // --- COMPONENTA DE CALENDAR (MONTH / YEAR) ---
          Expanded(
            flex: _viewMode == CalendarViewMode.month ? 0 : 3,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _viewMode == CalendarViewMode.month
                  ? _buildMonthCalendar(theme)
                  : _buildYearVerticalHeatmap(theme),
            ),
          ),

          const SizedBox(height: 4),
          Divider(color: theme.colorScheme.primary.withOpacity(0.2), indent: 16, endIndent: 16),

          // --- SECȚIUNEA DETALII ANTRENAMENTE ZI SELECTATĂ ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Workouts on: ${formatFriendlyDate(_selectedDay)}',
                style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          Expanded(
            flex: 2,
            child: selectedEvents.isEmpty
                ? Center(
                    child: Text(
                      'No workouts recorded for this day. 🛌',
                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 14),
                    ),
                  )
                : ListView.builder(
                    itemCount: selectedEvents.length,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    itemBuilder: (context, index) {
                      final workout = selectedEvents[index] as WorkoutLog;

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        elevation: 0,
                        color: theme.colorScheme.surfaceContainerLow,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.3)),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                            child: Icon(Icons.fitness_center, color: theme.colorScheme.primary, size: 20),
                          ),
                          title: Text(
                            workout.routineTitle,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          subtitle: Text(
                            '${workout.exercises.length} Exercises completed',
                            style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                          ),
                          trailing: const Icon(Icons.chevron_right, size: 20),
                          onTap: () {
                            dynamic correctLogKey;

                            for (var entry in DatabaseService.logsBox.toMap().entries) {
                              final dbLog = WorkoutLog.fromMap(entry.value as Map);
                              if (dbLog.startTime.millisecondsSinceEpoch == workout.startTime.millisecondsSinceEpoch) {
                                correctLogKey = entry.key;
                                break;
                              }
                            }

                            if (correctLogKey != null) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => WorkoutDetailPage(
                                    logKey: correctLogKey,
                                    log: workout,
                                  ),
                                ),
                              );
                            } else {
                              TopToast.show(context, 'Error: Workout log key not found.', type: ToastType.error);
                            }
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthCalendar(ThemeData theme) {
    return TableCalendar(
      key: const ValueKey('month_view'),
      startingDayOfWeek: StartingDayOfWeek.monday,
      firstDay: DateTime.utc(2020, 1, 1),
      lastDay: DateTime.utc(2030, 12, 31),
      focusedDay: _focusedDay,
      calendarFormat: _calendarFormat,
      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
      eventLoader: _getWorkoutsForDay,
      onDaySelected: (selectedDay, focusedDay) {
        setState(() {
          _selectedDay = selectedDay;
          _focusedDay = focusedDay;
          _selectedYear = selectedDay.year;
        });
      },
      onFormatChanged: (format) {
        setState(() {
          _calendarFormat = format;
        });
      },
      onPageChanged: (focusedDay) {
        setState(() {
          _focusedDay = focusedDay;
          _selectedYear = focusedDay.year; 
        });
      },
      calendarStyle: CalendarStyle(
        todayDecoration: BoxDecoration(
          color: theme.colorScheme.primary.withOpacity(0.3),
          shape: BoxShape.circle,
        ),
        selectedDecoration: BoxDecoration(
          color: theme.colorScheme.primary,
          shape: BoxShape.circle,
        ),
        markersMaxCount: 1,
        markerDecoration: BoxDecoration(
          color: theme.colorScheme.secondary,
          shape: BoxShape.circle,
        ),
      ),
      headerStyle: HeaderStyle(
        formatButtonDecoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.primary.withOpacity(0.5)),
          borderRadius: BorderRadius.circular(12),
        ),
        formatButtonTextStyle: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
        titleCentered: true,
      ),
    );
  }

  Widget _buildYearVerticalHeatmap(ThemeData theme) {
    final currentYear = _selectedYear;

    return GridView.builder(
      key: ValueKey('year_view_vertical_$currentYear'), 
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 12,
        childAspectRatio: 0.72,
      ),
      itemCount: 12,
      itemBuilder: (context, monthIndex) {
        final month = monthIndex + 1;
        final daysInMonth = DateTime(currentYear, month + 1, 0).day;
        final monthName = _getMonthName(month);

        final firstDayWeekday = DateTime(currentYear, month, 1).weekday;
        final int emptySpacesBefore = firstDayWeekday - 1;

        return Column(
          children: [
            Text(
              monthName,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  crossAxisSpacing: 2,
                  mainAxisSpacing: 2,
                ),
                itemCount: daysInMonth + emptySpacesBefore,
                itemBuilder: (context, index) {
                  if (index < emptySpacesBefore) {
                    return const SizedBox.shrink();
                  }

                  final day = index - emptySpacesBefore + 1;
                  final currentCheckDay = DateTime(currentYear, month, day);

                  final workouts = _getWorkoutsForDay(currentCheckDay);
                  final bool hasWorkout = workouts.isNotEmpty;
                  final bool isSelected = isSameDay(_selectedDay, currentCheckDay);

                  Color boxColor = theme.colorScheme.onSurfaceVariant.withOpacity(0.15);
                  if (hasWorkout) {
                    boxColor = theme.colorScheme.primary;
                  }

                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedDay = currentCheckDay;
                      });
                    },
                    borderRadius: BorderRadius.circular(2),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        color: boxColor,
                        borderRadius: BorderRadius.circular(2),
                        border: Border.all(
                          color: isSelected ? theme.colorScheme.secondary : Colors.transparent,
                          width: 1.0,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }
}