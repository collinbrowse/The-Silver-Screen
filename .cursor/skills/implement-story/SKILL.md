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
4. **Unit tests.** Add tests for the completed work under `URBNFlicksTests/`.
   - Use `FakeHTTPClient` and `TMDBFixtures` from `URBNFlicksTests/Support/` — do not invent a repository protocol or call TMDB.
   - Every `func test...` must assert something. Empty bodies and `testExample` / `testPerformanceExample` are banned (`scripts/validate-tests.py`).
   - Run `xcodebuild test -scheme URBNFlicks -only-testing:URBNFlicksTests`.
5. **Screenshot.** Capture the affected screen (`xcrun simctl io booted screenshot`). Use the `visual-qa` skill when comparing to comps. Record the screenshot path in the PR.
6. **Gates.** Run before claiming Done:
   ```bash
   python3 scripts/validate-rules.py
   BASE_SHA=origin/main python3 scripts/validate-tests.py
   ```
7. **Tick Done.** Only after tests pass **and** the visual check is done: tick the story `Done` box and update the progress table in `Requirements/README.md`. CI fails if you check Done without changing `URBNFlicksTests/`.
8. **Commit size.** When the user asks to commit or open a PR, keep this story (and any required foundation slice) as its own reviewable commit(s) — not one dump for the whole epic. See [`.cursor/rules/commits.mdc`](.cursor/rules/commits.mdc).
