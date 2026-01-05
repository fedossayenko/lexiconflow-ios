# App Icon Designer Brief

## Project Overview

**Client**: Lexicon Flow
**Project**: App Icon Design (1024x1024 master)
**Design Style**: Glass Morphism with Liquid Glass aesthetic
**Timeline**: 4-6 hours design time
**Deliverables**: 1x PNG-24 file (1024x1024), optional source file

## Brand Context

### What is Lexicon Flow?

Lexicon Flow is a vocabulary learning app that uses the **FSRS v5 algorithm** (most advanced spaced repetition system) with a beautiful **Liquid Glass UI**. The app differentiates itself through:

1. **Scientific Algorithm**: FSRS v5 optimizes review scheduling for 90% retention
2. **Beautiful Design**: Liquid Glass interface where glass thickness represents memory stability
3. **User Agency**: Two study modes (Scheduled vs. Cram) giving users control
4. **Privacy-First**: No accounts, no cloud sync, no subscriptions

### Target Audience

- **Primary**: Serious vocabulary learners (language students, test prep candidates)
- **Secondary**: Medical/law students (domain-specific vocabulary), lifelong learners
- **Age**: 18-45, college-educated, tech-savvy
- **Values**: Effectiveness, aesthetics, privacy, control

## Design Requirements

### Icon Concept

**Symbol**: Letter "L" (for "Lexicon" and "Learning")

**Why "L"?**
- Represents the core brand: **L**exicon Flow
- Symbolizes the value: **L**earning
- Simple, scalable, recognizable at all sizes
- No competitor uses "L" (differentiation)

### Visual Style: Glass Morphism

**Key Characteristics**:
- Frosted glass effect (blur, transparency, border)
- Depth through shadows and layers
- Gradient background (Indigo → Pink → Purple)
- Premium, modern, iOS-native aesthetic

**Reference Keywords**: Glassmorphism, frosted glass, depth, blur, premium, iOS 15+ aesthetic

## Technical Specifications

### Canvas & Layout

```
Canvas Size: 1024x1024px
Glass Card: 819x819px (80% of canvas, centered)
Corner Radius: 180px (22% of card width)
Letter "L": Centered within glass card
```

### Letter "L" Design

**Typography**:
- Font: Geometric sans-serif (similar to SF Pro Display Bold)
- Weight: Extra Bold (800-900)
- Color: Solid white (#FFFFFF)

**Proportions** (on 1024x1024 canvas):
- Stem Height: 716px (70% of canvas)
- Stem Width: 123px (12% of canvas)
- Crossbar Height: 307px (30% of canvas)
- Crossbar Length: 563px (55% from stem)
- Crossbar Thickness: 123px (matches stem)

**Shadow**:
- Offset: 0px, 4px
- Blur: 12px
- Color: rgba(0, 0, 0, 0.25)

### Glass Card Effects

**Fill**:
- Color: White (#FFFFFF)
- Opacity: 25%
- Blur: 40px Gaussian blur (applied to layer behind)

**Border**:
- Stroke: 2px
- Color: White (#FFFFFF)
- Opacity: 40%

**Shadow**:
- Offset: 0px, 20px
- Blur: 60px
- Color: rgba(0, 0, 0, 0.15)

**Enhancements**:
- Noise texture overlay: 5% (for frosted appearance)
- Inner shadow: 0px, 2px, 8px, rgba(255, 255, 255, 0.4)
- Top highlight: Gradient from rgba(255, 255, 255, 0.3) → transparent (100px height)

### Background Gradient

**Type**: Linear gradient
**Angle**: 135° (diagonal from top-left to bottom-right)
**Stops**:
1. 0% (top-left): #6366F1 (Indigo 500)
2. 50% (center): #EC4899 (Pink 500)
3. 100% (bottom-right): #8B5CF6 (Purple 500)

## Design Tool Recommendations

### Recommended Tools

**1. Figma** (⭐️ Recommended)
- **Pros**: Free, web-based, excellent for icon design, real-time collaboration
- **Why**: Best balance of features, cost, and ease of use
- **Workflow**: See "Figma Implementation Guide" below

**2. Sketch** (macOS only)
- **Pros**: Industry standard, great icon design features
- **Cons**: macOS only, paid subscription ($99/year)
- **Why**: If you already have it and prefer native Mac app

**3. Adobe Illustrator + Photoshop**
- **Pros**: Professional tools, maximum control
- **Cons**: Expensive ($54/month), steeper learning curve
- **Why**: If you're already an Adobe Creative Cloud subscriber

### Not Recommended

- **Canva**: Limited layer effects for glass morphism
- **GIMP**: Open-source but complex workflow for glass effects
- **Pixel-based tools without layer effects**: Can't achieve glass morphism easily

## Figma Implementation Guide

If using Figma (recommended), follow these steps:

### Step 1: Create Canvas

1. Create new frame: 1024x1024px
2. Name: "App Icon Master"

### Step 2: Create Background Gradient

1. Add rectangle: 1024x1024px (fill entire frame)
2. Fill → Linear gradient
3. Angle: 135°
4. Add 3 stops:
   - Stop 1: #6366F1 at 0%
   - Stop 2: #EC4899 at 50%
   - Stop 3: #8B5CF6 at 100%
5. Layer → Blur effect: Gaussian blur 40px

### Step 3: Create Glass Card

1. Add rectangle: 819x819px
2. Center in frame (X: 102.5, Y: 102.5)
3. Corner radius: 180px
4. Fill: Solid, #FFFFFF, Opacity: 25%
5. Stroke: 2px, #FFFFFF, Opacity: 40%
6. Effects → Add blur: Background blur 40px
7. Effects → Add drop shadow: (0, 20px, 60px, rgba(0,0,0,0.15))
8. Effects → Add inner shadow: (0, 2px, 8px, rgba(255,255,255,0.4))

### Step 4: Create Letter "L"

**Option A: Using Text Tool**
1. Add text layer: "L"
2. Font: SF Pro Display Bold (or similar geometric sans-serif)
3. Size: ~700px (adjust to fit)
4. Color: #FFFFFF
5. Align: Center middle
6. Effects → Add drop shadow: (0, 4px, 12px, rgba(0,0,0,0.25))

**Option B: Using Vector Shapes** (⭐️ Recommended for precision)
1. Create two rectangles:
   - Vertical stem: 123x716px
   - Horizontal crossbar: 563x123px
2. Union shapes to create "L"
3. Fill: #FFFFFF
4. Position: Center in glass card
5. Effects → Add drop shadow: (0, 4px, 12px, rgba(0,0,0,0.25))

### Step 5: Add Top Highlight (Optional Enhancement)

1. Add rectangle: 819x100px (same width as glass card, top 100px)
2. Position: Top edge of glass card
3. Fill: Linear gradient (90°, rgba(255,255,255,0.3) → transparent)
4. Mask: Apply linear gradient mask to fade from top
5. Blend mode: Screen or Overlay

### Step 6: Add Noise Texture (Optional Enhancement)

1. Add rectangle: 819x819px (same size as glass card)
2. Fill: Transparent
3. Effects → Add layer effect: Noise (5% amount)
4. Blend mode: Overlay
5. Clip to glass card

### Step 7: Export

1. Select frame "App Icon Master"
2. Export → Settings:
   - Format: PNG
   - Scale: 1x
   - Suffix: None
3. Export

### Step 8: Verify

1. Open exported PNG in Preview/Image viewer
2. Verify:
   - Dimensions are 1024x1024px
   - File size < 500KB
   - Colors look correct
   - "L" is centered
   - No transparency (should have solid background)

## Sketch Implementation Guide

If using Sketch (macOS only), follow these steps:

### Step 1: Create Artboard

1. Insert → Artboard
2. Preset: iOS App Icon (1024x1024)
3. Name: "App Icon Master"

### Step 2: Create Background Gradient

1. Add rectangle: Fill artboard
2. Fill → Linear gradient
3. Angle: 135°
4. Add 3 stops: #6366F1, #EC4899, #8B5CF6
5. Make sure to export with background (not transparent)

### Step 3-7: Same as Figma

Use same layer structure and effects as Figma guide.

### Step 8: Export

1. File → Export
2. Select "App Icon Master" artboard
3. Format: PNG
4. Scale: 1x
5. Export

## Adobe Implementation Guide

If using Adobe Illustrator + Photoshop:

### Illustrator (Vector Design)

1. Create document: 1024x1024px
2. Create vector shapes for background, glass card, letter "L"
3. Use gradient fills for background
4. Use opacity and effects for glass morphism

### Photoshop (Raster Effects)

1. Open Illustrator file in Photoshop
2. Rasterize layers
3. Apply blur effects, shadows, inner glows
4. Export as PNG-24, sRGB color profile

## Color Palette

### Primary Colors (Copy-Paste Ready)

```
Indigo 500:  #6366F1  │  rgb(99, 102, 241)
Pink 500:    #EC4899  │  rgb(236, 72, 153)
Purple 500:  #8B5CF6  │  rgb(139, 92, 246)
White:       #FFFFFF  │  rgb(255, 255, 255)
Shadow:      rgba(0, 0, 0, 0.25)
Card Shadow: rgba(0, 0, 0, 0.15)
Border:      rgba(255, 255, 255, 0.40)
Card Fill:   rgba(255, 255, 255, 0.25)
```

### Dark Mode Variant (Optional)

```
Indigo 600:  #4F46E5  │  rgb(79, 70, 229)
Pink 600:    #DB2777  │  rgb(219, 39, 119)
Purple 600:  #7C3AED  │  rgb(124, 58, 237)
```

## Export Settings

### Required Format

- **Format**: PNG-24
- **Color Space**: sRGB (NOT Display P3)
- **Bit Depth**: 32-bit (with alpha channel, though final has no transparency)
- **Compression**: None (or lossless)
- **Dimensions**: Exactly 1024x1024px
- **Transparency**: NO (must have solid background)

### File Naming

```
AppIcon-1024.png
```

### File Size

- **Target**: < 500KB (uncompressed)
- **Acceptable**: < 1MB (compressed)
- **Too Large**: > 1MB (consider optimization)

## Quality Checklist

Before submitting, verify:

### Visual Quality
- ✅ "L" is perfectly centered
- ✅ Glass card is perfectly centered
- ✅ Corner radius is uniform (180px)
- ✅ Gradient flows from top-left to bottom-right (135°)
- ✅ Glass effects look realistic (blur, transparency, border)
- ✅ No pixelation or artifacts
- ✅ Colors match specification

### Technical Quality
- ✅ File is exactly 1024x1024px
- ✅ File is PNG format
- ✅ Color profile is sRGB
- ✅ No transparency (solid background)
- ✅ File size is reasonable (< 500KB)

### Design Quality
- ✅ Icon is recognizable at 1024x1024
- ✅ "L" shape is clear
- ✅ Glass morphism effect is visible
- ✅ Differentiation from competitors
- ✅ Matches Liquid Glass UI aesthetic

## Delivery

### Primary Deliverable

**File**: AppIcon-1024.png
**Location**: Deliver via file transfer (WeTransfer, Dropbox, Google Drive)
**Format**: PNG-24, sRGB, 1024x1024px

### Optional Deliverables

- Source file (Figma/Sketch/Illustrator) for future edits
- Dark mode variant (if created)
- Icon preview mockups (showing icon on iPhone, iPad, Mac)

### Next Steps (After Design)

1. **Review**: Client reviews icon and requests revisions if needed
2. **Generate Variants**: If needed, create explicit sizes for small icons (16x16, 29x29, etc.)
3. **Implementation**: Add icon to Xcode project Assets.xcassets/AppIcon
4. **Testing**: Test icon on actual devices (iPhone, iPad, Mac)

## Questions?

If you have any questions about:
- Design specifications
- Tool-specific workflows
- Glass morphism effects
- Export settings
- Anything else

Please reach out before starting work to avoid misinterpretation.

---

**Designer Brief Version**: 1.0
**Last Updated**: 2026-01-06
**Related Documents**:
- `app-icon-design-concept.md` (full design specifications)
- `app-icon-visual-reference.md` (annotated visual reference)
- `app-icon-implementation-guide.md` (Xcode integration instructions)
