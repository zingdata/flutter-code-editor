import 'package:flutter_code_editor/src/code_field/disable_spell_check/disable_spell_check_if_web_stub.dart'
    if (dart.library.js) 'disable_spell_check_if_web.dart';

void disableSpellCheckIfWeb() {
  disableSpellCheck();
}
