import 'package:flutter_code_editor/src/single_line_comments/single_line_comment.dart';

abstract class AbstractSingleLineCommentParser {
  List<SingleLineComment> get comments;

  Map<int, SingleLineComment> getCommentsByLines() =>
      {for (final comment in comments) comment.lineIndex: comment};

  Map<int, bool> getIfReadonlyCommentByLine() {
    final result = <int, bool>{};
    for (final comment in comments) {
      result[comment.lineIndex] = comment.isReadonly;
    }
    return result;
  }
}
