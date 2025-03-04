// ignore: avoid_web_libraries_in_flutter
import 'dart:js_interop' as js;
import 'dart:js_interop_unsafe' as js_util;

/// Web implementation of selection enhancer
void initWebSelection() {
  _enhanceTextSelection();
}

// Using a raw string to avoid escaping issues
const _jsEnhanceTextSelection = r'''
(() => {
  // Run periodically to ensure it applies after Flutter renders the text field
  var enhanceTextSelection = setInterval(function() {
    var elements = document.getElementsByTagName('flt-glass-pane');
    if (elements.length > 0 && elements[0].shadowRoot) {
      for (let child of elements[0].shadowRoot.children) {
        if (child.tagName.toLowerCase() == 'form') {
          let textFields = child.getElementsByTagName('textarea');
          for (let textField of textFields) {
            // Improve selection visibility
            textField.style.caretColor = 'auto';
            
            // Fix double-click word selection
            textField.addEventListener('dblclick', function(e) {
              const start = this.selectionStart;
              const value = this.value;
              
              // Find word boundaries
              let left = start;
              while (left > 0 && value[left - 1].match(/[\w$]/)) left--;
              
              let right = start;
              while (right < value.length && value[right].match(/[\w$]/)) right++;
              
              // Set selection
              this.setSelectionRange(left, right);
              e.preventDefault();
            });
            
            // Fix triple-click line selection
            let lastClickTime = 0;
            let clickCount = 0;
            
            textField.addEventListener('mousedown', function(e) {
              const now = Date.now();
              if (now - lastClickTime < 500) {
                clickCount++;
                if (clickCount === 3) {
                  const start = this.selectionStart;
                  const value = this.value;
                  
                  // Find line boundaries
                  let left = start;
                  while (left > 0 && value[left - 1] !== '\n') left--;
                  
                  let right = start;
                  while (right < value.length && value[right] !== '\n') right++;
                  
                  // Set selection
                  this.setSelectionRange(left, right);
                  e.preventDefault();
                }
              } else {
                clickCount = 1;
              }
              lastClickTime = now;
            });
          }
        }
      }
    }
  }, 1000);
})();
''';

void _enhanceTextSelection() {
  js.globalContext.callMethod('eval'.toJS, _jsEnhanceTextSelection.toJS);
} 