# Quiet Screen

A small native macOS menu-bar app for an **already-unlocked** desktop. After the selected idle interval (five minutes by default) without keyboard/mouse activity, it covers every connected display with black and very dim, slowly drifting blue shapes. The cursor is hidden while the cover is showing. Move the mouse or otherwise resume activity and the cover hides and the cursor returns within roughly 100 ms, but the app stays running.

This is a visual screen cover, **not a security lock or Apple's screen saver**. It does not prevent sleep, change settings, unlock the Mac, inject input, request Accessibility/Screen Recording access, or install a login item. Real macOS screen savers/locks remain separate. It does not fix Computer Use's locked-session failure.

## Build and start

```sh
cd ~/code/quiet-screen
swift run PolicyChecks
./build.sh
open 'dist/Quiet Screen.app'
```

The moon-and-stars menu-bar icon (a status item) offers Test cover now, Pause/Resume, Hide cover and Quit. **Test cover now** shows the cover immediately, with the cursor hidden, even while automatic activation is paused. Move the mouse or press a key to dismiss it; the normal five-minute idle behavior then resumes (or stays paused). Quit closes every cover. Start manually again after logout/restart. Do not run multiple copies.

Hide only this app's covers from an authorized task:

```sh
"$HOME/code/quiet-screen/dist/Quiet Screen.app/Contents/MacOS/QuietScreen" --hide
```

That command leaves the app running and suppresses its cover for five minutes. It never dismisses the actual macOS saver or a password lock.

## Design and limitations

- Swift/AppKit, no third-party dependencies. Global input is not recorded: only aggregate idle time and cursor coordinates are sampled, using public macOS APIs.
- Hiding the cursor without taking keyboard focus requires the undocumented WindowServer property `SetsCursorInBackground` via `CGSSetConnectionProperty`. The symbols are resolved at runtime; if unavailable or rejected, the cover still works but the cursor may remain visible, and the failure is logged. This private API may change in future macOS releases and is not suitable for Mac App Store distribution.
- Ordinary non-key borderless windows; the app does not steal keyboard focus. Covers ignore mouse clicks, so the first click could still reach an underlying app. Moving the mouse first is recommended.
- Display arrangement changes rebuild the covers on the next polling tick. Covers join Spaces and accompany full-screen apps; unusual full-screen/window-level behavior needs on-device validation.
- Black/dim moving visuals reduce static image exposure but are not a guarantee against burn-in. Turning monitors off is more protective. This app does not keep the system or displays awake.
- Native macOS saver or display sleep may still take over based on your existing settings. User chooses any setting changes separately; this app makes none.
- This is locally built/ad-hoc signed, not notarized/distributed. No automatic startup or background service installed.

## Checks

`swift run PolicyChecks` checks idle threshold, resumed activity, pause, inactive session, invalid idle reading, explicit-hide cooldown and manual preview activation/dismissal. A standalone assertion runner is used because this machine's command-line Swift toolchain does not contain XCTest.

Visual acceptance: after a normal, unlocked session is available, launch, leave input idle for five minutes, verify every monitor is covered, visuals move and the cursor is hidden, move the pointer to dismiss and verify the cursor returns, check it remains in the menu bar, repeat, then test Test cover now (including while paused and dismissal by keyboard), Pause/Resume, display reconnection and Quit (including cursor restoration). These visual checks must not be claimed from build success alone.

## Persistent settings

Click the moon-and-stars menu icon → **Settings**:

- **Start after:** 1, 2, 5, 10, 15, 30 or 60 minutes.
- **Visual:** Blue Drift (soft blue pools), Quiet Stars (slowly drifting dim stars), Aurora Ribbons (three dim flowing lines), or Pure Black.

Both selections save automatically in this app's preferences and load on next launch. Checkmarks show the active choices. Changing the interval resets a full countdown; changing the visual dismisses the current cover. Use **Test cover now** to preview the selection. These settings belong only to Quiet Screen, not macOS's screen saver or lock settings.
