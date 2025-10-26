import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/font_manager.dart';
import '../services/themes/theme_manager.dart';

/// Modal unificado para ajuste de tamanho da fonte
/// Usa o FontManager global para manter estado sincronizado
class FontSizeDialog extends StatefulWidget {
  const FontSizeDialog({super.key});

  @override
  State<FontSizeDialog> createState() => _FontSizeDialogState();
}

class _FontSizeDialogState extends State<FontSizeDialog> {
  late double _localFontSize;

  @override
  void initState() {
    super.initState();
    final fontManager = context.read<FontManager>();
    _localFontSize = fontManager.fontSize;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeManager, FontManager>(
      builder: (context, themeManager, fontManager, _) {
        return AlertDialog(
          backgroundColor: themeManager.surfaceColor,
          title: Text(
            'Tamanho da Fonte',
            style: TextStyle(
              color: themeManager.primaryTextColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Preview do texto com tamanho atual
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: themeManager.cardColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '1 ',
                        style: TextStyle(
                          color: themeManager.primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: _localFontSize - 2,
                        ),
                      ),
                      TextSpan(
                        text: 'No princípio era o Verbo.',
                        style: TextStyle(
                          color: themeManager.primaryTextColor,
                          fontSize: _localFontSize,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              // Controles de ajuste
              Row(
                children: [
                  // Botão diminuir
                  IconButton(
                    onPressed: _localFontSize > fontManager.minSize 
                        ? () {
                            final currentIndex = fontManager.allowedSizes.indexOf(_localFontSize);
                            if (currentIndex > 0) {
                              setState(() {
                                _localFontSize = fontManager.allowedSizes[currentIndex - 1];
                              });
                            }
                          }
                        : null,
                    icon: Icon(
                      Icons.remove_circle_outline,
                      color: _localFontSize > fontManager.minSize 
                          ? themeManager.primaryColor 
                          : themeManager.secondaryTextColor,
                    ),
                  ),
                  
                  // Slider principal
                  Expanded(
                    child: Slider(
                      value: _localFontSize,
                      min: fontManager.minSize,
                      max: fontManager.maxSize,
                      divisions: fontManager.divisions,
                      activeColor: themeManager.primaryColor,
                      inactiveColor: themeManager.primaryColor.withOpacity(0.3),
                      onChanged: (value) {
                        // Encontra o tamanho permitido mais próximo
                        double closest = fontManager.allowedSizes.first;
                        double minDiff = (value - closest).abs();
                        
                        for (final allowedSize in fontManager.allowedSizes) {
                          final diff = (value - allowedSize).abs();
                          if (diff < minDiff) {
                            closest = allowedSize;
                            minDiff = diff;
                          }
                        }
                        
                        setState(() {
                          _localFontSize = closest;
                        });
                      },
                    ),
                  ),
                  
                  // Botão aumentar
                  IconButton(
                    onPressed: _localFontSize < fontManager.maxSize 
                        ? () {
                            final currentIndex = fontManager.allowedSizes.indexOf(_localFontSize);
                            if (currentIndex < fontManager.allowedSizes.length - 1) {
                              setState(() {
                                _localFontSize = fontManager.allowedSizes[currentIndex + 1];
                              });
                            }
                          }
                        : null,
                    icon: Icon(
                      Icons.add_circle_outline,
                      color: _localFontSize < fontManager.maxSize 
                          ? themeManager.primaryColor 
                          : themeManager.secondaryTextColor,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 8),
              
              // Indicador do tamanho atual
              Center(
                child: Text(
                  'Tamanho: ${_localFontSize.toInt()}pt',
                  style: TextStyle(
                    color: themeManager.primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancelar',
                style: TextStyle(color: themeManager.secondaryTextColor),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                // Aplica a mudança globalmente
                await fontManager.setFontSize(_localFontSize);
                if (mounted) {
                  Navigator.of(context).pop();
                  
                  // Mostra confirmação
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Tamanho da fonte alterado para ${_localFontSize.toInt()}pt'),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: themeManager.primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Aplicar'),
            ),
          ],
        );
      },
    );
  }
}
