# VTT Hardware Benchmarks - Documentation

Documentation for the VTT hardware benchmarking project.

## Quick Links

### Getting Started
- [Main README](../README.md) - Project overview and quick start
- [ROADMAP](ROADMAP.md) - Future features and next steps
- [GitHub Issues](github-issues-to-create.md) - Ready to create

### Setup Guides
- [HP ZBook Setup](HP-ZBOOK-SETUP.md) - Windows software installation
- [MS-01 Setup](MS-01-SETUP.md) - Keras OCR deployment for Rocket League
- [Docker Benchmarks](../docker/README.md) - Containerized benchmark guide

### Testing
- [Tonight's Checklist](TONIGHT-CHECKLIST.md) - Quick testing workflow
- [HP ZBook Template](../results/hp-zbook-template.md) - Result documentation template

### Planning Documents
- [Comprehensive Plan](comprehensive-benchmark-plan.md) - Original detailed plan
- [Framework Workflow](CONTINUATION-dogfooding-workflow-framework.md) - Framework testing notes
- [Framework Setup](CONTINUATION-start-framework-setup.md) - Framework setup notes

## Documentation Structure

```
vtt-hw-benchmarks/
├── README.md                 # Main project README
├── ROADMAP.md                # Feature roadmap and next steps
├── HP-ZBOOK-SETUP.md         # Windows setup guide
├── MS-01-SETUP.md            # Server setup guide
├── docker/
│   └── README.md             # Container benchmark guide
├── docs/                     # Additional documentation
│   ├── README.md             # This file
│   ├── TONIGHT-CHECKLIST.md  # Quick testing checklist
│   └── *.md                  # Planning documents
└── results/
    ├── hp-zbook-template.md  # Result template
    └── *.md                  # Actual results
```

## Contributing Documentation

When adding new features:
1. Update relevant setup guides
2. Add entry to ROADMAP.md
3. Create result templates if needed
4. Document any new scripts or tools

## Result Documentation

All benchmark results should be committed to the `results/` directory as markdown files.

**Naming convention:**
- `{device-type}-{unit-number}-{YYYYMMDD}.md`
- Examples: `hp-zbook-01-20260119.md`, `framework-laptop-20260119.md`

**Template:**
Use `results/hp-zbook-template.md` as a starting point.
