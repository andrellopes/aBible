import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import '../services/themes/theme_manager.dart';
import '../services/font_manager.dart';
import '../services/bible_settings_service.dart';
import '../services/bookmarks_provider.dart';
import '../database/bible_database_manager.dart';
import '../models/bible_book.dart';
import '../models/bible_verse.dart';
import '../services/reading_position_service.dart';
import '../widgets/bible_version_selector.dart';
import '../widgets/font_size_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/bible_metadata.dart';

class BibleReaderScreen extends StatefulWidget {
  const BibleReaderScreen({super.key});

  @override
  State<BibleReaderScreen> createState() => _BibleReaderScreenState();
}

class _BibleReaderScreenState extends State<BibleReaderScreen> {
  Future<void> _anunciarLivroCapituloEIniciarLeitura(String book, int chapter) async {
    // Remove handler temporário para evitar duplicidade
    _flutterTts.setCompletionHandler(() {});
    await _flutterTts.speak('Livro de $book, capítulo $chapter');
    // Aguarda término do anúncio
    bool terminou = false;
    _flutterTts.setCompletionHandler(() {
      terminou = true;
    });
    while (!terminou && _isSpeaking && !_isPaused) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    // Restaura handler padrão e inicia leitura dos versículos
    _flutterTts.setCompletionHandler(_onVerseCompleted);
    if (_isSpeaking && !_isPaused) {
      _currentReadingVerse = 0;
      _speakCurrentVerse();
    }
  }
  final BibleDatabaseManager _bibleManager = BibleDatabaseManager();
  final FlutterTts _flutterTts = FlutterTts();
  final ItemScrollController _itemScrollController = ItemScrollController();

  List<BibleBook> _books = [];
  List<BibleVerse> _verses = [];
  String _selectedVersion = '';
  String? _selectedBook;
  int? _selectedChapter;
  int? _selectedVerse;
  bool _isLoading = false;
  bool _isReadingMode = false;
  bool _showVerseSelector = false;
  bool _isSpeaking = false;
  bool _isPaused = false;
  int _currentReadingVerse = -1;

  Timer? _readingTimer;
  bool _rewardGiven = false;

  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Variáveis para seleção múltipla
  final Set<int> _selectedVerses = <int>{};
  bool _isMultiSelectMode = false;
  OverlayEntry? _overlayEntry;

  Future<void> _speakChapter() async {
    if (_verses.isEmpty) return;
    setState(() {
      _isSpeaking = true;
      _isPaused = false;
      // Se houver versículo selecionado, começa dele; senão, começa do primeiro
      if (_selectedVerse != null) {
        final index = _verses.indexWhere((v) => v.verse == _selectedVerse);
        _currentReadingVerse = index >= 0 ? index : 0;
      } else {
        _currentReadingVerse = 0;
      }
      // Salva posição ao iniciar leitura automática
      if (_selectedBook != null && _selectedChapter != null && _verses.isNotEmpty) {
        ReadingPositionService.saveReadingPosition(
          bookName: _selectedBook!,
          chapter: _selectedChapter!,
          verse: _verses[_currentReadingVerse].verse,
          version: _selectedVersion,
        );
      }
    });
    
    await _flutterTts.setLanguage('pt-BR');
    await _flutterTts.setSpeechRate(0.5);
    
    // Configurar callbacks para controle sequencial
    _flutterTts.setCompletionHandler(() {
      _onVerseCompleted();
    });
    
    _flutterTts.setErrorHandler((message) {
      setState(() {
        _isSpeaking = false;
        _isPaused = false;
        _currentReadingVerse = -1;
      });
    });
    
    // Começar a leitura do primeiro versículo
    _speakCurrentVerse();
  }

  Future<void> _speakCurrentVerse() async {
    if (_currentReadingVerse >= _verses.length || _currentReadingVerse < 0) {
      return;
    }
    final verse = _verses[_currentReadingVerse];
    
    // Pequeno delay antes do scroll para evitar efeito de "esticar"
    await Future.delayed(const Duration(milliseconds: 150));
    
    setState(() {
      _selectedVerse = verse.verse;
      // Salva posição ao atualizar título durante leitura automática
      if (_selectedBook != null && _selectedChapter != null) {
        ReadingPositionService.saveReadingPosition(
          bookName: _selectedBook!,
          chapter: _selectedChapter!,
          verse: verse.verse,
          version: _selectedVersion,
        );
      }
    });
    _scrollToVerse(verse.verse);
    // Falar o versículo atual apenas se ainda estamos em modo de leitura e não pausado
    if (_isSpeaking && !_isPaused) {
      final text = '${verse.verse}. ${verse.text}';
      await _flutterTts.speak(text);
    }
  }


  void _onVerseCompleted() {
    if (_isSpeaking && !_isPaused) {
      _currentReadingVerse++;
      if (_currentReadingVerse < _verses.length) {
        // Ainda há versículos no capítulo
        Future.delayed(const Duration(milliseconds: 800), () {
          if (_isSpeaking && !_isPaused) {
            _speakCurrentVerse();
          }
        });
      } else {
        // Chegou ao fim do capítulo
        Future.delayed(const Duration(milliseconds: 800), () async {
          if (_isSpeaking && !_isPaused) {
            // Avançar para o próximo capítulo/livro sem parar TTS
            await _navigateToNextChapterForTTS();
            // Aguardar um pouco para garantir que o capítulo foi carregado
            await Future.delayed(const Duration(milliseconds: 500));
            // Verificar se ainda estamos em modo de leitura e temos versículos
            if (_isSpeaking && !_isPaused && _verses.isNotEmpty) {
              final book = _selectedBook ?? '';
              final chapter = _selectedChapter ?? 1;
              await _anunciarLivroCapituloEIniciarLeitura(book, chapter);
            }
          }
        });
      }
    }
  }

  Future<void> _pauseTTS() async {
    if (_isSpeaking && !_isPaused) {
      await _flutterTts.pause();
      setState(() {
        _isPaused = true;
      });
    }
  }

  Future<void> _resumeTTS() async {
    if (_isPaused) {
      setState(() {
        _isPaused = false;
      });
      // Continuar da onde parou
      if (_isSpeaking && _currentReadingVerse >= 0 && _currentReadingVerse < _verses.length) {
        _speakCurrentVerse();
      }
    }
  }

  Future<void> _stopTTS() async {
    await _flutterTts.stop();
    setState(() {
      _isSpeaking = false;
      _isPaused = false;
      _currentReadingVerse = -1;
    });
  }

  @override
  void initState() {
    super.initState();
    _loadCurrentVersionAndBooks();
    _checkLastReadingPosition();
    _checkBookmarkNavigationTarget();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // FontManager cuida automaticamente do carregamento
  }

  @override
  void dispose() {
    _readingTimer?.cancel();

    _flutterTts.stop();
    _searchController.dispose();

    _hideFloatingWidget();
    super.dispose();
  }

  Future<void> _loadCurrentVersionAndBooks() async {
    setState(() => _isLoading = true);
    try {
      final settingsService = BibleSettingsService();
      _selectedVersion = await settingsService.getCurrentBibleVersion();
      
      await _loadBooks();
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Erro ao carregar: $e');
    }
  }

  void _showFontSizeDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return const FontSizeDialog();
      },
    );
  }

  Future<void> _loadBooks() async {
    // Esconder widget flutuante ao carregar livros
    _hideFloatingWidget();
    setState(() => _isLoading = true);
    try {
      final booksData = await _bibleManager.getBooks(_selectedVersion);
      final books = booksData.map((data) => BibleBook.fromMap(data)).toList();
      setState(() {
        _books = books;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Erro ao carregar livros: $e');
    }
  }

  Future<void> _loadChapter(String bookName, int chapter, {bool directRead = false}) async {
      // Parar qualquer leitura em andamento
      await _stopTTS();
      // Esconder widget flutuante ao carregar novo capítulo
      _hideFloatingWidget();
      // Limpar seleção múltipla ao carregar novo capítulo
      _clearSelection();
      
      setState(() => _isLoading = true);
      try {
        // Usar o método específico para buscar versículos de um capítulo
        final versesData = await _bibleManager.getChapterVerses(_selectedVersion, bookName, chapter);
      
        if (versesData.isEmpty) {
          setState(() => _isLoading = false);
          _showError('Nenhum versículo encontrado para $bookName $chapter');
          return;
        }

        final verses = versesData.map((data) => BibleVerse.fromMap({
          ...data,
          'book': bookName,
          'chapter': chapter,
          'version': _selectedVersion,
        })).toList();
      
        setState(() {
          _selectedBook = bookName;
          _selectedChapter = chapter;
          _verses = verses;
          _showVerseSelector = directRead ? false : true;
          _isReadingMode = directRead ? true : false;
          _isLoading = false;
          _rewardGiven = false;
          // Reset reading state
          _currentReadingVerse = -1;
          _selectedVerse = null;
        });
        for (int i = 0; i < verses.length && i < 10; i++) {
          print('   ${verses[i].verse}: "${verses[i].text.substring(0, math.min(50, verses[i].text.length))}..."');
        }
        
        // Criar mapa para versículos únicos - sempre manter o primeiro encontrado
        final Map<int, BibleVerse> uniqueVerses = {};
        
        for (final verse in verses) {
          final verseNum = verse.verse;
          
          // Se o versículo ainda não existe, adicionar
          // Se já existe, manter o que tem texto mais longo OU diferente
          if (!uniqueVerses.containsKey(verseNum)) {
            uniqueVerses[verseNum] = verse;
            print('   ✅ Adicionado versículo $verseNum');
          } else {
            final existing = uniqueVerses[verseNum]!;
            print('   ⚠️  Duplicata encontrada no versículo $verseNum:');
            print('      Existente: "${existing.text.substring(0, math.min(30, existing.text.length))}..."');
            print('      Novo: "${verse.text.substring(0, math.min(30, verse.text.length))}..."');
            
            // Comparar textos e manter o melhor
            if (verse.text != existing.text && verse.text.length > existing.text.length) {
              uniqueVerses[verseNum] = verse;
              print('      -> Substituído pelo texto mais longo');
            } else {
              print('      -> Mantido o existente');
            }
          }
        }
        
        // Ordenar os versículos por número
        final filteredVerses = uniqueVerses.values.toList()
          ..sort((a, b) => a.verse.compareTo(b.verse));

        print('✅ Resultado final: ${filteredVerses.length} versículos únicos');
        if (verses.length != filteredVerses.length) {
          print('�️  Removidas ${verses.length - filteredVerses.length} duplicatas');
        }
      
        setState(() {
          _selectedBook = bookName;
          _selectedChapter = chapter;
          _verses = verses;
          _showVerseSelector = directRead ? false : true;
          _isReadingMode = directRead ? true : false;
          _isLoading = false;
          _rewardGiven = false;
          // Reset reading state
          _currentReadingVerse = -1;
          _selectedVerse = null;
        });

        // Salvar posição de leitura automaticamente
        await ReadingPositionService.saveReadingPosition(
          bookName: bookName,
          chapter: chapter,
          version: _selectedVersion,
        );

      } catch (e) {
        setState(() => _isLoading = false);
        _showError('Erro ao carregar capítulo: $e');
      }
    }

  // Versão especial do _loadChapter para TTS que não para a leitura
  Future<void> _loadChapterForTTS(String bookName, int chapter) async {
    // Esconder widget flutuante ao carregar novo capítulo
    _hideFloatingWidget();
    // Limpar seleção múltipla ao carregar novo capítulo
    _clearSelection();
    setState(() => _isLoading = true);
    try {
      // Usar o método específico para buscar versículos de um capítulo
      final versesData = await _bibleManager.getChapterVerses(_selectedVersion, bookName, chapter);

      if (versesData.isEmpty) {
        setState(() => _isLoading = false);
        _showError('Nenhum versículo encontrado para $bookName $chapter');
        return;
      }

      final verses = versesData.map((data) => BibleVerse.fromMap({
        ...data,
        'book': bookName,
        'chapter': chapter,
        'version': _selectedVersion,
      })).toList();

      // Criar mapa para versículos únicos - sempre manter o primeiro encontrado
      final Map<int, BibleVerse> uniqueVerses = {};

      for (final verse in verses) {
        final verseNum = verse.verse;

        // Se o versículo ainda não existe, adicionar
        if (!uniqueVerses.containsKey(verseNum)) {
          uniqueVerses[verseNum] = verse;
        } else {
          final existing = uniqueVerses[verseNum]!;
          // Comparar textos e manter o melhor
          if (verse.text != existing.text && verse.text.length > existing.text.length) {
            uniqueVerses[verseNum] = verse;
          }
        }
      }

      // Ordenar os versículos por número
      final filteredVerses = uniqueVerses.values.toList()
        ..sort((a, b) => a.verse.compareTo(b.verse));

      setState(() {
        _selectedBook = bookName;
        _selectedChapter = chapter;
        _verses = filteredVerses;
        _showVerseSelector = false; 
        _isReadingMode = true; 
        _isLoading = false;
        _rewardGiven = false;
        // NÃO resetar _currentReadingVerse para manter continuidade da leitura
        _selectedVerse = null;
      });

      // Salvar posição de leitura automaticamente
      await ReadingPositionService.saveReadingPosition(
        bookName: bookName,
        chapter: chapter,
        version: _selectedVersion,
      );

    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Erro ao carregar capítulo: $e');
    }
  }

  /// Inicia uma nova sessão de leitura com controle de tempo
  void _startReadingSession() {
    _readingTimer?.cancel();
    
    // Aguarda 5 segundos antes de dar a recompensa
    _readingTimer = Timer(const Duration(seconds: 5), () {
      if (!_rewardGiven && mounted) {
        _recordChapterReadingAfterTime();
      }
    });
  }

  /// Registra a leitura após o tempo mínimo de engajamento
  Future<void> _recordChapterReadingAfterTime() async {
    if (_selectedBook == null || _selectedChapter == null || _rewardGiven) return;

    try {
      // Apenas marcar como lido localmente - sem gamificação
      setState(() {
        _rewardGiven = true;
      });
      
      print('✅ Capítulo $_selectedBook $_selectedChapter lido');
    } catch (e) {
      print('❌ Erro ao registrar leitura: $e');
    }
  }

  void _selectVerse(int verseNumber) {
    // Esconder widget flutuante ao selecionar versículo
    _hideFloatingWidget();
    setState(() {
      _selectedVerse = verseNumber;
      _isReadingMode = true;
      _showVerseSelector = false;
      // Salva posição ao selecionar versículo
      if (_selectedBook != null && _selectedChapter != null) {
        ReadingPositionService.saveReadingPosition(
          bookName: _selectedBook!,
          chapter: _selectedChapter!,
          verse: verseNumber,
          version: _selectedVersion,
        );
      }
    });
    _startReadingSession();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToVerse(verseNumber);
    });
  }

  void _scrollToVerse(int verseNumber, {double alignment = 0.3}) {
    final index = _verses.indexWhere((v) => v.verse == verseNumber);
    if (index >= 0) {
      _itemScrollController.scrollTo(
        index: index,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOut,
        alignment: alignment,
      );
    }
  }

  void _showBibleVersionDialog(BuildContext context, ThemeManager themeManager) {
    showDialog(
      context: context,
      builder: (context) => BibleVersionDialog(
        currentVersion: _selectedVersion,
        onVersionChanged: (newVersion) {
          // Esconder widget flutuante ao mudar versão
          _hideFloatingWidget();
          setState(() {
            _selectedVersion = newVersion;
          });
          if (_books.isNotEmpty) {
            _loadBooks();
          }
        },
      ),
    );
  }


  void _showError(String message) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _backToBooks() {
    // Parar leitura ao voltar
    _stopTTS();
    // Esconder widget flutuante ao voltar
    _hideFloatingWidget();
    // Limpar seleção múltipla
    _clearSelection();
    setState(() {
      _isReadingMode = false;
      _showVerseSelector = false;
      _selectedBook = null;
      _selectedChapter = null;
      _selectedVerse = null;
      _verses.clear();
      _currentReadingVerse = -1;
      _searchQuery = '';
      _searchController.clear();
    });
  }

  // Método para obter livros filtrados pela pesquisa
  List<BibleBook> get _filteredBooks {
    if (_searchQuery.isEmpty) {
      return _books;
    }
    
    // Normalizar a query de pesquisa (remover acentos e converter para minúsculo)
    final normalizedQuery = _normalizeText(_searchQuery);
    
    return _books.where((book) {
      // Normalizar o nome do livro também
      final normalizedBookName = _normalizeText(book.name);
      final normalizedAbbr = _normalizeText(_getBookAbbreviation(book.name));
      return normalizedBookName.contains(normalizedQuery) || normalizedAbbr.contains(normalizedQuery);
    }).toList();
  }

  // Método para normalizar texto (remover acentos e converter para minúsculo)
  String _normalizeText(String text) {
    return text
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('à', 'a')
        .replaceAll('â', 'a')
        .replaceAll('ã', 'a')
        .replaceAll('ä', 'a')
        .replaceAll('é', 'e')
        .replaceAll('è', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('ë', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ì', 'i')
        .replaceAll('î', 'i')
        .replaceAll('ï', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ò', 'o')
        .replaceAll('ô', 'o')
        .replaceAll('õ', 'o')
        .replaceAll('ö', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ù', 'u')
        .replaceAll('û', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ç', 'c')
        .replaceAll('ñ', 'n');
  }

  // Método para atualizar a pesquisa
  void _updateSearch(String query) {
    setState(() {
      _searchQuery = query;
    });
  }

  void _backToVerseSelector() {
    // Parar leitura ao voltar
    _stopTTS();
    // Esconder widget flutuante ao voltar
    _hideFloatingWidget();
    // Limpar seleção múltipla
    _clearSelection();
    setState(() {
      _isReadingMode = false;
      _showVerseSelector = true;
      _selectedVerse = null;
      _currentReadingVerse = -1;
    });
  }

  // ===== MÉTODOS DE MARCAÇÕES =====



  // Método para navegar para o próximo capítulo (incluindo próximo livro)
  Future<void> _navigateToNextChapter() async {
    await _stopTTS();
    // Esconder widget flutuante ao navegar
    _hideFloatingWidget();
    setState(() => _selectedVerse = null);
    
    final currentBook = _books.firstWhere(
      (b) => b.name == _selectedBook, 
      orElse: () => BibleBook(name: '', chapters: 1, testament: 'AT')
    );
    
    final currentChapter = _selectedChapter ?? 1;
    
    // Se ainda há capítulos no livro atual
    if (currentChapter < currentBook.chapters) {
      _loadChapter(_selectedBook!, currentChapter + 1, directRead: true);
      return;
    }
    
    // Chegou no último capítulo do livro - ir para o próximo livro
    final currentBookIndex = _books.indexWhere((b) => b.name == _selectedBook);
    
    if (currentBookIndex == -1) return;
    
    String? nextBookName;
    
    // Se não é o último livro da lista
    if (currentBookIndex < _books.length - 1) {
      nextBookName = _books[currentBookIndex + 1].name;
    } else {
      // Último livro (Apocalipse) - volta para o primeiro (Gênesis)
      nextBookName = _books.isNotEmpty ? _books.first.name : null;
    }
    
    if (nextBookName != null) {
      // Navega automaticamente para o próximo livro sem mostrar modal
      _loadChapter(nextBookName, 1, directRead: true);
    }
  }

  // Versão especial para TTS que não para a leitura
  Future<void> _navigateToNextChapterForTTS() async {
    // Esconder widget flutuante ao navegar
    _hideFloatingWidget();
    setState(() => _selectedVerse = null);
    
    final currentBook = _books.firstWhere(
      (b) => b.name == _selectedBook, 
      orElse: () => BibleBook(name: '', chapters: 1, testament: 'AT')
    );
    
    final currentChapter = _selectedChapter ?? 1;
    
    // Se ainda há capítulos no livro atual
    if (currentChapter < currentBook.chapters) {
      await _loadChapterForTTS(_selectedBook!, currentChapter + 1);
      return;
    }
    
    // Chegou no último capítulo do livro - ir para o próximo livro
    final currentBookIndex = _books.indexWhere((b) => b.name == _selectedBook);
    
    if (currentBookIndex == -1) return;
    
    String? nextBookName;
    
    // Se não é o último livro da lista
    if (currentBookIndex < _books.length - 1) {
      nextBookName = _books[currentBookIndex + 1].name;
    } else {
      // Último livro (Apocalipse) - volta para o primeiro (Gênesis)
      nextBookName = _books.isNotEmpty ? _books.first.name : null;
    }
    
    if (nextBookName != null) {
      // Navega automaticamente para o próximo livro sem mostrar modal
      await _loadChapterForTTS(nextBookName, 1);
    }
  }
  
  // Método para navegar para o capítulo anterior (incluindo livro anterior)
  Future<void> _navigateToPreviousChapter() async {
    await _stopTTS();
    // Esconder widget flutuante ao navegar
    _hideFloatingWidget();
    setState(() => _selectedVerse = null);
    
    final currentChapter = _selectedChapter ?? 1;
    
    // Se não é o primeiro capítulo do livro atual
    if (currentChapter > 1) {
      _loadChapter(_selectedBook!, currentChapter - 1, directRead: true);
      return;
    }
    
    // Primeiro capítulo do livro - ir para o último capítulo do livro anterior
    final currentBookIndex = _books.indexWhere((b) => b.name == _selectedBook);
    
    if (currentBookIndex == -1) return;
    
    String? previousBookName;
    int? previousBookLastChapter;
    
    // Se não é o primeiro livro da lista
    if (currentBookIndex > 0) {
      final previousBook = _books[currentBookIndex - 1];
      previousBookName = previousBook.name;
      previousBookLastChapter = previousBook.chapters;
    } else {
      // Primeiro livro (Gênesis) - vai para o último (Apocalipse)
      if (_books.isNotEmpty) {
        final lastBook = _books.last;
        previousBookName = lastBook.name;
        previousBookLastChapter = lastBook.chapters;
      }
    }
    
    if (previousBookName != null && previousBookLastChapter != null) {
      // Navega automaticamente para o livro anterior sem mostrar modal
      _loadChapter(previousBookName, previousBookLastChapter, directRead: true);
    }
  }
  

  /// Verifica se há uma posição de leitura salva e oferece para continuar
  Future<void> _checkLastReadingPosition() async {
    // Aguardar um pouco para garantir que os livros foram carregados
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final continueFromLastPosition = prefs.getBool('continueFromLastPosition') ?? true;
    if (!continueFromLastPosition) return;

    final lastPosition = await ReadingPositionService.getLastReadingPosition();
    if (lastPosition != null && lastPosition.isRecent) {
      // Carregar direto sem perguntar
      _loadChapter(
        lastPosition.bookName,
        lastPosition.chapter,
        directRead: true,
      );
      // Se tinha um versículo específico, selecionar após carregar
      if (lastPosition.verse != null) {
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted) {
            _selectVerse(lastPosition.verse!);
          }
        });
      }
    }
  }

  /// Verifica se há um alvo de navegação de marcação e navega para ele
  Future<void> _checkBookmarkNavigationTarget() async {
    // Aguardar um pouco para garantir que os livros foram carregados
    await Future.delayed(const Duration(milliseconds: 600));

    if (!mounted) return;

    final settingsService = BibleSettingsService();
    final navigationTarget = await settingsService.getBookmarkNavigationTarget();

    if (navigationTarget != null) {
      // Limpar o alvo de navegação após usá-lo
      await settingsService.clearBookmarkNavigationTarget();

      // Navegar para o capítulo e versículo especificados
      _loadChapter(
        navigationTarget['bookName'] as String,
        navigationTarget['chapter'] as int,
        directRead: true,
      );

      // Se tinha um versículo específico, selecionar após carregar
      final verse = navigationTarget['verse'] as int?;
      if (verse != null) {
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted) {
            _selectVerse(verse);
          }
        });
      }
    }
  }



  void _showFloatingWidget() {
    print('DEBUG: _showFloatingWidget called');
    if (_overlayEntry != null) return;

    _overlayEntry = OverlayEntry(
      builder: (context) => _buildFloatingWidget(),
    );

    // Usar o contexto do widget principal para garantir que o Overlay funcione
    Overlay.of(context).insert(_overlayEntry!);

    // Não auto-hide - botões ficam visíveis até o usuário rolar ou limpar
    // _autoHideTimer?.cancel();
    // _autoHideTimer = Timer(const Duration(seconds: 30), () {
    //   _hideFloatingWidget();
    // });
  }

  void _hideFloatingWidget() {
    // _autoHideTimer?.cancel(); // Removido - não há mais auto-hide
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Widget _buildFloatingWidget() {
    return Positioned(
          top: 100,
          right: 16,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.95),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(
              color: Theme.of(context).primaryColor.withOpacity(0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildFloatingButton(
                'Marcar',
                Icons.bookmark_add,
                () => _markSelectedVerses(),
              ),
              const SizedBox(width: 12),
              _buildFloatingButton(
                'Obs',
                Icons.note_add,
                () => _addObservationToSelected(),
              ),
              const SizedBox(width: 12),
              _buildFloatingButton(
                'Limpar',
                Icons.clear_all,
                () => _clearSelection(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingButton(String text, IconData icon, VoidCallback onPressed) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 60,
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: Theme.of(context).primaryColor,
              size: 20,
            ),
            const SizedBox(height: 2),
            Text(
              text,
              style: TextStyle(
                color: Theme.of(context).primaryColor,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _markSelectedVerses() async {
    if (_selectedVerses.isEmpty) return;

    final bookmarksProvider = Provider.of<BookmarksProvider>(context, listen: false);

    // Ordenar versículos selecionados
    final sortedVerses = List<int>.from(_selectedVerses)..sort();

    // Pegar informações do primeiro versículo para os metadados
    final firstVerse = _verses.firstWhere((v) => v.verse == sortedVerses.first);

    try {
      await bookmarksProvider.addBookmark(
        bookName: firstVerse.book,
        chapter: firstVerse.chapter,
        verses: sortedVerses,
        bibleVersion: firstVerse.version,
        note: '',
      );

      _clearSelection();
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_selectedVerses.length} versículos marcados!')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao marcar versículos: $e')),
        );
      }
    }
  }

  void _addObservationToSelected() {
    if (_selectedVerses.isEmpty) return;

    final bookmarksProvider = Provider.of<BookmarksProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Consumer<ThemeManager>(
          builder: (context, themeManager, child) {
            return StatefulBuilder(
              builder: (context, setState) {
                String observation = '';
                int maxLength = 500;

                return Dialog(
                  backgroundColor: Colors.transparent,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 400),
                    decoration: BoxDecoration(
                      color: themeManager.surfaceColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header com título e botão fechar
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          decoration: BoxDecoration(
                            color: themeManager.primaryColor.withOpacity(0.05),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(20),
                              topRight: Radius.circular(20),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.note_add,
                                color: themeManager.primaryColor,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Adicionar Observação',
                                  style: TextStyle(
                                    color: themeManager.primaryTextColor,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () => Navigator.of(context).pop(),
                                icon: Icon(
                                  Icons.close,
                                  color: themeManager.secondaryTextColor,
                                  size: 24,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        ),

                        // Conteúdo
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: themeManager.backgroundColor,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: themeManager.primaryColor.withOpacity(0.2),
                                  ),
                                ),
                                child: TextField(
                                  maxLines: 4,
                                  maxLength: maxLength,
                                  buildCounter: (context, {required currentLength, required isFocused, maxLength}) {
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        '$currentLength/${maxLength ?? 500}',
                                        style: TextStyle(
                                          color: maxLength != null && currentLength > maxLength * 0.9
                                              ? Colors.red
                                              : themeManager.secondaryTextColor,
                                          fontSize: 12,
                                        ),
                                      ),
                                    );
                                  },
                                  decoration: InputDecoration(
                                    hintText: 'Digite sua observação...',
                                    hintStyle: TextStyle(
                                      color: themeManager.secondaryTextColor,
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.all(16),
                                  ),
                                  style: TextStyle(
                                    color: themeManager.primaryTextColor,
                                    fontSize: 16,
                                  ),
                                  onChanged: (value) {
                                    setState(() {
                                      observation = value;
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Botões de ação
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          decoration: BoxDecoration(
                            color: themeManager.backgroundColor,
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(20),
                              bottomRight: Radius.circular(20),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text(
                                  'Cancelar',
                                  style: TextStyle(
                                    color: themeManager.secondaryTextColor,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton(
                                onPressed: observation.trim().isEmpty ? null : () async {
                                  // Ordenar versículos selecionados
                                  final sortedVerses = List<int>.from(_selectedVerses)..sort();

                                  // Pegar informações do primeiro versículo para os metadados
                                  final firstVerse = _verses.firstWhere((v) => v.verse == sortedVerses.first);

                                  try {
                                    await bookmarksProvider.addBookmark(
                                      bookName: firstVerse.book,
                                      chapter: firstVerse.chapter,
                                      verses: sortedVerses,
                                      bibleVersion: firstVerse.version,
                                      note: observation.trim(),
                                    );

                                    _clearSelection();

                                    if (context.mounted) {
                                      Navigator.of(context).pop();
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('${_selectedVerses.length} versículos marcados com observação!'),
                                          backgroundColor: themeManager.primaryColor,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Erro ao marcar versículos: $e'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: themeManager.primaryColor,
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  elevation: 0,
                                ),
                                child: Text(
                                  'Salvar',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
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
          },
        );
      },
    );
  }

  void _clearSelection() {
    setState(() {
      _selectedVerses.clear();
      _isMultiSelectMode = false;
    });
    _hideFloatingWidget();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<ThemeManager, FontManager, BookmarksProvider>(
      builder: (context, themeManager, fontManager, bookmarksProvider, child) {
        return Scaffold(
          backgroundColor: themeManager.backgroundColor,
          appBar: AppBar(
            automaticallyImplyLeading: (_isReadingMode || _showVerseSelector),
            leading: (_isReadingMode || _showVerseSelector)
                ? IconButton(
                    icon: const Icon(Icons.arrow_back),
                    tooltip: _isReadingMode
                        ? 'Voltar para seleção de versículo'
                        : 'Voltar para livros',
                    onPressed: () {
                      if (_isReadingMode) {
                        _backToVerseSelector();
                      } else {
                        _backToBooks();
                      }
                    },
                  )
                : null,
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _isReadingMode 
                      ? '$_selectedBook $_selectedChapter${_selectedVerse != null ? ':$_selectedVerse' : ''}'
                      : _showVerseSelector
                        ? '$_selectedBook $_selectedChapter'
                        : 'Bíblia',
                    style: TextStyle(
                      color: themeManager.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (!_isReadingMode && !_showVerseSelector)
                  InkWell(
                    onTap: () => _showBibleVersionDialog(context, themeManager),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        children: [
                          Text(
                            _selectedVersion.toUpperCase(),
                            style: TextStyle(
                              color: themeManager.primaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.edit,
                            color: themeManager.primaryColor,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            backgroundColor: themeManager.backgroundColor,
            elevation: 0,
            iconTheme: IconThemeData(color: themeManager.primaryTextColor),
            actions: [
              IconButton(
                icon: const Icon(Icons.format_size),
                tooltip: 'Ajustar tamanho da fonte',
                onPressed: _showFontSizeDialog,
              ),
              if (_isReadingMode)
                IconButton(
                  icon: const Icon(Icons.format_list_numbered),
                  onPressed: _backToVerseSelector,
                  tooltip: 'Escolher versículo',
                ),
              if (_isReadingMode || _showVerseSelector)
                IconButton(
                  icon: const Icon(Icons.menu_book),
                  onPressed: _backToBooks,
                  tooltip: 'Voltar aos livros',
                ),
            ],
          ),
          body: _isLoading
              ? Center(
                  child: CircularProgressIndicator(
                    color: themeManager.primaryColor,
                  ),
                )
              : _showVerseSelector
                  ? _buildVerseSelector(themeManager)
                  : _isReadingMode
                      ? _buildChapterView(themeManager, fontManager)
                      : _buildBooksView(themeManager),
        );
      },
    );
  }

  Widget _buildBooksView(ThemeManager themeManager) {
    return Column(
      children: [
        // Campo de pesquisa
        Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: themeManager.surfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: themeManager.primaryColor.withOpacity(0.2),
            ),
          ),
          child: TextField(
            controller: _searchController,
            onChanged: _updateSearch,
            decoration: InputDecoration(
              hintText: 'Buscar livro...',
              hintStyle: TextStyle(
                color: themeManager.secondaryTextColor,
              ),
              prefixIcon: Icon(
                Icons.search,
                color: themeManager.primaryColor,
              ),
              suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: Icon(
                      Icons.clear,
                      color: themeManager.secondaryTextColor,
                    ),
                    onPressed: () {
                      _searchController.clear();
                      _updateSearch('');
                    },
                  )
                : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            style: TextStyle(
              color: themeManager.primaryTextColor,
            ),
          ),
        ),

        // Lista de livros filtrados
        Expanded(
          child: _filteredBooks.isEmpty && _searchQuery.isNotEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.search_off,
                      size: 64,
                      color: themeManager.secondaryTextColor,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Nenhum livro encontrado',
                      style: TextStyle(
                        color: themeManager.secondaryTextColor,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tente uma busca diferente',
                      style: TextStyle(
                        color: themeManager.secondaryTextColor,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _filteredBooks.length,
                itemBuilder: (context, index) {
                  final book = _filteredBooks[index];
                  return _BookExpansionTile(
                    book: book,
                    themeManager: themeManager,
                    onChapterSelected: (chapter) => _loadChapter(book.name, chapter, directRead: false),
              );
            },
          ),
        ),
      ],
    );
  }  Widget _buildVerseSelector(ThemeManager themeManager) {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: themeManager.surfaceColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: themeManager.primaryColor.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(
              color: themeManager.primaryColor.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: themeManager.primaryColor,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: themeManager.primaryColor.withOpacity(0.2),
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.auto_stories_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              _selectedBook ?? '',
                              style: TextStyle(
                                color: themeManager.primaryTextColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '(${_getBookAbbreviation(_selectedBook!)})',
                              style: TextStyle(
                                color: themeManager.secondaryTextColor,
                                fontWeight: FontWeight.normal,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              Icons.menu_book,
                              color: themeManager.primaryColor,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _selectedVersion.toUpperCase(),
                              style: TextStyle(
                                color: themeManager.primaryColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 6,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1.2,
              ),
              itemCount: _verses.length,
              itemBuilder: (context, index) {
                final verse = _verses[index];
                return InkWell(
                  onTap: () => _selectVerse(verse.verse),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: themeManager.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: themeManager.primaryColor.withOpacity(0.2),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        verse.verse.toString(),
                        style: TextStyle(
                          color: themeManager.primaryColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChapterView(ThemeManager themeManager, FontManager fontManager) {
    return Column(
      children: [
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: (ScrollNotification scrollInfo) {
              if (scrollInfo is ScrollUpdateNotification &&
                  scrollInfo.scrollDelta != null &&
                  scrollInfo.scrollDelta!.abs() > 50.0) {
                _hideFloatingWidget();
              }
              return false;
            },
            child: ScrollConfiguration(
              behavior: const _NoGlowNoStretchBehavior(),
              child: ScrollablePositionedList.builder(
                itemScrollController: _itemScrollController,
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _verses.length,
                itemBuilder: (context, index) {
                  final verse = _verses[index];
                  final isSelected = _selectedVerse == verse.verse;
                  final isCurrentlyReading = _isSpeaking && _currentReadingVerse >= 0 &&
                      _currentReadingVerse < _verses.length &&
                      _verses[_currentReadingVerse].verse == verse.verse;

                  return GestureDetector(
                    onTap: () {
                      if (_isMultiSelectMode) {
                        final wasSelected = _selectedVerses.contains(verse.verse);
                        setState(() {
                          if (wasSelected) {
                            _selectedVerses.remove(verse.verse);
                          } else {
                            _selectedVerses.add(verse.verse);
                          }
                        });
                        if (_selectedVerses.isEmpty) {
                          setState(() => _isMultiSelectMode = false);
                          _hideFloatingWidget();
                          _selectVerse(verse.verse);
                          return;
                        } else {
                          _selectedVerse = verse.verse;
                          _showFloatingWidget();
                        }
                      } else {
                        _selectVerse(verse.verse);
                      }
                    },
                    onLongPress: () {
                      print('DEBUG: Long press triggered for verse ${verse.verse}');
                      setState(() {
                        _isMultiSelectMode = true;
                        if (!_selectedVerses.contains(verse.verse)) {
                          _selectedVerses.add(verse.verse);
                        }
                      });
                      _showFloatingWidget();
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      decoration: BoxDecoration(
                        color: isCurrentlyReading
                            ? themeManager.primaryColor.withOpacity(0.08)
                            : isSelected
                                ? themeManager.primaryColor.withOpacity(0.05)
                                : Colors.transparent,
                        border: Border(
                          left: BorderSide(
                            color: isCurrentlyReading
                                ? themeManager.primaryColor
                                : isSelected
                                    ? themeManager.primaryColor.withOpacity(0.3)
                                    : Colors.transparent,
                            width: isCurrentlyReading ? 3 : (isSelected ? 2 : 0),
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                        if (isCurrentlyReading)
                          Container(
                            margin: const EdgeInsets.only(right: 8),
                            child: Icon(
                              _isPaused ? Icons.pause : Icons.volume_up,
                              color: themeManager.primaryColor,
                              size: 18,
                            ),
                          ),
                        if (_selectedVerses.contains(verse.verse) && !isCurrentlyReading)
                          Container(
                            margin: const EdgeInsets.only(right: 8),
                            child: Icon(
                              Icons.check_circle,
                              color: themeManager.primaryColor,
                              size: 18,
                            ),
                          ),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: '${verse.verse} ',
                                  style: TextStyle(
                                    color: themeManager.primaryColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: isCurrentlyReading ? fontManager.fontSize - 1 : fontManager.fontSize - 2,
                                  ),
                                ),
                                TextSpan(
                                  text: verse.text,
                                  style: TextStyle(
                                    color: themeManager.primaryTextColor,
                                    fontSize: isCurrentlyReading ? fontManager.fontSize + 1 : fontManager.fontSize,
                                    height: 1.6,
                                    fontWeight: isCurrentlyReading ? FontWeight.w500 : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        SafeArea(
          bottom: true,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: themeManager.surfaceColor,
              border: Border(top: BorderSide(color: themeManager.primaryColor.withOpacity(0.12))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new),
                  tooltip: 'Capítulo anterior',
                  color: themeManager.primaryColor,
                  onPressed: _navigateToPreviousChapter,
                ),
                // PAUSE: sempre visível, só ativa durante leitura ativa
                IconButton(
                  icon: const Icon(Icons.pause_circle_filled, size: 28),
                  tooltip: 'Pausar leitura',
                  color: themeManager.primaryColor,
                  onPressed: (_isSpeaking && !_isPaused) ? _pauseTTS : null,
                ),
                // PLAY: sempre visível, só desativa durante leitura ativa
                IconButton(
                  icon: const Icon(Icons.play_circle_fill, size: 32),
                  tooltip: !_isSpeaking ? 'Ouvir capítulo' : (_isPaused ? 'Retomar leitura' : 'Lendo capítulo...'),
                  color: themeManager.primaryColor,
                  onPressed: (!_isSpeaking || _isPaused) ? (!_isSpeaking ? _speakChapter : _resumeTTS) : null,
                ),
                // STOP: sempre visível, só ativa durante leitura ou pausa
                IconButton(
                  icon: const Icon(Icons.stop_circle_outlined, size: 28),
                  tooltip: 'Parar leitura',
                  color: themeManager.primaryColor,
                  onPressed: (_isSpeaking || _isPaused) ? _stopTTS : null,
                ),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_ios),
                    tooltip: 'Próximo capítulo',
                    color: themeManager.primaryColor,
                    onPressed: _navigateToNextChapter,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// Widget para expansão de livros com capítulos
class _BookExpansionTile extends StatefulWidget {
  final BibleBook book;
  final ThemeManager themeManager;
  final Function(int) onChapterSelected;

  const _BookExpansionTile({
    required this.book,
    required this.themeManager,
    required this.onChapterSelected,
  });

  @override
  State<_BookExpansionTile> createState() => _BookExpansionTileState();
}

class _BookExpansionTileState extends State<_BookExpansionTile> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: widget.themeManager.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.themeManager.primaryColor.withOpacity(0.1),
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: widget.themeManager.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        widget.book.testament == 'AT' ? 'AT' : 'NT',
                        style: TextStyle(
                          color: widget.themeManager.primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              widget.book.name,
                              style: TextStyle(
                                color: widget.themeManager.primaryTextColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '(${_getBookAbbreviation(widget.book.name)})',
                              style: TextStyle(
                                color: widget.themeManager.secondaryTextColor,
                                fontWeight: FontWeight.normal,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${widget.book.chapters} capítulos',
                          style: TextStyle(
                            color: widget.themeManager.secondaryTextColor,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: widget.themeManager.secondaryTextColor,
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: widget.themeManager.backgroundColor.withOpacity(0.5),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: _buildChapterGrid(),
            ),
        ],
      ),
    );
  }

  Widget _buildChapterGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.2,
      ),
      itemCount: widget.book.chapters,
      itemBuilder: (context, index) {
        final chapter = index + 1;
        return InkWell(
          onTap: () => widget.onChapterSelected(chapter),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            decoration: BoxDecoration(
              color: widget.themeManager.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: widget.themeManager.primaryColor.withOpacity(0.2),
              ),
            ),
            child: Center(
              child: Text(
                chapter.toString(),
                style: TextStyle(
                  color: widget.themeManager.primaryColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// Função utilitária para pegar só a sigla
String _getBookAbbreviation(String bookName) {
  return BibleMetadata.getAbbreviation(bookName);
}

// Comportamento de scroll sem glow (Android) e sem stretch (iOS/Material3)
class _NoGlowNoStretchBehavior extends ScrollBehavior {
  const _NoGlowNoStretchBehavior();

  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) => const ClampingScrollPhysics();
}

