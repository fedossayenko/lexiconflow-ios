# Development Workflow

**Project:** Lexicon Flow iOS
**Branch Strategy:** Protected Main → Develop → Feature Branches

---

## Git Workflow

### Branch Structure

```
main (protected)
  └── develop (integration branch)
    ├── feature/phase0-environment-setup
    ├── feature/phase1-foundation
    ├── feature/phase2-liquid-ui
    ├── feature/phase3-intelligence
    └── feature/phase4-polish
```

### Branch Protection Rules

**main branch:**
- ✅ Require pull request reviews before merging
- ✅ Require status checks to pass before merging
- ✅ Require branches to be up to date before merging
- ✅ Block force pushes

**develop branch:**
- ✅ Require pull request reviews before merging to main
- ✅ Require status checks to pass

### Workflow

1. **Create Feature Branch**
   ```bash
   git checkout develop
   git pull origin develop
   git checkout -b feature/phase1-fsrs-integration
   ```

2. **Commit Changes**
   ```bash
   git add .
   git commit -m "feat: implement FSRS wrapper"
   ```

3. **Push to Remote**
   ```bash
   git push origin feature/phase1-fsrs-integration
   ```

4. **Create Pull Request**
   - Target: `develop`
   - Require: 1 review approval
   - Require: All CI checks pass

5. **Merge to develop**
   - After approval and checks pass
   - Squash and merge

6. **Merge develop to main**
   - Only after phase is complete
   - Via pull request
   - Tag release: `v0.1.0`, `v0.2.0`, etc.

---

## Commit Message Conventions

### Format

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Types

- **feat:** New feature
- **fix:** Bug fix
- **refactor:** Code refactoring
- **test:** Adding or updating tests
- **docs:** Documentation changes
- **chore:** Maintenance tasks
- **perf:** Performance improvements

### Examples

```
feat(models): add Card model with SwiftData

Implement the Card model with:
- word, definition, phonetic properties
- @Attribute(.externalStorage) for imageData
- relationship to Deck and ReviewLog

Tests: model creation, relationship CRUD
Refs: #1
```

```
fix(scheduler): handle nil dueDate gracefully

When a card has no dueDate set, default to Date()
instead of crashing. This can happen during
initial card creation.

Fixes #42
```

---

## Code Review Checklist

### Before Creating Pull Request

- [ ] Code compiles without warnings
- [ ] All tests pass (green CI/CD)
- [ ] Test coverage >80% for modified code
- [ ] SwiftLint passes
- [ ] SwiftFormat passes
- [ ] Documentation updated if needed

### During Code Review

- [ ] Code follows Swift 6 strict concurrency
- [ ] No force unwraps (`!`) without validation
- [ ] Proper error handling
- [ ] Performance considerations addressed
- [ ] Accessibility considered
- [ ] Security best practices followed

---

## CI/CD Pipeline

### GitHub Actions Workflow

**File:** `.github/workflows/ci.yml`

**Jobs:**

1. **Build and Test**
   - Runs on every push and pull request
   - Builds for iOS Simulator
   - Runs unit tests
   - Generates code coverage report

2. **SwiftLint**
   - Enforces code style
   - Uses strict mode

3. **SwiftFormat**
   - Checks code formatting

### Required Checks

Before merging, all must pass:
- ✅ Build succeeds
- ✅ Unit tests pass
- ✅ SwiftLint passes
- ✅ SwiftFormat passes

---

## Quality Gates

### Phase Completion Checklist

Before completing a phase and moving to the next:

1. **Code Quality**
   - [ ] All acceptance criteria met
   - [ ] Test coverage target reached (>80%)
   - [ ] No critical bugs
   - [ ] No compiler warnings

2. **Performance**
   - [ ] App launch time <2 seconds
   - [ ] Memory usage within acceptable limits
   - [ ] No memory leaks (Instruments verified)

3. **Documentation**
   - [ ] README updated if needed
   - [ ] Code comments added where complex
   - [ ] Technical documentation updated

4. **Testing**
   - [ ] Unit tests passing
   - [ ] Integration tests passing
   - [ ] UI tests passing
   - [ ] Manual testing completed

5. **Review**
   - [ ] Code reviewed by team
   - [ ] Demo shown to stakeholders
   - [ ] Phase retrospective completed

---

## Release Strategy

### Versioning

- **Phase 0:** `v0.0.1` - Environment setup
- **Phase 1:** `v0.1.0` - Foundation complete
- **Phase 2:** `v0.2.0` - Liquid UI complete
- **Phase 3:** `v0.3.0` - Intelligence complete
- **Phase 4:** `v1.0.0` - Launch ready

### Tags

Create annotated tags for each phase completion:

```bash
git tag -a v0.1.0 -m "Phase 1: Foundation complete"
git push origin v0.1.0
```

---

## Issue Templates

### Bug Report

**Title:** [Bug] Brief description

**Description:**
- What happened?
- What should have happened?
- Steps to reproduce
- Device/Simulator info
- Screenshots if applicable

### Feature Request

**Title:** [Feature] Brief description

**Description:**
- What feature do you want?
- Why is it needed?
- How should it work?
- Acceptance criteria

---

## Project Documentation

**Technical Documentation:** `/docs/`

- `STRATEGIC_ENGINEERING_REPORT.md` - Product blueprint
- `ARCHITECTURE.md` - Technical architecture
- `ALGORITHM_SPECS.md` - FSRS implementation details
- `PRODUCT_VISION.md` - Market positioning
- `ROADMAP.md` - 16-week development plan
- `API_AVAILABILITY_REPORT.md` - iOS 26 API verification

**Code Comments:**

- Complex algorithms should have comments explaining WHY
- Public APIs should have documentation comments
- Obvious code should NOT be commented

---

**Workflow Status:** ✅ Established
**Next:** Complete Phase 0 and begin Phase 1
