// TODO(alexeyinkin): Remove when dropping support for Flutter < 3.10, https://github.com/akvelon/flutter-code-editor/issues/245
// ignore_for_file: unnecessary_non_null_assertion

import 'package:flutter/material.dart';

import '../code_field/code_controller.dart';
import '../line_numbers/gutter_style.dart';
import 'error.dart';
import 'fold_toggle.dart';

const _issueColumnWidth = 16.0;
const _foldingColumnWidth = 16.0;

const _lineNumberColumn = 0;
const _issueColumn = 1;
const _foldingColumn = 2;

class GutterWidget extends StatelessWidget {
  const GutterWidget({
    super.key,
    required this.codeController,
    required this.style,
    required this.scrollController,
    required this.size,
  });

  final CodeController codeController;
  final GutterStyle style;
  final ScrollController scrollController;
  final Size? size;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: codeController,
      builder: _buildOnChange,
    );
  }

  Widget _buildOnChange(BuildContext context, Widget? child) {
    final code = codeController.code;

    final gutterWidth = style.width -
        (style.showErrors ? 0 : _issueColumnWidth) -
        (style.showFoldingHandles ? 0 : _foldingColumnWidth);

    final issueColumnWidth = style.showErrors ? _issueColumnWidth : 0.0;
    final foldingColumnWidth = style.showFoldingHandles ? _foldingColumnWidth : 0.0;

    final tableRows = List.generate(
      code.hiddenLineRanges.visibleLineNumbers.length,
      (i) => const TableRow(
        // Use SizedBox with height for consistent vertical spacing
        children: [
          SizedBox(),
          SizedBox(),
          SizedBox(),
        ],
      ),
    );

    _fillLineNumbers(tableRows);

    if (style.showErrors) {
      _fillIssues(tableRows);
    }
    if (style.showFoldingHandles) {
      _fillFoldToggles(tableRows);
    }

    return Container(
      padding: style.margin ??
          const EdgeInsets.only(
            top: 10,
            bottom: 10,
            right: 10,
          ),
      width: style.showLineNumbers ? gutterWidth : null,
      child: SingleChildScrollView(
        controller: scrollController,
        child: Table(
          columnWidths: {
            _lineNumberColumn: const FlexColumnWidth(),
            _issueColumn: FixedColumnWidth(issueColumnWidth),
            _foldingColumn: FixedColumnWidth(foldingColumnWidth),
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: tableRows,
        ),
      ),
    );
  }

  Size getTextWidth(String text, TextStyle textStyle) {
    final textSpan = TextSpan(text: text, style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    return textPainter.size;
  }

  void _fillLineNumbers(List<TableRow> tableRows) {
    final code = codeController.code;

    for (final i in code.hiddenLineRanges.visibleLineNumbers) {
      final lineIndex = _lineIndexToTableRowIndex(i);

      if (lineIndex == null) {
        continue;
      }
      const newLine = '\n';
      double textWrappedTimes = 1;
      if (size != null && code.text.isNotEmpty) {
        final textWidth = getTextWidth(code.lines[lineIndex].text, style.textStyle!);
        textWrappedTimes = textWidth.width / (size!.width - 36);
      }

      // Wrap the text in a container with centered alignment and padding
      tableRows[lineIndex].children[_lineNumberColumn] = Container(
        padding: const EdgeInsets.only(top: 3.0),
        alignment: Alignment.centerLeft,
        child: Text(
          style.showLineNumbers
              ? '${i + 1} ${textWrappedTimes > 1 ? (newLine * (textWrappedTimes.ceil() - 1)) : ''}'
              : ' ',
          style: style.textStyle,
          textAlign: style.textAlign,
        ),
      );
    }
  }

  void _fillIssues(List<TableRow> tableRows) {
    for (final issue in codeController.analysisResult.issues) {
      if (issue.line >= codeController.code.lines.length) {
        continue;
      }

      final lineIndex = _lineIndexToTableRowIndex(issue.line);
      if (lineIndex == null || lineIndex >= tableRows.length) {
        continue;
      }

      tableRows[lineIndex].children[_issueColumn] = Container(
        padding: const EdgeInsets.symmetric(vertical: 3.0),
        alignment: Alignment.center,
        child: GutterErrorWidget(
          issue,
          style.errorPopupTextStyle ?? (throw Exception('Error popup style should never be null')),
        ),
      );
    }
  }

  void _fillFoldToggles(List<TableRow> tableRows) {
    final code = codeController.code;

    for (final block in code.foldableBlocks) {
      final lineIndex = _lineIndexToTableRowIndex(block.firstLine);
      if (lineIndex == null) {
        continue;
      }

      final isFolded = code.foldedBlocks.contains(block);

      tableRows[lineIndex].children[_foldingColumn] = Container(
        padding: const EdgeInsets.symmetric(vertical: 3.0),
        alignment: Alignment.center,
        child: FoldToggle(
          color: style.textStyle?.color,
          isFolded: isFolded,
          onTap: isFolded
              ? () => codeController.unfoldAt(block.firstLine)
              : () => codeController.foldAt(block.firstLine),
        ),
      );
    }

    // Add folded blocks that are not considered as a valid foldable block,
    // but should be folded because they were folded before becoming invalid.
    for (final block in code.foldedBlocks) {
      final lineIndex = _lineIndexToTableRowIndex(block.firstLine);
      if (lineIndex == null || lineIndex >= tableRows.length) {
        continue;
      }

      tableRows[lineIndex].children[_foldingColumn] = Container(
        padding: const EdgeInsets.symmetric(vertical: 3.0),
        alignment: Alignment.center,
        child: FoldToggle(
          color: style.textStyle?.color,
          isFolded: true,
          onTap: () => codeController.unfoldAt(block.firstLine),
        ),
      );
    }
  }

  int? _lineIndexToTableRowIndex(int line) {
    return codeController.code.hiddenLineRanges.cutLineIndexIfVisible(line);
  }
}
