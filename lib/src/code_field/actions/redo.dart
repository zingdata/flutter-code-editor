import 'package:flutter/widgets.dart';

import 'package:flutter_code_editor/src/code_field/code_controller/code_controller.dart';

class RedoAction extends Action<RedoTextIntent> {

  RedoAction({
    required this.controller,
  });
  final CodeController controller;

  @override
  Object? invoke(RedoTextIntent intent) {
    controller.historyController.redo();
    return null;
  }
}
