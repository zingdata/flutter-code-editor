import 'package:highlight/languages/java.dart';
import 'package:tuple/tuple.dart';

import 'package:flutter_code_editor/src/single_line_comments/parser/single_line_comments.dart';
import 'package:flutter_code_editor/src/folding/parsers/fallback.dart';

class JavaFallbackFoldableBlockParser extends FallbackFoldableBlockParser {
  JavaFallbackFoldableBlockParser()
      : super(
          singleLineCommentSequences: SingleLineComments.byMode[java] ?? [],
          importPrefixes: ['package ', 'import '],
          multilineCommentSequences: [const Tuple2('/*', '*/')],
        );
}
