---
name: implement-story
description: Implements one URBNFlicks requirement story as the smallest slice with unit tests, a screenshot, and Done only after verification. Use when implementing a story, epic row, acceptance criteria, or work from Requirements/.
---

# Implement a story

No architecture spike. Implement the one requested story (or the next required story) and stop.

## Steps

1. **Read the row.** Open the epic file under `Requirements/` and read the single story row.
2. **Restate acceptance.** Quote the story text and list what “done” means before writing code.
3. **Smallest slice.** Change only what that story needs. Top Movies stays UIKit; all new work is SwiftUI. No 3rd-party dependencies.
4. **Unit tests.** Add tests for the completed work. Run `xcodebuild test -scheme URBNFlicks -only-testing:URBNFlicksTests`.
5. **Screenshot.** Capture the affected screen (`xcrun simctl io booted screenshot`). Use the `visual-qa` skill when comparing to comps.
6. **Tick Done.** Only after tests pass and the visual check is done: tick the story `Done` box and update the progress table in `Requirements/README.md`.
