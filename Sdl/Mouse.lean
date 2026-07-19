module

public import Sdl.Core.Macros
public meta import Sdl.Core.Macros
public import Sdl.Error
public meta import Sdl.Error
public import Sdl.Video
public meta import Sdl.Video
public import Sdl.Surface
public meta import Sdl.Surface

public section

/-!
# Mouse input state and cursors (`SDL_mouse.h`)

Query the connected mice, the cached/global/relative mouse button+position
state, warp the cursor, toggle relative mouse mode and capture, and create /
set / query cursors.

## Cursor ownership

`Cursor` is **finalizer-only** (no manual destroy is exposed). Two C external
classes back the one Lean type: an **owned** class (from `createCursor`,
`Surface.createColorCursor`, `createSystemCursor`; `SDL_DestroyCursor` on
finalize) and a **borrowed** class (from `getCursor` / `getDefaultCursor`, whose
`SDL_Cursor` is owned by SDL and never destroyed from Lean).

**The active cursor is retained by this binding.** SDL keeps rendering the
cursor most recently passed to `setCursor`, so the shim holds one extra
reference to it in a module-static slot (`ffi/mouse.c`): a successful `setCursor`
increments the new cursor and releases the previously-retained one. The slot is
only touched from shims (main thread). This prevents the active cursor's
finalizer from freeing an `SDL_Cursor` that SDL still displays.

`getCursor` does **not** preserve Lean handle identity (unlike windows): the
returned handle is a fresh borrowed wrapper, so do not compare cursor handles.

## Skipped

* `SDL_CreateAnimatedCursor` — takes an array of `SDL_CursorFrameInfo` structs
  referencing surfaces; no example needs it.
-/

namespace Sdl

/-- A mouse instance id, unique while the mouse is connected and never reused
for the lifetime of the app. `0` is never a valid id. The two named constants
are the virtual mice for touch and pen input. C: `SDL_MouseID`. -/
sdl_id MouseId : UInt32 where
  | touch := 0xFFFFFFFF  -- C: SDL_TOUCH_MOUSEID
  | pen   := 0xFFFFFFFE  -- C: SDL_PEN_MOUSEID

/-- A mouse button index (1-based). C: `SDL_BUTTON_*`. -/
sdl_id MouseButton : UInt8 where
  | left   := 1  -- C: SDL_BUTTON_LEFT
  | middle := 2  -- C: SDL_BUTTON_MIDDLE
  | right  := 3  -- C: SDL_BUTTON_RIGHT
  | x1     := 4  -- C: SDL_BUTTON_X1
  | x2     := 5  -- C: SDL_BUTTON_X2

/-- A bitmask of pressed mouse buttons, as reported by `getMouseState` etc.
C: `SDL_MouseButtonFlags`. -/
sdl_flags MouseButtonFlags : UInt32 where
  | left   := 0x1   -- C: SDL_BUTTON_LMASK
  | middle := 0x2   -- C: SDL_BUTTON_MMASK
  | right  := 0x4   -- C: SDL_BUTTON_RMASK
  | x1     := 0x8   -- C: SDL_BUTTON_X1MASK
  | x2     := 0x10  -- C: SDL_BUTTON_X2MASK

/-- The mask bit for a (1-based) mouse button. C: `SDL_BUTTON_MASK`. -/
def MouseButtonFlags.mask (b : MouseButton) : MouseButtonFlags :=
  ⟨1 <<< (b.val.toUInt32 - 1)⟩

#guard MouseButtonFlags.mask .left == .left
#guard MouseButtonFlags.mask .middle == .middle
#guard MouseButtonFlags.mask .right == .right
#guard MouseButtonFlags.mask .x1 == .x1
#guard MouseButtonFlags.mask .x2 == .x2

/-- The scroll direction reported in a mouse wheel event.
C: `SDL_MouseWheelDirection`. -/
sdl_enum MouseWheelDirection : UInt32 where
  | normal  => 0  -- C: SDL_MOUSEWHEEL_NORMAL
  | flipped => 1  -- C: SDL_MOUSEWHEEL_FLIPPED

/-- A built-in system cursor, for `createSystemCursor`. C: `SDL_SystemCursor`. -/
sdl_enum SystemCursor : UInt32 where
  | default    => 0   -- C: SDL_SYSTEM_CURSOR_DEFAULT
  | text       => 1   -- C: SDL_SYSTEM_CURSOR_TEXT
  | wait       => 2   -- C: SDL_SYSTEM_CURSOR_WAIT
  | crosshair  => 3   -- C: SDL_SYSTEM_CURSOR_CROSSHAIR
  | progress   => 4   -- C: SDL_SYSTEM_CURSOR_PROGRESS
  | nwseResize => 5   -- C: SDL_SYSTEM_CURSOR_NWSE_RESIZE
  | neswResize => 6   -- C: SDL_SYSTEM_CURSOR_NESW_RESIZE
  | ewResize   => 7   -- C: SDL_SYSTEM_CURSOR_EW_RESIZE
  | nsResize   => 8   -- C: SDL_SYSTEM_CURSOR_NS_RESIZE
  | move       => 9   -- C: SDL_SYSTEM_CURSOR_MOVE
  | notAllowed => 10  -- C: SDL_SYSTEM_CURSOR_NOT_ALLOWED
  | pointer    => 11  -- C: SDL_SYSTEM_CURSOR_POINTER
  | nwResize   => 12  -- C: SDL_SYSTEM_CURSOR_NW_RESIZE
  | nResize    => 13  -- C: SDL_SYSTEM_CURSOR_N_RESIZE
  | neResize   => 14  -- C: SDL_SYSTEM_CURSOR_NE_RESIZE
  | eResize    => 15  -- C: SDL_SYSTEM_CURSOR_E_RESIZE
  | seResize   => 16  -- C: SDL_SYSTEM_CURSOR_SE_RESIZE
  | sResize    => 17  -- C: SDL_SYSTEM_CURSOR_S_RESIZE
  | swResize   => 18  -- C: SDL_SYSTEM_CURSOR_SW_RESIZE
  | wResize    => 19  -- C: SDL_SYSTEM_CURSOR_W_RESIZE

/-- A cursor image. Finalizer-only (no manual destroy); the active cursor is
retained by the binding. C: `SDL_Cursor`. -/
sdl_opaque Cursor

@[extern "lean_sdl_mouse_register_classes"]
private opaque registerClasses : IO Unit

initialize registerClasses

/-- Maker for a `(MouseButtonFlags, x, y)` state result (C never builds Lean
tuples). -/
@[export lean_sdl_mk_mouse_state]
private def mkMouseState (state : UInt32) (x y : Float32) :
    MouseButtonFlags × Float32 × Float32 :=
  (⟨state⟩, x, y)

/-! ## Mouse devices -/

/-- Whether a mouse is currently connected. C: `SDL_HasMouse`. -/
@[extern "lean_sdl_has_mouse"]
opaque hasMouse : IO Bool

@[extern "lean_sdl_get_mice"]
private opaque getMiceRaw : IO (Array UInt32)

/-- The currently connected mice. May include devices with incidental mouse
functionality (some game controllers, KVM switches, ...). Throws on failure.
C: `SDL_GetMice`. -/
def getMice : IO (Array MouseId) := do
  return (← getMiceRaw).map (⟨·⟩)

namespace MouseId

@[extern "lean_sdl_get_mouse_name_for_id"]
private opaque nameRaw (id : UInt32) : IO String

/-- The name of the mouse (`""` if it has no name). Throws on failure.
C: `SDL_GetMouseNameForID`. -/
def name (self : MouseId) : IO String :=
  nameRaw self.val

end MouseId

/-- The window that currently has mouse focus, or `none` (no focus or a foreign
window not created through this binding). C: `SDL_GetMouseFocus`. -/
@[extern "lean_sdl_get_mouse_focus"]
opaque getMouseFocus : IO (Option Window)

/-! ## Mouse state -/

/-- SDL's cached synchronous mouse button state and the window-relative
SDL-cursor position `(flags, x, y)`, from the last event-queue pump.
C: `SDL_GetMouseState`. -/
@[extern "lean_sdl_get_mouse_state"]
opaque getMouseState : IO (MouseButtonFlags × Float32 × Float32)

/-- The platform's immediate asynchronous mouse button state and the
desktop-relative platform-cursor position `(flags, x, y)`.
C: `SDL_GetGlobalMouseState`. -/
@[extern "lean_sdl_get_global_mouse_state"]
opaque getGlobalMouseState : IO (MouseButtonFlags × Float32 × Float32)

/-- SDL's cached synchronous mouse button state and the accumulated relative
motion `(flags, dx, dy)` since the previous call.
C: `SDL_GetRelativeMouseState`. -/
@[extern "lean_sdl_get_relative_mouse_state"]
opaque getRelativeMouseState : IO (MouseButtonFlags × Float32 × Float32)

/-- Move the cursor to `(x, y)` within the window (or the current mouse focus).
Generates a motion event when relative mode is off. C: `SDL_WarpMouseInWindow`. -/
@[extern "lean_sdl_warp_mouse_in_window"]
opaque Window.warpMouse (self : @& Window) (x y : Float32) : IO Unit

/-- Move the cursor to `(x, y)` in global screen space. Throws on failure
(typically unsupported by the platform). C: `SDL_WarpMouseGlobal`. -/
@[extern "lean_sdl_warp_mouse_global"]
opaque warpMouseGlobal (x y : Float32) : IO Unit

/-- Enable or disable global mouse capture to track input outside a window.
Throws on failure. C: `SDL_CaptureMouse`. -/
@[extern "lean_sdl_capture_mouse"]
opaque captureMouse (enabled : Bool) : IO Unit

/-- Enable or disable relative mouse mode for the window (cursor hidden,
position constrained, continuous relative motion reported). Throws on failure.
C: `SDL_SetWindowRelativeMouseMode`. -/
@[extern "lean_sdl_set_window_relative_mouse_mode"]
opaque Window.setRelativeMouseMode (self : @& Window) (enabled : Bool) : IO Unit

/-- Whether relative mouse mode is enabled for the window.
C: `SDL_GetWindowRelativeMouseMode`. -/
@[extern "lean_sdl_get_window_relative_mouse_mode"]
opaque Window.relativeMouseMode (self : @& Window) : IO Bool

/-! ## Cursors -/

/-- Create a black-and-white cursor from `data`/`mask` bitmaps in MSB format
(`w` rounded up to a multiple of 8 bits, so each row is `(w+7)/8` bytes;
`data`/`mask` must each hold `((w+7)/8)*h` bytes). `hotX`/`hotY` place the hot
spot. `w` and `h` must be positive. Throws on failure. C: `SDL_CreateCursor`. -/
@[extern "lean_sdl_create_cursor"]
opaque createCursor (data mask : @& ByteArray) (w h hotX hotY : Int32) : IO Cursor

/-- Create a color cursor from a surface (SDL copies the pixels). `hotX`/`hotY`
place the hot spot. Throws on failure. C: `SDL_CreateColorCursor`. -/
@[extern "lean_sdl_create_color_cursor"]
opaque Surface.createColorCursor (surface : @& Surface) (hotX hotY : Int32) : IO Cursor

@[extern "lean_sdl_create_system_cursor"]
private opaque createSystemCursorRaw (id : UInt32) : IO Cursor

/-- Create one of the built-in system cursors. Throws on failure.
C: `SDL_CreateSystemCursor`. -/
def createSystemCursor (id : SystemCursor) : IO Cursor :=
  createSystemCursorRaw id.val

/-- Make `cursor` the active cursor (shown immediately if the cursor is
visible). The binding retains the active cursor (see the ownership notes above).
Throws on failure. C: `SDL_SetCursor`. -/
@[extern "lean_sdl_set_cursor"]
opaque setCursor (cursor : @& Cursor) : IO Unit

/-- Force a cursor redraw without changing the active cursor
(`SDL_SetCursor(NULL)`). Throws on failure. C: `SDL_SetCursor`. -/
@[extern "lean_sdl_redraw_cursor"]
opaque redrawCursor : IO Unit

/-- The active cursor, or `none` if there is no mouse. When the active cursor
was set via `setCursor`, this returns the **same handle** (identity-preserving,
kept alive by the active-cursor slot); otherwise (e.g. the default cursor) it is
a fresh borrowed wrapper. C: `SDL_GetCursor`. -/
@[extern "lean_sdl_get_cursor"]
opaque getCursor : IO (Option Cursor)

/-- The default cursor (borrowed; owned by SDL). Throws on failure.
C: `SDL_GetDefaultCursor`. -/
@[extern "lean_sdl_get_default_cursor"]
opaque getDefaultCursor : IO Cursor

/-- Show the cursor. Throws on failure. C: `SDL_ShowCursor`. -/
@[extern "lean_sdl_show_cursor"]
opaque showCursor : IO Unit

/-- Hide the cursor. Throws on failure. C: `SDL_HideCursor`. -/
@[extern "lean_sdl_hide_cursor"]
opaque hideCursor : IO Unit

/-- Whether the cursor is currently being shown. C: `SDL_CursorVisible`. -/
@[extern "lean_sdl_cursor_visible"]
opaque cursorVisible : IO Bool

@[extern "lean_sdl_set_relative_mouse_transform"]
private opaque setRelativeMouseTransformRaw
    (cb : UInt64 → Option Window → UInt32 → Float32 → Float32 →
          IO (Float32 × Float32)) : IO Unit

/-- Install the one global transform applied to raw relative mouse deltas
(`cb timestamp window mouse x y` returns the transformed `(x, y)`), replacing
any previous transform. Runs inside SDL's mouse input processing — potentially
a separate realtime-priority thread — so keep it fast and non-blocking (SDL
warns stalling that thread can freeze the whole system). An exception leaves
the delta unchanged. C: `SDL_SetRelativeMouseTransform`. -/
def setRelativeMouseTransform
    (cb : (timestamp : UInt64) → (window : Option Window) → (mouse : MouseId) →
          (x y : Float32) → IO (Float32 × Float32)) : IO Unit :=
  setRelativeMouseTransformRaw fun ts win which x y => cb ts win ⟨which⟩ x y

/-- Remove the relative-mouse-delta transform (a safe no-op if none).
C: `SDL_SetRelativeMouseTransform` with `NULL`. -/
@[extern "lean_sdl_clear_relative_mouse_transform"]
opaque clearRelativeMouseTransform : IO Unit

end Sdl

end
