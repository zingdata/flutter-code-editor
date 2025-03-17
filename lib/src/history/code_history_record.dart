import 'package:equatable/equatable.dart';
import 'package:flutter/services.dart';

import 'package:flutter_code_editor/src/code/code.dart';

class CodeHistoryRecord with EquatableMixin {

  const CodeHistoryRecord({
    required this.code,
    required this.selection,
  });
  final Code code;
  final TextSelection selection;

  @override
  List<Object> get props => [
        code,
        selection,
      ];
}
