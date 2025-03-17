import 'package:flutter/cupertino.dart';

import 'package:flutter_code_editor/flutter_code_editor.dart';

class IndentIntent extends Intent {
  const IndentIntent();
}

class IndentIntentAction extends Action<IndentIntent> {

  IndentIntentAction({
    required this.controller,
  });
  final CodeController controller;

  @override
  Object? invoke(IndentIntent intent) {
    controller.indentSelection();
    return null;
  }
}
