#!/bin/bash
# format.sh
#
# Formats Swift code using SwiftFormat and SwiftLint
# Usage: ./scripts/format.sh [lint]
#
# Arguments:
#   lint  - Only check formatting, don't make changes
#
# Examples:
#   ./scripts/format.sh      # Format all code
#   ./scripts/format.sh lint # Check formatting only

set -euo pipefail

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Parse arguments
LINT_ONLY=false
if [[ "${1:-}" == "lint" ]]; then
    LINT_ONLY=true
fi

echo -e "${GREEN}🔨 Swift Code Formatting${NC}"
echo ""

# Check if SwiftFormat is installed
if ! command -v swiftformat &> /dev/null; then
    echo -e "${YELLOW}⚠️  SwiftFormat not found. Installing...${NC}"
    brew install swiftformat
fi

# Check if SwiftLint is installed
if ! command -v swiftlint &> /dev/null; then
    echo -e "${YELLOW}⚠️  SwiftLint not found. Installing...${NC}"
    HOMEBREW_NO_AUTO_UPDATE=1 brew install swiftlint
fi

cd "$PROJECT_DIR/LexiconFlow"

if [ "$LINT_ONLY" = true ]; then
    echo -e "${GREEN}Checking formatting...${NC}"

    # Run SwiftFormat in lint mode
    if swiftformat --lint .; then
        echo -e "${GREEN}✅ SwiftFormat check passed${NC}"
    else
        echo -e "${RED}❌ SwiftFormat found issues${NC}"
        echo "Run 'swiftformat .' to auto-fix"
        exit 1
    fi

    # Run SwiftLint
    if swiftlint lint --strict; then
        echo -e "${GREEN}✅ SwiftLint check passed${NC}"
    else
        echo -e "${RED}❌ SwiftLint found issues${NC}"
        echo "Run 'swiftlint --fix' to auto-fix"
        exit 1
    fi

    echo ""
    echo -e "${GREEN}✅ All formatting checks passed!${NC}"
else
    echo -e "${GREEN}Formatting code...${NC}"

    # Run SwiftFormat
    swiftformat .

    # Run SwiftLint auto-fix
    swiftlint --fix

    echo -e "${GREEN}✅ Code formatted successfully${NC}"
fi
