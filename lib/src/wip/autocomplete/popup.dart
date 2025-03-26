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
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(rebuild);

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );

    // Initialize slide animation - direction will be set in build
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    // Slight delay before starting animation for a more natural feel
    Future.delayed(const Duration(milliseconds: 10), () {
      if (mounted) {
        _animationController.forward();
      }
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(rebuild);
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maxPopUpWidth = Sizes.autocompletePopupMaxWidth + (widget.isMobile ? 0 : 100);

    // Calculate available space on screen
    final screenSize = MediaQuery.of(context).size;

    // Determine if we need to flip the popup to show above cursor
    final bool shouldFlip = _shouldFlipPopup(context);

    // Update slide animation direction based on flip
    _slideAnimation = Tween<Offset>(
      begin: Offset(0, shouldFlip ? 0.05 : -0.05), // Slide down if flipped, up if normal
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    // Use the appropriate offset based on whether the popup should be flipped
    var useOffset = shouldFlip ? widget.flippedOffset : widget.normalOffset;
    useOffset = Offset(useOffset.dx, useOffset.dy + 10);
    // Get the editor's position and dimensions to adjust for side panels and boundaries
    final editorLeft = widget.editorOffset?.dx ?? 0;

    // Calculate editor's right boundary based on its width
    final editorWidth = widget.editingWindowSize.width;
    final editorRight = editorLeft + editorWidth;

    // Determine side panel width based on screen size
    double sidePanelWidth = 0;
    if (ScreenSize.isExtraWide(context)) {
      sidePanelWidth = 224;
    } else if (ScreenSize.isTablet(context)) {
      sidePanelWidth = 80.5;
    } else if (ScreenSize.isMobile(context)) {
      sidePanelWidth = 0;
    }

    // The caretDataOffset is the cursor position in global coordinates
    // Adjust for side panel width
    final adjustedLeftPosition = useOffset.dx - sidePanelWidth;

    // Constrain to screen and editor bounds
    final rightEdgePosition = adjustedLeftPosition + maxPopUpWidth;
    double finalLeftPosition = adjustedLeftPosition;

    // First check if popup extends beyond editor's right boundary
    if (rightEdgePosition > editorRight) {
      // Keep popup within editor bounds
      finalLeftPosition = max(editorLeft, editorRight - maxPopUpWidth - 4);
    }

    // Then check if popup extends beyond screen's right boundary
    if (rightEdgePosition > screenSize.width) {
      // Keep popup within screen bounds
      finalLeftPosition = max(0, screenSize.width - maxPopUpWidth - 8);
    }

    return PageStorage(
      bucket: pageStorageBucket,
      child: Positioned(
        left: finalLeftPosition,
        top: useOffset.dy,
        child: SlideTransition(
          position: _slideAnimation,
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
                color: Colors.transparent,
                shadowColor: Colors.black.withOpacity(0.14),
                borderRadius: const BorderRadius.all(Radius.circular(8)),
                child: Container(
                  decoration: BoxDecoration(
                    color: widget.backgroundColor ?? Colors.white,
                    borderRadius: const BorderRadius.all(Radius.circular(8)),
                    border: Border.all(
                      color: const Color(0xffDAE0E5),
                      width: 0.5,
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
    final isSelected = widget.controller.selectedIndex == index;

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
        hoverColor: Colors.grey.withOpacity(0.08),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOutCubic,
          color: isSelected ? const Color(0xff1D73C9).withOpacity(0.15) : Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  child: Image.asset(
                    getZingIcon(widget.controller.suggestions[index].keys.first),
                    width: 16,
                    height: 16,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(width: 6),
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
                        style: widget.style.copyWith(
                          fontSize: 13,
                          height: 1.2,
                          color: isSelected ? const Color(0xff1D73C9) : widget.style.color,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.controller.suggestions[index].keys.first,
                        textAlign: TextAlign.left,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: widget.style.copyWith(
                          fontSize: 12,
                          height: 1.2,
                          color: Theme.of(context).colorScheme.secondary.withOpacity(0.8),
                          fontFamily: 'NotoSans',
                          fontWeight: FontWeight.w400,
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
      if (widget.controller.shouldShow) {
        if (_animationController.isDismissed) {
          // Only animate when the popup is first appearing
          // Use a small delay to avoid visual glitches during quick typing
          Future.delayed(const Duration(milliseconds: 5), () {
            if (mounted && widget.controller.shouldShow) {
              _animationController.forward(from: 0.0);
            }
          });
        }
      } else {
        // If popup is being hidden, reset animation
        _animationController.value = 0.0;
      }
    });
  }
}
