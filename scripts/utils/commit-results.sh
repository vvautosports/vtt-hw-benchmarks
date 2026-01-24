#!/bin/bash
# Commit test results to repository with standardized format
# Usage: ./scripts/utils/commit-results.sh <result-file> [<machine-name>] [<test-type>]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Check arguments
if [ $# -lt 1 ]; then
    echo "Usage: $0 <result-file> [<machine-name>] [<test-type>]"
    echo ""
    echo "Examples:"
    echo "  $0 results/ai-models-fedora-20260123-143022.json framework-desktop ai-models"
    echo "  $0 results/hp-zbook-01-full-20260123.json hp-zbook-01 full-suite"
    exit 1
fi

RESULT_FILE="$1"
MACHINE_NAME="${2:-unknown}"
TEST_TYPE="${3:-benchmark}"

# Validate result file exists
if [ ! -f "$RESULT_FILE" ]; then
    echo "ERROR: Result file not found: $RESULT_FILE"
    exit 1
fi

# Get relative path
REL_PATH=$(realpath --relative-to="$REPO_ROOT" "$RESULT_FILE")

# Parse date from filename or use current date
if [[ $(basename "$RESULT_FILE") =~ ([0-9]{8}) ]]; then
    DATE="${BASH_REMATCH[1]}"
    FORMATTED_DATE=$(date -d "$DATE" +%Y-%m-%d 2>/dev/null || echo "$(date +%Y-%m-%d)")
else
    FORMATTED_DATE=$(date +%Y-%m-%d)
fi

# Generate commit message
COMMIT_MSG="results: Add $MACHINE_NAME $TEST_TYPE results

- Machine: $MACHINE_NAME
- Test: $TEST_TYPE
- Date: $FORMATTED_DATE
- File: $REL_PATH
"

# Show what we're about to commit
echo "═══════════════════════════════════════════════════════════════"
echo "Preparing to commit test results"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "File: $REL_PATH"
echo "Machine: $MACHINE_NAME"
echo "Test: $TEST_TYPE"
echo "Date: $FORMATTED_DATE"
echo ""
echo "Commit message:"
echo "$COMMIT_MSG"
echo ""

# Ask for confirmation
read -p "Commit this result? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

# Stage the file
cd "$REPO_ROOT"
git add "$RESULT_FILE"

# Also stage any associated log files
LOG_FILE="${RESULT_FILE%.json}.log"
if [ -f "$LOG_FILE" ]; then
    git add "$LOG_FILE"
    echo "Also staged: $(realpath --relative-to="$REPO_ROOT" "$LOG_FILE")"
fi

# Commit
git commit -m "$COMMIT_MSG"

echo ""
echo "✅ Results committed successfully"
echo ""
echo "To push to remote:"
echo "  git push origin $(git branch --show-current)"
