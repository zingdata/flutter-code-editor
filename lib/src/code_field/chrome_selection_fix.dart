// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
// ignore: deprecated_member_use
import 'dart:js' as js;

/// Chrome-specific text selection handling that fixes the line selection issues in Chrome browser
class ChromeSelectionFix {
  static bool _isFixed = false;
  
  /// Fix selection issues in Chrome browser
  static void fixChromeSelection() {
    if (_isFixed) return;
    
    if (_isChromeBrowser()) {
      _applyChromeSelectionFix();
      _isFixed = true;
    }
  }
  
  /// Detect if the browser is Chrome
  static bool _isChromeBrowser() {
    try {
      final vendor = html.window.navigator.vendor.toLowerCase();
      final agent = html.window.navigator.userAgent.toLowerCase();
      return vendor.contains('google') && agent.contains('chrome');
    } catch (_) {
      return false; 
    }
  }
  
  /// Apply the Chrome selection fix
  static void _applyChromeSelectionFix() {
    // Using raw JavaScript to directly address Chrome's selection issues
    const jsFixScript = r'''
    (() => {
      // Track if the script is already running
      if (window._chromeSelectionFixApplied) return;
      window._chromeSelectionFixApplied = true;
      
      // Wait for Flutter to render the text field
      const observer = new MutationObserver((mutations, obs) => {
        const glassPanes = document.getElementsByTagName('flt-glass-pane');
        if (glassPanes.length === 0) return;
        
        const pane = glassPanes[0];
        if (!pane.shadowRoot) return;
        
        // Get all textarea elements used by Flutter for text input
        const getTextAreas = () => {
          const textareas = [];
          for (const form of pane.shadowRoot.querySelectorAll('form')) {
            for (const textarea of form.querySelectorAll('textarea')) {
              textareas.push(textarea);
            }
          }
          return textareas;
        };
        
        // Process all textareas to fix selection
        const processTextAreas = () => {
          const textareas = getTextAreas();
          if (textareas.length === 0) return false;
          
          for (const textarea of textareas) {
            // Skip if already processed
            if (textarea.dataset.selectionFixed) continue;
            textarea.dataset.selectionFixed = "true";
            
            // Fix line-height CSS to ensure consistent selection behavior
            textarea.style.lineHeight = "1.5";
            
            // Prevent Chrome's auto-selection behavior
            textarea.addEventListener('mousedown', (e) => {
              // Mark start position to help determine line selection
              textarea.dataset.selectionStart = e.offsetY.toString();
            });
            
            // Fix selection on triple-click (line selection)
            textarea.addEventListener('click', (e) => {
              if (e.detail === 3) {
                e.preventDefault();
                e.stopPropagation();
                
                // Get the selection range
                const start = textarea.selectionStart;
                const text = textarea.value;
                
                // Find beginning of the line
                let lineStart = start;
                while (lineStart > 0 && text[lineStart - 1] !== '\n') {
                  lineStart--;
                }
                
                // Find end of the line
                let lineEnd = start;
                while (lineEnd < text.length && text[lineEnd] !== '\n') {
                  lineEnd++;
                }
                
                // Set selection
                textarea.setSelectionRange(lineStart, lineEnd);
              }
            });
            
            // Fix selection on double-click (word selection)
            textarea.addEventListener('dblclick', (e) => {
              e.preventDefault();
              
              const start = textarea.selectionStart;
              const text = textarea.value;
              
              // Find word boundaries
              let wordStart = start;
              while (wordStart > 0 && /[\w$]/.test(text[wordStart - 1])) {
                wordStart--;
              }
              
              let wordEnd = start;
              while (wordEnd < text.length && /[\w$]/.test(text[wordEnd])) {
                wordEnd++;
              }
              
              // Set selection
              textarea.setSelectionRange(wordStart, wordEnd);
            });
          }
          return true;
        };
        
        // Check periodically for new textareas
        const checkInterval = setInterval(() => {
          if (processTextAreas()) {
            // Continue checking for new textareas that might be added later
          }
        }, 500);
        
        // Stop observing once we've found and processed textareas
        obs.disconnect();
      });
      
      // Start observing for Flutter to render elements
      observer.observe(document.body, {
        childList: true,
        subtree: true
      });
    })();
    ''';
    
    // Execute the script
    js.context.callMethod('eval', [jsFixScript]);
  }
} 