#!/bin/bash
# Manage GitHub issues for VTT Hardware Benchmarks
# Usage: ./scripts/manage-gh-issues.sh [create|close|list] [issue-number]
#
# This script helps manage GitHub issues using the gh CLI tool.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ISSUES_FILE="$REPO_ROOT/docs/github-issues-to-create.md"

COMMAND="${1:-list}"
ISSUE_NUM="$2"

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    echo "❌ ERROR: GitHub CLI (gh) is not installed"
    echo ""
    echo "Install with:"
    echo "  Fedora: sudo dnf install gh"
    echo "  macOS:  brew install gh"
    echo "  Other:  https://cli.github.com/"
    echo ""
    echo "After install, authenticate with: gh auth login"
    exit 1
fi

# Check if authenticated
if ! gh auth status &> /dev/null; then
    echo "⚠️  Not authenticated with GitHub"
    echo "Run: gh auth login"
    exit 1
fi

echo "=== VTT Hardware Benchmarks - GitHub Issue Manager ==="
echo ""

case "$COMMAND" in
    list)
        echo "📋 Current Issues:"
        echo ""
        gh issue list --repo vvautosports/vtt-hw-benchmarks
        echo ""
        echo "💡 To create issues from docs/github-issues-to-create.md:"
        echo "   ./scripts/manage-gh-issues.sh create"
        ;;

    create)
        echo "📝 Creating issues from $ISSUES_FILE"
        echo ""

        # Issue #1: Storage Benchmark (already complete)
        echo "Issue #1: Storage Benchmark - ✅ Already completed, skipping"

        # Issue #2: Multi-Run Automation
        echo ""
        echo "Creating Issue #2: Multi-Run Automation..."
        gh issue create \
            --repo vvautosports/vtt-hw-benchmarks \
            --title "[Automation] Implement Multi-Run Benchmarks with Statistical Analysis" \
            --label "enhancement,automation,statistics,medium-difficulty" \
            --body "$(cat <<'EOF'
## Description
Enhance benchmark reliability by running each test multiple times (3-5 runs) and calculating statistical metrics (mean, median, standard deviation, min, max). This eliminates outliers and provides more accurate performance data.

## Current Status
- ✅ Single-run benchmarks working
- ✅ Multi-run script created (Linux)
- 🚧 Testing in progress
- ❌ Windows PowerShell version not yet implemented

## Acceptance Criteria
- [ ] Test and validate `docker/run-multiple.sh` (Linux)
- [ ] Create `docker/run-multiple.ps1` (Windows)
- [ ] Verify statistical calculations (mean, median, stddev, CV%)
- [ ] Test on Framework desktop
- [ ] Test on HP ZBook

## Priority
High - Critical for accurate performance comparison
EOF
)"
        echo "✅ Issue #2 created"

        # Issue #3: PresentMon FPS
        echo ""
        echo "Creating Issue #3: PresentMon FPS Automation..."
        gh issue create \
            --repo vvautosports/vtt-hw-benchmarks \
            --title "[Windows] Automated FPS Capture for Rocket League Benchmark" \
            --label "enhancement,windows,automation,benchmark,medium-difficulty" \
            --body "$(cat <<'EOF'
## Description
Integrate PresentMon for automated FPS (frames per second) capture during Rocket League benchmarks, eliminating manual observation and providing accurate performance metrics.

## Current Status
- ✅ Rocket League benchmark runs via LTT MarkBench
- ✅ Keras OCR service integration working
- ❌ FPS capture is manual (visual observation)
- ❌ No automated FPS metrics

## Acceptance Criteria
- [ ] Create `scripts/rocket-league-presentmon.ps1`
- [ ] Download and install PresentMon automatically
- [ ] Capture FPS data during benchmark run
- [ ] Calculate metrics: avg, min, max, 1% low, 0.1% low
- [ ] Output JSON format
- [ ] Test on HP ZBook

## Priority
High - Critical for accurate gaming performance measurement
EOF
)"
        echo "✅ Issue #3 created"

        # Issue #4: AI Model Testing (already complete)
        echo ""
        echo "Issue #4: AI Model Testing - ✅ Already completed, skipping"

        echo ""
        echo "✨ GitHub issues created successfully!"
        echo ""
        echo "View issues at: https://github.com/vvautosports/vtt-hw-benchmarks/issues"
        ;;

    close)
        if [ -z "$ISSUE_NUM" ]; then
            echo "❌ ERROR: Issue number required"
            echo "Usage: $0 close <issue-number>"
            exit 1
        fi

        echo "🔒 Closing issue #$ISSUE_NUM..."
        gh issue close "$ISSUE_NUM" --repo vvautosports/vtt-hw-benchmarks --comment "✅ Completed and merged to main"
        echo "✅ Issue #$ISSUE_NUM closed"
        ;;

    comment)
        if [ -z "$ISSUE_NUM" ]; then
            echo "❌ ERROR: Issue number required"
            echo "Usage: $0 comment <issue-number> <comment-text>"
            exit 1
        fi

        COMMENT="$3"
        if [ -z "$COMMENT" ]; then
            echo "❌ ERROR: Comment text required"
            echo "Usage: $0 comment <issue-number> <comment-text>"
            exit 1
        fi

        echo "💬 Adding comment to issue #$ISSUE_NUM..."
        gh issue comment "$ISSUE_NUM" --repo vvautosports/vtt-hw-benchmarks --body "$COMMENT"
        echo "✅ Comment added"
        ;;

    *)
        echo "❌ Unknown command: $COMMAND"
        echo ""
        echo "Usage: $0 [list|create|close|comment] [args]"
        echo ""
        echo "Commands:"
        echo "  list                    List all open issues"
        echo "  create                  Create issues from docs/github-issues-to-create.md"
        echo "  close <num>            Close issue #num"
        echo "  comment <num> <text>    Add comment to issue #num"
        exit 1
        ;;
esac

echo ""
