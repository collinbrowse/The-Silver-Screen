# URBNFlicks — agent contract

This file is the source of truth for the assessment constraints. Follow them. Architecture conventions live in [`.cursor/rules/architecture.mdc`](.cursor/rules/architecture.mdc) and the scoped rules beside it. Do not add optional epic recommendations beyond what Nuuly already wrote.

## Required work (in order)

Only the following is required. Everything else in [`Requirements/`](Requirements/README.md) is optional.

1. Complete the [Top Movies](Requirements/top-movies.md) epic first.
2. Then complete stories **1 and 2** of [Favorites & Bookmarking](Requirements/favorites.md).

Do **not** try to finish the backlog. Judgment and craft matter more than completion count.

## Ground rules

- All **new** work is SwiftUI.
- Top Movies fixes stay in the existing UIKit list ([`Requirements/top-movies.md`](Requirements/top-movies.md)).
- No 3rd-party dependencies.
- Add unit tests for completed work.
- Tick `Done` on a story (and update the progress table in [`Requirements/README.md`](Requirements/README.md)) only after verification: unit tests plus a visual check.

## How we work in this repo

- This harness lives in the repo and is part of the workflow.
- PRs are encouraged. Reviewers look at `main`, so completed work must land there.

## Pointers (do not duplicate architecture here)

- Architecture: [`.cursor/rules/architecture.mdc`](.cursor/rules/architecture.mdc) (always on), plus scoped rules for concurrency, SwiftUI, the legacy UIKit screen, the data layer, image loading, secrets, errors and logging, accessibility, and tests
- Skills: [`.cursor/skills/implement-story/`](.cursor/skills/implement-story/SKILL.md), [`.cursor/skills/visual-qa/`](.cursor/skills/visual-qa/SKILL.md)
- Hooks: [`.cursor/hooks.json`](.cursor/hooks.json)
- PR template: [`.github/pull_request_template.md`](.github/pull_request_template.md)
