import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:flutter_code_editor/src/code_field/code_controller/code_controller.dart';
import 'package:flutter_code_editor/src/code_field/text_editing_value.dart';

class CopyAction extends Action<CopySelectionTextIntent> {
  CopyAction({
    required this.controller,
  });
  final CodeController controller;

  @override
  Future<void> invoke(CopySelectionTextIntent intent) async {
    final selection = controller.code.hiddenRanges.recoverSelection(
      controller.value.selection,
    );

    await Clipboard.setData(
      ClipboardData(text: selection.textInside(controller.code.text)),
    );

    if (intent.collapseSelection) {
      controller.value = controller.value.deleteSelection();
    }
  }
}
