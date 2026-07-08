import 'package:flutter/material.dart';
import '../main.dart';
import '../models/models.dart';
import 'active_workout_page.dart';
import 'create_routine_page.dart'; // Importăm noul ecran

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Routine> _routines = [];

  @override
  void initState() {
    super.initState();
    _loadRoutines();
  }

  void _loadRoutines() {
    final routines =
        routinesBox.values.map((e) => Routine.fromMap(e as Map)).toList();
    setState(() {
      _routines = routines;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Heavy - My Routines',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _routines.isEmpty
          ? const Center(child: Text('No routines found. Create one!'))
          : ListView.builder(
              itemCount: _routines.length,
              itemBuilder: (context, index) {
                final routine = _routines[index];
                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  elevation: 2,
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    title: Text(routine.title,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6.0),
                      child: Text(
                          '${routine.exercises.length} exercises • ${routine.description ?? ''}',
                          style: const TextStyle(color: Colors.grey)),
                    ),
                    trailing: const CircleAvatar(
                      backgroundColor: Colors.green,
                      child: Icon(Icons.play_arrow, color: Colors.white),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              ActiveWorkoutPage(routine: routine),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
      // Butonul în stil Heavy jos în dreapta pentru a adăuga o rutină nouă
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          // Navigăm la pagina de creare și așteptăm să se întoarcă
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreateRoutinePage()),
          );
          // Când utilizatorul salvează și revine, reîncărcăm lista de pe ecran
          _loadRoutines();
        },
        label: const Text('Create Routine',
            style: TextStyle(fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.add),
        backgroundColor: Colors.blueAccent,
      ),
    );
  }
}
