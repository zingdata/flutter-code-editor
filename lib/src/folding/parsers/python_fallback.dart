import 'package:highlight/languages/python.dart';

import 'package:flutter_code_editor/src/single_line_comments/parser/single_line_comments.dart';
import 'package:flutter_code_editor/src/folding/parsers/fallback.dart';

class PythonFallbackFoldableBlockParser extends FallbackFoldableBlockParser {
  PythonFallbackFoldableBlockParser()
      : super(
          singleLineCommentSequences: SingleLineComments.byMode[python] ?? [],
          importPrefixes: ['import ', 'from '],
        );
}
