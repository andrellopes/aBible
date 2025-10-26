import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:provider/provider.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'services/themes/theme_manager.dart';
import 'services/font_manager.dart';
import 'services/purchase_service.dart';
import 'services/bookmarks_provider.dart';
import 'services/navigation_provider.dart';
import 'screens/main_navigation_screen.dart';
import 'widgets/database_initialization_screen.dart';
import 'database/database_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicialização do banco para desktop (Windows, Linux, macOS)
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  debugPrint('🚀 Iniciando aplicação Bible Reader...');

  // Respeitar configuração de manter tela ligada ao abrir o app
  final prefs = await SharedPreferences.getInstance();
  final keepScreenOn = prefs.getBool('keepScreenOn') ?? true;
  if (keepScreenOn) {
    WakelockPlus.enable();
  } else {
    WakelockPlus.disable();
  }

  // Inicializa Google Mobile Ads  
  await MobileAds.instance.initialize();

  // Inicializa compras e status PRO antes do ThemeManager
  final purchaseService = PurchaseService();
  await purchaseService.loadPurchaseStatusSync();

  // Inicializar ThemeManager com status PRO real
  final themeManager = ThemeManager();
  themeManager.setPremiumStatusSync(purchaseService.isProVersion);
  await themeManager.init();

  // Inicializar FontManager
  final fontManager = FontManager();
  await fontManager.initialize();

  // Inicializar BookmarksProvider
  final bookmarksProvider = BookmarksProvider();

  // Inicializar NavigationProvider
  final navigationProvider = NavigationProvider();

  runApp(MyApp(
    themeManager: themeManager, 
    purchaseService: purchaseService,
    fontManager: fontManager,
    bookmarksProvider: bookmarksProvider,
    navigationProvider: navigationProvider,
  ));
}

class MyApp extends StatefulWidget {
  final ThemeManager themeManager;
  final PurchaseService purchaseService;
  final FontManager fontManager;
  final BookmarksProvider bookmarksProvider;
  final NavigationProvider navigationProvider;
  
  const MyApp({
    super.key, 
    required this.themeManager, 
    required this.purchaseService,
    required this.fontManager,
    required this.bookmarksProvider,
    required this.navigationProvider,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isDatabaseInitialized = false;
  bool _isCheckingDatabase = true;

  @override
  void initState() {
    super.initState();
    _checkDatabaseInitialization();
  }

  Future<void> _checkDatabaseInitialization() async {
    try {
      // Verificar se o sistema está inicializado
      final dbHelper = DatabaseHelper();
      
      if (dbHelper.isInitialized) {
        // Se já está inicializado, verificar se consegue acessar uma Bíblia
        await dbHelper.bibleManager.openBibleVersion('NVI');
        
        setState(() {
          _isDatabaseInitialized = true;
          _isCheckingDatabase = false;
        });
      } else {
        // Se não está inicializado, precisa inicializar
        setState(() {
          _isDatabaseInitialized = false;
          _isCheckingDatabase = false;
        });
      }
    } catch (e) {
      // Se der erro, precisa inicializar
      setState(() {
        _isDatabaseInitialized = false;
        _isCheckingDatabase = false;
      });
    }
  }

  void _onDatabaseInitializationComplete() {
    setState(() {
      _isDatabaseInitialized = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: widget.themeManager),
        ChangeNotifierProvider.value(value: widget.purchaseService),
        ChangeNotifierProvider.value(value: widget.fontManager),
        ChangeNotifierProvider.value(value: widget.bookmarksProvider),
        ChangeNotifierProvider.value(value: widget.navigationProvider),
      ],
      child: Consumer<ThemeManager>(
        builder: (context, themeManager, child) {
          return MaterialApp(
            title: 'Bible Reader',
            debugShowCheckedModeBanner: false,
            theme: themeManager.currentTheme.toThemeData().copyWith(
              // Personalização adicional para o app bíblico
              textTheme: themeManager.currentTheme.toThemeData().textTheme.copyWith(
                headlineLarge: TextStyle(
                  color: themeManager.primaryTextColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 32,
                ),
                headlineMedium: TextStyle(
                  color: themeManager.primaryTextColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                ),
                titleLarge: TextStyle(
                  color: themeManager.primaryTextColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 20,
                ),
                bodyLarge: TextStyle(
                  color: themeManager.primaryTextColor,
                  fontSize: 16,
                ),
                bodyMedium: TextStyle(
                  color: themeManager.primaryTextColor,
                  fontSize: 14,
                ),
                bodySmall: TextStyle(
                  color: themeManager.secondaryTextColor,
                  fontSize: 12,
                ),
              ),
            ),
            home: SafeArea(
              child: _isCheckingDatabase
                  ? Scaffold(
                      backgroundColor: themeManager.backgroundColor,
                      body: Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            themeManager.primaryColor,
                          ),
                        ),
                      ),
                    )
                  : !_isDatabaseInitialized
                      ? DatabaseInitializationScreen(
                          onComplete: _onDatabaseInitializationComplete,
                        )
                      : const MainNavigationScreen(),
            ),
          );
        },
      ),
    );
  }
}
