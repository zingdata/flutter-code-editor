import 'dart:math';

import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import 'package:flutter_code_editor/src/sizes.dart';
import 'package:flutter_code_editor/src/wip/autocomplete/popup_controller.dart';

/// Popup window displaying the list of possible completions
class Popup extends StatefulWidget {

  const Popup({
    super.key,
    required this.controller,
    required this.editingWindowSize,
    required this.editorOffset,
    required this.flippedOffset,
    required this.normalOffset,
    required this.caretDataOffset,
    required this.parentFocusNode,
    required this.style,
    this.backgroundColor,
    this.isMobile = false,
  });
  final PopupController controller;
  final Size editingWindowSize;

  /// The window coordinates of the top-left corner of the editor widget.
  final Offset? editorOffset;

  /// The window coordinates of the highest allowed top-left corner
  /// of the popup if shown above the caret.
  ///
  /// Since the popup is pushed to the bottom of the allowed rectangle
  /// the actual position may be lower.
  final Offset flippedOffset;

  /// The window coordinates of the top-left corner of the popup
  /// if shown below the caret.
  final Offset normalOffset;

  final Offset caretDataOffset;

  final FocusNode parentFocusNode;
  final TextStyle style;
  final Color? backgroundColor;

  final bool isMobile;

  @override
  PopupState createState() => PopupState();
}

class PopupState extends State<Popup> with SingleTickerProviderStateMixin {
  final pageStorageBucket = PageStorageBucket();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(rebuild);

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    
    _animationController.forward();
  }

  @override
  void dispose() {
    widget.controller.removeListener(rebuild);
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maxPopUpWidth =
        Sizes.autocompletePopupMaxWidth + (widget.isMobile ? 0 : 100);

    // Calculate available space on screen
    final screenSize = MediaQuery.of(context).size;
    
    // Determine if we need to flip the popup to show above cursor
    final bool shouldFlip = _shouldFlipPopup(context);
    
    // Use the appropriate offset based on whether the popup should be flipped
    final useOffset = shouldFlip ? widget.flippedOffset : widget.normalOffset;
    
    // Adjust left position to ensure popup stays on screen
    double leftPosition = useOffset.dx;
    final rightEdgePosition = leftPosition + maxPopUpWidth;
    
    // If popup would go off right edge of screen, adjust leftward
    if (rightEdgePosition > screenSize.width) {
      leftPosition = max(0, screenSize.width - maxPopUpWidth - 4);
    }

    return PageStorage(
      bucket: pageStorageBucket,
      child: Positioned(
        left: leftPosition,
        top: useOffset.dy,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Container(
            alignment: Alignment.topCenter,
            constraints: BoxConstraints(
              maxHeight: widget.isMobile
                  ? Sizes.autocompletePopupMaxHeight
                  : Sizes.autocompletePopupMaxHeight + 100,
              maxWidth: maxPopUpWidth,
            ),
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
            child: Material(
              elevation: 8.0,
              borderRadius: const BorderRadius.all(Radius.circular(8)),
              child: Container(
                decoration: BoxDecoration(
                  color: widget.backgroundColor ?? Colors.white,
                  borderRadius: const BorderRadius.all(Radius.circular(8)),
                  border: Border.all(
                    color: const Color(0xffDAE0E5),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: ScrollablePositionedList.builder(
                  shrinkWrap: true,
                  physics: const ClampingScrollPhysics(),
                  itemScrollController: widget.controller.itemScrollController,
                  itemPositionsListener: widget.controller.itemPositionsListener,
                  itemCount: widget.controller.suggestions.length,
                  itemBuilder: (context, index) {
                    return _buildListItem(index);
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _shouldFlipPopup(BuildContext context) {
    // Calculate available space below cursor
    final screenHeight = MediaQuery.of(context).size.height;
    final spaceBelow = screenHeight - widget.normalOffset.dy;
    
    // Calculate popup height based on number of suggestions
    final suggestionsCount = widget.controller.suggestions.length;
    final popupHeight = min(suggestionsCount, 4) * Sizes.autocompleteItemHeight;
    
    // If not enough space below cursor but enough space above, flip the popup
    final spaceAbove = widget.flippedOffset.dy;
    return spaceBelow < popupHeight && spaceAbove > popupHeight;
  }

  Widget _buildListItem(int index) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: () {
          widget.controller.selectedIndex = index;
          widget.parentFocusNode.requestFocus();
          widget.controller.onCompletionSelected();
        },
        onDoubleTap: () {
          widget.controller.selectedIndex = index;
          widget.parentFocusNode.requestFocus();
          widget.controller.onCompletionSelected();
        },
        hoverColor: Colors.grey.withOpacity(0.1),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: ColoredBox(
          color: widget.controller.selectedIndex == index
              ? const Color(0xff1D73C9).withOpacity(0.3)
              : Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Image.asset(
                  getZingIcon(widget.controller.suggestions[index].keys.first),
                  width: 16,
                  height: 16,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.controller.suggestions[index].values.first
                            .replaceAll('"', '')
                            .replaceAll('`', ''),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                        style: widget.style.copyWith(fontSize: 12),
                      ),
                      Text(
                        widget.controller.suggestions[index].keys.first,
                        textAlign: TextAlign.right,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                        style: widget.style.copyWith(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.secondary,
                          fontFamily: 'NotoSans',
                          wordSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String getZingIcon(String category) {
    switch (category) {
      case 'Function':
        return 'assets/icons-new-import/function.png';

      case 'Table':
        return 'assets/icons-new-import/tables.png';

      case 'Column':
        return 'assets/icons-new-import/field.png';

      default:
        return 'assets/icons-new-import/field.png';
    }
  }

  void rebuild() {
    setState(() {
      if (widget.controller.shouldShow && !_animationController.isAnimating) {
        _animationController.forward(from: 0.0);
      }
    });
  }
}
