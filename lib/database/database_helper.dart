import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'bible_database_manager.dart';
import 'database_migrations.dart';

/// Callback para reportar progresso da inicialização
typedef InitializationProgressCallback = void Function(String message, double progress);

/// Gerenciador principal para o Bible Reader - apenas Bíblias e configurações
class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();
  
  BibleDatabaseManager? _bibleManager;
  Database? _configDatabase;
  
  bool _initialized = false;
  
  /// Inicializa o sistema de bancos do Bible Reader
  Future<void> initialize({InitializationProgressCallback? onProgress}) async {
    if (_initialized) return;
    
    try {
      print('📖 Inicializando Bible Reader...');
      onProgress?.call('Iniciando Bible Reader...', 0.0);
      
      // Instancia o gerenciador das Bíblias
      _bibleManager = BibleDatabaseManager();

      // 1. Instalação das versões da Bíblia
      onProgress?.call('Instalando versões da Bíblia...', 0.5);
      await _bibleManager!.extractAndInstallBibles();

      // 2. Inicializar banco de configurações
      onProgress?.call('Configurando preferências...', 0.8);
      await _initializeConfigDatabase();

      // 3. Finalização
      onProgress?.call('Finalizando...', 1.0);

      _initialized = true;
      print('✅ Bible Reader inicializado com sucesso!');
    } catch (e) {
      print('❌ Erro na inicialização do Bible Reader: $e');
      throw e;
    }
  }

  /// Inicializa banco de configurações do Bible Reader
  Future<void> _initializeConfigDatabase() async {
    try {
      String databasesPath = await getDatabasesPath();
      String configPath = join(databasesPath, 'bible_reader_config.db');
      
      _configDatabase = await openDatabase(
        configPath,
        version: DatabaseMigrations.CURRENT_VERSION,
        onCreate: (db, version) async {
          // Tabela para configurações gerais
          await db.execute('''
            CREATE TABLE app_config (
              key TEXT PRIMARY KEY,
              value TEXT NOT NULL,
              created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
              updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
            )
          ''');
          
          // Tabela para histórico de leitura apenas
          await db.execute('''
            CREATE TABLE reading_history (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              book_name TEXT NOT NULL,
              chapter INTEGER NOT NULL,
              verse INTEGER,
              bible_version TEXT NOT NULL,
              read_date DATETIME DEFAULT CURRENT_TIMESTAMP,
              reading_duration INTEGER DEFAULT 0
            )
          ''');
          
          // Tabela para marcadores/favoritos - NOVA ESTRUTURA
          await db.execute('''
            CREATE TABLE bookmarks (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              book_name TEXT NOT NULL,
              chapter INTEGER NOT NULL,
              verses TEXT NOT NULL,
              bible_version TEXT NOT NULL,
              note TEXT,
              created_at DATETIME DEFAULT CURRENT_TIMESTAMP
            )
          ''');
          
          // Índice para performance
          await db.execute('CREATE INDEX idx_bookmarks_location ON bookmarks(book_name, chapter, bible_version)');
          
          print('✅ Banco de configurações criado (v${DatabaseMigrations.CURRENT_VERSION})');
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          print('🔄 Executando migrations: v$oldVersion → v$newVersion');
          await DatabaseMigrations.migrate(db, oldVersion, newVersion);
        },
      );
      
    } catch (e) {
      print('❌ Erro ao criar banco de configurações: $e');
      throw e;
    }
  }

  /// Getter para o gerenciador das Bíblias
  BibleDatabaseManager get bibleManager {
    if (_bibleManager == null) {
      throw Exception('Bible Reader não foi inicializado');
    }
    return _bibleManager!;
  }

  /// Getter para o banco de configurações
  Database get configDatabase {
    if (_configDatabase == null) {
      throw Exception('Banco de configurações não foi inicializado');
    }
    return _configDatabase!;
  }

  /// Verifica se está inicializado
  bool get isInitialized => _initialized;

  // ===== MÉTODOS DE MARCAÇÕES =====

  /// Adiciona uma marcação com múltiplos versículos
  Future<void> addBookmark({
    required String bookName,
    required int chapter,
    required List<int> verses,
    required String bibleVersion,
    String? note,
  }) async {
    try {
      if (verses.isEmpty) {
        throw Exception('Lista de versículos não pode estar vazia');
      }

      await configDatabase.insert('bookmarks', {
        'book_name': bookName,
        'chapter': chapter,
        'verses': verses.toString(),  // Converte lista para string JSON-like
        'bible_version': bibleVersion,
        'note': note,
        'created_at': DateTime.now().toIso8601String(),
      });
      print('📖 Marcação adicionada: $bookName $chapter:${verses.join(',') }');
    } catch (e) {
      print('❌ Erro ao adicionar marcação: $e');
      rethrow;
    }
  }

  /// Remove uma marcação pelo ID
  Future<void> removeBookmark(int bookmarkId) async {
    try {
      final result = await configDatabase.delete(
        'bookmarks',
        where: 'id = ?',
        whereArgs: [bookmarkId],
      );

      if (result > 0) {
        print('📖 Marcação removida: ID $bookmarkId');
      } else {
        print('⚠️ Nenhuma marcação encontrada com ID: $bookmarkId');
      }
    } catch (e) {
      print('❌ Erro ao remover marcação: $e');
      rethrow;
    }
  }

  /// Verifica se um versículo está marcado em alguma marcação
  Future<bool> isBookmarked({
    required String bookName,
    required int chapter,
    required int verse,
    required String bibleVersion,
  }) async {
    try {
      final result = await configDatabase.query(
        'bookmarks',
        where: 'book_name = ? AND chapter = ? AND bible_version = ?',
        whereArgs: [bookName, chapter, bibleVersion],
      );

      // Verificar se o versículo está em algum dos arrays de versículos
      for (var bookmark in result) {
        final versesString = bookmark['verses'] as String?;
        if (versesString == null || versesString.isEmpty) {
          continue;
        }

        final verses = _parseVersesArray(versesString);
        if (verses.contains(verse)) {
          return true;
        }
      }

      return false;
    } catch (e) {
      print('❌ Erro ao verificar marcação: $e');
      return false;
    }
  }

  /// Busca todas as marcações ordenadas por data (mais recentes primeiro)
  Future<List<Map<String, dynamic>>> getAllBookmarks() async {
    try {
      final result = await configDatabase.query(
        'bookmarks',
        orderBy: 'created_at DESC',
      );
      print('📖 Encontradas ${result.length} marcações no banco');
      if (result.isNotEmpty) {
        print('📖 Primeira marcação: ${result.first}');
      }
      return result;
    } catch (e) {
      print('❌ Erro ao buscar marcações: $e');
      return [];
    }
  }

  /// Atualiza a observação de uma marcação
  Future<void> updateBookmarkNote({
    required int bookmarkId,
    required String note,
  }) async {
    try {
      final result = await configDatabase.update(
        'bookmarks',
        {'note': note},
        where: 'id = ?',
        whereArgs: [bookmarkId],
      );

      if (result > 0) {
        print('📖 Observação atualizada para marcação ID: $bookmarkId');
      } else {
        print('⚠️ Nenhuma marcação encontrada com ID: $bookmarkId');
      }
    } catch (e) {
      print('❌ Erro ao atualizar observação: $e');
      rethrow;
    }
  }

  // ===== MÉTODOS DE ÚLTIMO LIVRO/CAPÍTULO LIDO =====

  /// Salva o último livro e capítulo lido
  Future<void> saveLastRead({
    required String bookName,
    required int chapter,
    required String bibleVersion,
  }) async {
    try {
      // Remove o registro anterior
      await configDatabase.delete('app_config', where: 'key = ?', whereArgs: ['last_book']);
      await configDatabase.delete('app_config', where: 'key = ?', whereArgs: ['last_chapter']);
      await configDatabase.delete('app_config', where: 'key = ?', whereArgs: ['last_version']);

      // Adiciona os novos valores
      await configDatabase.insert('app_config', {
        'key': 'last_book',
        'value': bookName,
        'updated_at': DateTime.now().toIso8601String(),
      });
      
      await configDatabase.insert('app_config', {
        'key': 'last_chapter',
        'value': chapter.toString(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      await configDatabase.insert('app_config', {
        'key': 'last_version',
        'value': bibleVersion,
        'updated_at': DateTime.now().toIso8601String(),
      });

      print('📖 Último livro salvo: $bookName $chapter ($bibleVersion)');
    } catch (e) {
      print('❌ Erro ao salvar último livro lido: $e');
    }
  }

  /// Recupera o último livro e capítulo lido
  Future<Map<String, dynamic>?> getLastRead() async {
    try {
      final bookResult = await configDatabase.query('app_config', where: 'key = ?', whereArgs: ['last_book']);
      final chapterResult = await configDatabase.query('app_config', where: 'key = ?', whereArgs: ['last_chapter']);
      final versionResult = await configDatabase.query('app_config', where: 'key = ?', whereArgs: ['last_version']);

      if (bookResult.isNotEmpty && chapterResult.isNotEmpty && versionResult.isNotEmpty) {
        return {
          'book': bookResult.first['value'],
          'chapter': int.parse(chapterResult.first['value'] as String),
          'version': versionResult.first['value'],
        };
      }
      
      return null;
    } catch (e) {
      print('❌ Erro ao recuperar último livro lido: $e');
      return null;
    }
  }

  /// Fecha conexões
  Future<void> close() async {
    await _configDatabase?.close();
    _configDatabase = null;
    _initialized = false;
  }

  /// Converte string de array para List<int>
  /// Exemplo: "[1, 2, 3]" → [1, 2, 3]
  List<int> _parseVersesArray(String versesString) {
    try {
      if (versesString.isEmpty) {
        return [];
      }

      // Remove colchetes e espaços
      final cleanString = versesString.replaceAll('[', '').replaceAll(']', '').replaceAll(' ', '');
      if (cleanString.isEmpty) {
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
          }
        }
      }

      return verses;
    } catch (e) {
      print('❌ Erro ao fazer parse do array de versículos: $versesString - Erro: $e');
      return [];
    }
  }
}
