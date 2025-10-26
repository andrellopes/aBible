import 'package:shared_preferences/shared_preferences.dart';

class ReadingPositionService {
  static const String _keyLastBook = 'last_reading_book';
  static const String _keyLastChapter = 'last_reading_chapter';
  static const String _keyLastVerse = 'last_reading_verse';
  static const String _keyLastVersion = 'last_reading_version';
  static const String _keyLastTimestamp = 'last_reading_timestamp';

  /// Salva a posição atual de leitura
  static Future<void> saveReadingPosition({
    required String bookName,
    required int chapter,
    int? verse,
    required String version,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.setString(_keyLastBook, bookName);
    await prefs.setInt(_keyLastChapter, chapter);
    if (verse != null) {
      await prefs.setInt(_keyLastVerse, verse);
    } else {
      await prefs.remove(_keyLastVerse);
    }
    await prefs.setString(_keyLastVersion, version);
    await prefs.setInt(_keyLastTimestamp, DateTime.now().millisecondsSinceEpoch);
    
    print('💾 Posição salva: $bookName $chapter${verse != null ? ':$verse' : ''} ($version)');
  }

  /// Recupera a última posição de leitura
  static Future<ReadingPosition?> getLastReadingPosition() async {
    final prefs = await SharedPreferences.getInstance();
    
    final book = prefs.getString(_keyLastBook);
    final chapter = prefs.getInt(_keyLastChapter);
    final verse = prefs.getInt(_keyLastVerse);
    final version = prefs.getString(_keyLastVersion);
    final timestamp = prefs.getInt(_keyLastTimestamp);
    
    if (book == null || chapter == null || version == null) {
      return null;
    }
    
    return ReadingPosition(
      bookName: book,
      chapter: chapter,
      verse: verse,
      version: version,
      timestamp: timestamp != null 
        ? DateTime.fromMillisecondsSinceEpoch(timestamp)
        : DateTime.now(),
    );
  }

  /// Limpa a posição de leitura salva
  static Future<void> clearReadingPosition() async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.remove(_keyLastBook);
    await prefs.remove(_keyLastChapter);
    await prefs.remove(_keyLastVerse);
    await prefs.remove(_keyLastVersion);
    await prefs.remove(_keyLastTimestamp);
    
    print('🗑️ Posição de leitura limpa');
  }

  /// Verifica se há uma posição de leitura salva
  static Future<bool> hasLastReadingPosition() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_keyLastBook) && 
           prefs.containsKey(_keyLastChapter) &&
           prefs.containsKey(_keyLastVersion);
  }
}

class ReadingPosition {
  final String bookName;
  final int chapter;
  final int? verse;
  final String version;
  final DateTime timestamp;

  ReadingPosition({
    required this.bookName,
    required this.chapter,
    this.verse,
    required this.version,
    required this.timestamp,
  });

  String get displayText {
    return '$bookName $chapter${verse != null ? ':$verse' : ''}';
  }

  String get fullDisplayText {
    return '$bookName $chapter${verse != null ? ':$verse' : ''} ($version)';
  }

  /// Verifica se a posição é recente (última semana)
  bool get isRecent {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    return difference.inDays <= 7;
  }

  /// Tempo decorrido em formato legível
  String get timeAgoText {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inMinutes < 1) {
      return 'Agora mesmo';
    } else if (difference.inMinutes < 60) {
      return 'Há ${difference.inMinutes} minuto${difference.inMinutes > 1 ? 's' : ''}';
    } else if (difference.inHours < 24) {
      return 'Há ${difference.inHours} hora${difference.inHours > 1 ? 's' : ''}';
    } else if (difference.inDays < 7) {
      return 'Há ${difference.inDays} dia${difference.inDays > 1 ? 's' : ''}';
    } else {
      return 'Há mais de uma semana';
    }
  }
}
