import 'package:flutter/material.dart';
import '../database/database_helper.dart';

class BookmarksProvider with ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Map<String, dynamic>> _bookmarks = [];
  bool _isLoading = false;

  List<Map<String, dynamic>> get bookmarks => _bookmarks;
  bool get isLoading => _isLoading;

  BookmarksProvider() {
    // Não carregar automaticamente no construtor para evitar problemas de inicialização
    // O carregamento será feito manualmente quando necessário
  }

  Future<void> loadBookmarks() async {
    try {
      _isLoading = true;
      notifyListeners();

      debugPrint('BookmarksProvider: Iniciando carregamento de marcações...');

      // Verificar se o banco está inicializado
      if (!_dbHelper.isInitialized) {
        debugPrint('BookmarksProvider: Banco não inicializado, aguardando...');
        await Future.delayed(const Duration(milliseconds: 500));
        if (!_dbHelper.isInitialized) {
          debugPrint('BookmarksProvider: Banco ainda não inicializado após espera');
          _isLoading = false;
          notifyListeners();
          return;
        }
      }

      final bookmarks = await _dbHelper.getAllBookmarks();
      debugPrint('BookmarksProvider: Encontradas ${bookmarks.length} marcações no banco');

      _bookmarks = _formatBookmarksForDisplay(bookmarks);
      debugPrint('BookmarksProvider: Formatadas ${bookmarks.length} marcações para exibição');

      _isLoading = false;
      notifyListeners();
      debugPrint('BookmarksProvider: Carregamento concluído');
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      debugPrint('Erro ao carregar marcações: $e');
    }
  }

  /// Formata os bookmarks para exibição (agora sequências são reais)
  List<Map<String, dynamic>> _formatBookmarksForDisplay(List<Map<String, dynamic>> bookmarks) {
    return bookmarks.map((bookmark) {
      try {
        final versesString = bookmark['verses'] as String?;
        if (versesString == null || versesString.isEmpty) {
          debugPrint('BookmarksProvider: Campo verses vazio ou nulo');
          return {
            ...bookmark,
            'verses_list': <int>[],
            'verse_start': 0,
            'verse_end': 0,
            'is_sequence': false,
            'sequence_count': 0,
          };
        }

        final verses = _parseVersesArray(versesString);

        // Ordenar versículos para exibição consistente
        verses.sort();

        return {
          ...bookmark,
          'verses_list': verses,  // Lista parseada para uso interno
          'verse_start': verses.isNotEmpty ? verses.first : 0,
          'verse_end': verses.isNotEmpty ? verses.last : 0,
          'is_sequence': verses.length > 1,
          'sequence_count': verses.length,
        };
      } catch (e) {
        debugPrint('BookmarksProvider: Erro ao formatar bookmark: $e');
        return {
          ...bookmark,
          'verses_list': <int>[],
          'verse_start': 0,
          'verse_end': 0,
          'is_sequence': false,
          'sequence_count': 0,
        };
      }
    }).toList();
  }

  /// Converte string de array para List<int>
  List<int> _parseVersesArray(String versesString) {
    try {
      debugPrint('BookmarksProvider: Fazendo parse de: "$versesString"');

      if (versesString.isEmpty) {
        debugPrint('BookmarksProvider: String vazia');
        return [];
      }

      // Remove colchetes e espaços
      final cleanString = versesString.replaceAll('[', '').replaceAll(']', '').replaceAll(' ', '');
      if (cleanString.isEmpty) {
        debugPrint('BookmarksProvider: String vazia após limpeza');
        return [];
      }

      // Divide por vírgula e converte para int
      final parts = cleanString.split(',');
      final verses = <int>[];

      for (final part in parts) {
        final trimmed = part.trim();
        if (trimmed.isNotEmpty) {
          final verse = int.tryParse(trimmed);
          if (verse != null) {
            verses.add(verse);
          } else {
            debugPrint('BookmarksProvider: Não conseguiu fazer parse de: "$trimmed"');
          }
        }
      }

      debugPrint('BookmarksProvider: Parse concluído: $verses');
      return verses;
    } catch (e) {
      debugPrint('Erro ao fazer parse do array de versículos: $versesString - Erro: $e');
      return [];
    }
  }

  Future<void> addBookmark({
    required String bookName,
    required int chapter,
    required List<int> verses,
    required String bibleVersion,
    String? note,
  }) async {
    try {
      await _dbHelper.addBookmark(
        bookName: bookName,
        chapter: chapter,
        verses: verses,
        bibleVersion: bibleVersion,
        note: note,
      );
      await loadBookmarks(); // Recarregar após adicionar
    } catch (e) {
      debugPrint('Erro ao adicionar marcação: $e');
      rethrow;
    }
  }

  Future<void> removeBookmark(int bookmarkId) async {
    try {
      await _dbHelper.removeBookmark(bookmarkId);
      await loadBookmarks(); // Recarregar após remover
    } catch (e) {
      debugPrint('Erro ao remover marcação: $e');
      rethrow;
    }
  }

  Future<void> updateBookmarkNote({
    required int bookmarkId,
    required String note,
  }) async {
    try {
      await _dbHelper.updateBookmarkNote(
        bookmarkId: bookmarkId,
        note: note,
      );
      await loadBookmarks(); // Recarregar após atualizar
    } catch (e) {
      debugPrint('Erro ao atualizar observação: $e');
      rethrow;
    }
  }

  Future<bool> isBookmarked({
    required String bookName,
    required int chapter,
    required int verse,
    required String bibleVersion,
  }) async {
    return await _dbHelper.isBookmarked(
      bookName: bookName,
      chapter: chapter,
      verse: verse,
      bibleVersion: bibleVersion,
    );
  }
}
