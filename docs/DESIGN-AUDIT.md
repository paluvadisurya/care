# Design audit

An audit of the first build, the reasoning behind the changes, and what the design system now guarantees.

## What was already right

Worth naming, because it was kept: the aura idea (one gradient per person, carried from orb to header to notification), the semantic colour roles (coral attention, violet intelligence, mint done, amber upcoming), one hero per screen, the four-font pairing, and the module architecture that lets Today and People compose themselves from whatever modules are switched on. None of that changed.

## What was wrong

### 1. Repeated patterns were hand-built each time

Circular profile elements appeared in six places (Today, People, the store, the quick sheet, onboarding, module screens) and every one was assembled by hand. Seven different diameters were passed at call sites: 22, 38, 40, 44, 52, 56 and an animated 44 to 58. The component then added an invisible 8 pt to its own frame, so callers could not predict where the circle would actually sit.

The visible consequence: on Today the first name under the first orb was clipped to "rivalli", because the rail had no content margins and labels could exceed the item width. Selection rings and attention dots were positioned with `offset(x: 2, y: -2)`, a magic pair that clipped against scroll view edges.

**Fix.** `PersonOrb` now takes a size *role*, not a number. One `OrbRail` component renders every orb row in the app: fixed item width, single-line labels that truncate instead of clipping, content margins that reserve space for rings and dots, and view-aligned scroll snapping.

### 2. Typography had no ramp

Twenty distinct font sizes were called ad hoc: 44, 40, 38, 36, 34, 32, 28, 27, 26, 22, 21, 20, 19, 17, 15, 13, 12, 11. Tracking was applied with `displayTracking(22)`, a literal repeat of whatever size the text happened to be, so any size change silently desynchronised the letter spacing. Truncation rules were per call site, which is why one tile read "Every Sunday" at full size next to another squeezed to 70 percent.

**Fix.** `CareType` defines eighteen semantic roles. A role carries its family, size, tracking ratio, line limit, minimum scale factor and figure style together, and tracking scales with Dynamic Type. Text picks a role, never a size.

### 3. Layout numbers were scattered

Sixty-two hard-coded frame, padding and offset values sat in the view layer, including eleven fixed `minHeight` values. A tile pinned at 108 pt tall breaks the moment someone raises text size; a timeline time column pinned at 52 pt wide clips at accessibility sizes.

**Fix.** `CareLayout` holds every layout metric. Component heights use `@ScaledMetric`, so they grow with the text inside them rather than trapping it.

### 4. Tiles did not hold a rhythm

`BentoTile` allowed the value line two lines with a 0.7 minimum scale and let the detail line wrap twice. Adjacent tiles in a grid row therefore rendered at different optical weights and different heights, and a long module name ("Milestones and dates") pushed its own content down while its neighbour stayed put.

**Fix.** Tiles use a fixed three-zone grid, a single scaled minimum height, and a shared height preference so every tile in a row matches its tallest sibling. Long values scale within one line instead of wrapping.

### 5. Motion was declared but not wired

The motion tokens existed and were correct. What was missing was choreography: no zoom transition from a tile into its detail screen (the spec asked for it), tab changes were a plain cross-fade with no sense of direction, and sections appeared all at once.

**Fix.** Tiles and cards use `matchedTransitionSource` with a zoom navigation transition. Tab changes move content in the direction of travel. Today's sections enter on an 80 ms stagger. Rings fill with an overshoot, numbers roll, and every completed action lands a haptic that matches its meaning.

### 6. Accessibility gaps

Chips were 34 pt tall against a 44 pt minimum. Fixed heights capped Dynamic Type. Several icon-only controls had no label. Glass surfaces had no Reduce Transparency path in some components.

**Fix.** Every interactive surface reserves a 44 pt target even when it draws smaller. Heights scale. Labels are required by the component signatures rather than optional.

## Second pass: what the renders showed

The fixes above were made by reading the code. Then the screens were rendered and read back as pictures, which surfaced a different class of problem: things that are correct per component and wrong once assembled.

### 7. Mono was doing a job it is bad at

Geist Mono is for values a machine produced. It was also carrying people's names under the orbs, the five words under the mood scale, and eight explanatory paragraphs. A name set in 11 pt monospace reads as terminal output, and a paragraph set in it reads as a log line.

**Fix.** Two roles took that work: `itemLabel` for a short name or word beneath a circular item or a scale tick, and `footnote` for an explanatory paragraph. `CareType` now documents mono as times, counts, model names and key status only, and nothing else uses it.

### 8. A stat row that did not hold one baseline

Three stats in an insight put their label at the top and their value below. When one label wrapped to two lines, its value dropped with it while its neighbours stayed put, and three readings read as three loose readouts rather than one instrument.

**Fix.** The label sits at the top, the value is pinned to the bottom, and the tile stretches to the row height. Every value in a row lands on one baseline whatever the labels do.

### 9. The same number printed twice

Three places drew a ring with a percentage inside it and the same percentage again beside it. A ring at zero drew an empty circle labelled "0%" next to a headline that already said the state.

**Fix.** `Ring` gained a bare variant with an empty centre for when the number is already written beside it, and tiles draw the ring only once there is progress to show.

### 10. The aura wash began with a hard edge

The wash was a background on the person header, which sits below the orb rail. It therefore started partway down the screen with a visible horizontal seam.

**Fix.** `AuraWash` is a screen layer drawn from the top edge, behind the rail and under the status bar, fading as the header collapses.

### 11. The floating action sat behind the tab bar

A module screen is pushed inside a tab, so the tab bar stays on screen. The module scaffold pinned its action twelve points from the bottom, directly behind it.

**Fix.** `CareLayout.actionBarBottom` places the action above the bar, and the scroll inset is derived from that position plus the action height rather than a guessed constant.

### 12. Rows of badges could not wrap

A row of three tier badges inside a grid column had one answer when it did not fit: truncate. It also reported a minimum width that pushed its column wider than its share, which is enough to push a two column grid off the screen.

**Fix.** `FlowLayout` wraps. The store's badges and the quick check-in's symptom chips use it, so they stay readable at any Dynamic Type size and in any language.

### 13. Muted text failed contrast

`textMuted` measured 3.13:1 on light and 3.78:1 on night, against a 4.5:1 minimum for small text. Captions, footnotes and timestamps were decorative rather than readable.

**Fix.** 4.68:1 and 5.95:1.

### 14. One module looked like two things

The store drew each module as an emoji while every other surface drew the same module as a tinted SF Symbol.

**Fix.** `GlyphTile` is the one component for a symbol in its rounded square, with a tinted fill and an aura fill. The store, every card row and the onboarding cards use it.

### 15. Three hand-built capsule badges

A tier badge, a timeline status label and a refill marker were three implementations of the same seven-by-three capsule, and two of them had already drifted a point apart.

**Fix.** `CareTag` with five tones. `careChipSurface()` does the same for anything that has to look like a chip without being one.

## Principles the system now enforces

1. **Roles, not values.** Text picks a type role, a surface picks an elevation, an orb picks a size role. No raw numbers in screens.
2. **One component per repeated pattern.** If it appears twice, it is a component. Orb rows, section headers, tiles, rows, sheets and state views each have exactly one implementation.
3. **Reserve, then draw.** Components reserve space for their ornaments (rings, dots, shadows) so nothing clips and neighbours stay aligned.
4. **Scale with content.** Heights derive from type size. Nothing that holds text is pinned.
5. **Motion explains cause.** Every animation connects an action to its result. Decorative motion is cut.
6. **Spend boldness once.** One hero, one accent word, one glow per screen. Everything else is quiet.
