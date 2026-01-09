#!/bin/bash
# scan-dead-code.sh
#
# Scans for unused/dead code using Periphery
# Usage: ./scripts/scan-dead-code.sh
#
# Requirements:
#   - Periphery installed: brew install peripheryapp/periphery/periphery

set -euo pipefail

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo -e "${GREEN}🔍 Scanning for Dead Code${NC}"
echo ""

# Check if Periphery is installed
if ! command -v periphery &> /dev/null; then
    echo -e "${RED}❌ Periphery not found${NC}"
    echo ""
    echo "Install Periphery:"
    echo "  brew install peripheryapp/periphery/periphery"
    exit 1
fi

echo "Scanning project for unused code..."
echo ""

cd "$PROJECT_DIR"

# Run Periphery scan
periphery scan --setup . 2>&1 || {
    echo -e "${YELLOW}⚠️  Setup failed, trying scan anyway...${NC}"
}

echo ""
echo -e "${GREEN}Running Periphery scan...${NC}"
echo ""

if periphery scan; then
    echo ""
    echo -e "${GREEN}✅ No dead code found!${NC}"
else
    EXIT_CODE=$?
    echo ""
    if [ $EXIT_CODE -eq 1 ]; then
        echo -e "${YELLOW}⚠️  Dead code detected${NC}"
        echo ""
        echo "Review the output above and consider removing unused code."
        echo "To suppress false positives, add comments to retained declarations:"
        echo "  // periphery:ignore"
    else
        echo -e "${RED}❌ Periphery scan failed${NC}"
    fi
    exit $EXIT_CODE
fi
