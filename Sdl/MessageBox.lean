module

public import Sdl.Core.Macros
public meta import Sdl.Core.Macros
public import Sdl.Error
public meta import Sdl.Error
public import Sdl.Video
public meta import Sdl.Video

public section

/-!
# Message boxes (`SDL_messagebox.h`)

Native modal alert dialogs: a one-button `showSimpleMessageBox` and the fully
customizable `showMessageBox` (title, message, buttons, an optional color scheme,
and an optional parent window). Both block the calling thread until the user
dismisses the dialog.

**Main thread only.** These functions must run on the main thread (or the thread
that created the parent window). They may be called even before `Sdl.init`.

The Lean wrappers do all the packing: buttons are flattened to a metadata
`ByteArray` plus a parallel `Array String`, the color scheme to a 15-byte
`ByteArray`, so the C shim never reads a Lean structure.
-/

namespace Sdl

/-- Message box kind and button layout. C: `SDL_MessageBoxFlags`. -/
sdl_flags MessageBoxFlags : UInt32 where
  | error              := 0x10   -- C: SDL_MESSAGEBOX_ERROR
  | warning            := 0x20   -- C: SDL_MESSAGEBOX_WARNING
  | information        := 0x40   -- C: SDL_MESSAGEBOX_INFORMATION
  | buttonsLeftToRight := 0x80   -- C: SDL_MESSAGEBOX_BUTTONS_LEFT_TO_RIGHT
  | buttonsRightToLeft := 0x100  -- C: SDL_MESSAGEBOX_BUTTONS_RIGHT_TO_LEFT

#guard MessageBoxFlags.error.val == 0x10
#guard MessageBoxFlags.information.val == 0x40
#guard MessageBoxFlags.buttonsRightToLeft.val == 0x100
#guard (MessageBoxFlags.error ||| MessageBoxFlags.buttonsLeftToRight).val == 0x90

/-- Per-button behavior flags. C: `SDL_MessageBoxButtonFlags`. -/
sdl_flags MessageBoxButtonFlags : UInt32 where
  | returnkeyDefault := 0x1  -- C: SDL_MESSAGEBOX_BUTTON_RETURNKEY_DEFAULT
  | escapekeyDefault := 0x2  -- C: SDL_MESSAGEBOX_BUTTON_ESCAPEKEY_DEFAULT

#guard MessageBoxButtonFlags.returnkeyDefault.val == 0x1
#guard MessageBoxButtonFlags.escapekeyDefault.val == 0x2

/-- A single message box button. `id` is returned by `showMessageBox` when this
button is pressed. C: `SDL_MessageBoxButtonData` (`buttonID` → `id`). -/
structure MessageBoxButton where
  /-- Behavior flags (default: no flags). -/
  flags : MessageBoxButtonFlags := .none
  /-- User-defined id, returned by `showMessageBox` when pressed. -/
  id : Int32
  /-- UTF-8 button text. -/
  text : String
deriving Repr, BEq, Inhabited

#guard ({ id := 5, text := "OK" : MessageBoxButton }).flags == .none
#guard (MessageBoxButton.mk .returnkeyDefault 3 "OK").id == 3

/-- An RGB value in a message box color scheme. C: `SDL_MessageBoxColor`. -/
structure MessageBoxColor where
  /-- Red component [0-255]. -/
  r : UInt8
  /-- Green component [0-255]. -/
  g : UInt8
  /-- Blue component [0-255]. -/
  b : UInt8
deriving Repr, BEq, Inhabited

/-- A set of colors for a message box dialog. The field order matches
`SDL_MessageBoxColorType` (`SDL_MESSAGEBOX_COLOR_*`, indices 0–4).
C: `SDL_MessageBoxColorScheme`. -/
structure MessageBoxColorScheme where
  /-- C: `SDL_MESSAGEBOX_COLOR_BACKGROUND` (index 0). -/
  background : MessageBoxColor
  /-- C: `SDL_MESSAGEBOX_COLOR_TEXT` (index 1). -/
  text : MessageBoxColor
  /-- C: `SDL_MESSAGEBOX_COLOR_BUTTON_BORDER` (index 2). -/
  buttonBorder : MessageBoxColor
  /-- C: `SDL_MESSAGEBOX_COLOR_BUTTON_BACKGROUND` (index 3). -/
  buttonBackground : MessageBoxColor
  /-- C: `SDL_MESSAGEBOX_COLOR_BUTTON_SELECTED` (index 4). -/
  buttonSelected : MessageBoxColor
deriving Repr, BEq, Inhabited

/-! ## Byte packing helpers (all supported targets are little-endian) -/

/-- Append `v` to `b` as 4 little-endian bytes. -/
private def pushU32LE (b : ByteArray) (v : UInt32) : ByteArray :=
  b.push v.toUInt8 |>.push (v >>> 8).toUInt8 |>.push (v >>> 16).toUInt8
    |>.push (v >>> 24).toUInt8

/-- Append `v`'s two's-complement bit pattern to `b` as 4 little-endian bytes. -/
private def pushI32LE (b : ByteArray) (v : Int32) : ByteArray :=
  pushU32LE b v.toUInt32

/-- Append a color's `r`, `g`, `b` bytes (SDL_MessageBoxColor layout). -/
private def pushColor (b : ByteArray) (c : MessageBoxColor) : ByteArray :=
  (b.push c.r).push c.g |>.push c.b

/-- Pack a color scheme into 15 bytes: five colors (`r`,`g`,`b`) in
`SDL_MessageBoxColorType` order. -/
private def packColorScheme (cs : MessageBoxColorScheme) : ByteArray :=
  let b := ByteArray.emptyWithCapacity 15
  pushColor (pushColor (pushColor (pushColor (pushColor b
    cs.background) cs.text) cs.buttonBorder) cs.buttonBackground) cs.buttonSelected

@[extern "lean_sdl_show_simple_message_box"]
private opaque showSimpleMessageBoxRaw (flags : UInt32) (title message : @& String)
  (window : @& Option Window) : IO Unit

/-- Show a simple modal message box with the given `flags`, `title`, and
`message`, and a single OK button. Blocks until dismissed. `window` is the
parent (`none` = no parent). Throws on failure (e.g. no available video target).
C: `SDL_ShowSimpleMessageBox`. -/
def showSimpleMessageBox (flags : MessageBoxFlags) (title message : @& String)
    (window : Option Window := none) : IO Unit :=
  showSimpleMessageBoxRaw flags.val title message window

@[extern "lean_sdl_show_message_box"]
private opaque showMessageBoxRaw (flags : UInt32) (title message : @& String)
  (buttonMeta : @& ByteArray) (buttonTexts : @& Array String)
  (hasScheme : UInt8) (scheme : @& ByteArray) (window : @& Option Window) : IO Int32

/-- Show a customizable modal message box and return the pressed button's `id`.
Blocks until dismissed; SDL returns `-1` when the dialog is closed without a
button press. An empty `buttons` array yields an implementation-defined default
(on macOS, an OK button). `colorScheme` `none` uses system colors; `window`
`none` means no parent. Throws on failure. C: `SDL_ShowMessageBox`. -/
def showMessageBox (flags : MessageBoxFlags) (title message : @& String)
    (buttons : @& Array MessageBoxButton) (colorScheme : Option MessageBoxColorScheme := none)
    (window : Option Window := none) : IO Int32 := do
  let mut metaBytes := ByteArray.emptyWithCapacity (buttons.size * 8)
  for btn in buttons do
    metaBytes := pushI32LE (pushU32LE metaBytes btn.flags.val) btn.id
  let texts := buttons.map (·.text)
  let (hasScheme, scheme) := match colorScheme with
    | some cs => ((1 : UInt8), packColorScheme cs)
    | none    => ((0 : UInt8), ByteArray.empty)
  showMessageBoxRaw flags.val title message metaBytes texts hasScheme scheme window

end Sdl

end
