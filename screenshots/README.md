# Screenshots

Drop your screenshots here using the exact filenames below — the project
`README.md` already references them, so they'll appear automatically once added.

Capture **both** a light-mode and a dark-mode shot of each section (use the
theme toggle in the example app's app bar).

| Section  | Light mode                | Dark mode                |
| -------- | ------------------------- | ------------------------ |
| Sources  | `sources_light.png`       | `sources_dark.png`       |
| Features | `features_light.png`      | `features_dark.png`      |
| Gallery  | `gallery_light.png`       | `gallery_dark.png`       |
| Tools    | `tools_light.png`         | `tools_dark.png`         |
| Cache    | `cache_light.png`         | `cache_dark.png`         |

Optional extras (referenced if present):

- `hero.png` — a banner/cover image for the top of the README.
- `gallery_fullscreen.png` — the open full-screen gallery viewer.

## How to capture

Run the example app, then:

- **iOS Simulator:** `Cmd + S` (saves to Desktop), or `xcrun simctl io booted screenshot sources_light.png`.
- **Android emulator:** the camera icon in the toolbar, or `adb exec-out screencap -p > sources_light.png`.
- **macOS desktop:** `Cmd + Shift + 4`, then space to capture the window.

Recommended size: portrait phone (~1080×2340) or a tidy window crop. Keep both
modes at the same dimensions so they line up in the README table.
