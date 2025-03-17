import 'package:highlight/highlight_core.dart';

import 'package:flutter_code_editor/src/single_line_comments/parser/abstract_single_line_comment_parser.dart';
import 'package:flutter_code_editor/src/single_line_comments/parser/highlight_single_line_comment_parser.dart';
import 'package:flutter_code_editor/src/single_line_comments/parser/text_single_line_comment_parser.dart';

class SingleLineCommentParser {
  static AbstractSingleLineCommentParser parseHighlighted({
    required String text,
    required Result? highlighted,
    required List<String> singleLineCommentSequences,
  }) {
    if (highlighted?.language != null) {
      return HighlightSingleLineCommentParser(
        text: text,
        highlighted: highlighted!,
        singleLineCommentSequences: singleLineCommentSequences,
      );
    }

    return TextSingleLineCommentParser(
      text: text,
      singleLineCommentSequences: singleLineCommentSequences,
    );
  }
}
