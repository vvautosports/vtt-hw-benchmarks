#!/bin/bash
# Post update to Discord forum
# Usage: ./scripts/post-to-discord.sh [--auto|--dry-run]
#
# This script helps post benchmark updates to Discord.
# Since we don't have Discord API webhooks configured yet,
# it formats the content and provides manual posting instructions.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
POST_FILE="$REPO_ROOT/docs/discord-forum-post.md"

MODE="${1:---dry-run}"

echo "=== Discord Forum Post Helper ==="
echo ""

if [ ! -f "$POST_FILE" ]; then
    echo "ERROR: Discord post file not found at $POST_FILE"
    exit 1
fi

echo "📝 Post content loaded from: $POST_FILE"
echo ""

case "$MODE" in
    --dry-run)
        echo "🔍 DRY RUN MODE (showing content only)"
        echo ""
        echo "────────────────────────────────────────────────"
        cat "$POST_FILE"
        echo "────────────────────────────────────────────────"
        echo ""
        echo "ℹ️  To post to Discord:"
        echo "   1. Copy the content above"
        echo "   2. Go to Discord #hardware-benchmarks channel"
        echo "   3. Create a new forum post or reply to existing thread"
        echo "   4. Paste the content"
        echo ""
        echo "   Or run: ./scripts/post-to-discord.sh --manual"
        ;;

    --manual)
        echo "📋 Content copied to clipboard (if xclip/pbcopy available)"
        echo ""

        if command -v xclip &> /dev/null; then
            cat "$POST_FILE" | xclip -selection clipboard
            echo "✅ Copied to clipboard with xclip"
        elif command -v pbcopy &> /dev/null; then
            cat "$POST_FILE" | pbcopy
            echo "✅ Copied to clipboard with pbcopy"
        else
            echo "⚠️  No clipboard tool found (xclip/pbcopy)"
            echo "   Content saved to: /tmp/discord-post.md"
            cp "$POST_FILE" /tmp/discord-post.md
        fi

        echo ""
        echo "📍 Next steps:"
        echo "   1. Open Discord"
        echo "   2. Navigate to #hardware-benchmarks"
        echo "   3. Paste from clipboard (Ctrl+V / Cmd+V)"
        echo "   4. Send message"
        ;;

    --auto)
        echo "🚀 AUTO MODE (requires Discord webhook)"
        echo ""

        if [ -z "$DISCORD_WEBHOOK_URL" ]; then
            echo "❌ ERROR: DISCORD_WEBHOOK_URL environment variable not set"
            echo ""
            echo "To enable auto-posting:"
            echo "   1. Create a Discord webhook in channel settings"
            echo "   2. Export DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/..."
            echo "   3. Run: ./scripts/post-to-discord.sh --auto"
            exit 1
        fi

        # Convert markdown to Discord-friendly format
        CONTENT=$(cat "$POST_FILE")

        # Post to Discord webhook
        curl -X POST "$DISCORD_WEBHOOK_URL" \
            -H "Content-Type: application/json" \
            -d "{\"content\": $(echo "$CONTENT" | jq -Rs .)}"

        echo "✅ Posted to Discord via webhook"
        ;;

    *)
        echo "❌ Unknown mode: $MODE"
        echo ""
        echo "Usage: $0 [--dry-run|--manual|--auto]"
        echo "  --dry-run  Show content only (default)"
        echo "  --manual   Copy to clipboard and show instructions"
        echo "  --auto     Post via webhook (requires DISCORD_WEBHOOK_URL)"
        exit 1
        ;;
esac

echo ""
echo "✨ Done!"
