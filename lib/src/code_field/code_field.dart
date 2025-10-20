import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_code_editor/src/code_field/actions/comment_uncomment.dart';
import 'package:flutter_code_editor/src/code_field/actions/indent.dart';
import 'package:flutter_code_editor/src/code_field/actions/outdent.dart';
import 'package:flutter_code_editor/src/code_field/browser_detection.dart';
import 'package:flutter_code_editor/src/code_field/code_controller/code_controller.dart';
import 'package:flutter_code_editor/src/code_field/default_styles.dart';
import 'package:flutter_code_editor/src/code_field/disable_spell_check/disable_spell_check.dart';
import 'package:flutter_code_editor/src/code_theme/code_theme.dart';
import 'package:flutter_code_editor/src/gutter/gutter.dart';
import 'package:flutter_code_editor/src/line_numbers/gutter_style.dart';
import 'package:flutter_code_editor/src/sizes.dart';
import 'package:flutter_code_editor/src/wip/autocomplete/popup.dart';
import 'package:linked_scroll_controller/linked_scroll_controller.dart';

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
    this.undoController,
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

  /// An UndoHistoryController instance
  /// to control TextField history.
  final UndoHistoryController? undoController;

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
      if (!mounted) {
        return;
      }
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
        if (!mounted) {
          return;
        }
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
      height: themeData.textTheme.titleMedium?.height,
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
      undoController: widget.undoController,
      minLines: widget.minLines,
      maxLines: widget.maxLines,
      expands: widget.expands,
      scrollController: _codeScroll,
      keyboardType: widget.keyboardType,
      selectionControls: kIsWeb ? DesktopTextSelectionControls() : MaterialTextSelectionControls(),
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

    // Get the font metrics to calculate an accurate line height
    final fontSize = textStyle.fontSize ?? 14.0;
    final lineHeight = fontSize * (textStyle.height ?? 1.2);

    // Get caret position in global coordinates - this is absolute screen position
    // This now accounts for soft wrapping
    final Offset cursorOffset = _getCaretOffset(textPainter);

    // Calculate how many suggestions we'll show (for height calculation)
    final suggestionCount = widget.controller.popupController.suggestions.isNotEmpty
        ? min(widget.controller.popupController.suggestions.length, 4)
        : 4;
    final popupHeight = suggestionCount * Sizes.autocompleteItemHeight;

    // Get the viewport height
    final viewportHeight = windowSize?.height ?? 0;

    // Calculate positions for normal (below cursor) and flipped (above cursor) popup
    // Using the actual line height for better positioning
    final normalTopOffset =
        cursorOffset.dy + lineHeight + 2; // Position just below the current line
    final flippedTopOffset = cursorOffset.dy - popupHeight - 2; // Position above the current line

    // Calculate horizontal position - right at the cursor
    final leftOffset = cursorOffset.dx + 2; // Small offset for better visual appearance

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

    // Instead of calculating line position based on newlines,
    // we'll use the TextPainter's getOffsetForCaret method which
    // properly accounts for text wrapping

    // Create a text painter for the entire text
    final fullTextPainter = TextPainter(
      text: TextSpan(text: text, style: textStyle),
      textDirection: TextDirection.ltr,
    );

    // Get available width for layout
    final double availableWidth = renderBox.size.width - widget.padding.horizontal;
    fullTextPainter.layout(maxWidth: availableWidth);

    // Get the offset at cursor position (this accounts for wrapping)
    final Offset rawOffset = fullTextPainter.getOffsetForCaret(
      cursorPosition,
      Rect.zero,
    );

    // Get horizontal scroll offset to adjust for horizontal scrolling
    final horizontalScrollOffset = _horizontalCodeScroll?.offset ?? 0;

    // Get vertical scroll offset to adjust position
    final scrollY = _codeScroll?.offset ?? 0;

    // Apply scroll offsets
    final double adjustedX = rawOffset.dx - horizontalScrollOffset;
    final double adjustedY = rawOffset.dy - scrollY;

    // Convert to global coordinates
    return renderBox.localToGlobal(Offset(adjustedX, adjustedY));
  }

  double getLineHeight() {
    // Default line height multiple if not specified in the style
    return getChromeLineHeight() ?? (textStyle.height ?? 1.2);
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
