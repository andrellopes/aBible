import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io' show Platform, exit;
import 'package:provider/provider.dart';
import '../services/themes/theme_manager.dart';
import '../services/reading_position_service.dart';
import 'settings_screen.dart';
import 'bible_reader_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeManager>(
      builder: (context, themeManager, _) {
        return Scaffold(
          backgroundColor: themeManager.backgroundColor,
          drawer: _BibleDrawer(),
          bottomNavigationBar: null, // Banner removido - apenas na aba "Mais"
          body: SafeArea(
            child: _MenuView(),
          ),
        );
      },
    );
  }
}

class _MenuView extends StatefulWidget {
  const _MenuView();

  @override
  State<_MenuView> createState() => _MenuViewState();
}

class _MenuViewState extends State<_MenuView> {
  ReadingPosition? _lastPosition;

  @override
  void initState() {
    super.initState();
    _loadLastPosition();
  }

  Future<void> _loadLastPosition() async {
    final position = await ReadingPositionService.getLastReadingPosition();
    if (mounted) {
      setState(() {
        _lastPosition = position;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeManager>(
      builder: (context, themeManager, _) {
        return Column(
          children: [
            // Header com menu
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Builder(
                    builder: (context) => IconButton(
                      icon: Icon(
                        Icons.menu,
                        color: themeManager.primaryColor,
                        size: 28,
                      ),
                      onPressed: () => Scaffold.of(context).openDrawer(),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        'Bible Reader',
                        style: TextStyle(
                          color: themeManager.primaryTextColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 40), // espaço para equilibrar layout
                ],
              ),
            ),
            // Conteúdo principal
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 24),
                    // Área de Leitura da Bíblia
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: themeManager.surfaceColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: themeManager.cardColor.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.menu_book, color: themeManager.primaryColor, size: 28),
                              const SizedBox(width: 8),
                              Text(
                                'Leitura da Bíblia', 
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: themeManager.primaryTextColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          
                          // Botão "Continuar Leitura" (se houver posição salva)
                          if (_lastPosition != null && _lastPosition!.isRecent) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: themeManager.primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: themeManager.primaryColor.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.bookmark_added,
                                    color: themeManager.primaryColor,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Última leitura:',
                                          style: TextStyle(
                                            color: themeManager.secondaryTextColor,
                                            fontSize: 12,
                                          ),
                                        ),
                                        Text(
                                          _lastPosition!.displayText,
                                          style: TextStyle(
                                            color: themeManager.primaryTextColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        Text(
                                          _lastPosition!.timeAgoText,
                                          style: TextStyle(
                                            color: themeManager.secondaryTextColor,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.play_arrow),
                                label: const Text('Continuar Leitura'),
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => const BibleReaderScreen(),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: themeManager.primaryColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                          
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.menu_book),
                              label: const Text('Ler Bíblia'),
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => const BibleReaderScreen(),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: themeManager.primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _BibleDrawer extends StatelessWidget {
  _BibleDrawer();

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeManager>(
      builder: (context, themeManager, _) {
        return Drawer(
          backgroundColor: themeManager.backgroundColor,
          child: SafeArea(
            child: Column(
              children: [
                // Header do Drawer
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        themeManager.primaryColor,
                        themeManager.primaryColor.withOpacity(0.8),
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        child: const Icon(
                          Icons.menu_book,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Bible Reader',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Leia a Palavra de Deus',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                // Items do Menu
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [
                      _DrawerItem(
                        icon: Icons.menu_book,
                        title: 'Ler Bíblia',
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const BibleReaderScreen(),
                            ),
                          );
                        },
                      ),
                      _DrawerItem(
                        icon: Icons.settings,
                        title: 'Configurações',
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const SettingsScreen(),
                            ),
                          );
                        },
                      ),
                      const Divider(),
                      _DrawerItem(
                        icon: Icons.info_outline,
                        title: 'Sobre',
                        onTap: () {
                          Navigator.of(context).pop();
                          showDialog(
                            context: context,
                            builder: (context) => const AboutDialog(),
                          );
                        },
                      ),
                      _DrawerItem(
                        icon: Icons.exit_to_app,
                        title: 'Sair',
                        onTap: () {
                          if (Platform.isAndroid) {
                            SystemNavigator.pop();
                          } else {
                            exit(0);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeManager>(
      builder: (context, themeManager, _) {
        return ListTile(
          leading: Icon(
            icon,
            color: themeManager.primaryColor,
          ),
          title: Text(
            title,
            style: TextStyle(
              color: themeManager.primaryTextColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          onTap: onTap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        );
      },
    );
  }
}
