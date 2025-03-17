import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

class PopupController extends ChangeNotifier {
  PopupController({required this.onCompletionSelected}) : super();
  List<Map<String, String>> suggestions = [];
  int _selectedIndex = 0;
  bool isPopupShown = false;
  final List<Map<String, List<String>>> _suggestionCategories = [];
  bool shouldShow = false;

  final ItemScrollController itemScrollController = ItemScrollController();
  final ItemPositionsListener itemPositionsListener = ItemPositionsListener.create();
  List<Map<String, List<String>>> get suggestionCategories => _suggestionCategories;

  /// Should be called when an active list item is selected to be inserted into the text
  late final void Function() onCompletionSelected;

  set selectedIndex(int value) {
    _selectedIndex = value;
    notifyListeners();
  }

  int get selectedIndex => _selectedIndex;

  void show(String? tableName, List<String> suggestions) {
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

    if (tableName != null) {
      // Prioritize column suggestions for the provided table
      final columnKey = 'Column in $tableName';

      // Sort the suggestions array to put columns of the specified table first
      // For items of the same type (column or non-column), prioritize by shortest length
      suggestions0.sort((a, b) {
        final aIsColumn = a.keys.first == columnKey;
        final bIsColumn = b.keys.first == columnKey;
        final aValue = a.values.first;
        final bValue = b.values.first;

        if (aIsColumn && !bIsColumn) {
          return -1; // a comes first (columns have priority)
        } else if (!aIsColumn && bIsColumn) {
          return 1; // b comes first (columns have priority)
        } else {
          // Both are columns or both are not columns
          // Sort by length (shortest first), then alphabetically if same length
          return aValue.length == bValue.length
              ? aValue.compareTo(bValue)
              : aValue.length.compareTo(bValue.length);
        }
      });
    }

    this.suggestions = suggestions0;

    _selectedIndex = -1;
    shouldShow = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (itemScrollController.isAttached) {
        itemScrollController.jumpTo(index: 0);
      }
    });

    notifyListeners();
  }

  void showOnlyColumnsOfTable(String tableName) {
    final List<Map<String, String>> suggestions0 = [];
    final Map<String, List<String>>? columnsMap = _suggestionCategories
        .firstWhereOrNull((element) => element.keys.first == 'Column in $tableName');
    if (columnsMap != null) {
      columnsMap.forEach((key, value) {
        for (var element in value) {
          suggestions0.add({key: element});
        }
      });
    }

    suggestions = suggestions0;

    _selectedIndex = -1;
    shouldShow = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (itemScrollController.isAttached) {
        itemScrollController.jumpTo(index: 0);
      }
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
  bool isColumn() => suggestions[selectedIndex].keys.first.contains('Column in');
}

/// Possible directions of completions list navigation
enum ScrollDirection {
  up,
  down,
}
