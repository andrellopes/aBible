import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../services/themes/theme_manager.dart';
import '../widgets/bible_version_selector.dart';
import '../services/purchase_service.dart';
import '../widgets/about_dialog.dart';
import '../widgets/pro_upgrade_dialog.dart';
import '../widgets/font_size_dialog.dart';
import '../widgets/ad_banner.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _keepScreenOn = true;
  bool _isReadingSettingsExpanded = false;
  bool _continueFromLastPosition = true;
  String _appVersion = 'Carregando...';

  @override
  void initState() {
    super.initState();
    _loadKeepScreenOn();
    _loadContinueFromLastPosition();
    _loadAppVersion();
  }

  Future<void> _loadKeepScreenOn() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _keepScreenOn = prefs.getBool('keepScreenOn') ?? true;
    });
    WakelockPlus.enable();
    if (_keepScreenOn) {
      WakelockPlus.enable();
    } else {
      WakelockPlus.disable();
    }
  }

  Future<void> _loadContinueFromLastPosition() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _continueFromLastPosition = prefs.getBool('continueFromLastPosition') ?? true;
    });
  }

  Future<void> _loadAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = packageInfo.version;
    });
  }

  Future<void> _setContinueFromLastPosition(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('continueFromLastPosition', value);
    setState(() {
      _continueFromLastPosition = value;
    });
  }

  void _showFontSizeDialog(BuildContext context, ThemeManager themeManager) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return const FontSizeDialog();
      },
    );
  }

  Future<void> _setKeepScreenOn(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('keepScreenOn', value);
    setState(() {
      _keepScreenOn = value;
    });
    if (value) {
      WakelockPlus.enable();
    } else {
      WakelockPlus.disable();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeManager>(
      builder: (context, themeManager, child) {
        final isPro = Provider.of<PurchaseService>(context).isProVersion;
        debugPrint('🔍 SettingsScreen - Usuário é PRO: $isPro');
        return Scaffold(
          backgroundColor: themeManager.backgroundColor,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Configurações',
                  style: TextStyle(
                    color: themeManager.primaryTextColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (isPro) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.amber.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Text(
                          '⭐',
                          style: TextStyle(fontSize: 14),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'PRO',
                          style: TextStyle(
                            color: themeManager.primaryTextColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            backgroundColor: themeManager.surfaceColor,
            elevation: 0,
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // PRO card (aparece se não for PRO)
              if (!isPro) ...[
                _buildProEntry(context, themeManager),
              ],

              // Seletor de versão da Bíblia
              const BibleVersionSelector(),

              // Configurações de Leitura (agrupadas)
              _buildReadingSettingsCard(context, themeManager),

              // Tema (abre modal)
              Consumer<ThemeManager>(builder: (ctx, tm, _) {
                final currentTheme = tm.allThemes[tm.currentThemeIndex];
                final themeName = tm.getThemeName(currentTheme.labelKey);
                final isPremium = tm.isThemePremium(tm.currentThemeIndex);
                final subtitle = isPremium ? '$themeName • PRO' : themeName;
                
                return _settingsCard(
                  context,
                  themeManager: themeManager,
                  icon: Icons.palette,
                  color: currentTheme.primary,
                  title: "Tema",
                  subtitle: subtitle,
                  onTap: () async {
                    await showDialog(
                      context: context,
                      builder: (_) => const ThemeSelectionDialog(),
                    );
                  },
                );
              }),

              // Sobre
              _settingsCard(
                context,
                themeManager: themeManager,
                icon: Icons.info_outline,
                color: themeManager.primaryColor,
                title: "Sobre",
                subtitle: "Informações sobre o dev",
                onTap: () {
                  showAppAboutDialog(context);
                },
              ),

              // Banner de anúncio (apenas para usuários não-PRO)
              if (!isPro) ...[
                const SizedBox(height: 16),
                const SettingsAdBanner(),
              ],

              // Versão da app
              const SizedBox(height: 16),
              Center(
                child: Text(
                  'Versão $_appVersion',
                  style: TextStyle(
                    color: themeManager.secondaryTextColor,
                    fontSize: 12,
                  ),
                ),
              ),

            ],
          ),
        );
      },
    );
  }

  Widget _settingsCard(
    BuildContext context, {
    required ThemeManager themeManager,
    required IconData icon,
    required Color color,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
    Widget? child,
    Widget? trailing,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: themeManager.primaryTextColor,
                          ),
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle,
                            style: TextStyle(
                              color: themeManager.secondaryTextColor,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (trailing != null)
                    trailing
                  else if (onTap != null)
                    Icon(
                      Icons.chevron_right,
                      color: themeManager.secondaryTextColor,
                    ),
                ],
              ),
              if (child != null) ...[
                const SizedBox(height: 16),
                child,
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReadingSettingsCard(BuildContext context, ThemeManager themeManager) {
    return _settingsCard(
      context,
      themeManager: themeManager,
      icon: Icons.tune,
      color: themeManager.primaryColor,
      title: "Configurações de Leitura",
      subtitle: _isReadingSettingsExpanded 
        ? "Ajustes para sua experiência de leitura" 
        : "Fonte • Tela • Continuar",
      onTap: () {
        setState(() {
          _isReadingSettingsExpanded = !_isReadingSettingsExpanded;
        });
      },
      trailing: AnimatedRotation(
        turns: _isReadingSettingsExpanded ? 0.5 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: Icon(
          Icons.expand_more,
          color: themeManager.secondaryTextColor,
        ),
      ),
      child: _isReadingSettingsExpanded ? Column(
        children: [
          const SizedBox(height: 12),
          // Tamanho da fonte
          Row(
            children: [
              Icon(
                Icons.format_size,
                size: 20,
                color: themeManager.primaryColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Tamanho da fonte',
                  style: TextStyle(
                    color: themeManager.primaryTextColor,
                    fontSize: 15,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => _showFontSizeDialog(context, themeManager),
                child: Text(
                  'Ajustar',
                  style: TextStyle(
                    color: themeManager.primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Divider(color: themeManager.primaryColor.withOpacity(0.2)),
          const SizedBox(height: 8),
          // Continuar de onde parou
          Row(
            children: [
              Icon(
                Icons.play_circle_fill,
                size: 20,
                color: themeManager.primaryColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Continuar de onde parou',
                  style: TextStyle(
                    color: themeManager.primaryTextColor,
                    fontSize: 15,
                  ),
                ),
              ),
              Switch(
                value: _continueFromLastPosition,
                onChanged: _setContinueFromLastPosition,
                activeColor: themeManager.primaryColor,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Divider(color: themeManager.primaryColor.withOpacity(0.2)),
          const SizedBox(height: 8),
          // Manter tela ligada
          Row(
            children: [
              Icon(
                Icons.screen_lock_portrait,
                size: 20,
                color: themeManager.primaryColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Manter tela sempre ligada',
                  style: TextStyle(
                    color: themeManager.primaryTextColor,
                    fontSize: 15,
                  ),
                ),
              ),
              Switch(
                value: _keepScreenOn,
                onChanged: _setKeepScreenOn,
                activeColor: themeManager.primaryColor,
              ),
            ],
          ),

        ],
      ) : null,
    );
  }



  Widget _buildProEntry(BuildContext context, ThemeManager themeManager) {
    return Consumer<PurchaseService>(
      builder: (context, purchaseService, child) {
        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () => showDialog(
              context: context,
              builder: (_) => const ProUpgradeDialog(),
            ),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: themeManager.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.star, color: Colors.amber),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Atualizar para PRO',
                          style: TextStyle(
                            color: themeManager.primaryTextColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Sem Anúncios • Temas Exclusivos',
                          style: TextStyle(color: themeManager.secondaryTextColor, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: themeManager.secondaryTextColor),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ===== CLASSES GLOBAIS =====
// (deixe todas as classes globais e funções auxiliares abaixo deste ponto)

class ThemeSelectionDialog extends StatefulWidget {
  const ThemeSelectionDialog({super.key});

  @override
  State<ThemeSelectionDialog> createState() => _ThemeSelectionDialogState();
}

class _ThemeSelectionDialogState extends State<ThemeSelectionDialog> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = context.read<ThemeManager>().currentThemeIndex;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeManager>(builder: (context, themeManager, _) {
      final themes = themeManager.allThemes;
      
      return Dialog(
        backgroundColor: themeManager.surfaceColor,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Escolha o tema',
                      style: TextStyle(
                        color: themeManager.primaryTextColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, color: themeManager.secondaryTextColor),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Personalize a aparência do aplicativo',
                style: TextStyle(
                  color: themeManager.secondaryTextColor,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              
              // Lista de temas
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: themes.asMap().entries.map((entry) {
                      final index = entry.key;
                      final theme = entry.value;
                      final isSelected = _selectedIndex == index;
                      final isPremium = themeManager.isThemePremium(index);
                      final themeName = themeManager.getThemeName(theme.labelKey);
                      
                      return _buildThemeOption(
                        themeManager,
                        theme,
                        themeName,
                        index,
                        isSelected,
                        isPremium,
                      );
                    }).toList(),
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Botões
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'Cancelar',
                        style: TextStyle(color: themeManager.secondaryTextColor),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _applyTheme(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: themes[_selectedIndex].primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Aplicar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildThemeOption(
    ThemeManager themeManager,
    dynamic theme,
    String themeName,
    int index,
    bool isSelected,
    bool isPremium,
  ) {
    return InkWell(
      onTap: () => setState(() => _selectedIndex = index),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? theme.primary.withOpacity(0.1) : themeManager.backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? theme.primary : themeManager.cardColor.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Indicador visual do tema
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Fundo principal
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: theme.background,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  // Seção primária (diagonal)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _ThemeColorPainter(
                        primaryColor: theme.primary,
                        secondaryColor: theme.secondary,
                        surfaceColor: theme.surface,
                      ),
                    ),
                  ),
                  // Ícone central
                  Center(
                    child: Icon(
                      Icons.palette_rounded,
                      color: theme.font.withOpacity(0.8),
                      size: 16,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        themeName,
                        style: TextStyle(
                          color: isSelected ? theme.primary : themeManager.primaryTextColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      if (isPremium) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Colors.amber, Colors.orange],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'PRO',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getThemeDescription(themeName),
                    style: TextStyle(
                      color: themeManager.secondaryTextColor,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: theme.primary,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  String _getThemeDescription(String themeName) {
    switch (themeName.toLowerCase()) {
      case 'pergaminho antigo':
        return 'Clássico e elegante';
      case 'clássico bíblico':
        return 'Tradicional e limpo';
      case 'noite serena':
        return 'Escuro e moderno';
      case 'azul saber':
        return 'Profissional e calmo';
      default:
        return 'Tema personalizado';
    }
  }

  Future<void> _applyTheme() async {
    final themeManager = context.read<ThemeManager>();
    final isPremium = themeManager.isThemePremium(_selectedIndex);
    
    if (isPremium && !themeManager.isPremium) {
      await showDialog(
        context: context,
        builder: (_) => const ProUpgradeDialog(),
      );
      final ps = context.read<PurchaseService>();
      if (ps.isProVersion) {
        await themeManager.setPremiumStatus(true);
        try {
          await themeManager.setTheme(_selectedIndex);
          if (mounted) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Tema aplicado com sucesso!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Erro ao aplicar tema: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
      return;
    }
    
    try {
      await themeManager.setTheme(_selectedIndex);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Tema aplicado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao aplicar tema: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

// Custom painter para criar o indicador de cores do tema
class _ThemeColorPainter extends CustomPainter {
  final Color primaryColor;
  final Color secondaryColor;
  final Color surfaceColor;

  _ThemeColorPainter({
    required this.primaryColor,
    required this.secondaryColor,
    required this.surfaceColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final radius = 8.0;
    
    // Seção primária (canto superior direito)
    final primaryPath = Path()
      ..moveTo(size.width * 0.5, 0)
      ..lineTo(size.width - radius, 0)
      ..arcToPoint(
        Offset(size.width, radius),
        radius: Radius.circular(radius),
      )
      ..lineTo(size.width, size.height * 0.5)
      ..lineTo(size.width * 0.5, 0)
      ..close();

    canvas.drawPath(primaryPath, Paint()..color = primaryColor.withOpacity(0.8));

    // Seção secundária (canto inferior esquerdo)
    final secondaryPath = Path()
      ..moveTo(0, size.height * 0.5)
      ..lineTo(0, size.height - radius)
      ..arcToPoint(
        Offset(radius, size.height),
        radius: Radius.circular(radius),
      )
      ..lineTo(size.width * 0.5, size.height)
      ..lineTo(0, size.height * 0.5)
      ..close();

    canvas.drawPath(secondaryPath, Paint()..color = secondaryColor.withOpacity(0.6));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

