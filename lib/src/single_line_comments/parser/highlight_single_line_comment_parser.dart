import 'package:highlight/highlight_core.dart';

import 'package:flutter_code_editor/src/highlight/node.dart';
import 'package:flutter_code_editor/src/single_line_comments/single_line_comment.dart';
import 'package:flutter_code_editor/src/single_line_comments/parser/abstract_single_line_comment_parser.dart';

class HighlightSingleLineCommentParser extends AbstractSingleLineCommentParser {
  HighlightSingleLineCommentParser({
    required this.text,
    required this.highlighted,
    required this.singleLineCommentSequences,
  }) {
    _parse();
  }
  final String text;
  final Result highlighted;
  final List<String> singleLineCommentSequences;

  @override
  final comments = <SingleLineComment>[];

  void _parse() {
    int lineIndex = 0;
    int characterIndex = 0;

    for (final node in highlighted.nodes ?? const <Node>[]) {
      if (node.className == 'comment') {
        final value = node.children?[0].value ?? '';

        if (_isSingleLineCommentText(value)) {
          comments.add(
            SingleLineComment.cut(
              value,
              lineIndex: lineIndex,
              characterIndex: characterIndex,
              sequences: singleLineCommentSequences,
              source: node,
            ),
          );
        }
      }

      lineIndex += node.getNewlineCount();
      characterIndex += node.getCharacterCount();
    }
  }

  bool _isSingleLineCommentText(String commentText) {
    for (final prefix in singleLineCommentSequences) {
      if (commentText.startsWith(prefix)) {
        return true;
      }
    }

    return false;
  }
}
