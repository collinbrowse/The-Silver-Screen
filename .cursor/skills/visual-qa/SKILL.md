---
name: visual-qa
description: Screenshots the booted iOS simulator and compares the capture to Comps/redline.png or later screen specs. Use when verifying UI, checking layout against comps, or after implementing a visible story.
---

# Visual QA

Do not require XcodeBuildMCP. Use `xcrun simctl` and the booted simulator.

## Screenshot

1. Confirm a simulator is booted (`xcrun simctl list devices booted`).
2. Capture:

```bash
xcrun simctl io booted screenshot /tmp/urbnflicks-qa.png
```

3. Inspect the screenshot against the relevant spec.

## Compare

- Primary spec for Top Movies cells: [`Comps/redline.png`](Comps/redline.png).
- Later screens: use any spec images added under `Comps/`.

If `Comps/redline.png` (or the relevant spec) is **missing**, still take the screenshot, say the spec file is absent, and skip pixel comparison. Do not block the story on a missing comp file.

## Report

Note mismatches (spacing, aspect ratio, pinning, missing UI) in plain language. Do not tick `Done` on a visual story until the screen matches the spec, or until the missing-spec case has been reported.
