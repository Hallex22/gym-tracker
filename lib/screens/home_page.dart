import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gym_tracker/enums/workout_status.dart';
import 'package:gym_tracker/screens/routines/routine_detail_page.dart';
import 'package:gym_tracker/screens/routines/routine_form_page.dart';
import '../main.dart';
import '../models/models.dart';
import 'workout/active_workout_page.dart';
import 'package:gym_tracker/widgets/app_buttons.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<MapEntry<dynamic, Routine>> _routineEntries = [];
  WorkoutLog? _activeWorkout;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    final entries = routinesBox.toMap().entries.map((entry) {
      return MapEntry(entry.key, Routine.fromMap(entry.value as Map));
    }).toList();

    WorkoutLog? active;
    for (var value in logsBox.values) {
      final log = WorkoutLog.fromMap(value as Map);
      if (log.status == WorkoutStatus.started) {
        active = log;
        break;
      }
    }

    setState(() {
      _routineEntries = entries;
      _activeWorkout = active;
    });
  }

  void _tryStartWorkout(Routine routine) {
    if (_activeWorkout != null) {
      _showActiveWorkoutAlert();
    } else {
      _navigateToActiveWorkout(routine);
    }
  }

  void _startEmptyWorkout() {
    if (_activeWorkout != null) {
      _showActiveWorkoutAlert();
    } else {
      final emptyRoutine = Routine(
        title: 'Empty Workout',
        description: 'Custom session',
        exercises: [],
      );
      _navigateToActiveWorkout(emptyRoutine);
    }
  }

  void _navigateToActiveWorkout(Routine routine) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => ActiveWorkoutPage(routine: routine)),
    );
    _loadData();
  }

  void _showTopSuccessToast(String message) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) {
        return _TopToastWidget(
          message: message,
          onDismiss: () {
            overlayEntry.remove();
          },
        );
      },
    );

    overlay.insert(overlayEntry);
  }

  void _showActiveWorkoutAlert() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Workout in Progress ⚠️'),
        content: const Text(
            'You already have an active workout session. Please finish or cancel the current session before starting a new one.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          )
        ],
      ),
    );
  }

  // --- DRAWER PENTRU IMPORT ROUTINE ---
  void _showImportRoutineSheet() {
    final TextEditingController codeController = TextEditingController();
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled:
          true, // Permite sheet-ului să se ridice deasupra tastaturii
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context)
                .viewInsets
                .bottom, // Padding dinamic pentru tastatură
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color:
                            theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    'Import Routine 📥',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Paste the code received from your friend to clone their routine structure.',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: codeController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Paste code here...',
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.all(12),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.assignment_returned_outlined),
                        onPressed: () async {
                          final data =
                              await Clipboard.getData(Clipboard.kTextPlain);
                          if (data?.text != null) {
                            codeController.text = data!.text!;
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text('Cancel',
                              style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppFilledButton(
                          label: 'Import',
                          onPressed: () async {
                            final code = codeController.text;
                            final importedRoutine = Routine.fromShareCode(code);

                            if (importedRoutine != null) {
                              await routinesBox.add(importedRoutine.toMap());
                              if (!context.mounted) return;
                              Navigator.pop(context);
                              _loadData();
                              _showTopSuccessToast(
                                  'Successfully imported "${importedRoutine.title}"! 🏋️‍♂️');
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Invalid share code. Please try again! ⚠️'),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                            }
                          },
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
    );
  }

  // --- DRAWER-UL DE JOS PENTRU OPȚIUNI (MODAL BOTTOM SHEET) ---
  void _showRoutineOptionsSheet(
      BuildContext context, Routine routine, dynamic routineKey) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant
                        .withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  child: Text(
                    routine.title,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                ),
                const Divider(),

                // 1. View Routine
                ListTile(
                  leading: Icon(Icons.visibility_outlined,
                      color: Theme.of(context).colorScheme.primary),
                  title: const Text('View Routine'),
                  onTap: () async {
                    Navigator.pop(context);
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RoutineDetailPage(
                            routine: routine, routineKey: routineKey),
                      ),
                    );
                    _loadData();
                  },
                ),

                // 2. Edit Routine
                ListTile(
                  leading: const Icon(Icons.edit_outlined,
                      color: Colors.orangeAccent),
                  title: const Text('Edit Routine'),
                  onTap: () async {
                    Navigator.pop(context);
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RoutineFormPage(
                            routine: routine, routineKey: routineKey),
                      ),
                    );
                    _loadData();
                  },
                ),

                // 3. Share Routine
                ListTile(
                  leading: Icon(Icons.share_outlined,
                      color: Theme.of(context).colorScheme.primary),
                  title: const Text('Share Routine'),
                  subtitle: const Text('Copy share code to clipboard 📋'),
                  onTap: () async {
                    Navigator.pop(context);
                    final shareCode = routine.toShareCode();
                    await Clipboard.setData(ClipboardData(text: shareCode));
                    if (!context.mounted) return;
                    _showTopSuccessToast(
                        '"${routine.title}" code copied successfully! 🦾');
                  },
                ),
                const Divider(),

                // 4. Delete Routine
                ListTile(
                  leading:
                      const Icon(Icons.delete_outline, color: Colors.redAccent),
                  title: const Text('Delete Routine',
                      style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w500)),
                  onTap: () {
                    Navigator.pop(context);
                    _showDeleteConfirmationDialog(
                        context, routineKey, routine.title);
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
  void _showDeleteConfirmationDialog(
      BuildContext context, dynamic routineKey, String title) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Routine? 🚨'),
        content: Text(
            'Are you sure you want to delete "$title"? This will not affect your workout history.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              )),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              await routinesBox.delete(routineKey);
              if (!context.mounted) return;
              Navigator.pop(context);
              _loadData();

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('"$title" deleted.')),
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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('GymTracker'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. ANTRENAMENTUL ÎN DESFĂȘURARE (Dacă există)
              if (_activeWorkout != null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  child: Card(
                    color: Colors.amber.withOpacity(0.12),
                    shape: RoundedRectangleBorder(
                      side: const BorderSide(color: Colors.amber, width: 1.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: const CircleAvatar(
                        backgroundColor: Colors.amber,
                        child: Icon(Icons.fitness_center, color: Colors.black),
                      ),
                      title: const Text('CURRENT WORKOUT',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber)),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(_activeWorkout!.routineTitle,
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios,
                          color: Colors.amber, size: 16),
                      onTap: () {
                        _navigateToActiveWorkout(Routine(
                            title: _activeWorkout!.routineTitle,
                            exercises: []));
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],

              // 2. BUTONUL: START EMPTY WORKOUT
              if (_activeWorkout == null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  child: AppOutlinedButton(
                    label: 'Start Empty Workout',
                    icon: Icons.add,
                    onPressed: _startEmptyWorkout,
                  ),
                ),
              ],

              // 3. SECȚIUNEA DE HEADER PENTRU RUTINE + ACȚIUNI
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Routines',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        // Butonul New Routine redesenat compact pe rând
                        Expanded(
                          flex: 3,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: BorderSide(
                                  color: theme.colorScheme.primary
                                      .withOpacity(0.5)),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: Icon(Icons.playlist_add,
                                color: theme.colorScheme.primary),
                            label: Text(
                              'New Routine',
                              style: TextStyle(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.bold),
                            ),
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        const RoutineFormPage()),
                              );
                              _loadData();
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Noul buton de Import Routine cu logo dedicat (Folder cu Săgeată în jos / Download)
                        Expanded(
                          flex: 2,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: BorderSide(
                                  color: theme.colorScheme.onSurfaceVariant
                                      .withOpacity(0.3)),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: Icon(Icons.folder_zip_outlined,
                                color: theme.colorScheme.onSurfaceVariant),
                            label: Text(
                              'Import',
                              style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600),
                            ),
                            onPressed: _showImportRoutineSheet,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // 4. LISTA DE RUTINE
              if (_routineEntries.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Center(
                      child: Text(
                          'No routines found. Create your first one above!',
                          style: Theme.of(context).textTheme.bodyMedium)),
                )
              else
                ..._routineEntries.map((entry) {
                  final routineKey = entry.key;
                  final routine = entry.value;

                  final String exercisesPreview = routine.exercises.isEmpty
                      ? "No exercises added yet"
                      : routine.exercises.map((e) => e.name).join(', ');

                  return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () async {
                          await Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => RoutineDetailPage(
                                      routine: routine,
                                      routineKey: routineKey)));
                          _loadData();
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
                                      routine.title,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge,
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.more_horiz,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant),
                                    onPressed: () => _showRoutineOptionsSheet(
                                        context, routine, routineKey),
                                  ),
                                ],
                              ),
                              Text(
                                exercisesPreview,
                                style: Theme.of(context).textTheme.bodyMedium,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 16),
                              AppGhostButton(
                                label: 'Start Workout',
                                icon: Icons.play_arrow,
                                onPressed: () => _tryStartWorkout(routine),
                              ),
                            ],
                          ),
                        ),
                      ));
                }),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

// Structura pentru _TopToastWidget rămâne neschimbată...

class _TopToastWidget extends StatefulWidget {
  final String message;
  final VoidCallback onDismiss;

  const _TopToastWidget({required this.message, required this.onDismiss});

  @override
  State<_TopToastWidget> createState() => _TopToastWidgetState();
}

class _TopToastWidgetState extends State<_TopToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    // Configurația animației (durata de intrare/ieșire)
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, -1.5), // Pornește de deasupra ecranului
      end: Offset.zero, // Se oprește în poziția naturală
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack, // Efect elastic discret la coborâre
    ));

    _controller.forward(); // Pornim animația de intrare

    // Programăm dispariția automată după 2.5 secunde
    Future.delayed(const Duration(milliseconds: 2500), () async {
      if (mounted) {
        await _controller.reverse(); // Animație de retragere în sus
        widget.onDismiss();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SlideTransition(
        position: _offsetAnimation,
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16.0, vertical: 14.0),
                decoration: BoxDecoration(
                  // Nuanță modernă de verde emerald închis cu accent vibrant
                  color: const Color(0xFF0F5132),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: const Color(0xFF198754), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle,
                        color: Color(0xFF25D366), size: 22),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        widget.message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
