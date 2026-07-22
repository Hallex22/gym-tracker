import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:gym_tracker/services/database_service.dart';
import 'package:gym_tracker/services/stats_service.dart';
import 'package:gym_tracker/theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../enums/enums.dart';
import '../../../models/models.dart';
import '../../widgets/top_toast.dart';

enum ChartMetric { est1RM, maxWeight, totalVolume }

class ExerciseDetailPage extends StatefulWidget {
  final Exercise exercise;

  const ExerciseDetailPage({super.key, required this.exercise});

  @override
  State<ExerciseDetailPage> createState() => _ExerciseDetailPageState();
}

class _ExerciseDetailPageState extends State<ExerciseDetailPage> {
  ChartMetric _selectedMetric = ChartMetric.est1RM;

  // --- METODĂ DESCHIDERE URL (MUSCLE WIKI) ---
  Future<void> _launchSourceUrl(BuildContext context) async {
    final Uri url = Uri.parse(widget.exercise.sourceUrl);
    try {
      await launchUrl(url, mode: LaunchMode.inAppBrowserView);
    } catch (e) {
      if (!mounted) return;
      TopToast.show(context, 'Could not open the link', type: ToastType.warning);
    }
  }

  // --- CULORI DINAMICE DIFICULTATE ---
  Color _getDifficultyColor(Difficulty diff, ThemeData theme) {
    switch (diff.name.toLowerCase()) {
      case 'beginner':
        return Colors.green;
      case 'intermediate':
        return Colors.orange;
      case 'advanced':
      case 'expert':
        return Colors.red;
      default:
        return theme.colorScheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unit = DatabaseService.globalUnit;
    final prs = StatsService.getPersonalRecords(widget.exercise.id);
    final history = StatsService.getExerciseHistory(widget.exercise.id);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.exercise.name),
          centerTitle: true,
          actions: [
            IconButton(
              icon: Icon(Icons.open_in_new_rounded, color: theme.colorScheme.primary, size: 22),
              tooltip: 'Open in Muscle Wiki',
              onPressed: () => _launchSourceUrl(context),
            ),
          ],
          bottom: TabBar(
            indicatorColor: theme.colorScheme.primary,
            labelColor: theme.colorScheme.primary,
            unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
            indicatorSize: TabBarIndicatorSize.tab,
            tabs: const [
              Tab(text: 'About', icon: Icon(Icons.info_outline, size: 20)),
              Tab(text: 'Instructions', icon: Icon(Icons.format_list_numbered_rounded, size: 20)),
              Tab(text: 'History & PRs', icon: Icon(Icons.emoji_events_outlined, size: 20)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildAboutTab(context, theme),
            _buildInstructionsTab(theme),
            _buildHistoryAndPRsTab(theme, prs, unit, history),
          ],
        ),
      ),
    );
  }

  // ==================== TAB 1: ABOUT ====================
  Widget _buildAboutTab(BuildContext context, ThemeData theme) {
    final primaryMuscle = widget.exercise.primaryMuscles.isNotEmpty ? widget.exercise.primaryMuscles.first : null;
    final secondaryMuscles = widget.exercise.secondaryMuscles;
    final tertiaryMuscles = widget.exercise.tertiaryMuscles;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCoverImage(theme),
          const SizedBox(height: 20),
          Text(
            'Exercise Profile',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
          ),
          const SizedBox(height: 10),
          Card(
            elevation: 2,
            color: context.bg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: context.borderMuted),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  if (primaryMuscle != null)
                    _buildProfileRow(
                      theme,
                      icon: Icons.adjust_rounded,
                      label: 'Target Muscle',
                      value: primaryMuscle.group.name.toUpperCase(),
                      valueColor: theme.colorScheme.primary,
                    ),
                  _buildProfileRow(
                    theme,
                    icon: Icons.fitness_center_rounded,
                    label: 'Equipment',
                    value: widget.exercise.equipment.name.replaceAll('_', ' ').toUpperCase(),
                  ),
                  if (widget.exercise.mechanic != null)
                    _buildProfileRow(
                      theme,
                      icon: Icons.settings_accessibility_rounded,
                      label: 'Mechanics',
                      value: widget.exercise.mechanic!.name.toUpperCase(),
                    ),
                  if (widget.exercise.force != null)
                    _buildProfileRow(
                      theme,
                      icon: Icons.bolt_rounded,
                      label: 'Force Type',
                      value: widget.exercise.force!.name.toUpperCase(),
                    ),
                  _buildProfileRow(
                    theme,
                    icon: Icons.speed_rounded,
                    label: 'Difficulty',
                    value: widget.exercise.difficulty.name.toUpperCase(),
                    valueColor: _getDifficultyColor(widget.exercise.difficulty, theme),
                  ),
                  if (widget.exercise.grips.isNotEmpty)
                    _buildProfileRow(
                      theme,
                      icon: Icons.front_hand_outlined,
                      label: 'Required Grip',
                      value: widget.exercise.grips.map((g) => g.name.toUpperCase()).join(', '),
                      isLast: true,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (secondaryMuscles.isNotEmpty || tertiaryMuscles.isNotEmpty) ...[
            Text(
              'Anatomy & Muscle Recruitment',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
            ),
            const SizedBox(height: 10),
            if (secondaryMuscles.isNotEmpty) ...[
              Text(
                'Secondary Muscles:',
                style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: secondaryMuscles.map((muscle) {
                  return _buildMuscleBadge(context, muscle.label.toUpperCase(), isSecondary: true);
                }).toList(),
              ),
              const SizedBox(height: 14),
            ],
            if (tertiaryMuscles.isNotEmpty) ...[
              Text(
                'Stabilizers / Tertiary:',
                style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: tertiaryMuscles.map((muscle) {
                  return _buildMuscleBadge(context, muscle.label.toUpperCase(), isSecondary: false);
                }).toList(),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }

  // ==================== TAB 2: INSTRUCTIONS ====================
  Widget _buildInstructionsTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Step-by-Step Guide',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
          ),
          const SizedBox(height: 16),
          if (widget.exercise.instructions.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40.0),
                child: Text(
                  'No instructions available for this exercise.',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.exercise.instructions.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: theme.colorScheme.primary.withOpacity(0.15),
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(fontSize: 12, color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          widget.exercise.instructions[index],
                          style: TextStyle(fontSize: 14, height: 1.5, color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          const SizedBox(height: 12),
          Center(
            child: TextButton.icon(
              onPressed: () => _launchSourceUrl(context),
              icon: const Icon(Icons.language, size: 16),
              label: const Text('Read full breakdown on MuscleWiki',
                  style: TextStyle(fontSize: 13, decoration: TextDecoration.underline)),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== TAB 3: PERSONAL RECORDS & HISTORY ====================
  Widget _buildHistoryAndPRsTab(
    ThemeData theme,
    ExercisePRs prs,
    UnitSystem unit,
    List<MapEntry<WorkoutLog, LoggedExercise>> history,
  ) {
    String formatValue(double valueInKg) {
      if (valueInKg == 0.0) return '—';
      final double displayValue = unit == UnitSystem.lbs ? valueInKg * 2.2046226218 : valueInKg;
      final formattedNum = displayValue % 1 == 0 ? displayValue.toStringAsFixed(0) : displayValue.toStringAsFixed(1);
      return '$formattedNum ${unit.label}';
    }

    String formatDate(DateTime date) {
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Personal Records 🏆',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
          ),
          const SizedBox(height: 6),
          Text(
            'Your lifetime achievements for this exercise.',
            style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),

          // 1. Grila PR-uri (Carduri Fixe)
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.4,
            children: [
              _buildPRCard(
                  theme: theme,
                  title: 'Heaviest Weight',
                  value: formatValue(prs.heaviestWeight),
                  icon: Icons.fitness_center_rounded,
                  color: Colors.redAccent),
              _buildPRCard(
                  theme: theme,
                  title: 'Best Est. 1RM',
                  value: formatValue(prs.best1RM),
                  icon: Icons.star_rounded,
                  color: Colors.amber),
              _buildPRCard(
                  theme: theme,
                  title: 'Best Set Volume',
                  value: formatValue(prs.bestSetVolume),
                  icon: Icons.view_headline_rounded,
                  color: Colors.blueAccent),
              _buildPRCard(
                  theme: theme,
                  title: 'Best Session Vol.',
                  value: formatValue(prs.bestSessionVolume),
                  icon: Icons.analytics_rounded,
                  color: Colors.purpleAccent),
            ],
          ),

          const SizedBox(height: 28),

          // 2. Sectiunea Graficului de Progres
          Text(
            'Progress Analytics 📈',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
          ),
          const SizedBox(height: 10),

          // Chip-uri de comutare metrica
          Row(
            children: [
              _buildMetricChip(theme, 'Est. 1RM', ChartMetric.est1RM),
              const SizedBox(width: 8),
              _buildMetricChip(theme, 'Max Weight', ChartMetric.maxWeight),
              const SizedBox(width: 8),
              _buildMetricChip(theme, 'Total Volume', ChartMetric.totalVolume),
            ],
          ),
          const SizedBox(height: 16),

          // Container Grafic Dinamic
          _buildAnalyticsChart(theme, history, unit),

          const SizedBox(height: 32),

          // 3. Istoricul Sesiunilor
          Text(
            'Recent Performance History',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
          ),
          const SizedBox(height: 12),

          if (history.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.3)),
                boxShadow: context.cardShadow,
              ),
              child: const Row(
                children: [
                  Icon(Icons.history_toggle_off_rounded, color: Colors.grey),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Workout history logs will appear here once you complete sessions with this exercise.',
                      style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.3),
                    ),
                  ),
                ],
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: history.length,
              itemBuilder: (context, index) {
                final entry = history[index];
                final WorkoutLog log = entry.key;
                final LoggedExercise loggedExercise = entry.value;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 1,
                  color: theme.colorScheme.surfaceContainerLow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.3)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                log.routineTitle,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              formatDate(log.startTime),
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Divider(height: 1, color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
                        const SizedBox(height: 8),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: loggedExercise.sets.length,
                          itemBuilder: (context, setIndex) {
                            final set = loggedExercise.sets[setIndex];
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              child: Row(
                                children: [
                                  Container(
                                    width: 20,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      '${setIndex + 1}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${formatValue(set.weight)}  ×  ${set.reps} reps',
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // ==================== WIDGETS GRAFIC & HELPERE ====================

  Widget _buildMetricChip(ThemeData theme, String label, ChartMetric metric) {
    final isSelected = _selectedMetric == metric;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant,
        ),
      ),
      selected: isSelected,
      elevation: 1,
      selectedColor: theme.colorScheme.primary,
      backgroundColor: theme.colorScheme.surfaceContainerLow,
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? Colors.transparent : theme.colorScheme.outlineVariant.withOpacity(0.3),
        ),
      ),
      onSelected: (bool selected) {
        if (selected) {
          setState(() {
            _selectedMetric = metric;
          });
        }
      },
    );
  }

  Widget _buildAnalyticsChart(
    ThemeData theme,
    List<MapEntry<WorkoutLog, LoggedExercise>> history,
    UnitSystem unit,
  ) {
    if (history.isEmpty) {
      return Container(
        height: 180,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.3)),
          boxShadow: context.cardShadow,
        ),
        child: Text(
          'Log sessions to unlock chart insights.',
          style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
        ),
      );
    }

    // Istoricul vine de obicei descrescător, deci îl inversăm pentru grafic (stânga -> dreapta)
    final chronHistory = history.reversed.toList();
    final List<FlSpot> spots = [];

    for (int i = 0; i < chronHistory.length; i++) {
      final entry = chronHistory[i];
      final LoggedExercise loggedEx = entry.value;

      double valInKg = 0;
      switch (_selectedMetric) {
        case ChartMetric.est1RM:
          for (var set in loggedEx.sets) {
            final e1rm = set.reps > 0 ? set.weight * (1 + (set.reps / 30.0)) : set.weight;
            if (e1rm > valInKg) valInKg = e1rm;
          }
          break;

        case ChartMetric.maxWeight:
          for (var set in loggedEx.sets) {
            if (set.weight > valInKg) valInKg = set.weight;
          }
          break;

        case ChartMetric.totalVolume:
          for (var set in loggedEx.sets) {
            valInKg += (set.weight * set.reps);
          }
          break;
      }

      final double displayVal = unit == UnitSystem.lbs ? valInKg * 2.2046226218 : valInKg;
      spots.add(FlSpot(i.toDouble(), double.parse(displayVal.toStringAsFixed(1))));
    }

    // --- CALCUL DINAMIC INTERVAL AXA X ---
    // Vrem să afișăm maxim ~5 etichete de dată pe axa X pentru a preveni înghesuirea.
    final double computedInterval = (chronHistory.length / 4).ceilToDouble().clamp(1.0, double.infinity);

    return Container(
      height: 220,
      padding: const EdgeInsets.only(right: 20, left: 12, top: 20, bottom: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.3)),
        boxShadow: context.cardShadow,
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(
              color: theme.colorScheme.outlineVariant.withOpacity(0.2),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: TextStyle(
                      fontSize: 10,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                // Aplicăm intervalul dinamic calculat:
                interval: computedInterval,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  // Afișăm doar etichetele care se potrivesc cu pasul calculat și prima/ultima din listă
                  if (idx >= 0 && idx < chronHistory.length) {
                    final date = chronHistory[idx].key.startTime;
                    return Padding(
                      padding: const EdgeInsets.only(top: 6.0),
                      child: Text(
                        '${date.day}/${date.month}',
                        style: TextStyle(
                          fontSize: 10,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  }
                  return const SizedBox();
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: theme.colorScheme.primary,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                  radius: 4,
                  color: theme.colorScheme.primary,
                  strokeWidth: 2,
                  strokeColor: theme.colorScheme.surface,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                color: theme.colorScheme.primary.withOpacity(0.12),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  return LineTooltipItem(
                    '${spot.y} ${unit.label}',
                    TextStyle(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  );
                }).toList();
              },
            ),
          ),
        ),
      ),
    );
  }

  // ==================== WIDGETS PROFILE / COVER / BADGES ====================

  Widget _buildCoverImage(ThemeData theme) {
    if (widget.exercise.coverImage != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.asset(
          'assets/${widget.exercise.coverImage}',
          height: 200,
          width: double.infinity,
          fit: BoxFit.cover,
        ),
      );
    }
    return Container(
      height: 160,
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.15)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.fitness_center, size: 48, color: theme.colorScheme.primary.withOpacity(0.4)),
          const SizedBox(height: 8),
          Text(
            'No preview image available',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileRow(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    bool isLast = false,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10.0),
          child: Row(
            children: [
              Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: valueColor ?? theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
        if (!isLast) Divider(height: 1, color: context.primary.withOpacity(0.1)),
      ],
    );
  }

  Widget _buildPRCard({
    required ThemeData theme,
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 1,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: context.borderMuted),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style:
                      TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurfaceVariant),
                ),
                Icon(icon, size: 18, color: color),
              ],
            ),
            Text(
              value,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMuscleBadge(BuildContext context, String label, {required bool isSecondary}) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isSecondary
            ? theme.colorScheme.surfaceContainerLow
            : theme.colorScheme.surfaceContainerLowest.withOpacity(0.4),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isSecondary
              ? theme.colorScheme.onSurfaceVariant.withOpacity(0.15)
              : theme.colorScheme.onSurfaceVariant.withOpacity(0.05),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: isSecondary ? FontWeight.w600 : FontWeight.normal,
          color: isSecondary ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
