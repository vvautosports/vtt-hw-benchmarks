# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased] - 2026-01-23

### Added
- **Configuration System**
  - `models-inventory.yaml` for centralized model configuration
  - Default 5-model configuration (DeepSeek-R1, GLM-4.7, MiniMax, Qwen3-235B, GPT-OSS-20B)
  - `MODEL_CONFIG_MODE` environment variable (default/all modes)
  - Config parser utility (`scripts/utils/config-parser.sh`)
  - Example configurations in `config/examples/`

- **Script Enhancements**
  - `run-ai-models.sh` now supports config-based model selection
  - `--quick-test` flag for fast validation (one model, 2-3 min)
  - Backward compatibility maintained for auto-discovery mode

- **Documentation**
  - `docs/guides/QUICK-START.md` - Get running in 10 minutes
  - `docs/guides/WINDOWS-SETUP.md` - Windows/WSL2 setup guide
  - `docs/guides/CONFIGURATION.md` - Configuration reference
  - Updated main README.md with configuration info

- **Windows Support**
  - `scripts/utils/setup-windows.ps1` - Automated WSL2/Docker setup script
  - PowerShell script for less technical users

- **Validation Utilities**
  - `scripts/utils/validate-environment.sh` - Pre-test environment checks
  - `scripts/utils/validate-results.sh` - Post-test result validation

### Changed
- **Repository Organization**
  - Reorganized scripts into `testing/`, `deployment/`, `ci-cd/`, `utils/` subdirectories
  - Reorganized docs into `guides/`, `reference/`, `archive/` subdirectories
  - Moved config files to `config/examples/`
  - Renamed `docs/HP-ZBOOK-SETUP.md` to `docs/guides/HP-ZBOOK-ROCKET-LEAGUE.md`

- **Updated Documentation**
  - Updated `README.md` with new quick start and configuration sections
  - Updated `docs/README.md` with navigation decision tree
  - Updated directory structure diagrams

### Archived
- `SESSION-SUMMARY.md` → `docs/archive/`
- `roo-glm-config.md` → `docs/archive/`
- `docs/SESSION-2026-01-22-UPDATES.md` → `docs/archive/`
- `docs/TESTING-CONTINUATION-PROMPT.md` → `docs/archive/`

## [1.0.0] - 2026-01-21

Initial release with:
- Containerized benchmarks (7-Zip, STREAM, Storage, AI inference)
- AMD Strix Halo iGPU support
- Multi-model AI testing
- GitHub Container Registry integration
- Comprehensive documentation
