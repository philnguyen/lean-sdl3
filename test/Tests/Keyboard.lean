import Sdl
import Tests.Harness

namespace Tests.Keyboard
open Sdl Tests.Harness

/-- Keyboard-state tests (run under `SDL_VIDEO_DRIVER=dummy`). Exercises the
device queries, the keyboard-state snapshot, the scancode/keycode/name mapping
tables (layout-independent, so strict), the modifier-state round-trip, and the
per-window text-input life cycle (tolerated where the dummy driver has no IME).
Relies on the video subsystem being initialized. -/
def run : IO Unit := do
  Sdl.init .video

  -- devices
  let _ ← hasKeyboard
  check "hasKeyboard no-throw" true
  let _ ← getKeyboards
  check "getKeyboards no-throw" true
  let _ ← getKeyboardFocus
  check "getKeyboardFocus no-throw" true

  -- state snapshot
  let ks ← getKeyboardState
  check "keyboardState nonempty" (ks.states.size > 0)
  check "pressed .a == false" (ks.pressed .a == false)
  check "pressed ⟨5000⟩ == false (out of range)" (ks.pressed ⟨5000⟩ == false)

  -- scancode <-> keycode (SDL fallback keymap)
  check "getKeyFromScancode .a == Keycode.a" ((← getKeyFromScancode .a) == Keycode.a)
  let (sc, _) ← getScancodeFromKey Keycode.a
  check "getScancodeFromKey Keycode.a fst == .a" (sc == .a)

  -- name tables (SDL's layout-independent tables, strict)
  check "Scancode.name .a == A" ((← Scancode.name .a) == "A")
  check "getScancodeFromName A == .a" ((← getScancodeFromName "A") == .a)
  check "Keycode.name .a == A" ((← Keycode.name .a) == "A")
  check "getKeyFromName A == .a" ((← getKeyFromName "A") == .a)

  -- modifier state round-trip
  setModState .caps
  check "getModState == .caps" ((← getModState) == .caps)
  setModState .none
  check "getModState == .none" ((← getModState) == .none)

  -- reset
  resetKeyboard
  check "resetKeyboard no-throw" true

  -- text input life cycle on a window
  let win ← createWindow "kbd" 64 64
  try
    win.startTextInput
    check "textInputActive true after start" (← win.textInputActive)
    win.stopTextInput
    check "textInputActive false after stop" (!(← win.textInputActive))
  catch _ =>
    check "text input start/stop unsupported on dummy (tolerated)" true
  try
    win.setTextInputArea (some ⟨0, 0, 32, 16⟩) 4
    let (r, c) ← win.getTextInputArea
    check "text input area round-trip (tolerated)" (r == ⟨0, 0, 32, 16⟩ && c == 4)
  catch _ =>
    check "text input area unsupported on dummy (tolerated)" true
  try
    win.clearComposition
    check "clearComposition no-throw (tolerated)" true
  catch _ =>
    check "clearComposition unsupported on dummy (tolerated)" true

  -- screen keyboard (generic; false on the dummy driver, strict)
  check "hasScreenKeyboardSupport == false" (!(← hasScreenKeyboardSupport))
  check "screenKeyboardShown == false" (!(← win.screenKeyboardShown))

end Tests.Keyboard
