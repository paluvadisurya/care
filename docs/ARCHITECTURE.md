# Architecture

Care is one Xcode app target plus one Swift package with seven modules. Every module has one job and an explicit dependency direction, so a new feature lands in one place.

```
Care/                          App target. Tabs, router, onboarding, screens. Imports everything below.
Packages/Sources/
  CareCore/                    Pure Swift. Records, module logic, taxonomy, ranking, deep links.
  CareIntelligence/            Pure Swift. Insight contract, JSON schema, prompts, OpenAI + DeepSeek providers,
                               validator, on-device rule engine, context builder.
  CareReminders/               Pure Swift. Reminder planner, guardrails, notification categories.
  CareFixtures/                Pure Swift. The demo circle used by previews, tests and screenshots.
  CareDesign/                  SwiftUI. Tokens, fonts, motion, every reusable component.
  CareData/                    SwiftData models, the observable store, preferences, insight coordinator, scheduler.
  CareModules/                 SwiftUI. The visual half of every module, the insight block renderer, quick sheet.
```

Dependency direction: `CareCore ← CareIntelligence ← CareReminders`, `CareCore ← CareDesign`, `CareCore + CareIntelligence + CareFixtures ← CareData`, `CareDesign + CareData ← CareModules`, everything `← Care`.

The four pure targets contain no Apple UI frameworks, so `swift test` runs on Linux (and on a Mac with `CARE_PURE=1`) without Xcode. That is where the logic lives and where the tests are. CI builds the app with Xcode on a macOS runner and runs the tests on Linux.

## A module is two types

Every module is a `ModuleID` case plus:

1. **Logic** in `CareCore/Modules/<Name>Logic.swift`, conforming to `ModuleLogic`. Pure functions over records: the payload type, today's state for the tile, the signals it raises for Home, the context pack the model reads, the reminder candidates, and its timeline items. Registered in `ModuleRegistry.standard`.
2. **UI** in `CareModules/Modules/<Name>UI.swift`, conforming to `ModuleUI`. The tile (default provided), the one-gesture quick log sheet, and the detail screen. Registered in `ModuleUIRegistry.all`.

The catalogue entry (`ModuleCatalog`) carries name, symbol, category, tier, defaults per relationship and the two human lines the store shows. Modules that exist only as store cards set `isImplemented: false`.

Adding a module means: one logic file, one UI file, one catalogue entry, two registry lines. Today, People, Timeline, the store and the insight engine pick it up without changes.

## Records, not models, above the store

SwiftData `@Model` classes live only in `CareData/Models.swift`. Everything else works with value types (`PersonRecord`, `EntryRecord`, `EventRecord`, `InsightRecord`). `CareStore` loads all rows into memory on launch (Phase 0 is one household), writes through on every change, and exposes the arrays to views. Engines and tests never see SwiftData.

Entries carry a module-owned JSON payload. Adding a field to a payload never touches the shared schema. All ids are UUIDs, timestamps are set on write, deletes are soft, so CloudKit can be switched on later without a migration.

## Home ranking

Each enabled module for each person emits `Signal`s with a base priority, a time, a tone and a hero presentation. `HomeRanker.score` adds time pressure, a health weight and a neglect term, deterministically. The top signal with a presentation becomes the hero card; the next four distinct person-module pairs become the bento. The model never ranks; it only writes words.

## Intelligence

```
records → ModuleLogic.contextPack → ScopeContext → PromptLibrary → LLMProvider → Insight (typed blocks)
                                                                  ↘ LocalInsightEngine (no key, or offline)
                                                       → InsightValidator → InsightCoordinator → CareStore
```

- The model returns only the `care_insight` JSON contract: headline, tone, up to seven typed blocks, optional reminders, an evidence line. Unknown block types are dropped, not crashed on.
- `OpenAIProvider` uses the Responses API with a strict JSON schema. `DeepSeekProvider` uses the OpenAI-compatible chat API in JSON mode with the schema embedded in the system prompt. Both are behind `LLMProvider`; adding a vendor is one file.
- `InsightValidator` enforces the rules the prompt states: one action, allowed modules only, no clinical terms, reminders outside quiet hours and within seven days, note last.
- `LocalInsightEngine` writes a plain, numeric insight from the same packs when there is no key. The app is useful offline and the demo profile renders something real.
- Cache: 24 hours, skipped entirely when the input hash has not changed. Manual refresh has a one-hour cooldown. Failures keep the previous insight and add a small note.
- Keys live in the Keychain (`KeychainSecretStore`). Nothing is logged.

## Reminders

`ReminderPlanner` asks every module for candidates, then `Guardrails` applies the daily cap, quiet hours, dedupe, priority decay for ignored kinds, the away state from Travel plans, and keeps health detail out of lock-screen previews. Medication is time-sensitive and exempt from the cap. `ReminderScheduler` turns the plan into `UNCalendarNotificationTrigger` requests with one category per module, so an answer never needs the app to open.

## Design system

`CareDesign` owns the look, and it owns it exclusively: the escape hatches were deleted, so a screen that tries to invent a size, a font or a shadow does not compile.

**Tokens.** `CareType` holds twenty semantic text roles; a role carries family, size, tracking ratio, line limit, minimum scale factor and figure style together, and its tracking scales with Dynamic Type. `CareSpace` and `CareLayout` hold every spacing and layout metric, including where the tab bar sits and therefore where a floating action has to sit to clear it. `CareRadius` follows the concentric rule. `CareElevation` resolves its own shadow per colour scheme so no call site checks the appearance. All four are `nonisolated`, because a constant should be readable from anywhere, including from a `Layout`.

**Type discipline.** Four families, each with one job. Bricolage Grotesque for headlines and numerals, Geist for everything you read, Instrument Serif italic for exactly one accent word per screen, and Geist Mono for values a machine produced: times, counts, model names, key status. Never a sentence, never a person's name.

**Components.** Every repeated pattern has exactly one implementation. `PersonOrb` takes a size role and reserves the space its selection ring and attention dot need, so ornaments never clip. `OrbRail` renders every row of people in the app. `CareSurface` has seven variants. `BentoTile`, `AddTile` and `BentoGrid` keep a grid even. `CareTag` is the one capsule badge, `GlyphTile` the one symbol square, `FlowLayout` the one row that wraps instead of truncating.

**Motion.** Standard 0.35/0.15, snappy 0.25/0, expressive 0.5/0.3, 0.96 press scale, 60 ms block stagger, all replaced by a 200 ms ease under Reduce Motion. Tiles zoom into their detail screen through an environment-scoped namespace. Tab changes move in the direction of travel. Glass chrome uses Liquid Glass inside a `GlassEffectContainer`; Reduce Transparency swaps it for solid surfaces.

**Accessibility.** Every interactive surface reserves a 44 pt target even when it draws smaller. Component heights come from `@ScaledMetric`, so they grow with the text inside them. Text colours clear WCAG AA in both appearances.

`docs/DESIGN-AUDIT.md` records what was wrong before each of these existed, and what the renders showed once they did.

## What is deliberately not here yet

EventKit, Contacts, Photos, HealthKit, WeatherKit, widgets, Live Activities, App Intents, CloudKit and the paywall. Each has a seam already: importers on `ModuleLogic`, `EntitlementService.isUnlocked`, the notification categories, the `TimelineItem.source` labels. See `SPEC.html` sections 09 to 12 for the plan.
