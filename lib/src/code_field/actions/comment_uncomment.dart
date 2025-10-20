import 'package:flutter/widgets.dart';

import 'package:flutter_code_editor/src/code_field/code_controller/code_controller.dart';

class CommentUncommentIntent extends Intent {
  const CommentUncommentIntent();
}

class CommentUncommentAction extends Action<CommentUncommentIntent> {
  CommentUncommentAction({
    required this.controller,
  });
  final CodeController controller;

  @override
  Object? invoke(CommentUncommentIntent intent) {
    controller.commentOutOrUncommentSelection();
    return null;
  }
}
