import 'package:sqflite/sqflite.dart';

/// Classe responsável por gerenciar migrations do banco de dados
class DatabaseMigrations {
  static const int CURRENT_VERSION = 2;

  /// Executa todas as migrations necessárias
  static Future<void> migrate(Database db, int oldVersion, int newVersion) async {
    print('🔄 Iniciando migrations: v$oldVersion → v$newVersion');

    for (int version = oldVersion + 1; version <= newVersion; version++) {
      print('📦 Aplicando migration para versão $version');
      await _applyMigration(db, version);
    }

    print('✅ Todas as migrations aplicadas com sucesso');
  }

  /// Aplica uma migration específica
  static Future<void> _applyMigration(Database db, int version) async {
    switch (version) {
      case 2:
        await _migrateToVersion2(db);
        break;
      // Adicionar futuras migrations aqui
      // case 3:
      //   await _migrateToVersion3(db);
      //   break;
      default:
        throw Exception('Migration para versão $version não implementada');
    }
  }

  /// Migration v2: Converte estrutura de bookmarks para usar arrays de versículos
  static Future<void> _migrateToVersion2(Database db) async {
    print('🔄 Migration v2: Convertendo bookmarks para arrays de versículos');

    // 1. Criar nova tabela com estrutura correta
    await db.execute('''
      CREATE TABLE bookmarks_new (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        book_name TEXT NOT NULL,
        chapter INTEGER NOT NULL,
        verses TEXT NOT NULL,
        bible_version TEXT NOT NULL,
        note TEXT,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // 2. Migrar dados existentes
    final oldBookmarks = await db.query('bookmarks');
    print('📊 Migrando ${oldBookmarks.length} marcações existentes');

    for (var bookmark in oldBookmarks) {
      await db.insert('bookmarks_new', {
        'book_name': bookmark['book_name'],
        'chapter': bookmark['chapter'],
        'verses': '[${bookmark['verse']}]',  // Converte versículo único para array JSON
        'bible_version': bookmark['bible_version'],
        'note': bookmark['note'],
        'created_at': bookmark['created_at'],
      });
    }

    // 3. Criar índices para performance
    await db.execute('CREATE INDEX idx_bookmarks_new_location ON bookmarks_new(book_name, chapter, bible_version)');

    // 4. Substituir tabelas
    await db.execute('DROP TABLE bookmarks');
    await db.execute('ALTER TABLE bookmarks_new RENAME TO bookmarks');

    print('✅ Migration v2 concluída: ${oldBookmarks.length} marcações migradas');
  }
}
