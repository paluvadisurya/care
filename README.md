<p align="center">
  <img src="docs/icon/icon-pair.png" width="360" alt="Care app icon, light and dark">
</p>

<h1 align="center">Care</h1>

<p align="center"><strong>The people you love, finally in one place.</strong><br>
An iOS 27 app that turns looking after people into a ten-second habit. One profile per person, built from modules, with intelligence that remembers, notices and nudges for you.</p>

<p align="center">
  <img src="docs/hero.png" alt="Three Care screens: Srivalli's profile, Today, and a night-mode insight">
</p>

---

## What this is

Care is the Phase 0 build of the product described in [`SPEC.html`](SPEC.html): single user, fully local, no account. It is a complete, modular SwiftUI codebase for iOS 27 with a real design system, fourteen working modules, an insight engine that runs on device and switches to OpenAI or DeepSeek the moment you paste a key, a reminder planner, and a demo circle so the app is alive on first launch.

- **Four tabs.** Today, People, Timeline, You. Insights are not a tab; they live inside Today and inside every person, already rendered when you arrive.
- **Modules you switch on.** Mood, Health, Hydration, Mentions, Events, Milestones and dates, Travel plans, Shared checklist, Promises, Call rhythm, Medication, Appointments, Wishlist, and a new **Pet care** module for the dog. Eight more exist as store cards with tier labels for later.
- **One Home across everyone.** A deterministic ranker picks the one thing that needs you, then the orbs, then a bento of what is due.
- **Insights that render, not read.** The model answers only in typed blocks: headline, stat, trend, countdown, list, action, insight, mood strip, talking points, compare, note. Without a key, an on-device engine writes the same blocks from your own numbers.
- **Push with a reason.** Every reminder names a person, a reason and one action. Daily cap, quiet hours, medication exempt and time-sensitive.
- **Private by default.** Local SwiftData store. Keys in the Keychain. Export is one JSON file you own.

## Screens

These are **design renders** of the shipped SwiftUI screens, produced from the same fonts, tokens, copy and demo data the app uses, at iPhone 17 Pro size. They are not simulator captures: this build was written on a Linux machine with no Xcode, so the first real screenshots come from your Mac (see *Running it*). The renders exist so you can judge the design now.

They also earn their keep. Reading these back as pictures is what caught the floating action sitting behind the tab bar, a badge row pushing a two-column grid off the screen, and a seam where the aura wash began. Each render mirrors one token file, so a change to the design system shows up here the same way it shows up on device. `docs/DESIGN-AUDIT.md` lists all fifteen findings and what each one changed.

The demo circle is the one you gave me: **Surya** (you), **Srivalli** (partner, married 26 August 2026), **Ramarao** (father, BP patient and pre-diabetic), **Kasi Annapurna** (mother, on BP medication, Sunday calls), **Neeraj** (brother) and **Oreo** (Shih Tzu). Birthdays, cities, doctors and medicine names in the demo are placeholders to edit in the app.

| Today | Srivalli | Ramarao |
|---|---|---|
| ![Today](docs/screens/01-today.png) | ![Srivalli](docs/screens/02-person-srivalli.png) | ![Ramarao](docs/screens/03-person-ramarao.png) |
| The hero is Dad's missed 8 am Telmisartan. Every orb in the app comes from one rail component: same reserved width, same label treatment, attention dots that cannot clip. | Her colour washes the whole top of the screen, behind the rail and under the status bar, then fades as you scroll. Swipe left or right to change person and the content enters from the side you came from. | Medication and a BP reading above range both raise attention. The insight names the pattern (Wednesdays) without diagnosing anything. |

| Medication | Timeline | Quick check-in |
|---|---|---|
| ![Medication](docs/screens/04-medication-ramarao.png) | ![Timeline](docs/screens/05-timeline.png) | ![Quick sheet](docs/screens/06-quick-sheet.png) |
| Today's slots with Taken and Skip, adherence rings for 7 and 30 days, refill lead times. A module screen is pushed inside its tab, so the action clears the tab bar rather than hiding behind it. | Everyone's day on one rail, coloured by aura, with a live now marker and source labels. | A detent sheet over the screen it came from. One drag sets mood, chips wrap rather than truncate, one line captures a mention. |

| Insight, night mode | Module store | You and intelligence |
|---|---|---|
| ![Insight night](docs/screens/07-insight-night.png) | ![Store](docs/screens/08-module-store.png) | ![You](docs/screens/09-you-intelligence.png) |
| Every block type in one card: stats, mood strip, insight, list, countdown, action, evidence line. The three stats land on one baseline however long their labels run. | Every module as a card with its tier badges, per person toggles, category chips. Badges wrap onto a second line instead of squeezing. | Provider choice, key into the Keychain, editable model ids, a connection test, reminder controls. |

| Pet care, Oreo | Evening wrap | Onboarding |
|---|---|---|
| ![Pet care](docs/screens/10-petcare-oreo.png) | ![Evening wrap](docs/screens/11-evening-wrap.png) | ![Onboarding](docs/screens/12-onboarding.png) |
| Due dates for food, tick treatment, vet, grooming, deworming and vaccines, plus a weight trend. | Three questions about the people you saw today. Each answer is one tap. | One headline, two buttons. Start local, or load the demo circle. |

## Running it

You need a Mac with **Xcode 27** and an iPhone or simulator on **iOS 27**.

```bash
git clone https://github.com/paluvadisurya/care.git
cd care
open Care.xcodeproj
```

1. Select the **Care** scheme and a simulator, press Run.
2. On first launch choose **Try it with a demo circle** to see everything populated, or **Start on this device** to add your own people.
3. To run the logic tests without Xcode: `cd Packages && CARE_PURE=1 swift test` (on Linux plain `swift test`). They cover ranking, the event taxonomy, payload round-trips, the insight contract and validator, the local engine, and reminder guardrails.

If Xcode refuses the hand-built project file, `brew install xcodegen && xcodegen generate` recreates it from `project.yml`. Set your team under Signing before running on a device.

**Build status.** [![CI](https://github.com/paluvadisurya/care/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/paluvadisurya/care/actions/workflows/ci.yml) The whole app builds for the iOS Simulator on GitHub's macOS runner with Xcode 26.6, and the 36 logic tests pass on Swift 6.2 on Linux. The code was written on a Linux machine without Xcode and checked against Apple's exported Xcode 27 agent skills (`swiftui-whats-new-27`, `swiftui-specialist`), then compiled and fixed through CI. Nobody has tapped through it on a device yet: expect small layout and behaviour fixes on your first run, not a broken build.

**iOS 26 and 27.** The deployment target is iOS 26 so the project builds with today's runners and phones. Two iOS 27 additions (swipe actions in scroll views, the minimising navigation bar) sit behind a `CARE_SDK27` compilation condition in [`Compat.swift`](Packages/Sources/CareDesign/Motion/Compat.swift). On Xcode 27, add `-DCARE_SDK27` to Other Swift Flags and they light up on iOS 27.

## Bringing a model

Open **You › Intelligence**, pick OpenAI or DeepSeek, paste the key, tap Save, then **Test connection**. The key is stored in the Keychain and never leaves the device except in the request to that vendor. Model ids are editable; defaults are `gpt-5.6-luna` / `gpt-5.6-terra` for OpenAI and `deepseek-chat` / `deepseek-reasoner` for DeepSeek. Toggle **Use the model** off to stay on device even with a key.

What the model receives is compact: first names, module summaries, counts and dates, never photos, never free text longer than 140 characters per item. The system prompt is in [`PromptLibrary.swift`](Packages/Sources/CareIntelligence/Prompts/PromptLibrary.swift) and the strict schema in [`InsightSchema.swift`](Packages/Sources/CareIntelligence/Contract/InsightSchema.swift).

## Structure

```
Care.xcodeproj            Xcode project (synchronised folder for Care/). Config/Info.plist holds the URL scheme.
Care/                     App target: entry, router, Today, People, Timeline, You, store, onboarding, evening wrap.
Packages/                 One Swift package, seven modules (see docs/ARCHITECTURE.md).
  Sources/CareCore        Pure Swift. Records, module logic, ranking, deep links, taxonomy.
  Sources/CareIntelligence Pure Swift. Contract, schema, prompts, providers, validator, local engine.
  Sources/CareReminders   Pure Swift. Planner, guardrails, notification categories.
  Sources/CareFixtures    Pure Swift. The demo circle.
  Sources/CareDesign      SwiftUI design system: tokens, fonts, motion, components.
  Sources/CareData        SwiftData models, the store, preferences, insight coordinator, scheduler.
  Sources/CareModules     Module screens, quick logs, tiles, the insight block renderer.
  Tests/                  Swift Testing suites for the pure modules.
design/                   Icon source (SVG) and the screen render sources (build.py + CSS on the same tokens).
scripts/                  Playwright renderers for the icon, the screens and the README hero.
docs/                     Architecture notes, rendered screens, icon previews.
SPEC.html                 The product and build spec, version 2. Source of truth.
```

Read [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for how a module is built (two files and two registry lines), how ranking works, and how the intelligence pipeline validates what the model returns.

## Changing the look

- **Tokens**: [`CareColor.swift`](Packages/Sources/CareDesign/Tokens/CareColor.swift), [`CareFont.swift`](Packages/Sources/CareDesign/Tokens/CareFont.swift), [`CareSpace.swift`](Packages/Sources/CareDesign/Tokens/CareSpace.swift), [`CareMotion.swift`](Packages/Sources/CareDesign/Motion/CareMotion.swift). Colours are asset-catalogue tokens with light and night variants.
- **Onboarding**: [`OnboardingView.swift`](Care/Features/Onboarding/OnboardingView.swift). Three steps, each its own view.
- **Home**: [`TodayView.swift`](Care/Features/Today/TodayView.swift). The hero, orbs, bento and insight are separate sections.
- **A person**: [`PeopleView.swift`](Care/Features/People/PeopleView.swift) plus [`AuraHeader.swift`](Packages/Sources/CareDesign/Components/AuraHeader.swift).
- **Type**: [`CareType.swift`](Packages/Sources/CareDesign/Tokens/CareType.swift) holds twenty semantic roles. Text picks a role, never a size, and the role carries family, tracking, line limit and figure style together. Bricolage Grotesque for headlines and numerals, Geist for everything you read, Instrument Serif italic for one accent word per screen, and Geist Mono strictly for values a machine produced. All SIL Open Font License, bundled in `CareDesign/Resources/Fonts` with their licences.
- **Components**: every repeated pattern has one implementation, so a change lands once. [`OrbRail`](Packages/Sources/CareDesign/Components/OrbRail.swift) for any row of people, [`CareSurface`](Packages/Sources/CareDesign/Components/CareSurface.swift) for any card, [`BentoTile`](Packages/Sources/CareDesign/Components/BentoTile.swift) for any grid tile, [`CareTag`](Packages/Sources/CareDesign/Components/CareTag.swift) for any badge, [`FlowLayout`](Packages/Sources/CareDesign/Components/FlowLayout.swift) for any row that has to wrap.
- **Renders**: `design/screens/build.py` generates the screenshots above from the same token values. Regenerate with `python3 design/screens/build.py && node scripts/render-screens.mjs && node scripts/render-hero.mjs`.

## Roadmap seams already in the code

Contacts and Calendar import, Photos trips, HealthKit water, WeatherKit talking points, widgets, Live Activities, Siri intents, CloudKit sharing and the paywall each have a place to plug in: `importers` on `ModuleLogic`, `TimelineItem.source`, `NotificationCategorySpec`, and `EntitlementService.isUnlocked` (always true today). Sections 09 to 12 of the spec hold the plan and the prompt library for each milestone.

## Licence

Code: MIT. Fonts: SIL Open Font License 1.1, see `Packages/Sources/CareDesign/Resources/Fonts/Licenses`.
