import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:linked_scroll_controller/linked_scroll_controller.dart';

// Conditionally import dart:js
import 'package:flutter_code_editor/src/code_field/browser_detection.dart';

import 'package:flutter_code_editor/src/code_theme/code_theme.dart';
import 'package:flutter_code_editor/src/gutter/gutter.dart';
import 'package:flutter_code_editor/src/line_numbers/gutter_style.dart';
import 'package:flutter_code_editor/src/sizes.dart';
import 'package:flutter_code_editor/src/wip/autocomplete/popup.dart';
import 'package:flutter_code_editor/src/code_field/actions/comment_uncomment.dart';
import 'package:flutter_code_editor/src/code_field/actions/indent.dart';
import 'package:flutter_code_editor/src/code_field/actions/outdent.dart';
import 'package:flutter_code_editor/src/code_field/code_controller/code_controller.dart';
import 'package:flutter_code_editor/src/code_field/default_styles.dart';
import 'package:flutter_code_editor/src/code_field/disable_spell_check/disable_spell_check.dart';



final _shortcuts = <ShortcutActivator, Intent>{
  // Copy
  LogicalKeySet(
    LogicalKeyboardKey.control,
    LogicalKeyboardKey.keyC,
  ): CopySelectionTextIntent.copy,
  const SingleActivator(
    LogicalKeyboardKey.keyC,
    meta: true,
  ): CopySelectionTextIntent.copy,
  LogicalKeySet(
    LogicalKeyboardKey.control,
    LogicalKeyboardKey.insert,
  ): CopySelectionTextIntent.copy,

  // Cut
  LogicalKeySet(
    LogicalKeyboardKey.control,
    LogicalKeyboardKey.keyX,
  ): const CopySelectionTextIntent.cut(SelectionChangedCause.keyboard),
  const SingleActivator(
    LogicalKeyboardKey.keyX,
    meta: true,
  ): const CopySelectionTextIntent.cut(SelectionChangedCause.keyboard),
  LogicalKeySet(
    LogicalKeyboardKey.shift,
    LogicalKeyboardKey.delete,
  ): const CopySelectionTextIntent.cut(SelectionChangedCause.keyboard),

  // Undo
  LogicalKeySet(
    LogicalKeyboardKey.control,
    LogicalKeyboardKey.keyZ,
  ): const UndoTextIntent(SelectionChangedCause.keyboard),
  const SingleActivator(
    LogicalKeyboardKey.keyZ,
    meta: true,
  ): const UndoTextIntent(SelectionChangedCause.keyboard),

  // Redo
  LogicalKeySet(
    LogicalKeyboardKey.shift,
    LogicalKeyboardKey.control,
    LogicalKeyboardKey.keyZ,
  ): const RedoTextIntent(SelectionChangedCause.keyboard),
  LogicalKeySet(
    LogicalKeyboardKey.shift,
    LogicalKeyboardKey.meta,
    LogicalKeyboardKey.keyZ,
  ): const RedoTextIntent(SelectionChangedCause.keyboard),

  // Indent
  LogicalKeySet(
    LogicalKeyboardKey.tab,
  ): const IndentIntent(),

  // Outdent
  LogicalKeySet(
    LogicalKeyboardKey.shift,
    LogicalKeyboardKey.tab,
  ): const OutdentIntent(),

  // Comment Uncomment
  LogicalKeySet(
    LogicalKeyboardKey.control,
    LogicalKeyboardKey.slash,
  ): const CommentUncommentIntent(),
  const SingleActivator(
    LogicalKeyboardKey.slash,
    meta: true,
  ): const CommentUncommentIntent(),
};

class CodeField extends StatefulWidget {

  const CodeField({
    super.key,
    required this.controller,
    this.minLines,
    this.maxLines,
    this.expands = false,
    this.wrap = false,
    this.background,
    this.decoration,
    this.textStyle,
    this.padding = EdgeInsets.zero,
    GutterStyle? gutterStyle,
    this.enabled,
    this.readOnly = false,
    this.cursorColor,
    this.textSelectionTheme,
    this.lineNumberBuilder,
    this.focusNode,
    this.keyboardType,
    this.cursorHeight,
    this.onChanged,
    this.isMobile = false,
    @Deprecated('Use gutterStyle instead') this.lineNumbers,
    @Deprecated('Use gutterStyle instead') this.lineNumberStyle = const GutterStyle(),
  })  : assert(
            gutterStyle == null || lineNumbers == null,
            'Can not provide gutterStyle and lineNumbers at the same time. '
            'Please use gutterStyle and provide necessary columns to show/hide'),
        gutterStyle = gutterStyle ?? ((lineNumbers == false) ? GutterStyle.none : lineNumberStyle);
  /// {@macro flutter.widgets.textField.minLines}
  final int? minLines;

  /// {@macro flutter.widgets.textField.maxLInes}
  final int? maxLines;

  /// {@macro flutter.widgets.textField.expands}
  final bool expands;

  /// Whether overflowing lines should wrap around
  /// or make the field scrollable horizontally.
  final bool wrap;

  /// A CodeController instance to apply
  /// language highlight, themeing and modifiers.
  final CodeController controller;

  @Deprecated('Use gutterStyle instead')
  final GutterStyle lineNumberStyle;

  /// {@macro flutter.widgets.textField.cursorColor}
  final Color? cursorColor;

  /// {@macro flutter.widgets.textField.textStyle}
  final TextStyle? textStyle;

  /// A way to replace specific line numbers by a custom TextSpan
  final TextSpan Function(int, TextStyle?)? lineNumberBuilder;

  /// {@macro flutter.widgets.textField.enabled}
  final bool? enabled;

  /// {@macro flutter.widgets.editableText.onChanged}
  final void Function(String)? onChanged;

  /// {@macro flutter.widgets.editableText.readOnly}
  final bool readOnly;

  final TextInputType? keyboardType;
  final double? cursorHeight;

  final Color? background;
  final EdgeInsets padding;
  final Decoration? decoration;
  final TextSelectionThemeData? textSelectionTheme;
  final FocusNode? focusNode;

  @Deprecated('Use gutterStyle instead')
  final bool? lineNumbers;

  final GutterStyle gutterStyle;

  final bool isMobile;

  @override
  State<CodeField> createState() => _CodeFieldState();
}

class _CodeFieldState extends State<CodeField> {
  // Add a controller
  LinkedScrollControllerGroup? _controllers;
  ScrollController? _numberScroll;
  ScrollController? _codeScroll;
  ScrollController? _horizontalCodeScroll;
  final _codeFieldKey = GlobalKey();

  OverlayEntry? _suggestionsPopup;
  Offset _caretDataOffset = Offset.zero;
  Offset _normalPopupOffset = Offset.zero;
  Offset _flippedPopupOffset = Offset.zero;
  double painterWidth = 0;
  double painterHeight = 0;

  FocusNode? _focusNode;
  String? lines;
  String longestLine = '';
  Size? windowSize;
  late TextStyle textStyle;
  Color? _backgroundCol;

  final _editorKey = GlobalKey();
  Offset? _editorOffset;

  @override
  void initState() {
    super.initState();

    _controllers = LinkedScrollControllerGroup();
    _numberScroll = _controllers?.addAndGet();
    _codeScroll = _controllers?.addAndGet();
    // _horizontalCodeScroll = ScrollController();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode!.attach(context, onKeyEvent: _onKeyEvent);

    // Workaround for disabling spellchecks in FireFox
    // https://github.com/akvelon/flutter-code-editor/issues/197
    disableSpellCheckIfWeb();

    // Add scroll listener to update popup position when scrolling
    _codeScroll?.addListener(_updatePopupOffsetOnScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final double width = _codeFieldKey.currentContext!.size!.width;
      final double height = _codeFieldKey.currentContext!.size!.height;
      windowSize = Size(width, height);
      _updatePopupOffset();
    });

    widget.controller.addListener(_onTextChanged);
    widget.controller.addListener(_updatePopupOffset);

    widget.controller.popupController.addListener(_onPopupStateChanged);
    _onTextChanged();
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    return widget.controller.onKey(event);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    widget.controller.removeListener(_updatePopupOffset);
    widget.controller.popupController.removeListener(_onPopupStateChanged);
    _codeScroll?.removeListener(_updatePopupOffsetOnScroll);
    _suggestionsPopup?.remove();

    _numberScroll?.dispose();
    _codeScroll?.dispose();
    _horizontalCodeScroll?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CodeField oldWidget) {
    super.didUpdateWidget(oldWidget);
    widget.controller.removeListener(_onTextChanged);
    widget.controller.removeListener(_updatePopupOffset);
    widget.controller.popupController.removeListener(_onPopupStateChanged);

    widget.controller.addListener(_onTextChanged);
    widget.controller.addListener(_updatePopupOffset);
    widget.controller.popupController.addListener(_onPopupStateChanged);
  }

  void rebuild() {
    setState(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // For some reason _codeFieldKey.currentContext is null in tests
        // so check first.
        final context = _codeFieldKey.currentContext;
        if (context != null) {
          final double width = context.size!.width;
          final double height = context.size!.height;
          windowSize = Size(width, height);
        }
      });
    });
  }

  void _onTextChanged() {
    // Rebuild line number
    final str = widget.controller.text.split('\n');
    final buf = <String>[];

    for (var k = 0; k < str.length; k++) {
      buf.add((k + 1).toString());
    }

    // Find longest line
    longestLine = '';
    widget.controller.text.split('\n').forEach((line) {
      if (line.length > longestLine.length) longestLine = line;
    });

    // Update editor offset when text changes or scrolls
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_codeScroll != null && _editorKey.currentContext != null) {
        final box = _editorKey.currentContext!.findRenderObject() as RenderBox?;
        final localOffset = box?.localToGlobal(Offset.zero);
        if (localOffset != null) {
          setState(() {
            _editorOffset = localOffset;
          });
        }
      }
    });

    rebuild();
  }

  // Wrap the codeField in a horizontal scrollView
  Widget _wrapInScrollView(
    Widget codeField,
    TextStyle textStyle,
    double minWidth,
  ) {
    final intrinsic = IntrinsicWidth(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: 0,
              minWidth: minWidth,
            ),
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                longestLine,
                style: textStyle,
              ),
            ), // Add extra padding
          ),
          widget.expands ? Expanded(child: codeField) : codeField,
        ],
      ),
    );

    return intrinsic;
  }

  @override
  Widget build(BuildContext context) {
    // Default color scheme
    const rootKey = 'root';

    final themeData = Theme.of(context);
    final styles = CodeTheme.of(context)?.styles;
    _backgroundCol =
        widget.background ?? styles?[rootKey]?.backgroundColor ?? DefaultStyles.backgroundColor;

    if (widget.decoration != null) {
      _backgroundCol = null;
    }

    final defaultTextStyle = TextStyle(
      color: styles?[rootKey]?.color ?? DefaultStyles.textColor,
      fontSize: themeData.textTheme.titleMedium?.fontSize,
    );

    textStyle = defaultTextStyle.merge(widget.textStyle);

    // Adjust textStyle to have consistent line height
    // This is a key fix for Chrome selection issues
    final adjustedTextStyle = textStyle.copyWith(
      height: getLineHeight(), // Use the function instead of constant
      leadingDistribution: TextLeadingDistribution.even, // Added for consistent text baselines
    );

    final codeField = TextField(
      focusNode: _focusNode,
      scrollPadding: widget.padding,
      style: adjustedTextStyle,
      controller: widget.controller,
      minLines: widget.minLines,
      maxLines: widget.maxLines,
      expands: widget.expands,
      scrollController: _codeScroll,
      keyboardType: widget.keyboardType,
      selectionControls: MaterialTextSelectionControls(),
      decoration: const InputDecoration(
        isCollapsed: true,
        // Add more vertical padding to help with line selection
        contentPadding: EdgeInsets.symmetric(vertical: 16),
        disabledBorder: InputBorder.none,
        border: InputBorder.none,
        focusedBorder: InputBorder.none,
      ),
      textAlignVertical: TextAlignVertical.top, // Align text at the top for better matching
      cursorColor: widget.cursorColor ?? defaultTextStyle.color,
      cursorHeight: widget.cursorHeight,
      autocorrect: false,
      enableSuggestions: false,
      enabled: widget.enabled,
      onChanged: widget.onChanged,
      readOnly: widget.readOnly,
      showCursor: true,
      autofocus: true,
      enableInteractiveSelection: true,
      dragStartBehavior: DragStartBehavior.down,
      mouseCursor: WidgetStateMouseCursor.textable,
      contextMenuBuilder: (context, editableTextState) {
        return AdaptiveTextSelectionToolbar.editableText(
          editableTextState: editableTextState,
        );
      },
    );

    final editingField = Theme(
      data: Theme.of(context).copyWith(
        textSelectionTheme: widget.textSelectionTheme ??
            TextSelectionThemeData(
              // Use a more pronounced and distinguishable selection color
              // This helps with Chrome's selection rendering
              selectionColor: Theme.of(context).colorScheme.primary.withOpacity(0.5),
              cursorColor: widget.cursorColor ?? defaultTextStyle.color,
              selectionHandleColor: Theme.of(context).colorScheme.primary,
            ),
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          // Control horizontal scrolling
          return _wrapInScrollView(codeField, textStyle, constraints.maxWidth);
        },
      ),
    );

    return FocusableActionDetector(
      actions: widget.controller.actions,
      shortcuts: _shortcuts,
      child: Container(
        decoration: widget.decoration,
        color: _backgroundCol,
        key: _codeFieldKey,
        padding: const EdgeInsets.only(left: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.gutterStyle.showGutter)
              Container(
                alignment: Alignment.topCenter,
                child: _buildGutter(),
              ),
            Expanded(key: _editorKey, child: editingField),
          ],
        ),
      ),
    );
  }

  Widget _buildGutter() {
    final lineNumberSize = textStyle.fontSize;
    final lineNumberColor = widget.gutterStyle.textStyle?.color ?? textStyle.color?.withOpacity(.5);

    // Ensure same text style properties for consistent line height
    final lineNumberTextStyle = (widget.gutterStyle.textStyle ?? textStyle).copyWith(
      color: lineNumberColor,
      fontFamily: textStyle.fontFamily,
      fontSize: lineNumberSize,
      height: getLineHeight(), // Use the function instead of constant
      // Add additional properties to ensure metrics consistency
      leadingDistribution: TextLeadingDistribution.even,
    );

    final gutterStyle = widget.gutterStyle.copyWith(
      textStyle: lineNumberTextStyle,
      errorPopupTextStyle: widget.gutterStyle.errorPopupTextStyle ??
          textStyle.copyWith(
            fontSize: DefaultStyles.errorPopupTextSize,
            backgroundColor: DefaultStyles.backgroundColor,
            fontStyle: DefaultStyles.fontStyle,
          ),
    );

    return GutterWidget(
      codeController: widget.controller,
      style: gutterStyle,
      scrollController: _numberScroll!,
      size: windowSize ?? Size.zero,
    );
  }

  void _updatePopupOffset() {
    // Update editor offset first to ensure we have the latest position
    if (_editorKey.currentContext != null) {
      final box = _editorKey.currentContext!.findRenderObject() as RenderBox?;
      if (box != null) {
        _editorOffset = box.localToGlobal(Offset.zero);
      }
    }
    
    final textPainter = _getTextPainter(widget.controller.text);
    final caretHeight = _getCaretHeight(textPainter);
    
    // Get caret position in global coordinates - this is absolute screen position
    final Offset cursorOffset = _getCaretOffset(textPainter);
    
    // Calculate how many suggestions we'll show (for height calculation)
    final suggestionCount = widget.controller.popupController.suggestions.isNotEmpty
        ? min(widget.controller.popupController.suggestions.length, 4)
        : 4;
    final popupHeight = suggestionCount * Sizes.autocompleteItemHeight;
    
    // Get the viewport height and caret position relative to viewport
    final viewportHeight = windowSize?.height ?? 0;
    final scrollOffset = _codeScroll?.offset ?? 0;
    final horizontalScrollOffset = _horizontalCodeScroll?.offset ?? 0;
    final relativeToViewport = cursorOffset.dy - scrollOffset;
    
    // Calculate positions for normal (below cursor) and flipped (above cursor) popup
    final normalTopOffset = cursorOffset.dy + caretHeight + 2; // Add small vertical offset for better appearance
    final flippedTopOffset = cursorOffset.dy - popupHeight - 2; // Small negative offset for spacing
    
    // Calculate horizontal position - right at the cursor
    // We're explicitly using cursor position instead of adding gutter width
    // Add small offset for better visual appearance
    final leftOffset = cursorOffset.dx + 2;
    
    setState(() {
      _caretDataOffset = cursorOffset;
      _normalPopupOffset = Offset(leftOffset, normalTopOffset);
      _flippedPopupOffset = Offset(leftOffset, flippedTopOffset);
    });
  }

  TextPainter _getTextPainter(String text) {
    return TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(text: text, style: textStyle),
    )..layout();
  }

  Offset _getCaretOffset(TextPainter textPainter) {
    final RenderBox? renderBox = _editorKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return Offset.zero;
    
    final TextPosition cursorPosition = widget.controller.selection.base;
    final String text = widget.controller.text;
    
    // Handle empty text case
    if (text.isEmpty) {
      return renderBox.localToGlobal(Offset.zero);
    }
    
    // Find the line where the cursor is located
    int cursorLine = 0;
    int lineStartOffset = 0;
    
    // Calculate which line the cursor is on
    for (int i = 0; i < cursorPosition.offset; i++) {
      if (i >= text.length) break;
      if (text[i] == '\n') {
        cursorLine++;
        lineStartOffset = i + 1;
      }
    }
    
    // Get the text of the current line up to the cursor
    final String currentLineText = text.substring(
      lineStartOffset, 
      min(cursorPosition.offset, text.length)
    );
    
    // Create a text painter just for the current line
    final TextPainter linePainter = TextPainter(
      text: TextSpan(text: currentLineText, style: textStyle),
      textDirection: TextDirection.ltr,
    );
    
    // Get available width for layout
    final double availableWidth = renderBox.size.width - widget.padding.horizontal;
    linePainter.layout(maxWidth: availableWidth);
    
    // Get the width of text up to cursor in current line
    // Note: Do NOT add gutter width here as we only want position within the editor
    final double cursorX = linePainter.width;
    
    // Get line height
    final double lineHeight = getLineHeight() * (textStyle.fontSize ?? 14.0);
    
    // Calculate Y position based on line number
    // Adjust for scroll position and ensure we're at the bottom of the line
    final double scrollY = _codeScroll?.offset ?? 0;
    final double cursorY = (cursorLine * lineHeight) - scrollY;
    
    // Convert to global coordinates
    return renderBox.localToGlobal(Offset(cursorX, cursorY));
  }

  double _getCaretHeight(TextPainter textPainter) {
    return textStyle.fontSize! * (getLineHeight());
  }

  double getLineHeight() {
    // Default line height multiple if not specified in the style
    return textStyle.height ?? 1.2;
  }

  double _getPopupLeftOffset(TextPainter textPainter) {
    // Get the horizontal position right after the cursor
    final cursorOffset = _getCaretOffset(textPainter);
    final horizontalScrollOffset = _horizontalCodeScroll?.offset ?? 0;
    
    // Position the popup at the cursor's right edge
    // Add a small offset for better visual appearance
    final leftPosition = cursorOffset.dx + 2 - horizontalScrollOffset;
    
    // Ensure popup doesn't go off the left edge of the screen
    return max(leftPosition, 0);
  }

  double _getPopupTopOffset(TextPainter textPainter, double caretHeight) {
    // Get cursor position
    final cursorOffset = _getCaretOffset(textPainter);
    
    // Get the vertical scroll offset
    final scrollOffset = _codeScroll?.offset ?? 0;
    
    // Get editor bounds
    final editorTop = (_editorOffset?.dy ?? 0);
    final viewportHeight = windowSize?.height ?? 0;
    
    // Position popup just below the cursor line
    final rawTopOffset = cursorOffset.dy + caretHeight;
    
    // Check if popup would go off the bottom of the viewport
    final availableSpace = viewportHeight - (rawTopOffset - scrollOffset);
    final popupHeight = min(
      widget.controller.popupController.suggestions.length, 
      4
    ) * Sizes.autocompleteItemHeight;
    
    if (availableSpace < popupHeight) {
      // If not enough space below, the popup will be flipped to appear above
      // This is handled via flippedOffset
      return rawTopOffset;
    }
    
    return rawTopOffset;
  }

  void _onPopupStateChanged() {
    final shouldShow = widget.controller.popupController.shouldShow && windowSize != null;
    if (!shouldShow) {
      _suggestionsPopup?.remove();
      _suggestionsPopup = null;
      return;
    }

    if (_suggestionsPopup == null) {
      _suggestionsPopup = _buildSuggestionOverlay();
      Overlay.of(context).insert(_suggestionsPopup!);
    }

    _suggestionsPopup!.markNeedsBuild();
  }

  OverlayEntry _buildSuggestionOverlay() {
    return OverlayEntry(
      builder: (context) {
        return Popup(
          caretDataOffset: _caretDataOffset,
          normalOffset: _normalPopupOffset,
          flippedOffset: _flippedPopupOffset,
          controller: widget.controller.popupController,
          editingWindowSize: windowSize!,
          style: textStyle,
          backgroundColor: _backgroundCol,
          parentFocusNode: _focusNode!,
          editorOffset: _editorOffset,
          isMobile: widget.isMobile,
        );
      },
    );
  }

  void _updatePopupOffsetOnScroll() {
    // Only update during scrolling if popup is visible
    if (widget.controller.popupController.shouldShow) {
      _updatePopupOffset();
    }
    
    // Update editor offset when scrolling
    if (_editorKey.currentContext != null) {
      final box = _editorKey.currentContext!.findRenderObject() as RenderBox?;
      final localOffset = box?.localToGlobal(Offset.zero);
      if (localOffset != null) {
        setState(() {
          _editorOffset = localOffset;
        });
      }
    }
  }
}
