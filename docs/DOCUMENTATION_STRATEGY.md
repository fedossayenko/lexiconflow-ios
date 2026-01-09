# Documentation Strategy

## Overview

This document defines the documentation strategy for LexiconFlow, clarifying the purpose and organization of documentation files across the repository.

## Folder Structure

```
lexiconflow-ios/
├── docs/                           # Project documentation (root)
│   ├── ARCHITECTURE.md              # Comprehensive technical architecture
│   ├── ROADMAP.md                  # Development roadmap
│   ├── TESTING.md                  # Testing strategy and guidelines
│   ├── WORKFLOW.md                 # Git workflow and commit conventions
│   ├── ALGORITHM_SPECS.md          # FSRS v5 algorithm details
│   ├── PRODUCT_VISION.md           # Product vision and goals
│   ├── STRATEGIC_ENGINEERING_REPORT.md  # Engineering strategy
│   ├── ENVIRONMENT_SETUP.md        # Development environment setup
│   ├── API_AVAILABILITY_REPORT.md  # API availability analysis
│   ├── screenshots-plan.md         # Screenshot planning
│   └── test-data-setup-guide.md    # Test data setup guide
│
├── LexiconFlow/
│   └── docs/                       # Xcode project documentation
│       ├── ARCHITECTURE.md          # Focused technical architecture
│       ├── C1_C2_GAP.md            # C1/C2 vocabulary gap analysis
│       └── SMARTOOL_VALIDATION.md   # Smartool data validation
│
├── CLAUDE.md                        # Claude Code project instructions
└── README.md                        # Project overview for developers
```

## Documentation Locations

### `/docs/` (Project Root - User-Facing)

**Purpose**: Comprehensive documentation for developers, contributors, and stakeholders.

**Audience**:
- New contributors joining the project
- Developers understanding the codebase
- Project stakeholders reviewing technical decisions
- QA teams testing the application

**Content Types**:
- **ARCHITECTURE.md**: Full technical architecture (1000+ lines)
  - Technology stack rationale
  - System architecture diagrams
  - Data flow diagrams
  - Integration patterns
  - Deployment strategy

- **ROADMAP.md**: Development roadmap and milestones
- **TESTING.md**: Testing strategy, coverage targets, test patterns
- **WORKFLOW.md**: Git workflow, commit conventions, PR process
- **ALGORITHM_SPECS.md**: FSRS v5 algorithm implementation details
- **PRODUCT_VISION.md**: Product vision, goals, success metrics
- **STRATEGIC_ENGINEERING_REPORT.md**: Engineering strategy and trade-offs
- **ENVIRONMENT_SETUP.md**: Development environment setup guide
- **API_AVAILABILITY_REPORT.md**: API availability and fallback analysis

**Maintenance**:
- Updated with each major release
- Reviewed during sprint planning
- Version-controlled with project history

### `/LexiconFlow/docs/` (Xcode Project - Technical)

**Purpose**: Focused technical documentation within the Xcode project bundle.

**Audience**:
- iOS developers working in Xcode
- Code reviewers examining implementation
- Architects reviewing specific components

**Content Types**:
- **ARCHITECTURE.md**: Focused technical architecture (400-500 lines)
  - MVVM with SwiftData patterns
  - Actor-based concurrency patterns
  - SwiftData concurrency architecture
  - Glass morphism performance considerations
  - Key components and their interactions
  - Testing strategy

- **C1_C2_GAP.md**: C1/C2 vocabulary gap analysis
- **SMARTOOL_VALIDATION.md**: Smartool data validation methodology

**Maintenance**:
- Updated when architecture changes
- Kept in sync with `/docs/ARCHITECTURE.md`
- Shorter, more focused for quick reference

### `CLAUDE.md` (Project Root - AI Assistant)

**Purpose**: Instructions for Claude Code (AI coding assistant).

**Audience**: Claude Code AI assistant

**Content**:
- Project overview and build commands
- Architecture patterns and conventions
- Critical implementation patterns (15+ patterns)
- Code quality standards
- Testing guidelines
- Common pitfalls

**Maintenance**:
- Updated with new implementation patterns
- Reflects current coding standards
- Serves as "living specification"

### `README.md` (Project Root - Overview)

**Purpose**: Project overview and quick start guide.

**Audience**: Anyone visiting the repository

**Content**:
- Project description
- Quick start guide
- Key features
- Screenshots
- Contributing guidelines
- License information

## Documentation Duplication: ARCHITECTURE.md

### Current State

There are two ARCHITECTURE.md files with different content:

| File | Lines | Focus | Last Updated |
|------|-------|-------|--------------|
| `/docs/ARCHITECTURE.md` | 1044 | Comprehensive technical architecture | Jan 9, 2026 |
| `/LexiconFlow/docs/ARCHITECTURE.md` | 439 | Focused implementation patterns | Jan 9, 2026 |

### Why Both Exist

1. **`/docs/ARCHITECTURE.md`** (Comprehensive)
   - Full technology stack rationale
   - System architecture and data flow
   - Integration patterns
   - Deployment considerations
   - Strategic engineering decisions
   - **Used by**: Architects, technical leads, stakeholders

2. **`/LexiconFlow/docs/ARCHITECTURE.md`** (Focused)
   - MVVM with SwiftData patterns
   - Actor-based concurrency patterns
   - SwiftData concurrency architecture
   - Glass morphism performance
   - Key components
   - **Used by**: iOS developers in Xcode

### Resolution Strategy

**Option 1: Keep Both (RECOMMENDED)**
- Maintain `/docs/ARCHITECTURE.md` as comprehensive reference
- Maintain `/LexiconFlow/docs/ARCHITECTURE.md` as focused guide
- Add cross-references between documents
- Document the relationship in both files

**Rationale**:
- Different audiences need different detail levels
- Xcode developers need quick reference (focused version)
- Architects/stakeholders need full context (comprehensive version)
- Both serve legitimate purposes

**Implementation**:
```markdown
# In /docs/ARCHITECTURE.md
## Quick Reference
For a focused implementation guide, see [LexiconFlow/docs/ARCHITECTURE.md](../LexiconFlow/docs/ARCHITECTURE.md).

# In /LexiconFlow/docs/ARCHITECTURE.md
## Comprehensive Documentation
For full technical architecture including system design and deployment, see [docs/ARCHITECTURE.md](../../docs/ARCHITECTURE.md).
```

**Option 2: Single Source of Truth**
- Keep only `/docs/ARCHITECTURE.md`
- Delete `/LexiconFlow/docs/ARCHITECTURE.md`
- Add README in `/LexiconFlow/docs/` pointing to `/docs/`

**Rationale**: Avoid duplication, single source of truth

**Trade-off**: Loses focused guide for Xcode developers

## Documentation Standards

### Markdown Format

All documentation must:
- Use proper markdown syntax
- Include table of contents for long documents
- Use code fences with language specification
- Include relative links to related documents
- Render correctly in GitHub and Xcode

### Code Examples

All code examples must:
- Be syntactically correct
- Include necessary imports
- Compile against current codebase
- Include explanatory comments
- Follow project coding standards

### Diagrams

Diagrams should:
- Use ASCII art for simple diagrams
- Use Mermaid.js for complex flows (GitHub renders)
- Include text descriptions for accessibility
- Be version-controlled (not binary images)

### Accessibility

Documentation must be:
- Screen reader friendly (proper heading hierarchy)
- High contrast text (WCAG AA minimum)
- Descriptive link text (avoid "click here")
- Alt text for images and diagrams

## Documentation Review Process

1. **Creation**: Author creates documentation
2. **Technical Review**: Technical lead reviews for accuracy
3. **Editorial Review**: Project lead reviews for clarity
4. **Approval**: Merge after reviews complete
5. **Archival**: Old versions preserved in git history

## Maintenance Schedule

| Document | Review Frequency | Owner |
|----------|-----------------|-------|
| CLAUDE.md | Each new pattern | Tech Lead |
| docs/ARCHITECTURE.md | Quarterly | Architect |
| LexiconFlow/docs/ARCHITECTURE.md | Quarterly | iOS Lead |
| docs/ROADMAP.md | Monthly | PM |
| docs/TESTING.md | Each test suite | QA Lead |
| docs/WORKFLOW.md | As needed | DevOps |

## Deleting Documentation

**App Icon Documentation** (Deleted in improve-new-feature branch)

**What was deleted:**
- `docs/app-icon-design-concept.md`
- `docs/app-icon-design-specification.md`
- `docs/app-icon-designer-brief.md`
- `docs/app-icon-implementation-guide.md`
- `docs/app-icon-quick-reference.md`
- `docs/app-icon-variants-guide.md`
- `docs/app-icon-visual-reference.md`
- `docs/iphone-se-screenshot-guide.md`

**Why**: App icon design is complete. Documentation is no longer needed.

**Archival**: Git history preserves all deleted documents.

**Restoration**: If needed, restore from git history:
```bash
git checkout main~1 -- docs/app-icon-design-concept.md
```

**App Store Copy** (Deleted in improve-new-feature branch)

**What was deleted:**
- `docs/app-store-copy.md`
- `docs/app-store-description.md`
- `docs/app-store-keywords.md`
- `docs/app-store-promotional-text.md`

**Why**: App Store copy is managed in App Store Connect, not in repository.

**Archival**: Git history preserves all deleted documents.

## Quick Reference

| Need | Go To |
|------|-------|
| Quick start | README.md |
| Build/test commands | CLAUDE.md |
| Implementation patterns | CLAUDE.md (sections 16-19) |
| Full architecture | docs/ARCHITECTURE.md |
| Focused architecture | LexiconFlow/docs/ARCHITECTURE.md |
| Testing strategy | docs/TESTING.md |
| Git workflow | docs/WORKFLOW.md |
| Algorithm specs | docs/ALGORITHM_SPECS.md |
| Development roadmap | docs/ROADMAP.md |
| Environment setup | docs/ENVIRONMENT_SETUP.md |

## Future Improvements

1. **Documentation Generation**: Consider DocC for API documentation
2. **Automated Checks**: Pre-commit hooks for markdown linting
3. **Search Integration**: Add search to documentation site
4. **Versioned Docs**: Maintain documentation for each release
5. **Contributing Guide**: Expand CONTRIBUTING.md with documentation standards

## References

- [GitHub Markdown Guide](https://guides.github.com/features/mastering-markdown/)
- [Markdown Lint](https://github.com/DavidAnson/markdownlint)
- [Mermaid.js](https://mermaid-js.github.io/mermaid/)
- [WCAG Accessibility Guidelines](https://www.w3.org/WAI/WCAG21/quickref/)
