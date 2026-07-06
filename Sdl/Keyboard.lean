import Sdl.Core.Macros
import Sdl.Error
import Sdl.Scancode
import Sdl.Keycode
import Sdl.Video
import Sdl.Rect
import Sdl.Properties

/-!
# Keyboard input state (`SDL_keyboard.h`)

Query the connected keyboards, the current keyboard state snapshot, the key
modifier state, the scancode/keycode/name mapping tables, and the per-window
text-input (IME) life cycle.

`KeyboardState` is a **copy-no-handle** archetype (`docs/DESIGN.md`): a
`ByteArray` snapshot of SDL's internal `SDL_GetKeyboardState` array taken at the
call site, so there is no lifetime tied to SDL's global buffer.

## Skipped

* `SDL_SetScancodeName` — SDL borrows the name string forever ("the string is
  not copied, so the pointer given to this function must stay valid while SDL is
  being used"). Sound binding would need a global retention scheme for a niche
  feature, so it is omitted.
-/

namespace Sdl

/-- A keyboard instance id, unique while the keyboard is connected and never
reused for the lifetime of the app. `0` is never a valid id. Open numeric
domain. C: `SDL_KeyboardID`. -/
sdl_id KeyboardId : UInt32

/-- A snapshot of the full keyboard state, indexed by scancode, taken by
`getKeyboardState`. Copied out of SDL's internal array at the call site (SDL
would otherwise hand back a pointer valid for the whole app lifetime).
C: `SDL_GetKeyboardState`. -/
structure KeyboardState where
  /-- One byte per scancode index; nonzero = pressed. -/
  states : ByteArray
deriving Inhabited

/-- Whether `s` was pressed in this snapshot (false for out-of-range/`other`). -/
def KeyboardState.pressed (ks : KeyboardState) (s : Scancode) : Bool :=
  let i := s.val.toNat
  i < ks.states.size && ks.states[i]! != 0

/-- Maker: wrap a raw `ByteArray` snapshot as a `KeyboardState` (C never lays
out a Lean structure). -/
@[export lean_sdl_mk_keyboard_state]
private def mkKeyboardState (states : ByteArray) : KeyboardState := { states }

/-- Maker for a `Scancode × Keymod` pair result (C never builds Lean tuples).
Used by `getScancodeFromKey`. -/
@[export lean_sdl_mk_scancode_keymod]
private def mkScancodeKeymod (sc : UInt32) (mod : UInt16) : Scancode × Keymod :=
  (⟨sc⟩, ⟨mod⟩)

/-- Maker for a `Rect × Int32` pair result. Used by `Window.getTextInputArea`
(the text input area rectangle plus the cursor offset). -/
@[export lean_sdl_mk_rect_cursor]
private def mkRectCursor (x y w h cursor : Int32) : Rect × Int32 :=
  (⟨x, y, w, h⟩, cursor)

/-! ## Keyboard devices -/

/-- Whether a keyboard is currently connected. C: `SDL_HasKeyboard`. -/
@[extern "lean_sdl_has_keyboard"]
opaque hasKeyboard : IO Bool

@[extern "lean_sdl_get_keyboards"]
private opaque getKeyboardsRaw : IO (Array UInt32)

/-- The currently connected keyboards. May include devices with incidental
keyboard functionality (some mice, KVM switches, power buttons, ...). Throws on
failure. C: `SDL_GetKeyboards`. -/
def getKeyboards : IO (Array KeyboardId) := do
  return (← getKeyboardsRaw).map (⟨·⟩)

namespace KeyboardId

@[extern "lean_sdl_get_keyboard_name_for_id"]
private opaque nameRaw (id : UInt32) : IO String

/-- The name of the keyboard (`""` if it has no name). Throws on failure.
C: `SDL_GetKeyboardNameForID`. -/
def name (self : KeyboardId) : IO String :=
  nameRaw self.val

end KeyboardId

/-- The window that currently has keyboard focus, or `none` (no focus or a
foreign window not created through this binding). C: `SDL_GetKeyboardFocus`. -/
@[extern "lean_sdl_get_keyboard_focus"]
opaque getKeyboardFocus : IO (Option Window)

/-! ## Keyboard state and modifiers -/

/-- A snapshot of the current keyboard state, indexed by `Scancode`. Reflects
the state after all processed events (`SDL_PumpEvents` updates it). Note SDL
does not factor in whether shift is pressed. C: `SDL_GetKeyboardState`. -/
@[extern "lean_sdl_get_keyboard_state"]
opaque getKeyboardState : IO KeyboardState

/-- Clear the keyboard state, generating key-up events for all pressed keys.
C: `SDL_ResetKeyboard`. -/
@[extern "lean_sdl_reset_keyboard"]
opaque resetKeyboard : IO Unit

@[extern "lean_sdl_get_mod_state"]
private opaque getModStateRaw : IO UInt32

/-- The current key modifier state (an OR'd combination of `Keymod`).
C: `SDL_GetModState`. -/
def getModState : IO Keymod := do
  return ⟨(← getModStateRaw).toUInt16⟩

@[extern "lean_sdl_set_mod_state"]
private opaque setModStateRaw (mod : UInt16) : IO Unit

/-- Impose a key modifier state on SDL (does not change the physical key state).
C: `SDL_SetModState`. -/
def setModState (mod : Keymod) : IO Unit :=
  setModStateRaw mod.val

/-! ## Scancode/keycode/name mapping -/

@[extern "lean_sdl_get_key_from_scancode"]
private opaque getKeyFromScancodeRaw (scancode : UInt32) (mod : UInt16)
  (keyEvent : Bool) : IO UInt32

/-- The keycode for the given scancode under the current layout. If `keyEvent`
is `true`, applies `SDL_HINT_KEYCODE_OPTIONS` as when delivering key events;
otherwise it is a plain modifier-aware translation. C: `SDL_GetKeyFromScancode`. -/
def getKeyFromScancode (scancode : Scancode) (mod : Keymod := .none)
    (keyEvent : Bool := false) : IO Keycode := do
  return ⟨← getKeyFromScancodeRaw scancode.val mod.val keyEvent⟩

@[extern "lean_sdl_get_scancode_from_key"]
private opaque getScancodeFromKeyRaw (key : UInt32) : IO (Scancode × Keymod)

/-- The scancode and the modifier state that generate the given keycode under
the current layout (the first match if several exist).
C: `SDL_GetScancodeFromKey`. -/
def getScancodeFromKey (key : Keycode) : IO (Scancode × Keymod) :=
  getScancodeFromKeyRaw key.val

@[extern "lean_sdl_get_scancode_name"]
private opaque scancodeNameRaw (scancode : UInt32) : IO String

/-- A human-readable name for the scancode (`""` if it has none). The name is
by design not stable across platforms and is unsuitable for a persistent
two-way string↔scancode mapping. C: `SDL_GetScancodeName`. -/
def Scancode.name (s : Scancode) : IO String :=
  scancodeNameRaw s.val

@[extern "lean_sdl_get_scancode_from_name"]
private opaque getScancodeFromNameRaw (name : @& String) : IO UInt32

/-- The scancode for a human-readable name, or `Scancode.unknown` if the name
is not recognized. Ambiguity: SDL returns `SDL_SCANCODE_UNKNOWN` (and sets an
error) for both an unrecognized name and the literal name of the "unknown"
scancode, so this never throws. C: `SDL_GetScancodeFromName`. -/
def getScancodeFromName (name : @& String) : IO Scancode := do
  return ⟨← getScancodeFromNameRaw name⟩

@[extern "lean_sdl_get_key_name"]
private opaque keyNameRaw (key : UInt32) : IO String

/-- A human-readable name for the key (`""` if it has none; letters in
uppercase form). C: `SDL_GetKeyName`. -/
def Keycode.name (k : Keycode) : IO String :=
  keyNameRaw k.val

@[extern "lean_sdl_get_key_from_name"]
private opaque getKeyFromNameRaw (name : @& String) : IO UInt32

/-- The keycode for a human-readable name, or `Keycode.unknown` if the name is
not recognized (SDL sets an error but also returns `SDLK_UNKNOWN` for the real
"unknown" name, so this never throws). C: `SDL_GetKeyFromName`. -/
def getKeyFromName (name : @& String) : IO Keycode := do
  return ⟨← getKeyFromNameRaw name⟩

namespace Window

/-! ## Text input (IME) -/

/-- Start accepting Unicode text-input events (`SDL_EVENT_TEXT_INPUT` /
`SDL_EVENT_TEXT_EDITING`) in the window; may show a screen keyboard / activate
an IME. Pair with `stopTextInput`. Throws on failure. C: `SDL_StartTextInput`. -/
@[extern "lean_sdl_start_text_input"]
opaque startTextInput (self : @& Window) : IO Unit

/-- Start text input with a group of `SDL_PROP_TEXTINPUT_*` properties (input
type, capitalization, autocorrect, multiline, ...). Throws on failure.
C: `SDL_StartTextInputWithProperties`. -/
@[extern "lean_sdl_start_text_input_with_properties"]
opaque startTextInputWithProperties (self : @& Window) (props : @& Properties) : IO Unit

/-- Whether Unicode text-input events are enabled for the window.
C: `SDL_TextInputActive`. -/
@[extern "lean_sdl_text_input_active"]
opaque textInputActive (self : @& Window) : IO Bool

/-- Stop receiving text-input events in the window (hiding the screen keyboard
if one was shown). Throws on failure. C: `SDL_StopTextInput`. -/
@[extern "lean_sdl_stop_text_input"]
opaque stopTextInput (self : @& Window) : IO Unit

/-- Dismiss the composition window / IME without disabling text input. Throws
on failure. C: `SDL_ClearComposition`. -/
@[extern "lean_sdl_clear_composition"]
opaque clearComposition (self : @& Window) : IO Unit

@[extern "lean_sdl_set_text_input_area"]
private opaque setTextInputAreaRaw (self : @& Window) (hasRect : UInt8)
  (x y w h : Int32) (cursor : Int32) : IO Unit

/-- Set the area (in window coordinates) used to type text, so native input
methods can place a suggestion window without covering it; `cursor` is the
cursor offset relative to `rect.x`. `none` clears the area. Throws on failure.
C: `SDL_SetTextInputArea`. -/
def setTextInputArea (self : @& Window) (rect : Option Rect := none)
    (cursor : Int32 := 0) : IO Unit :=
  match rect with
  | some r => setTextInputAreaRaw self 1 r.x r.y r.w r.h cursor
  | none   => setTextInputAreaRaw self 0 0 0 0 0 cursor

/-- The text input area and cursor offset previously set with
`setTextInputArea`, as `(rect, cursor)`. Throws on failure.
C: `SDL_GetTextInputArea`. -/
@[extern "lean_sdl_get_text_input_area"]
opaque getTextInputArea (self : @& Window) : IO (Rect × Int32)

end Window

/-! ## Screen keyboard -/

/-- Whether the platform has any screen-keyboard support.
C: `SDL_HasScreenKeyboardSupport`. -/
@[extern "lean_sdl_has_screen_keyboard_support"]
opaque hasScreenKeyboardSupport : IO Bool

/-- Whether the screen keyboard is currently shown for the window.
C: `SDL_ScreenKeyboardShown`. -/
@[extern "lean_sdl_screen_keyboard_shown"]
opaque Window.screenKeyboardShown (self : @& Window) : IO Bool

end Sdl
