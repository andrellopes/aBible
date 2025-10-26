import 'package:shared_preferences/shared_preferences.dart';
import '../database/bible_database_manager.dart';

/// Service para gerenciar configurações da versão da Bíblia
class BibleSettingsService {
  static final BibleSettingsService _instance = BibleSettingsService._internal();
  factory BibleSettingsService() => _instance;
  BibleSettingsService._internal();

  /// Obtém a versão atual da Bíblia escolhida pelo usuário
  Future<String> getCurrentBibleVersion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('current_bible_version') ?? 'NVI';
    } catch (e) {
      print('Erro ao obter versão da Bíblia: $e');
      return 'NVI';
    }
  }

  /// Define a nova versão da Bíblia escolhida pelo usuário
  Future<void> setBibleVersion(String version) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_bible_version', version);
      
      print('✅ Versão da Bíblia alterada para: $version');
    } catch (e) {
      print('❌ Erro ao alterar versão da Bíblia: $e');
      throw Exception('Erro ao alterar versão da Bíblia: $e');
    }
  }

  /// Verifica se uma versão específica está disponível
  Future<bool> isVersionAvailable(String version) async {
    try {
      // Verifica se está na lista de versões disponíveis
      final availableVersions = BibleDatabaseManager.AVAILABLE_VERSIONS;
      return availableVersions.any((v) => v['code'] == version);
    } catch (e) {
      print('Erro ao verificar disponibilidade da versão $version: $e');
      return false;
    }
  }

  /// Lista todas as versões disponíveis
  List<Map<String, String>> getAvailableVersions() {
    return BibleDatabaseManager.AVAILABLE_VERSIONS;
  }

  /// Obtém o tamanho da fonte atual para leitura de versículos
  Future<double> getFontSize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getDouble('verse_font_size') ?? 16.0;
    } catch (e) {
      print('Erro ao obter tamanho da fonte: $e');
      return 16.0;
    }
  }

  /// Define o novo tamanho da fonte para leitura de versículos
  Future<void> setFontSize(double fontSize) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('verse_font_size', fontSize);
      
      print('✅ Tamanho da fonte alterado para: $fontSize');
    } catch (e) {
      print('❌ Erro ao alterar tamanho da fonte: $e');
      throw Exception('Erro ao alterar tamanho da fonte: $e');
    }
  }

  /// Armazena informações temporárias para navegação a partir de uma marcação
  Future<void> setBookmarkNavigationTarget({
    required String bookName,
    required int chapter,
    int? verse,
    required String bibleVersion,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('bookmark_nav_book', bookName);
      await prefs.setInt('bookmark_nav_chapter', chapter);
      if (verse != null) {
        await prefs.setInt('bookmark_nav_verse', verse);
      } else {
        await prefs.remove('bookmark_nav_verse');
      }
      await prefs.setString('bookmark_nav_version', bibleVersion);
      await prefs.setBool('has_bookmark_navigation', true);
      
      print('✅ Navegação para marcação configurada: $bookName $chapter${verse != null ? ':$verse' : ''} ($bibleVersion)');
    } catch (e) {
      print('❌ Erro ao configurar navegação para marcação: $e');
    }
  }

  /// Obtém as informações de navegação para marcação (se existirem)
  Future<Map<String, dynamic>?> getBookmarkNavigationTarget() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasNavigation = prefs.getBool('has_bookmark_navigation') ?? false;
      
      if (!hasNavigation) {
        return null;
      }

      final bookName = prefs.getString('bookmark_nav_book');
      final chapter = prefs.getInt('bookmark_nav_chapter');
      final verse = prefs.getInt('bookmark_nav_verse');
      final bibleVersion = prefs.getString('bookmark_nav_version');

      if (bookName != null && chapter != null && bibleVersion != null) {
        return {
          'bookName': bookName,
          'chapter': chapter,
          'verse': verse,
          'bibleVersion': bibleVersion,
        };
      }
      
      return null;
    } catch (e) {
      print('❌ Erro ao obter navegação para marcação: $e');
      return null;
    }
  }

  /// Limpa as informações de navegação para marcação
  Future<void> clearBookmarkNavigationTarget() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('bookmark_nav_book');
      await prefs.remove('bookmark_nav_chapter');
      await prefs.remove('bookmark_nav_verse');
      await prefs.remove('bookmark_nav_version');
      await prefs.setBool('has_bookmark_navigation', false);
      
      print('✅ Navegação para marcação limpa');
    } catch (e) {
      print('❌ Erro ao limpar navegação para marcação: $e');
    }
  }
}
