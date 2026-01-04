# Lexicon Flow iOS - Development Roadmap

## Overview

This document outlines the phased development approach for Lexicon Flow, from initial concept through App Store launch. The roadmap is designed for a **16-week execution cycle (Q1-Q2 2026)**.

---

## Timeline Summary

| Phase | Duration | Focus | Key Deliverable |
|-------|----------|-------|-----------------|
| **1** | Weeks 1-4 | Foundation | Data model, FSRS integration |
| **2** | Weeks 5-8 | Liquid UI | GlassEffectContainer, gestures |
| **3** | Weeks 9-12 | Intelligence | AI, translation, audio |
| **4** | Weeks 13-16 | Polish & Launch | Widgets, beta, App Store |

**Target Launch**: June 2026

---

## Phase 1: The Foundation (Weeks 1-4)

### Objectives
- Establish project architecture
- Implement data persistence with SwiftData
- Integrate FSRS v5 algorithm
- Build core card/deck models

### Week 1: Project Setup
- [ ] Initialize Xcode 26 project with iOS 26 target
- [ ] Configure Swift 6 strict concurrency settings
- [ ] Set up SwiftData model container
- [ ] Create base project structure (folders, groups)
- [ ] Configure SwiftFSRS package dependency
- [ ] Set up git repository and CI/CD

### Week 2: Data Model
- [ ] Implement `Card`, `Deck`, `ReviewLog`, `FSRSState` models
- [ ] Configure relationships and delete rules
- [ ] Set up `@Attribute(.externalStorage)` for image data
- [ ] Create model migrations strategy
- [ ] Write unit tests for model validation
- [ ] Implement `ModelActor` for background operations

### Week 3: FSRS Integration
- [ ] Integrate SwiftFSRS library
- [ ] Create `Scheduler` actor for thread-safe operations
- [ ] Implement rating system (Again, Hard, Good, Easy)
- [ ] Build due card query logic
- [ ] Create Cram Mode vs Scheduled Review logic
- [ ] Write comprehensive unit tests:
  - New card first review
  - Again resets state
  - Easy increases stability
  - Late review bonus

### Week 4: Basic UI Structure
- [ ] Set up main app entry point
- [ ] Create placeholder deck list view
- [ ] Build basic flashcard view (without glass effects)
- [ ] Implement tap-to-flip functionality
- [ ] Create settings placeholder
- [ ] Build onboarding flow (placeholder content)

**Exit Criteria:**
- App launches without crashes on iOS 26
- Can create a deck and add cards manually
- FSRS algorithm schedules next review correctly
- All unit tests passing

---

## Phase 2: The Liquid UI (Weeks 5-8)

### Objectives
- Implement "Liquid Glass" design system
- Build fluid gesture-based grading
- Create immersive card interactions
- Implement haptic feedback

### Week 5: GlassEffectContainer
- [ ] Implement `GlassEffectContainer` for card stack
- [ ] Apply `.glassEffect()` modifier to flashcard
- [ ] Create glass thickness visualization (stability → opacity)
- [ ] Implement glass tint feedback based on swipe direction
- [ ] Performance testing with 50+ overlapping glass elements
- [ ] Optimize for 120Hz ProMotion displays

### Week 6: Gesture System
- [ ] Implement drag gesture on flashcard
- [ ] Add visual feedback during drag:
  - Swipe right (Good) → Green tint, "swelling" effect
  - Swipe left (Again) → Red tint, "shrinking" effect
  - Swipe up (Easy) → Blue tint, lightening effect
  - Swipe down (Hard) → Orange tint, heavy effect
- [ ] Tune gesture recognition thresholds
- [ ] Add cancel gesture (swipe back to center)
- [ ] Implement `.interactive()` modifier for reactive refraction

### Week 7: Morphing Transitions
- [ ] Replace standard 3D flip with `glassEffectTransition(.materialize)`
- [ ] Implement `matchedGeometryEffect` for smooth element transitions
- [ ] Create "materialize" animation:
  - Front content blurs into glass
  - Back content sharpens from refraction
- [ ] Add `glassEffectUnion` for deck icon + progress bar merging
- [ ] Implement navigation transitions between views

### Week 8: Haptics & Audio Feedback
- [ ] Design `CoreHaptics` patterns:
  - Again: Heavy thud
  - Hard: Firm press
  - Good: Crisp click
  - Easy: Light tap
- [ ] Implement harmonic chimes for streak building
- [ ] Add audio feedback toggle in settings
- [ ] Test haptic intensity levels
- [ ] A/B test gesture vs. button grading

**Exit Criteria:**
- Glass effects render at 120Hz smoothly
- Gestures feel natural and responsive
- Haptic feedback provides clear confirmation
- Card transitions are "morphing" not "sliding"

---

## Phase 3: Intelligence & Content (Weeks 9-12)

### Objectives
- Integrate Foundation Models for AI features
- Implement Translation API
- Add neural TTS with accent selection
- Import and process base dictionary

### Week 9: Foundation Models
- [ ] Integrate Foundation Models framework
- [ ] Create `LanguageModelSession` wrapper
- [ ] Implement sentence generation with prompt engineering:
  - Casual American English context
  - Simple vocabulary constraint
  - Pedagogical value optimization
- [ ] Build sentence caching strategy (7-day TTL)
- [ ] Add "Regenerate Sentence" button
- [ ] Test generation latency and quality

### Week 10: Translation API
- [ ] Integrate Translation framework
- [ ] Create `TranslationSession` manager
- [ ] Implement tap-to-translate on example sentences
- [ ] Build batch translation for word imports
- [ ] Add language availability checking
- [ ] Implement offline language pack detection
- [ ] Create Share Extension for Safari → card creation

### Week 11: Audio System
- [ ] Implement `AVSpeechSynthesizer` wrapper
- [ ] Build voice quality selector:
  - Premium > Enhanced > Default
  - Filter by language code
  - Sort by quality
- [ ] Create accent selection UI:
  - en-US (American)
  - en-GB (British)
  - en-AU (Australian)
  - en-IE (Irish)
- [ ] Add playback rate controls
- [ ] Implement "Auto-play on card flip" setting
- [ ] Detect and prompt for premium voice downloads

### Week 12: Dictionary Import
- [ ] Source/acquire 10,000-word English dataset
- [ ] Create JSON import format specification
- [ ] Implement background import with `ModelActor`
- [ ] Build import progress UI with cancellation
- [ ] Add batch image processing
- [ ] Test import performance (target: <30 seconds)
- [ ] Implement incremental updates

**Exit Criteria:**
- AI generates coherent, varied sentences
- Translation works offline after language pack download
- Neural voices play clearly with correct accent
- 10,000-word dictionary imports successfully

---

## Phase 4: Polish & Launch (Weeks 13-16)

### Objectives
- Build Lock Screen widgets and Live Activities
- Implement freemium features
- Beta testing and iteration
- App Store submission

### Week 13: Widgets & Live Activities
- [ ] Create Lock Screen widget:
  - AccessoryCircular: Due count
  - AccessoryRectangular: Due count + streak
  - `.containerBackground(.glassEffect)`
- [ ] Implement Live Activity for study sessions:
  - Dynamic Island support
  - Lock Screen support
  - Pulsing animation when paused
- [ ] Configure App Group for data sharing
- [ ] Add widget deep links to app
- [ ] Test widget battery impact

### Week 14: Freemium Features
- [ ] Implement StoreKit 2:
  - Configure products (Monthly, Yearly)
  - Create Subscription Group
  - `SubscriptionStoreView` integration
- [ ] Build feature flags:
  - Free: 20 words/day limit
  - Pro: Unlimited words, AI, cloud sync
- [ ] Create onboarding paywall
- [ ] Implement CloudKit sync for Pro users
- [ ] Add purchase restoration logic

### Week 15: Dashboard & Analytics
- [ ] Build DashboardView with:
  - Swift Charts for progress visualization
  - Streak counter with freeze mechanic
  - Due cards distribution
  - Study session history
- [ ] Implement "Knowledge Graph" visualization:
  - Nodes for words (size = stability)
  - Strands for connections (synonyms/antonyms)
  - Liquid Glass blobs that merge
- [ ] Add detailed retention heatmap
- [ ] Create export functionality

### Week 16: Beta & Launch
- [ ] Recruit 50 beta testers
- [ ] Distribute via TestFlight
- [ ] Collect feedback via:
  - In-app feedback form
  - Survey for feature prioritization
  - Analytics for crash reporting
- [ ] Address critical bugs
- [ ] Tune FSRS parameters based on beta data
- [ ] Create App Store assets:
  - App icon (1024x1024)
  - Screenshots for all device sizes
  - App Store preview video
  - Promotional text
  - Keywords and description
- [ ] Submit to App Store

**Exit Criteria:**
- Zero critical bugs
- App launch time <2 seconds
- Battery usage <5% per hour of study
- App Store submission complete

---

## Post-Launch Roadmap

### Version 1.1 (Month 2)
- [ ] FSRS optimizer auto-tuning
- [ ] Advanced export (CSV, PDF, Anki)
- [ ] Dark mode refinements
- [ ] Accessibility improvements (VoiceOver, Dynamic Type)

### Version 1.2 (Month 3)
- [ ] Shared decks via CloudKit
- [ ] Import from Anki (.apkg)
- [ ] Study reminders with rich notifications
- [ ] Screen Flash notification option

### Version 2.0 (Month 6)
- [ ] Multi-language support (Spanish, French, German)
- [ ] Community deck marketplace
- [ ] AI-powered example sentence refinement
- [ ] Pronunciation assessment (Speech Recognition)

### Version 3.0 (Year 2)
- [ ] Mac app via Mac Catalyst
- [ ] Apple Watch micro-learning
- [ ] Curriculum mode (career-based learning paths)
- [ ] Reading app integration (auto-vocab extraction)

---

## Risk Mitigation

| Risk | Probability | Impact | Mitigation Strategy |
|------|-------------|--------|---------------------|
| **Foundation Models limitations** | Medium | Medium | Implement caching; fallback to static sentences |
| **Glass performance issues** | Low | High | Extensive testing; fallback to standard Material |
| **FSRS complexity** | Low | Medium | Excellent onboarding; hide complexity behind UI |
| **App Store rejection** | Low | High | Strict adherence to guidelines; legal review |
| **iOS 26 adoption slow** | Medium | High | Target power users; emphasize "requires latest iOS" |
| **Beta tester recruitment** | Medium | Medium | Reddit, Twitter/X, language learning communities |

---

## Success Milestones

### Technical Milestones

- [x] **Milestone 1: Core Algorithm** (Week 4)
- [ ] **Milestone 2: Liquid UI Complete** (Week 8)
- [ ] **Milestone 3: AI Features Working** (Week 12)
- [ ] **Milestone 4: Beta Ready** (Week 15)
- [ ] **Milestone 5: App Store Submission** (Week 16)
- [ ] **Milestone 6: First 1,000 Downloads** (Post-Launch Month 1)
- [ ] **Milestone 7: 100 Paying Subscribers** (Post-Launch Month 2)

### Quality Milestones

- [ ] **99% Crash-Free Sessions** (Beta)
- [ ] **4.5+ App Store Rating** (Month 1)
- [ ] **25% Day 7 Retention** (Month 1)
- [ ] **10% Free-to-Pro Conversion** (Month 3)

---

## Team Structure (Recommended)

### Minimum Viable Team

| Role | FTE | Responsibilities |
|------|-----|------------------|
| **iOS Engineer** | 1 | Swift 6, SwiftUI, SwiftData, algorithm integration |
| **UI/UX Designer** | 0.5 | "Liquid Glass" design, animations, user flow |
| **QA/Beta Coordinator** | 0.25 | TestFlight management, bug triage |

### Extended Team (Post-Launch)

| Role | FTE | Responsibilities |
|------|-----|------------------|
| **Backend Engineer** | 0.5 | CloudKit sync, community features |
| **Data Scientist** | 0.25 | FSRS optimization, A/B testing |
| **Marketing** | 0.5 | ASO, content marketing, community management |

---

## Development Workflow

### Git Workflow

```
main (protected)
├── develop (integration branch)
    ├── feature/phase1-foundation
    ├── feature/phase2-liquid-ui
    ├── feature/phase3-intelligence
    └── feature/phase4-polish
```

### Code Review Standards

- All code requires review before merging to `develop`
- Swift 6 strict concurrency warnings must be addressed
- Unit tests required for all algorithm changes
- UI components require screenshot/video in PR

### CI/CD Pipeline

- **On PR**: Run unit tests, SwiftLint, SwiftFormat
- **On Merge to Develop**: Build test flight for internal team
- **On Merge to Main**: Tag release, build TestFlight for beta

---

## Budget Estimate

### One-Time Costs

| Item | Cost |
|------|------|
| Apple Developer Program | $99/year |
| 10k Word Dictionary License | $500-2,000 |
| App Store Screenshots/Video | $500 |
| Legal (Privacy Policy, ToS) | $1,000 |
| **Total** | **~$2,100-3,600** |

### Recurring Costs

| Item | Cost |
|------|------|
| Apple Developer Program | $99/year |
| CloudKit (beyond free tier) | $0-50/month (usage-based) |
| Foundation Models API | $0 (on-device) |
| **Total** | **~$100-700/year** |

---

## Conclusion

This roadmap is designed to deliver Lexicon Flow to the App Store in **16 weeks** with a focus on:

1. **Technical Excellence**: iOS 26 features implemented correctly
2. **User Experience**: Fluid, engaging interactions
3. **Pedagogical Integrity**: FSRS v5 from day one
4. **Commercial Viability**: Clear freemium model

The phased approach allows for:
- Early validation of core technology
- Iterative refinement based on beta feedback
- Flexibility to pivot if needed

**Success = Execution + Agility + User Feedback.**

---

**Document Version**: 1.0
**Last Updated**: January 2026
**Target Launch**: Q2 2026 (June)
**Total Duration**: 16 weeks
