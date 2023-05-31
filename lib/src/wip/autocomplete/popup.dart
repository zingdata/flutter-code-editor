import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../sizes.dart';
import 'popup_controller.dart';

/// Popup window displaying the list of possible completions
class Popup extends StatefulWidget {
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

  final FocusNode parentFocusNode;
  final TextStyle style;
  final Color? backgroundColor;

  final bool isMobile;

  const Popup({
    super.key,
    required this.controller,
    required this.editingWindowSize,
    required this.editorOffset,
    required this.flippedOffset,
    required this.normalOffset,
    required this.parentFocusNode,
    required this.style,
    this.backgroundColor,
    this.isMobile = false,
  });

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
    final verticalFlipRequired = _isVerticalFlipRequired();
    final bool horizontalOverflow =
        widget.normalOffset.dx + Sizes.autocompletePopupMaxWidth > widget.editingWindowSize.width;
    final double leftOffsetLimit =
        // TODO(nausharipov): find where 100 comes from
        widget.editingWindowSize.width - Sizes.autocompletePopupMaxWidth + 100;

    return PageStorage(
      bucket: pageStorageBucket,
      child: Positioned(
        left: horizontalOverflow ? leftOffsetLimit - 100 : widget.normalOffset.dx - 100,
        top: verticalFlipRequired ? widget.flippedOffset.dy : widget.normalOffset.dy,
        child: Container(
          alignment: Alignment.topCenter,
          constraints: BoxConstraints(
            maxHeight: widget.isMobile
                ? Sizes.autocompletePopupMaxHeight
                : Sizes.autocompletePopupMaxHeight + 100,
            maxWidth: widget.isMobile
                ? Sizes.autocompletePopupMaxWidth
                : Sizes.autocompletePopupMaxWidth + 50,
          ),
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
          // Container is used because the vertical borders
          // in DecoratedBox are hidden under scroll.
          // ignore: use_decorated_box
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: const [
                BoxShadow(
                  color: Color.fromRGBO(9, 45, 83, .2),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
                BoxShadow(
                  color: Color.fromRGBO(9, 45, 83, .15),
                  blurRadius: 32,
                  spreadRadius: 2,
                  offset: Offset(0, 4),
                ),
              ],
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

  bool _isVerticalFlipRequired() {
    final isPopupShorterThanWindow =
        Sizes.autocompletePopupMaxHeight < widget.editingWindowSize.height;
    final isPopupOverflowingHeight =
        widget.normalOffset.dy + Sizes.autocompletePopupMaxHeight - (widget.editorOffset?.dy ?? 0) >
            widget.editingWindowSize.height;

    return isPopupOverflowingHeight && isPopupShorterThanWindow;
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Image.asset(
                        getZingIcon(widget.controller.suggestions[index].keys.first),
                        width: 16,
                        height: 16,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(width: 4),
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: widget.isMobile ? 140 : 180),
                        child: Text(
                          widget.controller.suggestions[index].values.first,
                          overflow: TextOverflow.ellipsis,
                          style: widget.style,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 140,
                  child: Text(
                    widget.controller.suggestions[index].keys.first,
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                    style: widget.style.copyWith(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.secondary,
                      fontFamily: 'NotoSans',
                      wordSpacing: 1,
                    ),
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
    setState(() {});
  }
}
