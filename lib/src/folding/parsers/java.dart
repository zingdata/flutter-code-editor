import 'package:highlight/highlight.dart';

import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter_code_editor/src/code/code_lines.dart';
import 'package:flutter_code_editor/src/folding/parsers/abstract.dart';
import 'package:flutter_code_editor/src/folding/parsers/java_fallback.dart';

class JavaFoldableBlockParser extends AbstractFoldableBlockParser {
  @override
  void parse({
    required Result highlighted,
    required Set<Object?> serviceCommentsSources,
    CodeLines lines = CodeLines.empty,
  }) {
    final textParser = highlighted.language == null
        ? JavaFallbackFoldableBlockParser()
        : HighlightFoldableBlockParser();
    textParser.parse(
      highlighted: highlighted,
      serviceCommentsSources: serviceCommentsSources,
      lines: lines,
    );

    blocks.addAll(textParser.blocks);
    invalidBlocks.addAll(textParser.invalidBlocks);
  }
}
