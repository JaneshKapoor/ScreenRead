# App Store review notes

Paste the block below into **App Store Connect ▸ your version ▸ App Review
Information ▸ Notes**. It exists because ScreenRead is a background agent whose
main feature does nothing until a system permission is granted — a reviewer who
launches it without reading this sees an app that appears to be broken, which is
the usual route to a Guideline 2.1 rejection.

---

## Notes to paste

```
ScreenRead is a menu bar utility. It has no Dock icon and no main window by
design — it stays out of the way until you press its shortcut.

HOW TO TEST

1. Launch ScreenRead. A "Welcome to ScreenRead" window opens on first launch
   and explains the app. Its icon also appears in the menu bar at the top right
   of the screen (a bracketed text symbol).

2. macOS will ask for Screen Recording permission. This must be granted or the
   app cannot function — reading text off the screen requires reading the
   screen. If the prompt is dismissed, grant it manually at
   System Settings > Privacy & Security > Screen Recording, then quit and
   reopen ScreenRead. macOS only applies a new Screen Recording grant on the
   next launch.

3. Open any document, web page or image containing text.

4. Press Shift-Command-T. The screen dims and a crosshair appears.

5. Drag a box around some text and release.

6. The recognised text is now on the clipboard. Press Command-V in any text
   field to paste it.

Everything else is reachable from the menu bar icon: Capture Text, Settings
(where the shortcut can be rebound), Launch at Login, and "How ScreenRead
Works" which reopens the welcome window.

PRIVACY

Text recognition runs entirely on-device using Apple's Vision framework.
ScreenRead makes no network requests of any kind. It has no analytics, no
accounts, and no server. Captured pixels are held in memory only for the
duration of one recognition pass and are never written to disk. Nothing is
collected, so the privacy nutrition label is "Data Not Collected".

WHY SCREEN RECORDING

This is the only permission the app requests. macOS classes any programmatic
read of screen contents under Screen Recording, so an app that extracts text
from the screen necessarily needs it. ScreenRead does not record video, does
not capture continuously, and only ever reads the single region the user drags
a box around. Capture happens through ScreenCaptureKit
(SCScreenshotManager.captureImage), one still image per user-initiated snip.

SANDBOX

The app is sandboxed with no exceptions or temporary entitlements — the
entitlements file contains only com.apple.security.app-sandbox.
```

---

## Pre-submission checklist

- [ ] Sign in to Xcode ▸ Settings ▸ Accounts with the paid developer account
      (team `UYB9427R4U`).
- [ ] Register the bundle ID `com.JaneshKapoor.ScreenRead` on the developer
      portal, or let Xcode create it during the first archive.
- [ ] Product ▸ Archive, then Distribute App ▸ App Store Connect. Xcode swaps
      the development certificate for a Mac App Store one and strips the
      `get-task-allow` entitlement automatically — that entitlement is present
      in local builds and must not appear in the uploaded binary.
- [ ] Confirm the uploaded build's entitlements with
      `codesign -d --entitlements - /path/to/ScreenRead.app` — expect
      `com.apple.security.app-sandbox` and nothing else.
- [ ] Screenshots: App Store Connect requires at least one 2880×1800 or
      2560×1600 macOS screenshot. The welcome window and a mid-snip overlay are
      the two that explain the app fastest.
- [ ] Privacy nutrition label: select **Data Not Collected**.
- [ ] Category: Utilities. Age rating: 4+.
