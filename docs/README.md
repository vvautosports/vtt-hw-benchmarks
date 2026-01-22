# VTT Hardware Benchmarks Documentation

Complete documentation index for the VTT Hardware Benchmarks project.

---

## Setup Guides

### System Configuration

**[AMD-STRIX-HALO-SETUP.md](AMD-STRIX-HALO-SETUP.md)**
- AMD Ryzen AI Max+ 395 iGPU configuration
- BIOS settings (4GB UMA allocation)
- Vulkan vs ROCm backend comparison
- Critical llama.cpp flags for Strix Halo
- Performance optimization tips

**[HP-ZBOOK-SETUP.md](HP-ZBOOK-SETUP.md)**
- Windows 11 setup for HP ZBook laptops
- Benchmark software installation
- Rocket League configuration
- Testing prerequisites

**[MS-01-SETUP.md](MS-01-SETUP.md)** *(Legacy)*
- Direct Docker deployment of Keras OCR
- Now superseded by LXC deployment
- Kept for reference

**[MS-01-LXC-DEPLOYMENT.md](MS-01-LXC-DEPLOYMENT.md)** *(Recommended)*
- Proxmox LXC container deployment
- Keras OCR service for Rocket League benchmarks
- Headscale mesh VPN integration
- Container management and troubleshooting

---

## Testing Guides

**[GLM-4.7-TESTING.md](GLM-4.7-TESTING.md)**
- Extended context testing for GLM-4.7 models
- Q8 vs BF16 vs REAP-218B comparison
- Memory requirements and VRAM estimates
- Use case recommendations by model type
- Real-world context size statistics
- When to use each model variant

---

## Reference Documentation

**[../docker/README.md](../docker/README.md)**
- Containerized benchmark details
- Docker/Podman usage
- Build and run instructions
- Container configuration

**[../scripts/README.md](../scripts/README.md)**
- Helper script documentation
- GHCR push/pull workflows
- Automation utilities

**[../.github/README.md](../.github/README.md)**
- CI/CD workflow documentation
- Automated container builds
- GitHub Actions integration

---

## Archived Documentation

**[archive/](archive/)**
- Historical planning documents
- Old roadmaps and checklists
- Session continuations
- GitHub issue templates (already created)
- Discord forum posts (already published)

Contents:
- `comprehensive-benchmark-plan.md` - Original planning doc
- `CONTINUATION-*.md` - Old session notes
- `discord-forum-post.md` - Discord announcement template
- `github-issues-to-create.md` - Issue templates (now created)
- `TONIGHT-CHECKLIST.md` - Original test checklist
- `ROADMAP.md` - Original roadmap (now superseded by README.md)

---

## Quick Reference

### Most Important Documents

**Getting Started:**
1. Main [README.md](../README.md) - Project overview and quick start
2. [AMD-STRIX-HALO-SETUP.md](AMD-STRIX-HALO-SETUP.md) - iGPU configuration
3. [docker/README.md](../docker/README.md) - Running benchmarks

**For HP ZBook Testing:**
1. [HP-ZBOOK-SETUP.md](HP-ZBOOK-SETUP.md) - Windows setup
2. [MS-01-LXC-DEPLOYMENT.md](MS-01-LXC-DEPLOYMENT.md) - Keras OCR deployment

**For AI Model Testing:**
1. [GLM-4.7-TESTING.md](GLM-4.7-TESTING.md) - Extended context testing
2. [AMD-STRIX-HALO-SETUP.md](AMD-STRIX-HALO-SETUP.md) - iGPU optimization

---

## Documentation Standards

When updating documentation:
- Use clear, descriptive section headers
- Include code examples where applicable
- Specify system requirements
- Add troubleshooting sections
- Update "Last Updated" date at bottom
- Archive outdated docs instead of deleting

---

**Last Updated:** 2026-01-21
