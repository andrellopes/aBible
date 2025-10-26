import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/themes/theme_manager.dart';
import '../services/navigation_provider.dart';
import 'bible_reader_screen.dart';
import 'bookmarks_screen.dart';
import 'settings_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  late final List<Widget> _screens;
  
  @override
  void initState() {
    super.initState();
    _screens = [
      const BibleReaderScreen(),
      const BookmarksScreen(),
      const SettingsScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeManager, NavigationProvider>(
      builder: (context, themeManager, navigationProvider, _) {
        return Scaffold(
          backgroundColor: themeManager.backgroundColor,
          body: PageView(
            controller: navigationProvider.pageController,
            onPageChanged: (index) {
              navigationProvider.setIndex(index);
            },
            children: _screens,
          ),
          bottomNavigationBar: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BottomNavigationBar(
                currentIndex: navigationProvider.currentIndex,
                onTap: (index) {
                  navigationProvider.animateToIndex(index);
                },
                backgroundColor: themeManager.surfaceColor,
                selectedItemColor: themeManager.primaryColor,
                unselectedItemColor: themeManager.secondaryTextColor,
                selectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w400,
                  fontSize: 11,
                ),
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.menu_book),
                    activeIcon: Icon(Icons.menu_book, size: 28),
                    label: 'Bíblia',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.bookmark_outline),
                    activeIcon: Icon(Icons.bookmark, size: 28),
                    label: 'Marcações',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.settings_outlined),
                    activeIcon: Icon(Icons.settings, size: 28),
                    label: 'Configurações',
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
