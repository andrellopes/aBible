import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Gerenciador global do tamanho da fonte para todo o app
class FontManager extends ChangeNotifier {
  static final FontManager _instance = FontManager._internal();
  factory FontManager() => _instance;
  FontManager._internal();

  // Configurações da fonte
  static const double _minFontSize = 16.0;
  static const double _maxFontSize = 32.0;
  static const double _defaultFontSize = 18.0;
  static const String _fontSizeKey = 'verse_font_size';

  double _fontSize = _defaultFontSize;
  bool _isInitialized = false;

  /// Tamanho atual da fonte
  double get fontSize => _fontSize;

  /// Valores possíveis do slider (de 2 em 2)
  List<double> get allowedSizes => [16, 18, 20, 22, 24, 26, 28, 30, 32];

  /// Tamanho mínimo
  double get minSize => _minFontSize;

  /// Tamanho máximo
  double get maxSize => _maxFontSize;

  /// Número de divisões do slider
  int get divisions => allowedSizes.length - 1; // 8 divisões para 9 valores

  /// Se foi inicializado
  bool get isInitialized => _isInitialized;

  /// Inicializa o gerenciador carregando a fonte salva
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedSize = prefs.getDouble(_fontSizeKey) ?? _defaultFontSize;
      
      // Garante que o valor está na lista de tamanhos permitidos
      _fontSize = _findClosestAllowedSize(savedSize);
      _isInitialized = true;
      
      print('✅ FontManager inicializado com tamanho: $_fontSize');
      notifyListeners();
    } catch (e) {
      print('❌ Erro ao inicializar FontManager: $e');
      _fontSize = _defaultFontSize;
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Encontra o tamanho permitido mais próximo
  double _findClosestAllowedSize(double size) {
    double closest = allowedSizes.first;
    double minDiff = (size - closest).abs();
    
    for (final allowedSize in allowedSizes) {
      final diff = (size - allowedSize).abs();
      if (diff < minDiff) {
        closest = allowedSize;
        minDiff = diff;
      }
    }
    
    return closest;
  }

  /// Altera o tamanho da fonte
  Future<void> setFontSize(double newSize) async {
    // Garante que é um tamanho permitido
    final adjustedSize = _findClosestAllowedSize(newSize);
    
    if (_fontSize == adjustedSize) return; // Não mudou
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_fontSizeKey, adjustedSize);
      
      _fontSize = adjustedSize;
      print('✅ Fonte alterada para: $_fontSize');
      
      // Notifica todos os listeners (telas que usam a fonte)
      notifyListeners();
    } catch (e) {
      print('❌ Erro ao salvar tamanho da fonte: $e');
      throw Exception('Erro ao salvar tamanho da fonte: $e');
    }
  }

  /// Aumenta a fonte (próximo tamanho permitido)
  Future<void> increaseFontSize() async {
    final currentIndex = allowedSizes.indexOf(_fontSize);
    if (currentIndex < allowedSizes.length - 1) {
      await setFontSize(allowedSizes[currentIndex + 1]);
    }
  }

  /// Diminui a fonte (tamanho anterior permitido)
  Future<void> decreaseFontSize() async {
    final currentIndex = allowedSizes.indexOf(_fontSize);
    if (currentIndex > 0) {
      await setFontSize(allowedSizes[currentIndex - 1]);
    }
  }

  /// Reset para tamanho padrão
  Future<void> resetToDefault() async {
    await setFontSize(_defaultFontSize);
  }

  /// Libera recursos
  void dispose() {
    _isInitialized = false;
    super.dispose();
  }
}
