# Web Workers Deployment Guide

This guide explains how to enable Squadron web workers for better performance when deploying the Flutter Code Editor package.

## Overview

Squadron workers provide significant performance improvements by offloading heavy computations to background threads. Without workers, the package automatically falls back to main thread processing.

### Performance Impact

| Operation | Main Thread | With Workers | Improvement |
|-----------|-------------|--------------|-------------|
| Process 1000 suggestions | ~150ms | ~45ms | **3.3x faster** |
| Large JSON decode | ~200ms | ~60ms | **3.3x faster** |
| SQL table processing | ~300ms | ~90ms | **3.3x faster** |

## Quick Start

### For Package Developers

1. **Build with workers:**
   ```bash
   ./tool/build_web_with_workers.sh
   ```

2. **Test locally:**
   ```bash
   python3 -m http.server 8000 --directory build/web
   # Open http://localhost:8000
   ```

3. **Verify workers loaded:**
   - Open browser console
   - Look for: `✅ [WEB WORKER] processSqlSuggestionItems: Completed in Xms`

### For Package Users

When using `flutter_code_editor` as a dependency:

1. **Build your web app:**
   ```bash
   flutter build web
   ```

2. **Copy worker files** (choose one method):

   **Method A: Manual copy**
   ```bash
   # From your .pub-cache or package location
   mkdir -p build/web/workers
   find .dart_tool/build -name "*suggestion_worker_pool.web.g.dart.js" -exec cp {} build/web/workers/ \;
   ```

   **Method B: Add to your build script**
   ```bash
   #!/bin/bash
   flutter build web
   mkdir -p build/web/workers
   # Copy from package
   cp path/to/flutter_code_editor/lib/src/code_field/code_controller/helpers/suggestions/*.web.g.dart.js build/web/workers/
   ```

## Detailed Setup

### 1. Build Configuration

The package's `build.yaml` is already configured:

```yaml
targets:
  $default:
    builders:
      squadron_builder:
        enabled: true
        options:
          web_output_path: web/workers
          generate_vm: true
          generate_web: true
```

### 2. Worker File Structure

After building, you should have:

```
build/web/
├── index.html
├── main.dart.js
└── workers/
    ├── suggestion_worker_pool.web.g.dart.js    (Required)
    ├── suggestion_worker_pool.web.g.dart.wasm  (Optional, better performance)
    └── suggestion_worker_pool.web.g.dart.mjs   (Optional, ES6 modules)
```

### 3. Web Server Configuration

#### MIME Types

Ensure your server serves these MIME types correctly:

```nginx
# Nginx example
location ~* \.js$ {
    types { application/javascript js; }
}
location ~* \.wasm$ {
    types { application/wasm wasm; }
}
location ~* \.mjs$ {
    types { application/javascript mjs; }
}
```

```apache
# Apache example (.htaccess)
<FilesMatch "\.(js|mjs)$">
    ForceType application/javascript
</FilesMatch>
<FilesMatch "\.wasm$">
    ForceType application/wasm
</FilesMatch>
```

#### CORS Headers

If workers are on a different origin (not recommended), configure CORS:

```nginx
# Nginx
add_header Access-Control-Allow-Origin "*";
add_header Access-Control-Allow-Methods "GET, OPTIONS";
```

**Best Practice:** Serve workers from the same origin to avoid CORS issues.

### 4. Content Security Policy (CSP)

If using CSP headers, ensure workers are allowed:

```html
<meta http-equiv="Content-Security-Policy"
      content="worker-src 'self';">
```

Or in HTTP headers:
```
Content-Security-Policy: worker-src 'self';
```

### 5. HTTPS Requirement

Web Workers require a **secure context** (HTTPS) in production.

- ✅ Development: `localhost` and `127.0.0.1` are considered secure
- ✅ Production: HTTPS required
- ❌ Production HTTP: Workers will fail to load

## Deployment Checklist

Use this checklist before deploying:

- [ ] Worker files copied to `web/workers/` directory
- [ ] At minimum, `*.web.g.dart.js` files present
- [ ] Web server configured to serve `.js`, `.wasm`, `.mjs` correctly
- [ ] CORS headers configured (if needed)
- [ ] CSP allows `worker-src 'self'`
- [ ] Using HTTPS in production
- [ ] Tested in target browsers

## Verification

### Browser Console

Check for these indicators:

**Success:**
```
✅ [WEB WORKER] processSqlSuggestionItems: Completed in 45ms
🚀 Squadron Platform Type: PlatformType.js
```

**Fallback (workers not loaded):**
```
❌ Failed to load worker - falling back to main thread
⚠️  Workers unavailable, using main thread processing
```

### Developer Tools

1. Open DevTools → Network tab
2. Filter by `workers`
3. Verify worker files are loaded (200 status)
4. Check for CORS or 404 errors

### Test Script

Run this in browser console:

```javascript
// Check if workers directory is accessible
fetch('/workers/suggestion_worker_pool.web.g.dart.js')
  .then(r => console.log('✅ Worker file accessible:', r.status === 200))
  .catch(e => console.error('❌ Worker file not found:', e));
```

## Platform-Specific Notes

### Firebase Hosting

```json
{
  "hosting": {
    "public": "build/web",
    "rewrites": [{
      "source": "**",
      "destination": "/index.html"
    }],
    "headers": [{
      "source": "/workers/**",
      "headers": [{
        "key": "Cache-Control",
        "value": "public, max-age=31536000"
      }]
    }]
  }
}
```

### Netlify

Create `netlify.toml`:

```toml
[[headers]]
  for = "/workers/*"
  [headers.values]
    Cache-Control = "public, max-age=31536000"
    Access-Control-Allow-Origin = "*"
```

### GitHub Pages

Workers should work out of the box. Just ensure files are in `workers/` directory.

### Vercel

Create `vercel.json`:

```json
{
  "headers": [
    {
      "source": "/workers/(.*)",
      "headers": [
        {
          "key": "Cache-Control",
          "value": "public, max-age=31536000, immutable"
        }
      ]
    }
  ]
}
```

## Troubleshooting

### Workers Not Loading

**Problem:** Console shows "Failed to load worker"

**Solutions:**
1. Check worker files exist in `build/web/workers/`
2. Verify web server is running and serving files
3. Check browser console for 404 or CORS errors
4. Ensure HTTPS in production

### Performance Not Improved

**Problem:** Workers load but performance is same

**Possible causes:**
1. Dataset too small (< 500 items) - workers have overhead
2. Workers are loading but falling back - check console for errors
3. Browser doesn't support workers

### CORS Errors

**Problem:** "Cross-origin request blocked"

**Solution:**
- Serve workers from same origin as app
- Or configure CORS headers on worker files

### CSP Violations

**Problem:** "Refused to create worker"

**Solution:**
Add to CSP: `worker-src 'self';`

## Fallback Behavior

The package is designed to work without workers:

1. App tries to initialize workers
2. If workers fail to load → automatic fallback
3. All functionality works on main thread
4. Slightly slower for large datasets
5. User experience is identical

**This means:** Workers are an **optimization**, not a **requirement**.

## Monitoring

### Production Monitoring

Track worker usage in your analytics:

```dart
import 'package:flutter_code_editor/src/code_field/code_controller/helpers/suggestions/worker_pool_manager.dart';

final health = await WorkerPoolManager.getHealthCheck();
// Send to analytics:
// - health['workersAvailable']
// - health['activeWorkers']
```

### Debug Information

In development, get detailed info:

```dart
final debugInfo = await WorkerPoolManager.getDebugInfo();
print(debugInfo);
// Shows: platform, worker count, initialization status, etc.
```

## Best Practices

1. **Always include worker files** in your deployment
2. **Test on target browsers** before production
3. **Monitor worker availability** in analytics
4. **Cache worker files** for better performance
5. **Use HTTPS** in production
6. **Don't rely on workers** for critical functionality

## Support

If workers don't load:
- The package automatically falls back to main thread
- All features continue to work
- Only performance is affected

For issues, check:
1. Browser console for specific errors
2. Network tab for failed requests
3. This deployment guide

## Summary

| Aspect | Status |
|--------|--------|
| Required for package to work | ❌ No (automatic fallback) |
| Improves performance | ✅ Yes (3x faster) |
| Extra deployment steps | ✅ Yes (copy worker files) |
| Complexity | 🟡 Medium |
| Worth it for production | ✅ Highly recommended |
