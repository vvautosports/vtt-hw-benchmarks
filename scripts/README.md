# VTT Hardware Benchmarks - Automation Scripts

Workflow automation scripts for managing GitHub issues and Discord updates.

## Available Scripts

### Container Registry Management

**Files:** `push-to-ghcr.sh`, `pull-from-ghcr.sh`

Push and pull benchmark container images to/from GitHub Container Registry.

**Push images to GHCR:**
```bash
# Dry run (preview only)
./scripts/push-to-ghcr.sh --dry-run

# Push with version tag
./scripts/push-to-ghcr.sh --push v1.0.0

# Push as latest
./scripts/push-to-ghcr.sh --push latest
```

**Pull images from GHCR:**
```bash
# Pull latest version
./scripts/pull-from-ghcr.sh

# Pull specific version
./scripts/pull-from-ghcr.sh v1.0.0
```

**Authentication (for pushing):**
```bash
# Create GitHub Personal Access Token with 'write:packages' scope
# https://github.com/settings/tokens

# Login to GHCR
echo $GITHUB_TOKEN | podman login ghcr.io -u USERNAME --password-stdin
```

**Use cases:**
- **HP ZBooks**: Pull pre-built images instead of building locally
- **CI/CD**: Use versioned images for reproducible testing
- **Quick deployment**: No build time required on test systems

**Automated CI/CD:**

The repository includes GitHub Actions workflows that automatically:
- Build all 4 container images on push to `master`
- Push images to GHCR with `latest` tag
- Post notification to Discord (if webhook configured)
- Run linting on all pull requests

See `.github/workflows/build-and-push-containers.yml` for the automated pipeline.

**Manual override:**
```bash
# If you need to push manually (e.g., from local dev)
./scripts/push-to-ghcr.sh --push latest
```

### Discord Posting

**File:** `post-to-discord.sh`

Post benchmark updates to Discord #hardware-benchmarks channel.

```bash
# Show content only (default)
./scripts/post-to-discord.sh

# Copy to clipboard and show manual instructions
./scripts/post-to-discord.sh --manual

# Auto-post via webhook (requires DISCORD_WEBHOOK_URL)
export DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/..."
./scripts/post-to-discord.sh --auto
```

**Configuration:**
- Content source: `docs/discord-forum-post.md`
- Requires: `xclip` or `pbcopy` for clipboard (manual mode)
- Requires: `DISCORD_WEBHOOK_URL` env var (auto mode)

### GitHub Issue Management

**File:** `manage-gh-issues.sh`

Create and manage GitHub issues using the `gh` CLI tool.

```bash
# List all open issues
./scripts/manage-gh-issues.sh list

# Create issues from docs/github-issues-to-create.md
./scripts/manage-gh-issues.sh create

# Close an issue
./scripts/manage-gh-issues.sh close 4

# Add comment to issue
./scripts/manage-gh-issues.sh comment 2 "Testing complete on Framework desktop"
```

**Requirements:**
- GitHub CLI (`gh`) installed
- Authenticated with: `gh auth login`
- Repository: vvautosports/vtt-hw-benchmarks

**Install gh CLI:**
```bash
# Fedora
sudo dnf install gh

# macOS
brew install gh

# Other platforms
# See: https://cli.github.com/
```

## Workflow Integration

These scripts are designed to be used as Claude commands at the workspace level across VVT repos.

### Using with Claude

When working on benchmark updates:

1. **Update documentation:**
   - Edit `docs/discord-forum-post.md` with latest results
   - Edit `docs/github-issues-to-create.md` to mark issues complete

2. **Post to Discord:**
   ```bash
   ./scripts/post-to-discord.sh --manual
   ```

3. **Manage GitHub issues:**
   ```bash
   # Create issues
   ./scripts/manage-gh-issues.sh create

   # Close completed issues
   ./scripts/manage-gh-issues.sh close 4
   ```

### As Claude Commands

To use these across repos, create workspace-level aliases:

```bash
# In ~/.bashrc or ~/.zshrc
alias vtt-discord='~/repos/virtual-velocity-collective/vvautosports/vtt-hw-benchmarks/scripts/post-to-discord.sh'
alias vtt-issues='~/repos/virtual-velocity-collective/vvautosports/vtt-hw-benchmarks/scripts/manage-gh-issues.sh'
```

Or use from any VVT repo:

```bash
# Relative path from workspace root
../vtt-hw-benchmarks/scripts/post-to-discord.sh
../vtt-hw-benchmarks/scripts/manage-gh-issues.sh
```

## Claude Code Integration

These scripts follow the workflow patterns from `vtt-infrastructure/OPERATIONS.md`:

- **Quick reference** - Simple, focused scripts for common tasks
- **Safety first** - Dry-run modes, clear confirmation prompts
- **Tool-agnostic** - Work with or without API access (fallback to manual)
- **Documentation-driven** - Content in markdown, scripts just format/post

## Discord Webhook Setup (Optional)

For automated posting without manual copy/paste:

1. Open Discord channel settings
2. Navigate to Integrations → Webhooks
3. Create new webhook
4. Copy webhook URL
5. Export environment variable:
   ```bash
   export DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/YOUR_WEBHOOK_ID/YOUR_WEBHOOK_TOKEN"
   ```

6. Use auto mode:
   ```bash
   ./scripts/post-to-discord.sh --auto
   ```

## Examples

### Complete Workflow After Benchmark Implementation

```bash
# 1. Run benchmarks
cd docker
./run-all.sh

# 2. Update documentation
vim docs/discord-forum-post.md
# Add latest results

# 3. Commit changes
git add docs/discord-forum-post.md
git commit -m "Update benchmark results"

# 4. Post to Discord
./scripts/post-to-discord.sh --manual

# 5. Update GitHub issues
./scripts/manage-gh-issues.sh close 4
```

### Quick Discord Update

```bash
# Edit post content
vim docs/discord-forum-post.md

# Preview
./scripts/post-to-discord.sh

# Post (copies to clipboard)
./scripts/post-to-discord.sh --manual
```

### Bulk GitHub Issue Creation

```bash
# Edit issue content
vim docs/github-issues-to-create.md

# Create all issues at once
./scripts/manage-gh-issues.sh create
```

## Notes

- Scripts are idempotent where possible
- All scripts check for required tools before running
- Markdown content is the source of truth
- Scripts are formatting/delivery mechanisms only
- Works across Linux, macOS, WSL

## Related

- [Discord Post Template](../docs/discord-forum-post.md)
- [GitHub Issues Template](../docs/github-issues-to-create.md)
- [VTT Infrastructure Operations](../../vtt-infrastructure/OPERATIONS.md)
