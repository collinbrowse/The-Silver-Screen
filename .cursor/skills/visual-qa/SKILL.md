---
name: visual-qa
description: Screenshots the booted iOS simulator and compares the capture to Comps/redline.png or later screen specs. Use when verifying UI, checking layout against comps, or after implementing a visible story.
---

# Visual QA

Do not require XcodeBuildMCP. Xcode 27 shows simulators in Device Hub, not the Simulator app.

iPhone captures use the **iPhone 17e**. If several simulators are booted, target that device by UDID. `booted` is only safe when it is the only booted device.

Taps, swipes, and typing go through MobAI `execute_dsl` on the iPhone 17e device id. Do not use `cliclick` or click the Device Hub window. Screenshots stay on `xcrun simctl io`.

## Screenshot

1. Resolve the iPhone 17e (`xcrun simctl list devices`). Boot it if it is shut down (`xcrun simctl boot <udid>`). Do not open `Simulator.app`.
2. Capture:

```bash
xcrun simctl io <iphone-17e-udid> screenshot /tmp/urbnflicks-qa.png
```

3. Inspect the screenshot against the relevant spec.

## Compare

- Primary spec for Top Movies cells: [`Comps/redline.png`](Comps/redline.png).
- Later screens: use any spec images added under `Comps/`.

If `Comps/redline.png` (or the relevant spec) is **missing**, still take the screenshot, say the spec file is absent, and skip pixel comparison. Do not block the story on a missing comp file.

## Report

Note mismatches (spacing, aspect ratio, pinning, missing UI) in plain language. Do not tick `Done` on a visual story until the screen matches the spec, or until the missing-spec case has been reported.
