import 'dart:math';

import 'package:flutter/widgets.dart';

import 'package:flutter_code_editor/src/code_field/editor_params.dart';
import 'package:flutter_code_editor/src/code_modifiers/code_modifier.dart';

class IndentModifier extends CodeModifier {
  const IndentModifier({
    this.handleBrackets = true,
  }) : super('\n');
  final bool handleBrackets;

  @override
  TextEditingValue? updateString(
    String text,
    TextSelection sel,
    EditorParams params,
  ) {
    var spacesCount = 0;
    String? lastChar;

    for (var k = min(sel.start, text.length) - 1; k >= 0; k--) {
      if (text[k] == '\n') {
        break;
      }

      if (text[k] == ' ') {
        spacesCount += 1;
      } else {
        lastChar ??= text[k];
        spacesCount = 0;
      }
    }

    if (lastChar == ':' || lastChar == '{') {
      spacesCount += params.tabSpaces;
    }

    final insert = '\n${' ' * spacesCount}';
    return replace(text, sel.start, sel.end, insert);
  }
}
