import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

class PopupController extends ChangeNotifier {
  List<Map<String, String>> suggestions = [];
  int _selectedIndex = 0;
  bool isPopupShown = false;
  final List<Map<String, List<String>>> _suggestionCategories = [];
  bool shouldShow = false;

  final ItemScrollController itemScrollController = ItemScrollController();
  final ItemPositionsListener itemPositionsListener = ItemPositionsListener.create();

  /// Should be called when an active list item is selected to be inserted into the text
  late final void Function() onCompletionSelected;

  PopupController({required this.onCompletionSelected}) : super();

  set selectedIndex(int value) {
    _selectedIndex = value;
    notifyListeners();
  }

  int get selectedIndex => _selectedIndex;

  void show(List<String> suggestions) {
    final List<Map<String, String>> suggestions0 = [];

    for (final e in suggestions) {
      for (final element in _suggestionCategories) {
        element.forEach((key, value) {
          if (value.contains(e)) {
            suggestions0.add({key: e});
          }
        });
      }
    }

    this.suggestions = suggestions0;

    _selectedIndex = 0;
    shouldShow = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (itemScrollController.isAttached) {
        itemScrollController.jumpTo(index: 0);
      }
      notifyListeners();
    });

    notifyListeners();
  }

  void hide() {
    shouldShow = false;
    notifyListeners();
  }

  void addSuggestionCategories(List<Map<String, List<String>>> suggestionCategoriesSet) {
    _suggestionCategories.addAll(suggestionCategoriesSet);
  }

  void clearSuggestionCategory() {
    _suggestionCategories.clear();
  }

  /// Changes the selected item and scrolls through the list of completions on keyboard arrows pressed
  void scrollByArrow(ScrollDirection direction) {
    final previousSelectedIndex = selectedIndex;
    if (direction == ScrollDirection.up) {
      selectedIndex = (selectedIndex - 1 + suggestions.length) % suggestions.length;
    } else {
      selectedIndex = (selectedIndex + 1) % suggestions.length;
    }
    final visiblePositions = itemPositionsListener.itemPositions.value
        .where((item) {
          final bool isTopVisible = item.itemLeadingEdge >= 0;
          final bool isBottomVisible = item.itemTrailingEdge <= 1;
          return isTopVisible && isBottomVisible;
        })
        .map((e) => e.index)
        .toList();

    // List offset will be changed only if new selected item is not visible
    if (!visiblePositions.contains(selectedIndex)) {
      // If previously selected item was at the bottom of the visible part of the list,
      // on 'down' arrow the new one will appear at the bottom as well
      final isStepDown = selectedIndex - previousSelectedIndex == 1;
      if (isStepDown && selectedIndex < suggestions.length - 1) {
        itemScrollController.jumpTo(index: selectedIndex + 1, alignment: 1);
      } else {
        itemScrollController.jumpTo(index: selectedIndex);
      }
    }
    notifyListeners();
  }

  String getSelectedWord() => suggestions[selectedIndex].values.first;
}

/// Possible directions of completions list navigation
enum ScrollDirection {
  up,
  down,
}
