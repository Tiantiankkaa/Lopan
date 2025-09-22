# Repository Guidelines

## Project Structure & Module Organization
Primary application code lives in `Lopan/`. Feature views live under `Views/`, with observable logic in `ViewModels/`, business rules in `UseCases/`, and data contracts in `Models/`. Data fetching resides in `Repository/` and `Services/`, while cross-cutting helpers are in `Utils/` and `Extensions/`. Dependency setup is managed through the factories in `DependencyInjection/` (see `AppDependencies.swift` and `SafeLazyDependencyContainer.swift`). Assets are stored in `Assets.xcassets`, localization strings in `en.lproj` and `zh-Hans.lproj`, and configuration/privacy artifacts in `Configuration/`. Product docs and flow references live in `Documentation/` and `Examples/`. Unit and snapshot resources are in `LopanTests/`; UI automation lives in `LopanUITests/`.

## Build, Test, and Development Commands
Use `open Lopan.xcodeproj` to launch the workspace in Xcode. For a clean simulator build, run `xcodebuild -scheme Lopan -configuration Debug -sdk iphonesimulator build`. Execute unit and UI tests with `xcodebuild test -scheme Lopan -destination 'platform=iOS Simulator,name=iPhone 15'`. Archive releases via `xcodebuild -scheme Lopan -configuration Release archive`. Keep Derived Data trimmed with `xcodebuild -scheme Lopan clean` after large refactors.

## Coding Style & Naming Conventions
Follow Swift API Design Guidelines with four-space indentation and 120-character soft limits. Types adopt `PascalCase`, functions and stored properties use `camelCase`, and constants add a leading `k` only when mirroring system APIs. Match file names to the primary type (e.g., `InventoryDashboardView.swift`, `InventoryDashboardViewModel.swift`). Prefer protocol-first designs; add new protocols to `DependencyProtocols.swift` and register implementations in `AppDependencies.swift`. Use `// MARK:` sections to separate lifecycle, view composition, and bindings. Opt into async/await over completion closures when touching `Services/`.

## Testing Guidelines
Tests use XCTest. Name methods `test_<UnitUnderTest>_<Condition>_<Expectation>` to align with the existing suites. Place stubs or fixtures beside the test that uses them and share only through `LopanTests/Support` if they cross modules. Maintain 80% minimum coverage for new features; add UI coverage for critical flows using `LopanUITests/`. Before pushing, run the full test command above on the latest simulator runtime.

## Commit & Pull Request Guidelines
Follow the lightweight Conventional Commits pattern observed in history (`fix:`, `perf:`, `docs:`). Keep subject lines in the imperative mood and under 60 characters, elaborating in the body when context is non-obvious. Each pull request should describe scope, include screenshots for UI-facing work, and link to the relevant Linear or GitHub issue. Request review from the module owner (Views, Data, or Platform) and wait for CI green builds before merging.
