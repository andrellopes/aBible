import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/themes/theme_manager.dart';
import '../services/bookmarks_provider.dart';
import '../services/bible_settings_service.dart';
import '../services/navigation_provider.dart';

class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({super.key});

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  @override
  void initState() {
    super.initState();
    // Carregar marcações quando a tela for aberta
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bookmarksProvider = Provider.of<BookmarksProvider>(context, listen: false);
      bookmarksProvider.loadBookmarks();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeManager, BookmarksProvider>(
      builder: (context, themeManager, bookmarksProvider, _) {
        final bookmarks = bookmarksProvider.bookmarks;
        final isLoading = bookmarksProvider.isLoading;

        return Scaffold(
          backgroundColor: themeManager.backgroundColor,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            backgroundColor: themeManager.surfaceColor,
            elevation: 0,
            title: Text(
              'Marcações',
              style: TextStyle(
                color: themeManager.primaryTextColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          body: isLoading
              ? Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      themeManager.primaryColor,
                    ),
                  ),
                )
              : bookmarks.isEmpty
                  ? _buildEmptyState(themeManager)
                  : _buildBookmarksList(themeManager, bookmarks, bookmarksProvider),
        );
      },
    );
  }

  Widget _buildEmptyState(ThemeManager themeManager) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bookmark_outline,
            size: 64,
            color: themeManager.secondaryTextColor,
          ),
          const SizedBox(height: 16),
          Text(
            'Nenhuma marcação ainda',
            style: TextStyle(
              color: themeManager.secondaryTextColor,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Toque longo em um versículo para marcá-lo',
            style: TextStyle(
              color: themeManager.secondaryTextColor,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBookmarksList(
    ThemeManager themeManager,
    List<Map<String, dynamic>> bookmarks,
    BookmarksProvider bookmarksProvider,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: bookmarks.length,
      itemBuilder: (context, index) {
        final bookmark = bookmarks[index];
        final hasNote = bookmark['note'] != null && bookmark['note'].toString().isNotEmpty;
        
        // Formatar data/hora
        String formattedDate = '';
        if (bookmark['created_at'] != null) {
          try {
            final dateTime = DateTime.parse(bookmark['created_at']);
            formattedDate = '${dateTime.day.toString().padLeft(2, '0')}/'
                          '${dateTime.month.toString().padLeft(2, '0')}/'
                          '${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:'
                          '${dateTime.minute.toString().padLeft(2, '0')}';
          } catch (e) {
            formattedDate = 'Data indisponível';
          }
        }
        
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            onTap: () => _navigateToBookmark(context, bookmark),
            leading: CircleAvatar(
              backgroundColor: themeManager.primaryColor,
              child: const Icon(
                Icons.bookmark,
                color: Colors.white,
                size: 20,
              ),
            ),
            title: Text(
              '${bookmark['book_name'] ?? 'Livro'} ${bookmark['chapter'] ?? 0}:${_formatVerses(bookmark)}',
              style: TextStyle(
                color: themeManager.primaryTextColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasNote) ...[
                  Text(
                    bookmark['note'],
                    style: TextStyle(
                      color: themeManager.secondaryTextColor,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  'Versão: ${bookmark['bible_version']} • $formattedDate',
                  style: TextStyle(
                    color: themeManager.secondaryTextColor,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            trailing: PopupMenuButton(
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      const Icon(Icons.edit_note),
                      const SizedBox(width: 8),
                      Text(hasNote ? 'Editar observação' : 'Adicionar observação'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'remove',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Remover', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
              onSelected: (value) {
                if (value == 'edit') {
                  _editNote(context, bookmark, bookmarksProvider);
                } else if (value == 'remove') {
                  _removeBookmark(context, bookmark, bookmarksProvider);
                }
              },
            ),
          ),
        );
      },
    );
  }

  void _navigateToBookmark(BuildContext context, Map<String, dynamic> bookmark) async {
    final bookName = bookmark['book_name'] as String?;
    final chapter = bookmark['chapter'] as int?;
    final versesList = bookmark['verses_list'] as List<int>?;
    final bibleVersion = bookmark['bible_version'] as String?;

    if (bookName != null && chapter != null && bibleVersion != null) {
      // Configurar navegação para a marcação
      final settingsService = BibleSettingsService();
      await settingsService.setBookmarkNavigationTarget(
        bookName: bookName,
        chapter: chapter,
        verse: versesList?.isNotEmpty == true ? versesList!.first : null,
        bibleVersion: bibleVersion,
      );

      // Mudar para a tela da Bíblia usando NavigationProvider
      if (context.mounted) {
        final navigationProvider = Provider.of<NavigationProvider>(context, listen: false);
        navigationProvider.animateToIndex(0); // Índice 0 = tela da Bíblia
      }
    }
  }

  Future<void> _removeBookmark(
    BuildContext context,
    Map<String, dynamic> bookmark,
    BookmarksProvider bookmarksProvider,
  ) async {
    try {
      final bookmarkId = bookmark['id'] as int;
      await bookmarksProvider.removeBookmark(bookmarkId);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Marcação removida')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao remover marcação: $e')),
        );
      }
    }
  }

  Future<void> _editNote(
    BuildContext context,
    Map<String, dynamic> bookmark,
    BookmarksProvider bookmarksProvider,
  ) async {
    final TextEditingController noteController = TextEditingController(
      text: bookmark['note'] ?? '',
    );

    final result = await showDialog<String>(
      context: context,
      builder: (context) => Consumer<ThemeManager>(
        builder: (context, themeManager, _) => StatefulBuilder(
          builder: (context, setState) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 8,
            backgroundColor: themeManager.surfaceColor,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header com ícone e título
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: themeManager.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.edit_note,
                          color: themeManager.primaryColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Observação',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: themeManager.primaryTextColor,
                              ),
                            ),
                            Text(
                              '${bookmark['book_name']} ${bookmark['chapter']}:${_formatVerses(bookmark)}',
                              style: TextStyle(
                                fontSize: 14,
                                color: themeManager.secondaryTextColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(
                          Icons.close,
                          color: themeManager.secondaryTextColor,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: themeManager.secondaryTextColor.withOpacity(0.1),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Campo de texto melhorado
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: themeManager.primaryColor.withOpacity(0.2),
                      ),
                    ),
                    child: TextField(
                      controller: noteController,
                      maxLines: 4,
                      minLines: 3,
                      maxLength: 500,
                      style: TextStyle(
                        color: themeManager.primaryTextColor,
                        fontSize: 16,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Digite sua observação aqui...',
                        hintStyle: TextStyle(
                          color: themeManager.secondaryTextColor.withOpacity(0.6),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(16),
                        counterStyle: TextStyle(
                          color: themeManager.secondaryTextColor,
                          fontSize: 12,
                        ),
                      ),
                      buildCounter: (context, {required currentLength, required isFocused, maxLength}) {
                        return Container(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                '$currentLength/$maxLength',
                                style: TextStyle(
                                  color: currentLength > maxLength! * 0.8
                                      ? Colors.orange
                                      : themeManager.secondaryTextColor,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Botões de ação
                  Row(
                    children: [
                      const Spacer(),

                      // Botão salvar
                      ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context, noteController.text),
                        icon: const Icon(Icons.save, size: 18),
                        label: const Text('Salvar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: themeManager.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 2,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (result != null && context.mounted) {
      try {
        final bookmarkId = bookmark['id'] as int;
        await bookmarksProvider.updateBookmarkNote(
          bookmarkId: bookmarkId,
          note: result,
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text('Observação salva com sucesso!'),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text('Erro ao salvar: $e'),
                ],
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        }
      }
    }
  }
}

String _formatVerses(Map<String, dynamic> bookmark) {
  try {
    final versesList = bookmark['verses_list'] as List<int>?;
    if (versesList == null || versesList.isEmpty) {
      debugPrint('BookmarksScreen: Lista de versículos vazia ou nula');
      return '';
    }

    debugPrint('BookmarksScreen: Formatando versículos: $versesList');

    // Se for apenas um versículo
    if (versesList.length == 1) {
      return versesList.first.toString();
    }

    // Verificar se é uma sequência contínua
    final sortedVerses = List<int>.from(versesList)..sort();
    bool isConsecutive = true;
    for (int i = 1; i < sortedVerses.length; i++) {
      if (sortedVerses[i] != sortedVerses[i - 1] + 1) {
        isConsecutive = false;
        break;
      }
    }

    // Se for sequência contínua, mostrar como range
    if (isConsecutive) {
      return '${sortedVerses.first}-${sortedVerses.last}';
    }

    // Se não for contínua, mostrar como lista separada por vírgulas
    final versesString = sortedVerses.join(', ');

    // Se for muito longo, truncar
    if (versesString.length > 20) {
      final truncated = sortedVerses.take(3).join(', ');
      return '$truncated...';
    }

    return versesString;
  } catch (e) {
    debugPrint('BookmarksScreen: Erro ao formatar versículos: $e');
    return '';
  }
}
