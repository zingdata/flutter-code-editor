#!/bin/bash
# Build Flutter Web with Squadron Workers
#
# This script builds the Flutter web app and copies Squadron worker files
# to the output directory so they can be loaded by the browser.
#
# Usage: ./tool/build_web_with_workers.sh [--release|--profile]

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse arguments
BUILD_MODE="release"
if [ "$1" = "--profile" ]; then
  BUILD_MODE="profile"
fi

echo -e "${BLUE}🏗️  Building Flutter Web with Squadron Workers (${BUILD_MODE} mode)${NC}"
echo ""

# Step 1: Clean previous build
echo -e "${YELLOW}🧹 Cleaning previous build...${NC}"
flutter clean

# Step 2: Get dependencies
echo -e "${YELLOW}📦 Getting dependencies...${NC}"
flutter pub get

# Step 3: Generate Squadron workers
echo -e "${YELLOW}⚙️  Generating Squadron worker files...${NC}"
flutter pub run build_runner build --delete-conflicting-outputs

# Verify worker files were generated
if ! ls lib/src/code_field/code_controller/helpers/suggestions/*.web.g.dart >/dev/null 2>&1; then
  echo -e "${RED}❌ ERROR: Squadron worker files were not generated!${NC}"
  echo -e "${YELLOW}   Check build_runner output for errors${NC}"
  exit 1
fi

echo -e "${GREEN}✅ Squadron worker files generated successfully${NC}"

# Step 4: Build web
echo -e "${YELLOW}🌐 Building Flutter web app (${BUILD_MODE})...${NC}"
if [ "$BUILD_MODE" = "profile" ]; then
  flutter build web --profile
else
  flutter build web --release
fi

# Step 5: Copy worker files to output directory
echo -e "${YELLOW}📋 Copying Squadron worker files to build/web/workers/...${NC}"

# Create workers directory
mkdir -p build/web/workers

# Copy JavaScript worker files (required)
JS_FILES=$(find lib -name "*.web.g.dart.js" 2>/dev/null)
if [ -n "$JS_FILES" ]; then
  find lib -name "*.web.g.dart.js" -exec cp {} build/web/workers/ \;
  echo -e "${GREEN}   ✓ Copied JavaScript workers${NC}"
else
  echo -e "${RED}   ⚠️  No JavaScript worker files found!${NC}"
fi

# Copy WASM files (optional, for better performance)
WASM_FILES=$(find lib -name "*.web.g.dart.wasm" 2>/dev/null)
if [ -n "$WASM_FILES" ]; then
  find lib -name "*.web.g.dart.wasm" -exec cp {} build/web/workers/ \; 2>/dev/null || true
  echo -e "${GREEN}   ✓ Copied WASM workers (optional)${NC}"
fi

# Copy MJS module files (optional, for ES6 modules)
MJS_FILES=$(find lib -name "*.web.g.dart.mjs" 2>/dev/null)
if [ -n "$MJS_FILES" ]; then
  find lib -name "*.web.g.dart.mjs" -exec cp {} build/web/workers/ \; 2>/dev/null || true
  echo -e "${GREEN}   ✓ Copied MJS modules (optional)${NC}"
fi

# Step 6: Verify worker files in output
echo ""
echo -e "${BLUE}📊 Build Summary:${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

WORKER_COUNT=$(ls -1 build/web/workers/ 2>/dev/null | wc -l | tr -d ' ')
if [ "$WORKER_COUNT" -gt 0 ]; then
  echo -e "${GREEN}✅ Build completed successfully!${NC}"
  echo ""
  echo -e "Worker files in build/web/workers/:"
  ls -lh build/web/workers/ | tail -n +2 | awk '{print "   " $9 " (" $5 ")"}'
  echo ""
  echo -e "${BLUE}📍 Output location:${NC} build/web/"
  echo -e "${BLUE}🌐 Worker files:${NC} build/web/workers/ ($WORKER_COUNT files)"
  echo ""
  echo -e "${GREEN}🚀 Ready to deploy!${NC}"
  echo ""
  echo -e "${YELLOW}Next steps:${NC}"
  echo -e "  1. Test locally:  python3 -m http.server 8000 --directory build/web"
  echo -e "  2. Open browser:  http://localhost:8000"
  echo -e "  3. Check console for: '✅ [WEB WORKER] ...' messages"
  echo ""
else
  echo -e "${RED}❌ ERROR: No worker files found in build/web/workers/${NC}"
  echo -e "${YELLOW}   The build may have succeeded but workers weren't copied.${NC}"
  echo -e "${YELLOW}   Check the script output above for errors.${NC}"
  exit 1
fi
