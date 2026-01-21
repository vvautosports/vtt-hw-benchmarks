# GitHub Actions Workflows

Automated CI/CD pipelines for VTT Hardware Benchmarks.

## Available Workflows

### Build and Push Containers

**File:** `workflows/build-and-push-containers.yml`

Automatically builds and publishes all benchmark container images to GitHub Container Registry.

**Triggers:**
- **Push to `master`**: Builds and pushes all images with `latest` tag
- **Pull Request**: Builds images for testing (doesn't push)
- **Manual dispatch**: Build and push with custom version tag

**What it does:**
1. Builds all 4 benchmark images in parallel:
   - `vtt-benchmark-7zip`
   - `vtt-benchmark-stream`
   - `vtt-benchmark-storage`
   - `vtt-benchmark-llama`

2. Pushes to: `ghcr.io/vvautosports/vtt-hw-benchmarks/<image>:latest`

3. Posts Discord notification (if `DISCORD_WEBHOOK_PROGRESS` secret is configured)

**Registry location:**
```
ghcr.io/vvautosports/vtt-hw-benchmarks/vtt-benchmark-7zip:latest
ghcr.io/vvautosports/vtt-hw-benchmarks/vtt-benchmark-stream:latest
ghcr.io/vvautosports/vtt-hw-benchmarks/vtt-benchmark-storage:latest
ghcr.io/vvautosports/vtt-hw-benchmarks/vtt-benchmark-llama:latest
```

**Manual trigger:**
```bash
# Via GitHub UI: Actions tab → Build and Push Containers → Run workflow
# Or via gh CLI:
gh workflow run build-and-push-containers.yml --ref master
```

**Permissions:**
- Uses `GITHUB_TOKEN` (automatic, no setup needed)
- Token has `packages: write` permission for GHCR
- Images are public by default

### CI - Linting

**File:** `workflows/ci.yml`

Runs linting on shell scripts and markdown files.

**Triggers:**
- **Push to any branch**
- **Pull Request to `master`**

**What it does:**
1. **Shellcheck**: Validates all bash scripts
2. **Markdownlint**: Checks markdown formatting (non-blocking)

**Linted files:**
- All `.sh` scripts in repository
- All `.md` documentation files

## Secrets Configuration

The following secrets can be configured in repository settings for optional features:

### Discord Notifications

**Secret:** `DISCORD_WEBHOOK_PROGRESS`

**Purpose:** Post notifications when container images are published

**Setup:**
1. Go to Discord channel settings
2. Integrations → Webhooks → New Webhook
3. Copy webhook URL
4. In GitHub: Settings → Secrets and variables → Actions
5. Add secret: `DISCORD_WEBHOOK_PROGRESS` = webhook URL

**Optional:** If not configured, builds still work - just no Discord notifications.

## Integration with vtt-infrastructure

These workflows follow the same patterns as `vtt-infrastructure`:

**Similarities:**
- Discord webhook integration
- PR notifications (could be added)
- Daily commit summaries (could be added)
- Same secret naming convention

**Differences:**
- Container builds instead of infrastructure changes
- Pushes to GHCR instead of deploying to Proxmox
- Public packages instead of private infrastructure

## Local Development

GitHub Actions run automatically on push, but you can test locally:

```bash
# Build images locally (same as CI does)
cd docker
./build-all.sh

# Push manually (requires authentication)
./scripts/push-to-ghcr.sh --push latest

# Pull from GHCR (what HP ZBooks will do)
./scripts/pull-from-ghcr.sh
```

## Troubleshooting

### Images not pushing to GHCR

**Check:**
1. Workflow runs: https://github.com/vvautosports/vtt-hw-benchmarks/actions
2. Permissions: Repository → Settings → Actions → General → Workflow permissions
3. Should be set to: "Read and write permissions"

### Discord notifications not working

**Check:**
1. Secret is configured: Settings → Secrets and variables → Actions
2. Secret name is exactly: `DISCORD_WEBHOOK_PROGRESS`
3. Webhook URL is valid and points to correct channel

### Build failures

**Common causes:**
1. Dockerfile syntax errors
2. Base image not available
3. Network issues pulling dependencies

**Debug:**
1. Check workflow logs in Actions tab
2. Reproduce locally: `cd docker/<benchmark> && podman build .`
3. Test individual image: `podman run --rm vtt-benchmark-<name>`

## Future Enhancements

Potential workflows to add:

- **PR notifications**: Auto-post to Discord when PRs are opened
- **Benchmark validation**: Run quick tests before pushing images
- **Multi-arch builds**: Support ARM64 for Apple Silicon / Raspberry Pi
- **Version tagging**: Semantic versioning on tagged releases
- **Size optimization**: Layer caching and multi-stage builds

## Related Documentation

- [Container Push/Pull Scripts](../scripts/README.md)
- [Docker Benchmarks](../docker/README.md)
- [VTT Infrastructure Workflows](../../vtt-infrastructure/.github/workflows/)
