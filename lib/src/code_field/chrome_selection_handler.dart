import 'package:flutter_code_editor/src/code_field/chrome_selection_fix_stub.dart'
    if (dart.library.html) 'chrome_selection_fix.dart';

/// Initialize Chrome selection fix
void initChromeSelectionFix() {
  ChromeSelectionFix.fixChromeSelection();
} 