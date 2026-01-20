# Contributing to VTT Hardware Benchmarks

Thanks for your interest in contributing to the Virtual Velocity Collective hardware benchmarking project!

## Getting Started

1. **Review the project structure:**
   - Read [README.md](README.md) for overview
   - Check [ROADMAP.md](ROADMAP.md) for planned features
   - Explore `docs/` for detailed guides

2. **Set up your environment:**
   - For Docker benchmarks: See [docker/README.md](docker/README.md)
   - For Windows testing: See [HP-ZBOOK-SETUP.md](HP-ZBOOK-SETUP.md)
   - For Keras OCR setup: See [MS-01-SETUP.md](MS-01-SETUP.md)

## Contributing Changes

### Bug Fixes
1. Identify the issue and create a bug report (or reference an existing issue)
2. Create a feature branch: `git checkout -b fix/issue-description`
3. Make changes with clear, descriptive commits
4. Test your changes thoroughly
5. Submit a pull request with a clear description

### New Features
1. Check [ROADMAP.md](ROADMAP.md) - is this planned?
2. If not planned, open a discussion or issue first
3. Create a feature branch: `git checkout -b feature/feature-name`
4. Implement the feature following the existing code patterns
5. Add documentation (update relevant README or create new guide)
6. Test thoroughly and submit a pull request

### Documentation
1. Update relevant files in `docs/`
2. Keep examples up-to-date
3. Follow the existing markdown style
4. Test any commands or instructions you document

## Benchmark Results

### Recording Results
1. Use the appropriate result template:
   - HP ZBook: `results/hp-zbook-template.md`
   - Framework: Create following the same pattern
2. Naming convention: `{device}-{unit}-{YYYYMMDD}.md`
3. Include:
   - System specifications
   - All benchmark scores
   - Environmental notes (temperature, conditions)
   - Any anomalies or issues

### Testing Protocol
- Run benchmarks in controlled conditions
- Document system state (background processes, temperature)
- Run multiple times for consistency checks
- Record raw outputs for verification

## Code Style

- **Bash scripts:** Clear comments, proper error handling
- **Python scripts:** Follow PEP 8, include docstrings
- **Documentation:** Clear, concise, with examples

## Commit Messages

Use clear, descriptive commit messages:
- `Add storage benchmark suite`
- `Fix Keras OCR connection timeout`
- `Document multi-run testing procedure`
- `Update HP ZBook 02 results`

Avoid vague messages like "update stuff" or "bug fix".

## Testing Your Changes

Before submitting:
1. Test locally on at least one system
2. Verify documentation is accurate
3. Check that scripts are executable: `chmod +x scripts/*.sh`
4. Validate markdown syntax
5. Run any benchmarks affected by your changes

## Questions?

- Check existing documentation in `docs/`
- Review the [ROADMAP.md](ROADMAP.md) for context
- Look at previous results for examples

## Areas We Need Help With

- [ ] Testing on additional hardware
- [ ] Improving benchmark automation
- [ ] Building the Supabase integration
- [ ] Creating the Streamlit dashboard
- [ ] Adding more benchmark types
- [ ] Performance analysis tools
- [ ] Documentation improvements

See [ROADMAP.md](ROADMAP.md) for full feature list.

---

Thank you for contributing to advancing hardware benchmarking for the Virtual Velocity Collective!
