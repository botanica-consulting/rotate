# InsulinPumpSiteJournal

A small native iOS app that keeps a local journal of Omnipod pump-site placements,
suggests four rotation sites when you start a new Pod (least-recently-used, region-diverse),
saves your choice, and reminds you to continue Pod activation in [Loop](https://github.com/LoopKit/Loop).

This MVP is a polished UI/UX prototype: it has **no** Loop integration, pump communication,
networking, accounts, HealthKit, or CloudKit. Data is stored locally with SwiftData and stays
eligible for your normal encrypted iPhone backup.

> **Not a medical device.** Follow your Omnipod training and the
> [Omnipod placement guide](https://www.omnipod.com/current-podders/resources/pod-placement-guide)
> for approved placement details.

## Requirements

- Xcode 26 (iOS 26 SDK — the UI uses native Liquid Glass APIs)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

## Setup

```sh
xcodegen generate
open InsulinPumpSiteJournal.xcodeproj
```

The `.xcodeproj` and `Info.plist` are generated from `project.yml` and are not committed.

## Build & test (CLI)

```sh
xcodebuild -project InsulinPumpSiteJournal.xcodeproj \
  -scheme InsulinPumpSiteJournal \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build

xcodebuild ... test -only-testing:InsulinPumpSiteJournalTests
xcodebuild ... test -only-testing:InsulinPumpSiteJournalUITests
```

## iCloud sync

The SwiftData store mirrors to the user's private CloudKit database
(`iCloud.io.github.0xa10.InsulinPumpSiteJournal`). Sync is account-scoped and
automatic — no account means the app simply stays local until one appears.
CloudKit's silent pushes (the `remote-notification` background mode) pull in
changes made on other devices. Building requires a development team with the
iCloud capability; with automatic signing, Xcode provisions the container on
first build.

## Structure

- `Models/` — `PlacementRecord` (SwiftData) and the compile-time `PumpSite` catalog (12 sites)
- `Services/SiteSuggestionEngine.swift` — deterministic LRU + region-diversity picker
- `Views/` — history home, new-Pod flow (suggestions → confirm → Loop handoff), body silhouettes
- `Design/AppTheme.swift` — Loop's palette (systemBlue accent, insulin orange for recent history), rounded type
