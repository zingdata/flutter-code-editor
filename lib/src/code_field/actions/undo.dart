import 'package:flutter/widgets.dart';

import 'package:flutter_code_editor/src/code_field/code_controller/code_controller.dart';

class UndoAction extends Action<UndoTextIntent> {
  UndoAction({
    required this.controller,
  });
  final CodeController controller;

  @override
  Object? invoke(UndoTextIntent intent) {
    controller.historyController.undo();
    return null;
  }
}
