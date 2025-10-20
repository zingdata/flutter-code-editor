import 'package:flutter/cupertino.dart';

import 'package:flutter_code_editor/flutter_code_editor.dart';

class OutdentIntent extends Intent {
  const OutdentIntent();
}

class OutdentIntentAction extends Action<OutdentIntent> {
  OutdentIntentAction({
    required this.controller,
  });
  final CodeController controller;

  @override
  Object? invoke(OutdentIntent intent) {
    controller.outdentSelection();

    return null;
  }
}
