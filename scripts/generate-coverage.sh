#!/bin/bash
# generate-coverage.sh
#
# Generates code coverage reports from Xcode test results
# Usage: ./scripts/generate-coverage.sh [TestResults.xcresult]
#
# Requirements:
#   - xcodebuild test with -enableCodeCoverage YES
#   - xccov-to-lcov converter (install via: brew install xccov-to-lcov)

set -euo pipefail

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default result bundle path
RESULT_BUNDLE="${1:-TestResults.xcresult}"

echo -e "${GREEN}📊 Generating Coverage Report${NC}"
echo ""

# Check if result bundle exists
if [ ! -d "$RESULT_BUNDLE" ]; then
    echo -e "${RED}❌ Error: Result bundle not found: $RESULT_BUNDLE${NC}"
    echo "Please run tests with coverage first:"
    echo "  xcodebuild test -enableCodeCoverage YES -resultBundlePath TestResults.xcresult"
    exit 1
fi

# Check if xccov-to-lcov is installed
if ! command -v xccov-to-lcov &> /dev/null; then
    echo -e "${YELLOW}⚠️  xccov-to-lcov not found. Installing...${NC}"
    brew install xccov-to-lcov
fi

# Generate coverage.info file
echo -e "${GREEN}Converting xcresult to lcov format...${NC}"
xccov-to-lcov < "$RESULT_BUNDLE" > coverage.info

if [ -f coverage.info ]; then
    # Get coverage summary
    LINES=$(grep -E "^LF:" coverage.info | awk '{sum+=$2} END {print sum}')
    COVERED=$(grep -E "^LF:" coverage.info | awk '{sum+=$2} END {print sum}')  # Placeholder

    # Calculate percentage using lcov
    if command -v lcov &> /dev/null; then
        SUMMARY=$(lcov --summary coverage.info 2>&1 | grep "lines" || echo "")
        echo "$SUMMARY"
    fi

    echo ""
    echo -e "${GREEN}✅ Coverage report generated: coverage.info${NC}"
    echo ""
    echo "To view detailed coverage:"
    echo "  lcov --list coverage.info"
    echo ""
    echo "To generate HTML report:"
    echo "  genhtml coverage.info -o coverage_html"
    echo ""
    echo "To upload to Codecov:"
    echo "  codecov -f coverage.info"
else
    echo -e "${RED}❌ Failed to generate coverage.info${NC}"
    exit 1
fi
