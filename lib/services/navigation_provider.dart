import 'package:flutter/material.dart';

class NavigationProvider extends ChangeNotifier {
  int _currentIndex = 0;
  final PageController _pageController = PageController();
  bool _isAnimating = false;

  int get currentIndex => _currentIndex;
  PageController get pageController => _pageController;

  void setIndex(int index) {
    if (_isAnimating) return; // Ignora mudanças durante animação programática
    _currentIndex = index;
    notifyListeners();
  }

  void animateToIndex(int index) {
    if (_currentIndex == index) return;
    _isAnimating = true;
    _currentIndex = index;
    notifyListeners(); // Notifica imediatamente para atualizar UI
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    ).then((_) {
      _isAnimating = false;
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}
