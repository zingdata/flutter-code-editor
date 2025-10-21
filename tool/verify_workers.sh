#!/bin/bash
# Verify Squadron Workers Setup
#
# This script checks if Squadron workers are properly set up and ready for deployment.
#
# Usage: ./tool/verify_workers.sh [--build-dir <path>]

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Default build directory
BUILD_DIR="build/web"

# Parse arguments
if [ "$1" = "--build-dir" ] && [ -n "$2" ]; then
  BUILD_DIR="$2"
fi

echo -e "${BLUE}🔍 Verifying Squadron Workers Setup${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

ERRORS=0
WARNINGS=0

# Check 1: Source files
echo -e "${YELLOW}1. Checking source files...${NC}"
SOURCE_FILES=$(find lib -name "suggestion_worker_pool.dart" 2>/dev/null | wc -l | tr -d ' ')
if [ "$SOURCE_FILES" -gt 0 ]; then
  echo -e "${GREEN}   ✓ Source file found: suggestion_worker_pool.dart${NC}"
else
  echo -e "${RED}   ✗ Source file not found: suggestion_worker_pool.dart${NC}"
  ERRORS=$((ERRORS + 1))
fi

# Check 2: Generated Squadron files
echo -e "${YELLOW}2. Checking generated Squadron files...${NC}"

FILES_TO_CHECK=(
  "suggestion_worker_pool.worker.g.dart"
  "suggestion_worker_pool.activator.g.dart"
  "suggestion_worker_pool.vm.g.dart"
  "suggestion_worker_pool.web.g.dart"
  "suggestion_worker_pool.stub.g.dart"
)

for file in "${FILES_TO_CHECK[@]}"; do
  if find lib -name "$file" 2>/dev/null | grep -q .; then
    echo -e "${GREEN}   ✓ $file${NC}"
  else
    echo -e "${RED}   ✗ $file (not generated)${NC}"
    ERRORS=$((ERRORS + 1))
  fi
done

# Check 3: build.yaml configuration
echo -e "${YELLOW}3. Checking build.yaml configuration...${NC}"
if [ -f "build.yaml" ]; then
  if grep -q "squadron_builder" build.yaml; then
    echo -e "${GREEN}   ✓ squadron_builder configured${NC}"

    if grep -q "web_output_path.*workers" build.yaml; then
      echo -e "${GREEN}   ✓ web_output_path set to workers${NC}"
    else
      echo -e "${YELLOW}   ⚠  web_output_path not set to workers${NC}"
      WARNINGS=$((WARNINGS + 1))
    fi
  else
    echo -e "${RED}   ✗ squadron_builder not configured${NC}"
    ERRORS=$((ERRORS + 1))
  fi
else
  echo -e "${RED}   ✗ build.yaml not found${NC}"
  ERRORS=$((ERRORS + 1))
fi

# Check 4: Build output (if exists)
echo -e "${YELLOW}4. Checking build output...${NC}"
if [ -d "$BUILD_DIR" ]; then
  echo -e "${GREEN}   ✓ Build directory exists: $BUILD_DIR${NC}"

  # Check for workers directory
  if [ -d "$BUILD_DIR/workers" ]; then
    echo -e "${GREEN}   ✓ Workers directory exists${NC}"

    # Count worker files
    JS_COUNT=$(ls -1 "$BUILD_DIR/workers/"*.js 2>/dev/null | wc -l | tr -d ' ')
    WASM_COUNT=$(ls -1 "$BUILD_DIR/workers/"*.wasm 2>/dev/null | wc -l | tr -d ' ')
    MJS_COUNT=$(ls -1 "$BUILD_DIR/workers/"*.mjs 2>/dev/null | wc -l | tr -d ' ')

    if [ "$JS_COUNT" -gt 0 ]; then
      echo -e "${GREEN}   ✓ JavaScript workers: $JS_COUNT file(s)${NC}"
    else
      echo -e "${RED}   ✗ No JavaScript workers found (required)${NC}"
      ERRORS=$((ERRORS + 1))
    fi

    if [ "$WASM_COUNT" -gt 0 ]; then
      echo -e "${GREEN}   ✓ WASM workers: $WASM_COUNT file(s)${NC}"
    else
      echo -e "${YELLOW}   ⚠  No WASM workers (optional)${NC}"
    fi

    if [ "$MJS_COUNT" -gt 0 ]; then
      echo -e "${GREEN}   ✓ MJS modules: $MJS_COUNT file(s)${NC}"
    else
      echo -e "${YELLOW}   ⚠  No MJS modules (optional)${NC}"
    fi

    # List files
    if [ "$JS_COUNT" -gt 0 ] || [ "$WASM_COUNT" -gt 0 ] || [ "$MJS_COUNT" -gt 0 ]; then
      echo ""
      echo -e "${BLUE}   Worker files:${NC}"
      ls -lh "$BUILD_DIR/workers/" 2>/dev/null | tail -n +2 | awk '{print "     " $9 " (" $5 ")"}'
    fi
  else
    echo -e "${YELLOW}   ⚠  Workers directory doesn't exist: $BUILD_DIR/workers/${NC}"
    echo -e "${YELLOW}     Run: ./tool/copy_workers.sh${NC}"
    WARNINGS=$((WARNINGS + 1))
  fi
else
  echo -e "${YELLOW}   ⚠  Build directory doesn't exist: $BUILD_DIR${NC}"
  echo -e "${YELLOW}     Run: flutter build web${NC}"
fi

# Check 5: pubspec.yaml dependencies
echo -e "${YELLOW}5. Checking pubspec.yaml dependencies...${NC}"
if [ -f "pubspec.yaml" ]; then
  if grep -q "squadron:" pubspec.yaml; then
    echo -e "${GREEN}   ✓ squadron dependency found${NC}"
  else
    echo -e "${RED}   ✗ squadron dependency not found${NC}"
    ERRORS=$((ERRORS + 1))
  fi

  if grep -q "squadron_builder:" pubspec.yaml; then
    echo -e "${GREEN}   ✓ squadron_builder dev dependency found${NC}"
  else
    echo -e "${RED}   ✗ squadron_builder dev dependency not found${NC}"
    ERRORS=$((ERRORS + 1))
  fi
fi

# Summary
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}📊 Verification Summary${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
  echo -e "${GREEN}✅ All checks passed! Workers are ready.${NC}"
  echo ""
  echo -e "${BLUE}Next steps:${NC}"
  echo -e "  1. Deploy build/web/ to your web server"
  echo -e "  2. Verify workers load in browser console"
  echo -e "  3. Check for: '✅ [WEB WORKER] ...' messages"
  exit 0
elif [ $ERRORS -eq 0 ]; then
  echo -e "${YELLOW}⚠️  $WARNINGS warning(s) - workers may work with reduced performance${NC}"
  exit 0
else
  echo -e "${RED}❌ $ERRORS error(s) found${NC}"
  if [ $WARNINGS -gt 0 ]; then
    echo -e "${YELLOW}   $WARNINGS warning(s)${NC}"
  fi
  echo ""
  echo -e "${YELLOW}Fix errors and run verification again.${NC}"
  echo ""
  echo -e "${BLUE}To fix:${NC}"
  if ! find lib -name "*.worker.g.dart" 2>/dev/null | grep -q .; then
    echo -e "  1. Run: flutter pub run build_runner build --delete-conflicting-outputs"
  fi
  if [ ! -d "$BUILD_DIR/workers" ] || [ "$(ls -A $BUILD_DIR/workers 2>/dev/null)" = "" ]; then
    echo -e "  2. Run: ./tool/build_web_with_workers.sh"
    echo -e "     OR: ./tool/copy_workers.sh (if already built)"
  fi
  exit 1
fi
