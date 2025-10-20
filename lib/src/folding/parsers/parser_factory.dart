import 'package:highlight/highlight_core.dart';
import 'package:highlight/languages/java.dart';
import 'package:highlight/languages/python.dart';
import 'package:highlight/languages/yaml.dart';

import 'package:flutter_code_editor/src/folding/parsers/abstract.dart';
import 'package:flutter_code_editor/src/folding/parsers/highlight.dart';
import 'package:flutter_code_editor/src/folding/parsers/indent.dart';
import 'package:flutter_code_editor/src/folding/parsers/java.dart';
import 'package:flutter_code_editor/src/folding/parsers/python.dart';

class FoldableBlockParserFactory {
  static AbstractFoldableBlockParser provideParser(Mode mode) {
    if (mode == python) {
      return PythonFoldableBlockParser();
    }
    if (mode == java) {
      return JavaFoldableBlockParser();
    }

    if (mode == yaml) {
      return IndentFoldableBlockParser();
    }

    return HighlightFoldableBlockParser();
  }
}
