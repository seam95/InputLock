# Repository Guidelines

## Project Structure & Module Organization
- `InputLock/InputLock/` is the macOS app target.
  - `AppState/`: app state composition and feature wiring.
  - `Managers/`: domain/application services (input method, clipboard, quick phrase).
  - `System/`: platform adapters and external system integrations.
  - `Models/`: core value types and model objects.
  - `Views/`: SwiftUI UI components and screens.
  - `Resources/{en.lproj,zh-Hans.lproj}`: localization resources.
- `InputLock/InputLockTests/` contains XCTest-based unit/integration tests, organized by feature area.
- `InputLock/InputLockUITests/` contains UI and launch smoke tests.
- `docs/` stores product/design references and execution plans.
- `tools/` stores repository helper scripts.

## Build, Test, and Development Commands
- `open InputLock/InputLock.xcodeproj` — open the project in Xcode.
- `xcodebuild -project InputLock/InputLock.xcodeproj -scheme InputLock -destination 'platform=macOS' build` — build app target from CLI.
- `xcodebuild -project InputLock/InputLock.xcodeproj -scheme InputLock -destination 'platform=macOS' test` — run all unit and UI tests.
- `xcodebuild -project InputLock/InputLock.xcodeproj -scheme InputLock -destination 'platform=macOS' -only-testing:InputLockTests/ClipboardHistoryManagerTests test` — run a focused test suite quickly.

## Coding Style & Naming Conventions
- Use Swift + Xcode default formatting with 4-space indentation.
- Use `UpperCamelCase` for types/protocols and `lowerCamelCase` for properties/functions.
- Keep file names aligned with roles (for example: `Managers/*Manager.swift`, `System/*Client.swift`).
- Prefer small, single-responsibility types; inject dependencies for testability.
- Apply DRY/KISS/YAGNI: avoid duplicate logic across `Managers/` and `System/`.

## Testing Guidelines
- Testing framework: XCTest (`InputLockTests`, `InputLockUITests`).
- Name test files with `*Tests.swift`; name test methods to describe behavior and outcome.
- Add or update tests with every behavior change, prioritizing manager/system-level regression coverage.

## Commit & Pull Request Guidelines
- Existing history mixes short Chinese commits and Conventional-Commit-style prefixes (`chore:`). Prefer consistent prefixes: `feat:`, `fix:`, `chore:`.
- Keep commits scoped to one concern; include related tests in the same commit.
- PRs should include: concise summary, changed modules/paths, executed test commands, and screenshots for UI/menu bar changes.

## Security & Configuration Tips
- Do not commit machine-local artifacts (for example `.DS_Store`) or user-specific runtime data.
- Keep configuration non-secret; avoid hardcoded sensitive values.
- Re-verify permission-sensitive flows (Accessibility, Input Monitoring) before release.
