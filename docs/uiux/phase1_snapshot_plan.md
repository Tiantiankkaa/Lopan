# Phase 1 Snapshot & UI Test Plan

Snapshot/UI automation will land once the shared harness is configured. This document captures the scenarios we will encode.

## Snapshot Targets
- Batch Processing (light/dark, zh-Hans/en, Dynamic Type Large & Accessibility XL)
- Batch Creation (machine selector visible, conflict alert, cache debug overlay hidden)
- Batch Management (pending list, history list, review sheet)
- Warehouse Keeper TabView (each tab, quick action sheet)

## UI Flow Tests (XCTest UI)
1. Batch creation happy path: select machine → add product → create batch.
2. Batch review reject: open pending batch → reject with notes → confirm dialog.
3. Warehouse quick actions: open menu → select “Refresh Data” → ensure sheet dismisses.

Each test will run against iPhone 17 Pro Max iOS 26, with zh-Hans and en variants. Add more locales once automation is in place.

