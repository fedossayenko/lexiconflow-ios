# App Icon Designer Brief

**Document Version**: 1.0
**Issued**: 2026-01-06
**To**: UI/UX Designer
**From**: LexiconFlow Product Team

---

## Project Overview

**App Name**: LexiconFlow
**Category**: Education / Vocabulary Learning
**Platform**: iOS (iPhone & iPad)
**Asset Type**: App Icon (1024×1024)

---

## Design Request

Create a **glass morphism app icon** for LexiconFlow that:

1. Showcases the app's "Liquid Glass" UI design language
2. Differentiates from flat, utilitarian competitors (Anki, Quizlet)
3. Communicates premium quality and advanced technology
4. Remains recognizable at sizes as small as 16×16px

---

## Brand Context

### What is LexiconFlow?

LexiconFlow is a vocabulary learning app that combines:
- **FSRS v5** - Most advanced spaced repetition algorithm
- **Liquid Glass UI** - Beautiful, depth-rich interface
- **Smart Scheduling** - Optimized for 90% retention rate

### Target Audience

- **Primary**: Serious learners (language students, test prep)
- **Secondary**: Design-conscious users who value aesthetics
- **Age**: 18-45, college-educated, tech-savvy
- **Psychographics**: Appreciates minimalist, premium design

### Competitive Landscape

| App | Icon Style | Differentiation |
|-----|------------|-----------------|
| **Anki** | Flat blue elephant | Dated, utilitarian |
| **Quizlet** | Flat blue "Q" | Generic, boring |
| **LexiconFlow** | **Glass morphism 'L'** | Modern, premium, unique |

---

## Design Requirements

### Core Symbol: Fluid 'L'

Create a calligraphic, fluid 'L' that represents:
- **L**exiconFlow (brand identity)
- **L**earning as journey (fluid motion)
- **L**iquidity (glass/water metaphor)

### Visual Style: Glass Morphism

**MUST INCLUDE**:
1. ✅ Frosted glass card with 40px Gaussian blur
2. ✅ Transparency effect (25% opacity)
3. ✅ Gradient colors: #6366F1 → #EC4899 → #8B5CF6
4. ✅ Semi-transparent border (2px, 40% opacity)
5. ✅ Noise texture for realistic frosted effect (5% opacity)
6. ✅ Multi-layered depth (glass card over solid background)

**MUST NOT INCLUDE**:
- ❌ Drop shadows (too heavy, conflicts with glass effect)
- ❌ Inner shadows or bevels (dated aesthetic)
- ❌ Jellyfish or any symbol other than 'L'
- ❌ Flat colors without blur or transparency
- ❌ More than 3 gradient colors

---

## Technical Specifications

### Canvas & Composition

| Property | Value |
|----------|-------|
| **Canvas Size** | 1024×1024px (App Store requirement) |
| **Glass Card Size** | 819×819px (80% of canvas, centered) |
| **Corner Radius** | 184px (22.5% of card width) |
| **Symbol Height** | ~500px (centered in glass card) |

### Colors

**Gradient for 'L' symbol** (45° angle):
- Start: `#6366F1` (Indigo 500)
- Middle: `#EC4899` (Pink 500)
- End: `#8B5CF6` (Violet 500)

**Light Mode**:
- Background: `#FFFFFF` (100%)
- Glass fill: `#FFFFFF` (25% opacity)
- Border: `#FFFFFF` (40% opacity)

**Dark Mode**:
- Background: `#000000` (100%)
- Glass fill: `#FFFFFF` (30% opacity)
- Border: `#FFFFFF` (50% opacity)

### Effects

1. **Layer Blur**: 40px Gaussian blur on glass card
2. **Noise Overlay**: 5% opacity, grayscale texture
3. **Stroke**: 2px border with reduced opacity

---

## Inspiration & References

### Design Style: Glass Morphism

Study these examples:
1. **macOS Big Sur** - Translucent windows, sidebar blur
2. **iOS Control Center** - Frosted glass toggles, depth
3. **Dribbble "Glassmorphism"** - Top-rated designs for inspiration

### Symbol: Calligraphic 'L'

Reference these for stroke quality:
1. **Bodoni** - High contrast stroke widths
2. **Brush Script MT** - Fluid motion quality
3. **Custom SVG** - Build from scratch for perfect control

### Color Gradient

Study similar gradients:
1. Instagram's brand gradient (purple→pink→orange)
2. Discord's blurple (blue→purple)
3. Tailwind CSS "violet to pink" gradient

---

## Deliverables

### Primary Assets

1. **app-icon.png** (1024×1024)
   - Light mode version
   - PNG format, no alpha channel (solid background)
   - Optimized for App Store (<500KB)

2. **app-icon-dark.png** (1024×1024)
   - Dark mode version
   - Slightly higher glass opacity (30% vs 25%)
   - PNG format, no alpha channel

### iOS Icon Set

Generate all iOS sizes from 1024×1024 master:
- iPhone: 60×60 (@2x, @3x), 40×40 (@2x, @3x), 29×29 (@2x, @3x), 20×20 (@2x, @3x)
- iPad: 76×76 (@2x), 83.5×83.5 (@2x)
- Mac: 16×16, 32×32, 128×128, 256×256, 512×512, 1024×1024

**Total**: 16 icon files

### Source Files

Provide editable source file in:
- **Figma** (preferred) - Share link or export .fig
- **Sketch** (alternative) - Export .sketch
- **Adobe Illustrator** (fallback) - Export .ai or .svg

---

## Design Tools

### Recommended Software

1. **Figma** (primary recommendation)
   - Free, browser-based
   - Excellent layer blur and gradient tools
   - Easy export at multiple scales
   - Real-time collaboration

2. **Sketch** (alternative)
   - macOS-only, paid
   - Similar capabilities to Figma
   - Better for macOS-centric workflows

3. **Adobe Illustrator** (if vector needed)
   - Use if pixel-perfect scalability required
   - Export final design as PNG

### Figma Setup

If using Figma, create this structure:

```
Frame: App Icon (1024×1024)
  ├─ Rectangle: Background (#FFFFFF)
  ├─ Rectangle: Glass Card (819×819)
  │   ├─ Effect: Layer blur (40px)
  │   ├─ Fill: White (25% opacity)
  │   └─ Stroke: White (40% opacity, 2px)
  ├─ Vector: Fluid 'L' (gradient: #6366F1→#EC4899→#8B5CF6)
  └─ Rectangle: Noise Overlay (5% opacity)
```

---

## Testing & Validation

### Size Test

View icon at these sizes to ensure legibility:
- ✅ 16×16px (smallest: Info.plist)
- ✅ 32×32px (Mac app)
- ✅ 60×60px (iPhone app)
- ✅ 1024×1024px (App Store)

**Pass Criteria**: 'L' symbol remains recognizable at 16px

### Background Test

Place icon on:
- ✅ White background
- ✅ Black background
- ✡ Gray backgrounds (#F5F5F5, #2C2C2E)

**Pass Criteria**: Glass effect works in all contexts

### Accessibility Test

- ✅ Enable "Reduce Transparency" in iOS Settings
- ✅ Verify icon still looks good (graceful degradation)
- ✅ Check color contrast ratios (>3:1 for AA)

---

## Review Criteria

The icon will be approved when:

- [ ] Glass morphism effect is clearly visible (blur, transparency, border)
- [ ] Fluid 'L' symbol is centered, legible, and on-brand
- [ ] Gradient flows smoothly from indigo→pink→violet
- [ ] Icon remains recognizable at 16×16px
- [ ] Noise texture creates realistic frosted glass (not gritty)
- [ ] Both light and dark mode versions provided
- [ ] All iOS icon sizes generated correctly
- [ ] Files are PNG format without alpha channel
- [ ] Source file provided (Figma/Sketch/AI)
- [ ] Design team and product lead sign off

---

## Common Pitfalls to Avoid

### ❌ Don't Do This

1. **Too much blur** (>60px) - Creates muddy, indistinct shapes
2. **Too much opacity** (>40%) - Glass effect becomes solid
3. **Too little opacity** (<15%) - Glass effect becomes invisible
4. **No noise texture** - Looks like plastic, not frosted glass
5. **Wrong symbol** - Jellyfish or any non-'L' symbol
6. **Flat design** - No blur, no transparency, no depth
7. **Too many colors** - More than 3 colors in gradient
8. **Sharp corners** - No rounded corners on glass card

### ✅ Do This Instead

1. **40px blur** - Sweet spot for glass morphism
2. **25% opacity** - Perfect balance of transparency and visibility
3. **5% noise** - Subtle texture for realistic frosted effect
4. **Fluid 'L'** - Calligraphic, gradient-colored
5. **Multi-layered** - Glass card over solid background
6. **3-color gradient** - Indigo→pink→violet (max 3 stops)
7. **184px corner radius** - Rounded, friendly, modern

---

## Timeline & Budget

### Estimated Time

- **Concept sketches**: 2-4 hours
- **Figma design**: 4-6 hours
- **Size variations**: 1-2 hours
- **Revisions**: 2-4 hours
- **Final export**: 1 hour

**Total**: 10-17 hours

### Budget Range

- **In-house designer**: $500-$1,000
- **Freelance designer**: $300-$800
- **Crowdsourced (99designs, etc.)**: $200-$500

---

## Submission Instructions

### File Organization

```
lexiconflow-app-icon/
├── sources/
│   └── lexiconflow-app-icon.fig (or .sketch, .ai)
├── light-mode/
│   ├── app-icon-1024.png
│   ├── app-icon-512.png
│   ├── app-icon-256.png
│   ├── app-icon-128.png
│   ├── app-icon-64@2x.png
│   ├── app-icon-60@2x.png
│   ├── app-icon-60@3x.png
│   ├── app-icon-40@2x.png
│   ├── app-icon-40@3x.png
│   ├── app-icon-29@2x.png
│   ├── app-icon-29@3x.png
│   ├── app-icon-20@2x.png
│   ├── app-icon-20@3x.png
│   └── app-icon-16.png
└── dark-mode/
    ├── app-icon-1024-dark.png
    └── [same 15 sizes as light-mode]
```

### Naming Convention

Use iOS-standard naming:
- `app-icon-{size}@{scale}x.png` for Retina displays
- `app-icon-{size}.png` for 1x displays
- `app-icon-1024-dark.png` for dark mode master

### Upload Location

Share files via:
- **Google Drive** (preferred): [Upload link]
- **Dropbox**: [Upload link]
- **Figma Share Link**: [Link to file]
- **Email**: [Product lead email]

---

## Questions & Support

### For Design Questions

Contact:
- **Product Lead**: [Name, email]
- **Design Reviewer**: [Name, email]
- **iOS Engineer**: [Name, email]

### Technical Questions

- iOS asset catalog structure
- Xcode integration
- Icon testing in Simulator

---

## Approval Process

1. **Initial Review** (1-2 days after submission)
   - Design team checks against requirements
   - Product lead validates brand alignment

2. **Revision Round** (if needed)
   - Feedback provided within 24 hours
   - Designer implements revisions

3. **Final Approval** (within 3-5 days total)
   - Sign-off from product lead
   - Integration into iOS project

4. **QA Testing** (after integration)
   - Test on actual devices
   - Verify in iOS Simulator
   - Check App Store preview

---

## Appendix: Quick Reference Card

```
┌────────────────────────────────────────┐
│   LEXICONFLOW APP ICON - QUICK REF    │
├────────────────────────────────────────┤
│ Symbol:        Fluid 'L'               │
│ Style:         Glass morphism          │
│ Gradient:      #6366F1 → #EC4899       │
│                → #8B5CF6               │
│ Glass Card:    819×819, 184px radius  │
│ Blur:          40px Gaussian           │
│ Opacity:       25% (light), 30% (dark) │
│ Border:        2px, 40% opacity        │
│ Noise:         5% grayscale            │
│                                        │
⚠️  NO JELLYFISH - FLUID 'L' ONLY!      │
└────────────────────────────────────────┘
```

---

**Document Control**

- **Author**: Product Team
- **Status**: Issued
- **Deadline**: [Date]
- **Next Review**: After initial mockup

**Good luck! We're excited to see your design.** 🎨✨
