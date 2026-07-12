import 'package:flutter/material.dart';
import '../screens/home_page.dart';
import '../screens/profile/profile_page.dart';

class MainNavigationHub extends StatefulWidget {
  const MainNavigationHub({super.key});

  @override
  State<MainNavigationHub> createState() => _MainNavigationHubState();
}

class _MainNavigationHubState extends State<MainNavigationHub> {
  int _currentIndex = 0;

  // Lista ecranelor prin care navigăm
  final List<Widget> _screens = [
    const HomePage(),
    const ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Afișează ecranul corespunzător indexului curent
      body: _screens[_currentIndex],

      // Bara de navigare din partea de jos în stil modern, curat
      bottomNavigationBar: Container(
        // 💡 Aici aplicăm stilizarea pentru border
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              // Folosim culoarea outlineVariant sau primary cu opacitate, să fie discretă și modernă
              color:
                  Theme.of(context).colorScheme.primary.withOpacity(0.2),
              width: 1.0, // Grosimea liniei de sus
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          selectedItemColor: Theme.of(context).colorScheme.primary,
          unselectedItemColor: Theme.of(context).colorScheme.onSurfaceVariant,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          // 💡 IMPORTANT: Scoatem shadow-ul nativ (elevation) ca să se vadă doar border-ul nostru curat
          elevation: 0,
          // Opțional, forțăm fundalul să fie transparent ca să preia culoarea containerului părinte
          backgroundColor: Colors.transparent,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.fitness_center),
              label: 'Workout',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
