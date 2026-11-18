import 'package:flutter/material.dart';
import 'dish_list.dart';
import 'notebook_screen.dart';
import 'settings_screen.dart';
import '../widgets/account_migration_banner.dart';
import '../auth.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      backend.refreshSession().catchError((Object _) {});
    }
  }

  final List<Widget> _screens = [
    const DishListScreen(),
    const NotebookScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width >= 800) {
      return Scaffold(
        body: Column(
          children: [
            const AccountMigrationBanner(),
            Expanded(
              child: Row(
                children: [
                  NavigationRail(
                    extended: true,
                    selectedIndex: _currentIndex,
                    onDestinationSelected: (index) =>
                        setState(() => _currentIndex = index),
                    leading: const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'Tweak',
                        style: TextStyle(fontFamily: 'Noot', fontSize: 32),
                      ),
                    ),
                    destinations: const [
                      NavigationRailDestination(
                        icon: Icon(Icons.restaurant_menu),
                        label: Text('Recipes'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.book_outlined),
                        label: Text('Notebook'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.settings_outlined),
                        label: Text('Settings'),
                      ),
                    ],
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: IndexedStack(
                      index: _currentIndex,
                      children: _screens,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return Scaffold(
      body: Column(
        children: [
          const AccountMigrationBanner(),
          Expanded(
            child: IndexedStack(index: _currentIndex, children: _screens),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.restaurant_menu),
            label: 'Recipes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.book_outlined),
            label: 'Notebook',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
