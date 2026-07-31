# ScreenRead

Snip any part of your screen, get the text on your clipboard.

ScreenRead is a tiny macOS menu-bar app that does one thing: press **⇧⌘T**, drag a box
around anything on screen — a screenshot, a PDF, a video frame, an error dialog, a photo of
a whiteboard — and the text inside it lands on your clipboard, ready to paste.

It's the macOS equivalent of PowerToys Text Extractor. Everything runs on-device using
Apple's Vision framework; nothing is uploaded anywhere.

```
⇧⌘T  ──▶  screen freezes  ──▶  drag a box  ──▶  text is on your clipboard
```

---

## Install

```bash
git clone https://github.com/JaneshKapoor/ScreenRead.git
cd ScreenRead
./scripts/install.sh
```

This builds a Release binary, installs it to `/Applications`, and launches it. A
text-viewfinder icon appears in your menu bar.

Requires macOS 15.3+ and Xcode 16.4+ to build.

### Grant Screen Recording permission

On first launch macOS asks for **Screen Recording** permission. ScreenRead reads text from
the pixels on your screen, so this is unavoidable — it's the same permission any screenshot
tool needs.

1. **System Settings ▸ Privacy & Security ▸ Screen Recording**
2. Enable **ScreenRead**
3. **Quit and relaunch the app** — macOS only picks up the new permission on next launch

You can check the current status any time from the menu bar item.

---

## Use

| Action | How |
| --- | --- |
| Capture text | **⇧⌘T** from anywhere, or **Capture Text** in the menu bar |
| Change the shortcut | **Settings…** in the menu bar, then click the shortcut and press a new combination |
| Cancel | **Esc**, right-click, or a single click without dragging |
| Start on login | **Launch at Login** in the menu bar |
| Quit | **Quit ScreenRead** in the menu bar |

The screen dims and freezes, you drag a box, and a small HUD confirms how many characters
were copied. There is no window to dismiss and nothing to click through — paste and carry on.

Multiple displays are all covered at once; the region you drag is captured from whichever
display you started the drag on.

### Changing the shortcut

Open **Settings…** from the menu bar, click the shortcut button, and press the combination you
want. It's stored immediately and survives restarts.

Almost anything works — one modifier or four, letters, digits, punctuation, arrows, ↩, ⇥, Space.
Two rules:

- **Plain typing keys need at least one modifier.** Binding a bare `T` would swallow that key
  system-wide and you could never type the letter again.
- **Function keys work on their own**, since they aren't used for typing. `F5` alone is fine.

If the combination is already taken by another app, ScreenRead says so and keeps your previous
shortcut rather than leaving you with none.

Key names are resolved against your *current* keyboard layout, so a non-QWERTY layout shows the
key you actually pressed rather than the letter in that position on a US keyboard.

---

## How it works

The core design decision is **snapshot-first**: the moment you press the shortcut, ScreenRead
captures every display via ScreenCaptureKit *before* showing any UI, then displays those
frozen images as the selection overlay.

That ordering solves several problems at once:

- The dimming overlay can never end up inside the captured pixels.
- There's no race between "user releases the mouse" and "take the screenshot" — animations,
  tooltips and video keep playing underneath but what you selected is what you saw.
- Cropping is a pure in-memory operation on an image you already have, so results appear
  effectively instantly.

The pipeline:

| Step | File |
| --- | --- |
| Global hotkey (Carbon — no Accessibility permission needed) | `HotkeyManager.swift` |
| Shortcut storage, rendering and rebinding | `Shortcut.swift`, `HotkeyController.swift` |
| Capture every display at native resolution | `ScreenCapturer.swift` |
| Full-screen overlay + drag selection | `SnipOverlayController.swift` |
| Crop, OCR, copy, confirm | `CaptureCoordinator.swift` |
| Vision OCR + reading-order reconstruction | `TextRecognizer.swift` |
| Non-blocking confirmation toast | `HUD.swift` |
| Menu bar item and lifecycle | `AppDelegate.swift` |

A couple of details worth calling out:

**Coordinate mapping.** The overlay view uses a flipped (top-left origin) coordinate space so
it lines up with the snapshot's pixel buffer directly. Selection rects are scaled by the
display's `backingScaleFactor`, so a 100×50 pt drag on a Retina screen crops the full 200×100
px region — you get native-resolution pixels into the OCR engine, which materially improves
accuracy on small text.

**Reading order.** Vision returns text fragments in no guaranteed order. ScreenRead re-sorts
them top-to-bottom and groups them into rows using the *median glyph height* as the tolerance,
so a two-column snippet doesn't come back interleaved.

**Background agent.** The app is `LSUIElement` — no Dock icon, no app switcher entry, no
window. It's a menu bar item and a hotkey, nothing more.

---

## Development

```bash
# Run the tests
xcodebuild test -project ScreenRead.xcodeproj -scheme ScreenRead -destination 'platform=macOS'

# Open in Xcode
open ScreenRead.xcodeproj
```

The test suite covers the two parts that are easy to get subtly wrong and hard to eyeball:
OCR reading-order reconstruction, and the point→pixel crop math across Retina and non-Retina
scale factors. Both run on synthetic in-memory images, so they need no permissions and no
display.

### Logs

The app runs without a window, so it logs through `os.Logger`:

```bash
log stream --predicate 'subsystem == "com.JaneshKapoor.ScreenRead"' --level info
```

---

## Troubleshooting

**"Screen Recording permission required" even though I granted it.**
macOS applies the permission at launch. Quit ScreenRead completely (menu bar ▸ Quit) and open
it again.

**Permission gets asked for again after every rebuild.**
This happens when the app is ad-hoc signed: macOS then identifies it by a hash of the binary,
which changes on every build, so the grant silently stops matching. The project is configured
to sign with an Apple Development certificate instead, giving a stable identity of bundle ID +
certificate that survives rebuilds. If you fork this, point `CODE_SIGN_IDENTITY` at your own
identity (`security find-identity -v -p codesigning`). To clear a stuck grant:

```bash
tccutil reset ScreenCapture com.JaneshKapoor.ScreenRead
```

**The shortcut does nothing.**
Another app has claimed it — ScreenRead warns at launch and offers to open Settings so you can
pick a different combination. The menu bar **Capture Text** item always works regardless.

**"No text found in selection".**
The OCR engine found nothing legible. Very small text is the usual cause; try selecting a
slightly larger region, or zoom in on the source before capturing.

---

## License

MIT
