import 'package:flutter/material.dart';
import 'dart:math';
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

class PopupState extends State<Popup> {
  final pageStorageBucket = PageStorageBucket();
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(rebuild);
  }

  @override
  void dispose() {
    widget.controller.removeListener(rebuild);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maxPopUpWidth =
        Sizes.autocompletePopupMaxWidth + (ScreenSize.isMobile(context) ? 0 : 100);
    
    // Determine if popup should be flipped (shown above caret instead of below)
    final bool shouldFlip = _isVerticalFlipRequired(context);
    
    // Use the appropriate offset based on whether we should flip or not
    final Offset positionOffset = shouldFlip ? widget.flippedOffset : widget.normalOffset;
    
    // Ensure popup stays within screen bounds
    final screenSize = MediaQuery.of(context).size;
    double adjustedLeft = positionOffset.dx;
    
    // Adjust if popup would go off the right edge of the screen
    if (adjustedLeft + maxPopUpWidth > screenSize.width) {
      adjustedLeft = max(0, screenSize.width - maxPopUpWidth - 16); // 16px margin
    }
    
    // Adjust if popup would go off the left edge
    adjustedLeft = max(16, adjustedLeft); // 16px minimum margin
    
    // Calculate popup height - ensure minimum height for empty suggestions
    // Each item is exactly 34px high
    final int itemCount = max(1, widget.controller.suggestions.length);
    // Limit to 5 items max height, with minimum of 1 item
    final int visibleItemCount = min(5, itemCount);
    final double actualHeight = visibleItemCount * 34.0;

    return PageStorage(
      bucket: pageStorageBucket,
      child: Positioned(
        left: adjustedLeft,
        top: positionOffset.dy,
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(8),
          clipBehavior: Clip.antiAlias,
          child: Container(
            height: actualHeight, // Explicitly set height to ensure consistency
            width: maxPopUpWidth,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.all(Radius.circular(8)),
              border: Border.all(
                color: const Color(0xffDAE0E5),
              ),
            ),
            clipBehavior: Clip.hardEdge,
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
    );
  }

  bool _isVerticalFlipRequired(BuildContext context) {
    // Get the screen size
    final screenSize = MediaQuery.of(context).size;
    
    // Calculate exact height based on number of items (each is 34px)
    final int itemCount = max(1, widget.controller.suggestions.length);
    final int visibleItemCount = min(5, itemCount);
    final double popupHeight = visibleItemCount * 34.0;
    
    // Check if popup would extend below the bottom of the screen
    final wouldOverflowBottom = widget.normalOffset.dy + popupHeight > screenSize.height - 16;
    
    // Check if there's enough space to flip (show above cursor)
    final hasSpaceToFlip = widget.flippedOffset.dy > 16; // Minimum 16px from top
    
    // Flip if it would overflow AND there's space above
    return wouldOverflowBottom && hasSpaceToFlip;
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
        child: SizedBox(
          height: 34, // Fixed height for each suggestion item
          child: ColoredBox(
            color: widget.controller.selectedIndex == index
                ? const Color(0xff1D73C9).withOpacity(0.3)
                : Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
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
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.controller.suggestions[index].values.first
                              .replaceAll('"', '')
                              .replaceAll('`', ''),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: widget.style.copyWith(fontSize: 12),
                        ),
                        Text(
                          widget.controller.suggestions[index].keys.first,
                          textAlign: TextAlign.right,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
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
    setState(() {});
  }
}
