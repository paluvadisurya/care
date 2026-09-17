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

## Principles the system now enforces

1. **Roles, not values.** Text picks a type role, a surface picks an elevation, an orb picks a size role. No raw numbers in screens.
2. **One component per repeated pattern.** If it appears twice, it is a component. Orb rows, section headers, tiles, rows, sheets and state views each have exactly one implementation.
3. **Reserve, then draw.** Components reserve space for their ornaments (rings, dots, shadows) so nothing clips and neighbours stay aligned.
4. **Scale with content.** Heights derive from type size. Nothing that holds text is pinned.
5. **Motion explains cause.** Every animation connects an action to its result. Decorative motion is cut.
6. **Spend boldness once.** One hero, one accent word, one glow per screen. Everything else is quiet.
