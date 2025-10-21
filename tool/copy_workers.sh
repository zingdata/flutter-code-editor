#!/bin/bash
# Copy Squadron Worker Files to Build Output
#
# This is a standalone script to copy worker files after a regular Flutter build.
# Use this if you've already built with `flutter build web` and just need to copy workers.
#
# Usage: ./tool/copy_workers.sh

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}📋 Copying Squadron worker files...${NC}"

# Check if build/web exists
if [ ! -d "build/web" ]; then
  echo -e "${RED}❌ Error: build/web directory not found${NC}"
  echo -e "${YELLOW}   Run 'flutter build web' first${NC}"
  exit 1
fi

# Create workers directory
mkdir -p build/web/workers

# Copy worker files
echo -e "${YELLOW}Copying files from lib/ to build/web/workers/${NC}"

# JavaScript workers (required)
find lib -name "*.web.g.dart.js" -exec cp {} build/web/workers/ \; 2>/dev/null && \
  echo -e "${GREEN}✓ JavaScript workers copied${NC}" || \
  echo -e "${RED}⚠️  No JavaScript workers found${NC}"

# WASM workers (optional)
find lib -name "*.web.g.dart.wasm" -exec cp {} build/web/workers/ \; 2>/dev/null && \
  echo -e "${GREEN}✓ WASM workers copied${NC}" || \
  echo -e "${YELLOW}  No WASM workers found (optional)${NC}"

# MJS modules (optional)
find lib -name "*.web.g.dart.mjs" -exec cp {} build/web/workers/ \; 2>/dev/null && \
  echo -e "${GREEN}✓ MJS modules copied${NC}" || \
  echo -e "${YELLOW}  No MJS modules found (optional)${NC}"

echo ""
echo -e "${BLUE}Worker files in build/web/workers/:${NC}"
ls -lh build/web/workers/ 2>/dev/null | tail -n +2 | awk '{print "  " $9 " (" $5 ")"}'

echo ""
echo -e "${GREEN}✅ Done!${NC}"
