import Sdl.Core.Macros
import Sdl.Error
import Sdl.Pixels
import Sdl.Rect
import Sdl.Surface
import Sdl.Properties

/-!
# Display and window management (`SDL_video.h`)

Windows, displays, display modes, and the OpenGL context/attribute API. A
`Window` handle wraps an `SDL_Window *`; a `GLContext` handle wraps an
`SDL_GLContext`.

**Call on the main thread.** Per SDL, every function in this module is
main-thread-only (window creation, the event pump, and all rendering must stay
on the thread that ran `main`). Do not let the *last* reference to a `Window`
or `GLContext` die inside a `Task` — finalizers run on the dropping thread and
video destroys are main-thread-only (see `docs/DESIGN.md`).

## Ownership

* `Window` is **finalizer-only** (no manual destroy): popup children and window
  surfaces make a manual destroy unsound. Top-level windows have no owner;
  popup windows hold an owned ref to their creation parent, so SDL's
  "child popups destroyed with the parent" contract is respected by
  reference-count ordering.
* `GLContext` is an owned leaf that pins its window; `GLContext.destroy` is
  exposed. Each window created through this binding registers its Lean external
  as a non-owning `"lean_sdl.window"` pointer property, so `SDL_Window *` →
  `Window` lookups (`getWindowFromId`, `Window.parent`, `getGrabbedWindow`,
  `glGetCurrentWindow`, `getWindows`) return the *same* handle. Windows not
  created through this binding ("foreign" windows) are not registered and are
  skipped by those lookups.

## OpenGL attribute values

`glSetAttribute`/`glGetAttribute` pass raw `Int32` values. The enums/flags below
(`GLProfile`, `GLContextFlag`, `GLContextReleaseBehavior`,
`GLContextResetNotification`) are provided as *typed constants only*; converting
to `Int32` at the call site is the caller's job, e.g.

```
Sdl.glSetAttribute .contextProfileMask (Int32.ofNat GLProfile.core.val.toNat)
```

## Skipped

Types: `SDL_HitTest`/`SDL_HitTestResult` (callback — deferred to M6); all
`SDL_EGL*` types and `SDL_GLContextState` internals (out of scope).

Functions: `SDL_SetWindowHitTest` (callback → M6); `SDL_GL_GetProcAddress` /
`SDL_EGL_GetProcAddress` (raw function pointers, unusable without a GL binding);
`SDL_EGL_GetCurrentDisplay` / `SDL_EGL_GetCurrentConfig` /
`SDL_EGL_GetWindowSurface` / `SDL_EGL_SetAttributeCallbacks` (EGL out of scope);
`SDL_GL_GetCurrentContext` (no way to map a raw context back to the owning Lean
handle — track your own current context).
-/

namespace Sdl

/-- The instance id of a display, unique while the display is connected and
never reused for the lifetime of the app. `0` is never a valid id.
C: `SDL_DisplayID`. -/
sdl_id DisplayId : UInt32

/-- The unique id of a window. `0` is never a valid id. C: `SDL_WindowID`. -/
sdl_id WindowId : UInt32

/-- The current system theme. C: `SDL_SystemTheme`. -/
sdl_enum SystemTheme : UInt32 where
  | unknown => 0  -- C: SDL_SYSTEM_THEME_UNKNOWN
  | light   => 1  -- C: SDL_SYSTEM_THEME_LIGHT
  | dark    => 2  -- C: SDL_SYSTEM_THEME_DARK

/-- The way a display is rotated. C: `SDL_DisplayOrientation`. -/
sdl_enum DisplayOrientation : UInt32 where
  | unknown          => 0  -- C: SDL_ORIENTATION_UNKNOWN
  | landscape        => 1  -- C: SDL_ORIENTATION_LANDSCAPE
  | landscapeFlipped => 2  -- C: SDL_ORIENTATION_LANDSCAPE_FLIPPED
  | portrait         => 3  -- C: SDL_ORIENTATION_PORTRAIT
  | portraitFlipped  => 4  -- C: SDL_ORIENTATION_PORTRAIT_FLIPPED

/-- A display mode. Mirrors the public fields of C's `SDL_DisplayMode`; the
trailing private `internal` pointer is dropped. SDL matches modes by their
public fields (`SDL_GetFullscreenDisplayModes` results are compared field-wise
by `SDL_SetWindowFullscreenMode`), so rebuilding a zero-initialized
`SDL_DisplayMode` with `internal = NULL` from these fields is sound.
C: `SDL_DisplayMode`. -/
structure DisplayMode where
  /-- The display this mode is associated with. -/
  displayId : DisplayId
  /-- Pixel format. -/
  format : PixelFormat
  /-- Width. -/
  w : Int32
  /-- Height. -/
  h : Int32
  /-- Scale converting size to pixels (e.g. 2.0 on a HiDPI display). -/
  pixelDensity : Float32
  /-- Refresh rate in Hz (0.0 if unspecified). -/
  refreshRate : Float32
  /-- Precise refresh-rate numerator (0 if unspecified). -/
  refreshRateNumerator : Int32
  /-- Precise refresh-rate denominator. -/
  refreshRateDenominator : Int32
deriving Repr, BEq, Inhabited

/-- Maker called from C to hand a `DisplayMode` back to Lean (flattened
scalars; the raw format value is decoded with the total `PixelFormat.ofVal`). -/
@[export lean_sdl_mk_display_mode]
private def mkDisplayMode (displayId format : UInt32) (w h : Int32)
    (pixelDensity refreshRate : Float32) (num den : Int32) : DisplayMode :=
  { displayId := ⟨displayId⟩, format := PixelFormat.ofVal format, w, h,
    pixelDensity, refreshRate,
    refreshRateNumerator := num, refreshRateDenominator := den }

/-- The flags on a window (some immutable after creation, some app-settable,
some altered by the user or system). C: `SDL_WindowFlags`. -/
sdl_flags WindowFlags : UInt64 where
  | fullscreen        := 0x0000000000000001  -- C: SDL_WINDOW_FULLSCREEN
  | opengl            := 0x0000000000000002  -- C: SDL_WINDOW_OPENGL
  | occluded          := 0x0000000000000004  -- C: SDL_WINDOW_OCCLUDED
  | hidden            := 0x0000000000000008  -- C: SDL_WINDOW_HIDDEN
  | borderless        := 0x0000000000000010  -- C: SDL_WINDOW_BORDERLESS
  | resizable         := 0x0000000000000020  -- C: SDL_WINDOW_RESIZABLE
  | minimized         := 0x0000000000000040  -- C: SDL_WINDOW_MINIMIZED
  | maximized         := 0x0000000000000080  -- C: SDL_WINDOW_MAXIMIZED
  | mouseGrabbed      := 0x0000000000000100  -- C: SDL_WINDOW_MOUSE_GRABBED
  | inputFocus        := 0x0000000000000200  -- C: SDL_WINDOW_INPUT_FOCUS
  | mouseFocus        := 0x0000000000000400  -- C: SDL_WINDOW_MOUSE_FOCUS
  | external          := 0x0000000000000800  -- C: SDL_WINDOW_EXTERNAL
  | modal             := 0x0000000000001000  -- C: SDL_WINDOW_MODAL
  | highPixelDensity  := 0x0000000000002000  -- C: SDL_WINDOW_HIGH_PIXEL_DENSITY
  | mouseCapture      := 0x0000000000004000  -- C: SDL_WINDOW_MOUSE_CAPTURE
  | mouseRelativeMode := 0x0000000000008000  -- C: SDL_WINDOW_MOUSE_RELATIVE_MODE
  | alwaysOnTop       := 0x0000000000010000  -- C: SDL_WINDOW_ALWAYS_ON_TOP
  | utility           := 0x0000000000020000  -- C: SDL_WINDOW_UTILITY
  | tooltip           := 0x0000000000040000  -- C: SDL_WINDOW_TOOLTIP
  | popupMenu         := 0x0000000000080000  -- C: SDL_WINDOW_POPUP_MENU
  | keyboardGrabbed   := 0x0000000000100000  -- C: SDL_WINDOW_KEYBOARD_GRABBED
  | fillDocument      := 0x0000000000200000  -- C: SDL_WINDOW_FILL_DOCUMENT (Emscripten only)
  | vulkan            := 0x0000000010000000  -- C: SDL_WINDOW_VULKAN
  | metal             := 0x0000000020000000  -- C: SDL_WINDOW_METAL
  | transparent       := 0x0000000040000000  -- C: SDL_WINDOW_TRANSPARENT
  | notFocusable      := 0x0000000080000000  -- C: SDL_WINDOW_NOT_FOCUSABLE

/-- A window flash operation. C: `SDL_FlashOperation`. -/
sdl_enum FlashOperation : UInt32 where
  | cancel       => 0  -- C: SDL_FLASH_CANCEL
  | briefly      => 1  -- C: SDL_FLASH_BRIEFLY
  | untilFocused => 2  -- C: SDL_FLASH_UNTIL_FOCUSED

/-- A window progress-bar state. The C sentinel `SDL_PROGRESS_STATE_INVALID`
(`-1`) is an error marker (like `ScaleMode.invalid`/`PowerState.error`) and is
excluded here; `Window.getProgressState` throws on it.
C: `SDL_ProgressState`. -/
sdl_enum ProgressState : UInt32 where
  | none          => 0  -- C: SDL_PROGRESS_STATE_NONE
  | indeterminate => 1  -- C: SDL_PROGRESS_STATE_INDETERMINATE
  | normal        => 2  -- C: SDL_PROGRESS_STATE_NORMAL
  | paused        => 3  -- C: SDL_PROGRESS_STATE_PAUSED
  | error         => 4  -- C: SDL_PROGRESS_STATE_ERROR

/-- An OpenGL configuration attribute, set/read with `glSetAttribute` /
`glGetAttribute`. C: `SDL_GLAttr`. -/
sdl_enum GLAttr : UInt32 where
  | redSize                => 0   -- C: SDL_GL_RED_SIZE
  | greenSize              => 1   -- C: SDL_GL_GREEN_SIZE
  | blueSize               => 2   -- C: SDL_GL_BLUE_SIZE
  | alphaSize              => 3   -- C: SDL_GL_ALPHA_SIZE
  | bufferSize             => 4   -- C: SDL_GL_BUFFER_SIZE
  | doublebuffer           => 5   -- C: SDL_GL_DOUBLEBUFFER
  | depthSize              => 6   -- C: SDL_GL_DEPTH_SIZE
  | stencilSize            => 7   -- C: SDL_GL_STENCIL_SIZE
  | accumRedSize           => 8   -- C: SDL_GL_ACCUM_RED_SIZE
  | accumGreenSize         => 9   -- C: SDL_GL_ACCUM_GREEN_SIZE
  | accumBlueSize          => 10  -- C: SDL_GL_ACCUM_BLUE_SIZE
  | accumAlphaSize         => 11  -- C: SDL_GL_ACCUM_ALPHA_SIZE
  | stereo                 => 12  -- C: SDL_GL_STEREO
  | multisamplebuffers     => 13  -- C: SDL_GL_MULTISAMPLEBUFFERS
  | multisamplesamples     => 14  -- C: SDL_GL_MULTISAMPLESAMPLES
  | acceleratedVisual      => 15  -- C: SDL_GL_ACCELERATED_VISUAL
  | retainedBacking        => 16  -- C: SDL_GL_RETAINED_BACKING
  | contextMajorVersion    => 17  -- C: SDL_GL_CONTEXT_MAJOR_VERSION
  | contextMinorVersion    => 18  -- C: SDL_GL_CONTEXT_MINOR_VERSION
  | contextFlags           => 19  -- C: SDL_GL_CONTEXT_FLAGS
  | contextProfileMask     => 20  -- C: SDL_GL_CONTEXT_PROFILE_MASK
  | shareWithCurrentContext => 21 -- C: SDL_GL_SHARE_WITH_CURRENT_CONTEXT
  | framebufferSrgbCapable => 22  -- C: SDL_GL_FRAMEBUFFER_SRGB_CAPABLE
  | contextReleaseBehavior => 23  -- C: SDL_GL_CONTEXT_RELEASE_BEHAVIOR
  | contextResetNotification => 24 -- C: SDL_GL_CONTEXT_RESET_NOTIFICATION
  | contextNoError         => 25  -- C: SDL_GL_CONTEXT_NO_ERROR
  | floatbuffers           => 26  -- C: SDL_GL_FLOATBUFFERS
  | eglPlatform            => 27  -- C: SDL_GL_EGL_PLATFORM

/-- OpenGL context profile, a value for the `contextProfileMask` attribute.
C: `SDL_GLProfile`. -/
sdl_flags GLProfile : UInt32 where
  | core          := 0x0001  -- C: SDL_GL_CONTEXT_PROFILE_CORE
  | compatibility := 0x0002  -- C: SDL_GL_CONTEXT_PROFILE_COMPATIBILITY
  | es            := 0x0004  -- C: SDL_GL_CONTEXT_PROFILE_ES

/-- OpenGL context flags, a value for the `contextFlags` attribute.
C: `SDL_GLContextFlag`. -/
sdl_flags GLContextFlag : UInt32 where
  | debug            := 0x0001  -- C: SDL_GL_CONTEXT_DEBUG_FLAG
  | forwardCompatible := 0x0002 -- C: SDL_GL_CONTEXT_FORWARD_COMPATIBLE_FLAG
  | robustAccess     := 0x0004  -- C: SDL_GL_CONTEXT_ROBUST_ACCESS_FLAG
  | resetIsolation   := 0x0008  -- C: SDL_GL_CONTEXT_RESET_ISOLATION_FLAG

/-- OpenGL context release behavior, a value for the `contextReleaseBehavior`
attribute. C: `SDL_GLContextReleaseFlag` (`SDL_GL_CONTEXT_RELEASE_BEHAVIOR_*`). -/
sdl_enum GLContextReleaseBehavior : UInt32 where
  | none  => 0  -- C: SDL_GL_CONTEXT_RELEASE_BEHAVIOR_NONE
  | flush => 1  -- C: SDL_GL_CONTEXT_RELEASE_BEHAVIOR_FLUSH

/-- OpenGL context reset notification, a value for the
`contextResetNotification` attribute. C: `SDL_GLContextResetNotification`. -/
sdl_enum GLContextResetNotification : UInt32 where
  | noNotification => 0  -- C: SDL_GL_CONTEXT_RESET_NO_NOTIFICATION
  | loseContext    => 1  -- C: SDL_GL_CONTEXT_RESET_LOSE_CONTEXT

/-- A window: an OS-managed drawing surface. Finalizer-only (no manual
destroy). C: `SDL_Window`. -/
sdl_opaque Window

/-- An OpenGL context. Owned; destroyed on finalize or via `GLContext.destroy`.
C: `SDL_GLContext`. -/
sdl_opaque GLContext

@[extern "lean_sdl_video_register_classes"]
private opaque registerClasses : IO Unit

initialize registerClasses

/-- Maker for an `Int32 × Int32` pair result (C never builds Lean tuples). -/
@[export lean_sdl_mk_int32_pair]
private def mkInt32Pair (a b : Int32) : Int32 × Int32 := (a, b)

/-- Maker for a `Float32 × Float32` pair result. -/
@[export lean_sdl_mk_float32_pair]
private def mkFloat32Pair (a b : Float32) : Float32 × Float32 := (a, b)

/-- Maker for an `Int32 × Int32 × Int32 × Int32` quad result. -/
@[export lean_sdl_mk_int32_quad]
private def mkInt32Quad (a b c d : Int32) : Int32 × Int32 × Int32 × Int32 := (a, b, c, d)

/-- Flatten an `Option Rect` to the `(hasRect, x, y, w, h)` shape the raw
externs take (mirrors `Sdl.Surface`'s private helper). -/
private def rectArgs : Option Rect → UInt8 × Int32 × Int32 × Int32 × Int32
  | some r => (1, r.x, r.y, r.w, r.h)
  | none   => (0, 0, 0, 0, 0)

/-- Append `v` to `b` as 4 little-endian bytes (its two's-complement bit
pattern). Used to pack `SDL_Rect[]` for `Window.updateSurfaceRects`; all
supported targets are little-endian. -/
private def pushRectLE (b : ByteArray) (v : Int32) : ByteArray :=
  let u := v.toUInt32
  b.push u.toUInt8 |>.push (u >>> 8).toUInt8 |>.push (u >>> 16).toUInt8
    |>.push (u >>> 24).toUInt8

/-! ## Video drivers and system theme -/

/-- The number of video drivers compiled into SDL.
C: `SDL_GetNumVideoDrivers`. -/
@[extern "lean_sdl_get_num_video_drivers"]
opaque getNumVideoDrivers : IO Int32

/-- The name of the built-in video driver at `index` (a simple low-ASCII id
like `"cocoa"`/`"x11"`), or `none` if `index` is out of range.
C: `SDL_GetVideoDriver`. -/
@[extern "lean_sdl_get_video_driver"]
opaque getVideoDriver (index : Int32) : IO (Option String)

/-- The names of all built-in video drivers, in initialization-check order.
Convenience loop over `getNumVideoDrivers` / `getVideoDriver`. -/
def getVideoDrivers : IO (Array String) := do
  let n ← getNumVideoDrivers
  let mut drivers := #[]
  for i in [0:n.toNatClampNeg] do
    if let some name ← getVideoDriver (Int32.ofNat i) then
      drivers := drivers.push name
  return drivers

/-- The name of the currently initialized video driver, or `none` if the video
subsystem is not initialized. C: `SDL_GetCurrentVideoDriver`. -/
@[extern "lean_sdl_get_current_video_driver"]
opaque getCurrentVideoDriver : IO (Option String)

@[extern "lean_sdl_get_system_theme"]
private opaque getSystemThemeRaw : IO UInt32

/-- The current system theme (light/dark/unknown). C: `SDL_GetSystemTheme`. -/
def getSystemTheme : IO SystemTheme := do
  return SystemTheme.ofVal? (← getSystemThemeRaw) |>.getD .unknown

/-! ## Displays -/

@[extern "lean_sdl_get_displays"]
private opaque getDisplaysRaw : IO (Array UInt32)

/-- The currently connected displays. C: `SDL_GetDisplays`. -/
def getDisplays : IO (Array DisplayId) := do
  return (← getDisplaysRaw).map (⟨·⟩)

@[extern "lean_sdl_get_primary_display"]
private opaque getPrimaryDisplayRaw : IO UInt32

/-- The primary display. Throws if there is none. C: `SDL_GetPrimaryDisplay`. -/
def getPrimaryDisplay : IO DisplayId := do
  return ⟨← getPrimaryDisplayRaw⟩

@[extern "lean_sdl_get_display_for_point"]
private opaque getDisplayForPointRaw (x y : Int32) : IO UInt32

/-- The display containing point `p`. Throws on failure.
C: `SDL_GetDisplayForPoint`. -/
def getDisplayForPoint (p : Point) : IO DisplayId := do
  return ⟨← getDisplayForPointRaw p.x p.y⟩

@[extern "lean_sdl_get_display_for_rect"]
private opaque getDisplayForRectRaw (x y w h : Int32) : IO UInt32

/-- The display best containing rectangle `r`. Throws on failure.
C: `SDL_GetDisplayForRect`. -/
def getDisplayForRect (r : Rect) : IO DisplayId := do
  return ⟨← getDisplayForRectRaw r.x r.y r.w r.h⟩

namespace DisplayId

@[extern "lean_sdl_get_display_properties"]
private opaque getPropertiesRaw (id : UInt32) : IO Properties

/-- The properties associated with the display. Borrowed (SDL-global lifetime;
never destroyed from Lean). Throws on failure. C: `SDL_GetDisplayProperties`. -/
def getProperties (self : DisplayId) : IO Properties :=
  getPropertiesRaw self.val

@[extern "lean_sdl_get_display_name"]
private opaque nameRaw (id : UInt32) : IO String

/-- The name of the display (UTF-8). Throws on failure. C: `SDL_GetDisplayName`. -/
def name (self : DisplayId) : IO String :=
  nameRaw self.val

@[extern "lean_sdl_get_display_bounds"]
private opaque boundsRaw (id : UInt32) : IO Rect

/-- The desktop area of the display, in screen coordinates. Throws on failure.
C: `SDL_GetDisplayBounds`. -/
def bounds (self : DisplayId) : IO Rect :=
  boundsRaw self.val

@[extern "lean_sdl_get_display_usable_bounds"]
private opaque usableBoundsRaw (id : UInt32) : IO Rect

/-- The usable desktop area of the display (system-reserved regions removed).
Throws on failure. C: `SDL_GetDisplayUsableBounds`. -/
def usableBounds (self : DisplayId) : IO Rect :=
  usableBoundsRaw self.val

@[extern "lean_sdl_get_natural_display_orientation"]
private opaque naturalOrientationRaw (id : UInt32) : IO UInt32

/-- The natural (as-manufactured) orientation of the display.
C: `SDL_GetNaturalDisplayOrientation`. -/
def naturalOrientation (self : DisplayId) : IO DisplayOrientation := do
  return DisplayOrientation.ofVal? (← naturalOrientationRaw self.val) |>.getD .unknown

@[extern "lean_sdl_get_current_display_orientation"]
private opaque currentOrientationRaw (id : UInt32) : IO UInt32

/-- The current orientation of the display.
C: `SDL_GetCurrentDisplayOrientation`. -/
def currentOrientation (self : DisplayId) : IO DisplayOrientation := do
  return DisplayOrientation.ofVal? (← currentOrientationRaw self.val) |>.getD .unknown

@[extern "lean_sdl_get_display_content_scale"]
private opaque contentScaleRaw (id : UInt32) : IO Float32

/-- The content scale of the display (the suggested UI scale, e.g. `2.0` on a
HiDPI display). Throws on failure. C: `SDL_GetDisplayContentScale`. -/
def contentScale (self : DisplayId) : IO Float32 :=
  contentScaleRaw self.val

@[extern "lean_sdl_get_fullscreen_display_modes"]
private opaque fullscreenModesRaw (id : UInt32) : IO (Array DisplayMode)

/-- The full list of fullscreen display modes for the display. May be empty.
Throws on failure. C: `SDL_GetFullscreenDisplayModes`. -/
def fullscreenModes (self : DisplayId) : IO (Array DisplayMode) :=
  fullscreenModesRaw self.val

@[extern "lean_sdl_get_closest_fullscreen_display_mode"]
private opaque closestFullscreenModeRaw (id : UInt32) (w h : Int32)
  (refreshRate : Float32) (includeHighDensityModes : Bool) : IO DisplayMode

/-- The fullscreen display mode closest to the requested `w × h` /
`refreshRate` (0 = highest available). If `includeHighDensityModes` is `true`,
modes with a pixel density greater than 1.0 are also considered. Throws if no
mode matches. C: `SDL_GetClosestFullscreenDisplayMode`. -/
def closestFullscreenMode (self : DisplayId) (w h : Int32) (refreshRate : Float32)
    (includeHighDensityModes : Bool) : IO DisplayMode :=
  closestFullscreenModeRaw self.val w h refreshRate includeHighDensityModes

@[extern "lean_sdl_get_desktop_display_mode"]
private opaque desktopModeRaw (id : UInt32) : IO DisplayMode

/-- The desktop display mode (the mode in use when SDL started, before any
fullscreen change). Throws on failure. C: `SDL_GetDesktopDisplayMode`. -/
def desktopMode (self : DisplayId) : IO DisplayMode :=
  desktopModeRaw self.val

@[extern "lean_sdl_get_current_display_mode"]
private opaque currentModeRaw (id : UInt32) : IO DisplayMode

/-- The current display mode (may differ from `desktopMode` if a fullscreen
window changed it). Throws on failure. C: `SDL_GetCurrentDisplayMode`. -/
def currentMode (self : DisplayId) : IO DisplayMode :=
  currentModeRaw self.val

end DisplayId

/-! ## Window creation and identity -/

@[extern "lean_sdl_create_window"]
private opaque createWindowRaw (title : @& String) (w h : Int32) (flags : UInt64) : IO Window

/-- Create a window with the given title, size, and flags. Throws on failure.
The window is registered for identity-preserving lookups. C: `SDL_CreateWindow`. -/
def createWindow (title : @& String) (w h : Int32) (flags : WindowFlags := .none) : IO Window :=
  createWindowRaw title w h flags.val

@[extern "lean_sdl_create_popup_window"]
private opaque createPopupWindowRaw (parent : @& Window)
  (offsetX offsetY w h : Int32) (flags : UInt64) : IO Window

/-- Create a popup window positioned relative to `parent`. `flags` must include
exactly one of `.tooltip` or `.popupMenu` (SDL enforces this). The popup holds
an owned reference to `parent` (SDL destroys child popups with their parent).
Throws on failure. C: `SDL_CreatePopupWindow`. -/
def createPopupWindow (parent : @& Window) (offsetX offsetY w h : Int32)
    (flags : WindowFlags) : IO Window :=
  createPopupWindowRaw parent offsetX offsetY w h flags.val

/-- Create a window from a group of `SDL_PROP_WINDOW_CREATE_*` properties (e.g.
`"SDL.window.create.title"`, `"SDL.window.create.width"`,
`"SDL.window.create.fullscreen"`). Throws on failure. The window is registered
for identity-preserving lookups. C: `SDL_CreateWindowWithProperties`. -/
@[extern "lean_sdl_create_window_with_properties"]
opaque createWindowWithProperties (props : @& Properties) : IO Window

@[extern "lean_sdl_get_window_from_id"]
private opaque getWindowFromIdRaw (id : UInt32) : IO (Option Window)

/-- The window with the given id, or `none` if there is no such window (or it
is a foreign window not created through this binding). Returns the *same*
handle the window was created with. C: `SDL_GetWindowFromID`. -/
def getWindowFromId (id : WindowId) : IO (Option Window) :=
  getWindowFromIdRaw id.val

/-- All open windows created through this binding (foreign windows are skipped).
Throws on failure. C: `SDL_GetWindows`. -/
@[extern "lean_sdl_get_windows"]
opaque getWindows : IO (Array Window)

/-- The window that currently has an input grab, or `none`. Returns the same
handle the window was created with. C: `SDL_GetGrabbedWindow`. -/
@[extern "lean_sdl_get_grabbed_window"]
opaque getGrabbedWindow : IO (Option Window)

namespace Window

/-- `SDL_WINDOW_SURFACE_VSYNC_DISABLED`: value for `setSurfaceVSync` disabling
vsync. C: `SDL_WINDOW_SURFACE_VSYNC_DISABLED`. -/
def surfaceVSyncDisabled : Int32 := 0

/-- `SDL_WINDOW_SURFACE_VSYNC_ADAPTIVE`: value for `setSurfaceVSync` requesting
adaptive vsync. C: `SDL_WINDOW_SURFACE_VSYNC_ADAPTIVE`. -/
def surfaceVSyncAdaptive : Int32 := -1

@[extern "lean_sdl_get_window_id"]
private opaque idRaw (self : @& Window) : IO UInt32

/-- The numeric id of the window. Throws on failure. C: `SDL_GetWindowID`. -/
def id (self : @& Window) : IO WindowId := do
  return ⟨← idRaw self⟩

/-- The parent of a popup/modal window, or `none` for a top-level or foreign
window. Returns the same handle the parent was created with.
C: `SDL_GetWindowParent`. -/
@[extern "lean_sdl_get_window_parent"]
opaque parent (self : @& Window) : IO (Option Window)

@[extern "lean_sdl_get_display_for_window"]
private opaque getDisplayRaw (self : @& Window) : IO UInt32

/-- The display containing the center of the window. Throws on failure.
C: `SDL_GetDisplayForWindow`. -/
def getDisplay (self : @& Window) : IO DisplayId := do
  return ⟨← getDisplayRaw self⟩

/-! ### Window state -/

/-- The pixel density: how many pixels a screen coordinate maps to. Throws on
failure. C: `SDL_GetWindowPixelDensity`. -/
@[extern "lean_sdl_get_window_pixel_density"]
opaque pixelDensity (self : @& Window) : IO Float32

/-- The content display scale relative to the window's pixel size. Throws on
failure. C: `SDL_GetWindowDisplayScale`. -/
@[extern "lean_sdl_get_window_display_scale"]
opaque displayScale (self : @& Window) : IO Float32

@[extern "lean_sdl_set_window_fullscreen_mode"]
private opaque setFullscreenModeRaw (self : @& Window) (hasMode : UInt8)
  (displayId format : UInt32) (w h : Int32) (density rate : Float32)
  (num den : Int32) : IO Unit

/-- Set the display mode used when the window is fullscreen; `none` selects
borderless fullscreen-desktop mode. Throws on failure.
C: `SDL_SetWindowFullscreenMode`. -/
def setFullscreenMode (self : @& Window) (mode : Option DisplayMode) : IO Unit :=
  match mode with
  | some m =>
    setFullscreenModeRaw self 1 m.displayId.val m.format.val m.w m.h
      m.pixelDensity m.refreshRate m.refreshRateNumerator m.refreshRateDenominator
  | none => setFullscreenModeRaw self 0 0 0 0 0 0 0 0 0

/-- The exclusive fullscreen display mode of the window, or `none` for
borderless fullscreen-desktop mode. C: `SDL_GetWindowFullscreenMode`. -/
@[extern "lean_sdl_get_window_fullscreen_mode"]
opaque getFullscreenMode (self : @& Window) : IO (Option DisplayMode)

/-- The raw ICC profile data for the display the window is on (copied out).
Throws on failure. C: `SDL_GetWindowICCProfile`. -/
@[extern "lean_sdl_get_window_icc_profile"]
opaque iccProfile (self : @& Window) : IO ByteArray

@[extern "lean_sdl_get_window_pixel_format"]
private opaque pixelFormatRaw (self : @& Window) : IO UInt32

/-- The pixel format of the window. Throws on failure (`SDL_PIXELFORMAT_UNKNOWN`
is the error sentinel). C: `SDL_GetWindowPixelFormat`. -/
def pixelFormat (self : @& Window) : IO PixelFormat := do
  return PixelFormat.ofVal (← pixelFormatRaw self)

/-- The properties associated with the window. Borrowed: tied to the window's
lifetime, never destroyed from Lean. Throws on failure.
C: `SDL_GetWindowProperties`. -/
@[extern "lean_sdl_get_window_properties"]
opaque getProperties (self : @& Window) : IO Properties

@[extern "lean_sdl_get_window_flags"]
private opaque flagsRaw (self : @& Window) : IO UInt64

/-- The current flags of the window. C: `SDL_GetWindowFlags`. -/
def flags (self : @& Window) : IO WindowFlags := do
  return ⟨← flagsRaw self⟩

/-- Set the window title (UTF-8). Throws on failure. C: `SDL_SetWindowTitle`. -/
@[extern "lean_sdl_set_window_title"]
opaque setTitle (self : @& Window) (title : @& String) : IO Unit

/-- The window title, or the empty string if none. C: `SDL_GetWindowTitle`. -/
@[extern "lean_sdl_get_window_title"]
opaque getTitle (self : @& Window) : IO String

/-- Set the window icon from a surface (SDL copies the pixels). Throws on
failure. C: `SDL_SetWindowIcon`. -/
@[extern "lean_sdl_set_window_icon"]
opaque setIcon (self : @& Window) (icon : @& Surface) : IO Unit

/-- Request the window position. Throws on failure. C: `SDL_SetWindowPosition`. -/
@[extern "lean_sdl_set_window_position"]
opaque setPosition (self : @& Window) (x y : Int32) : IO Unit

/-- The window position `(x, y)`. Throws on failure. C: `SDL_GetWindowPosition`. -/
@[extern "lean_sdl_get_window_position"]
opaque getPosition (self : @& Window) : IO (Int32 × Int32)

/-- Request the window client-area size. Throws on failure. C: `SDL_SetWindowSize`. -/
@[extern "lean_sdl_set_window_size"]
opaque setSize (self : @& Window) (w h : Int32) : IO Unit

/-- The window client-area size `(w, h)`. Throws on failure. C: `SDL_GetWindowSize`. -/
@[extern "lean_sdl_get_window_size"]
opaque getSize (self : @& Window) : IO (Int32 × Int32)

/-- The safe area (region not obscured by notches/rounded corners). Throws on
failure. C: `SDL_GetWindowSafeArea`. -/
@[extern "lean_sdl_get_window_safe_area"]
opaque getSafeArea (self : @& Window) : IO Rect

/-- Set the window aspect-ratio limits (`0` = no limit). Throws on failure.
C: `SDL_SetWindowAspectRatio`. -/
@[extern "lean_sdl_set_window_aspect_ratio"]
opaque setAspectRatio (self : @& Window) (minAspect maxAspect : Float32) : IO Unit

/-- The window aspect-ratio limits `(minAspect, maxAspect)`. Throws on failure.
C: `SDL_GetWindowAspectRatio`. -/
@[extern "lean_sdl_get_window_aspect_ratio"]
opaque getAspectRatio (self : @& Window) : IO (Float32 × Float32)

/-- The window border sizes as `(top, left, bottom, right)`. Throws if the
window manager does not support querying borders. C: `SDL_GetWindowBordersSize`. -/
@[extern "lean_sdl_get_window_borders_size"]
opaque getBordersSize (self : @& Window) : IO (Int32 × Int32 × Int32 × Int32)

/-- The window size in pixels (may differ from `getSize` on HiDPI displays).
Throws on failure. C: `SDL_GetWindowSizeInPixels`. -/
@[extern "lean_sdl_get_window_size_in_pixels"]
opaque getSizeInPixels (self : @& Window) : IO (Int32 × Int32)

/-- Set the minimum client-area size. Throws on failure.
C: `SDL_SetWindowMinimumSize`. -/
@[extern "lean_sdl_set_window_minimum_size"]
opaque setMinimumSize (self : @& Window) (w h : Int32) : IO Unit

/-- The minimum client-area size `(w, h)`. Throws on failure.
C: `SDL_GetWindowMinimumSize`. -/
@[extern "lean_sdl_get_window_minimum_size"]
opaque getMinimumSize (self : @& Window) : IO (Int32 × Int32)

/-- Set the maximum client-area size. Throws on failure.
C: `SDL_SetWindowMaximumSize`. -/
@[extern "lean_sdl_set_window_maximum_size"]
opaque setMaximumSize (self : @& Window) (w h : Int32) : IO Unit

/-- The maximum client-area size `(w, h)`. Throws on failure.
C: `SDL_GetWindowMaximumSize`. -/
@[extern "lean_sdl_get_window_maximum_size"]
opaque getMaximumSize (self : @& Window) : IO (Int32 × Int32)

/-- Add or remove the window border. Throws on failure. C: `SDL_SetWindowBordered`. -/
@[extern "lean_sdl_set_window_bordered"]
opaque setBordered (self : @& Window) (bordered : Bool) : IO Unit

/-- Enable or disable user resizing of the window. Throws on failure.
C: `SDL_SetWindowResizable`. -/
@[extern "lean_sdl_set_window_resizable"]
opaque setResizable (self : @& Window) (resizable : Bool) : IO Unit

/-- Set whether the window is always on top. Throws on failure.
C: `SDL_SetWindowAlwaysOnTop`. -/
@[extern "lean_sdl_set_window_always_on_top"]
opaque setAlwaysOnTop (self : @& Window) (onTop : Bool) : IO Unit

/-- Set fill-document mode (Emscripten only; throws elsewhere).
C: `SDL_SetWindowFillDocument`. -/
@[extern "lean_sdl_set_window_fill_document"]
opaque setFillDocument (self : @& Window) (fill : Bool) : IO Unit

/-- Show the window. Throws on failure. C: `SDL_ShowWindow`. -/
@[extern "lean_sdl_show_window"]
opaque «show» (self : @& Window) : IO Unit

/-- Hide the window. Throws on failure. C: `SDL_HideWindow`. -/
@[extern "lean_sdl_hide_window"]
opaque hide (self : @& Window) : IO Unit

/-- Raise the window above others and give it input focus. Throws on failure.
C: `SDL_RaiseWindow`. -/
@[extern "lean_sdl_raise_window"]
opaque raise (self : @& Window) : IO Unit

/-- Maximize the window. Throws on failure. C: `SDL_MaximizeWindow`. -/
@[extern "lean_sdl_maximize_window"]
opaque maximize (self : @& Window) : IO Unit

/-- Minimize the window. Throws on failure. C: `SDL_MinimizeWindow`. -/
@[extern "lean_sdl_minimize_window"]
opaque minimize (self : @& Window) : IO Unit

/-- Restore a minimized/maximized window to its normal size and position.
Throws on failure. C: `SDL_RestoreWindow`. -/
@[extern "lean_sdl_restore_window"]
opaque restore (self : @& Window) : IO Unit

/-- Enter or leave fullscreen (borderless-desktop unless a fullscreen mode was
set with `setFullscreenMode`). Throws on failure. C: `SDL_SetWindowFullscreen`. -/
@[extern "lean_sdl_set_window_fullscreen"]
opaque setFullscreen (self : @& Window) (fullscreen : Bool) : IO Unit

/-- Block until any pending window-state changes have been applied. Throws on
failure. C: `SDL_SyncWindow`. -/
@[extern "lean_sdl_sync_window"]
opaque sync (self : @& Window) : IO Unit

/-! ### Window surface -/

/-- Whether the window has an associated surface. C: `SDL_WindowHasSurface`. -/
@[extern "lean_sdl_window_has_surface"]
opaque hasSurface (self : @& Window) : IO Bool

/-- The window's SDL-managed surface (creating it if needed). **Borrowed**:
owned by the window, never destroyed from Lean. The returned surface is
invalidated by a window resize and by `destroySurface` — re-fetch after either
(this mirrors the SDL contract and is *not* caught by the use-after-destroy
guard). Throws on failure. C: `SDL_GetWindowSurface`. -/
@[extern "lean_sdl_get_window_surface"]
opaque getSurface (self : @& Window) : IO Surface

/-- Set the vsync mode for the window surface (`surfaceVSyncDisabled`,
`surfaceVSyncAdaptive`, or a positive frame count). Throws on failure.
C: `SDL_SetWindowSurfaceVSync`. -/
@[extern "lean_sdl_set_window_surface_vsync"]
opaque setSurfaceVSync (self : @& Window) (vsync : Int32) : IO Unit

/-- The current vsync mode for the window surface. Throws on failure.
C: `SDL_GetWindowSurfaceVSync`. -/
@[extern "lean_sdl_get_window_surface_vsync"]
opaque getSurfaceVSync (self : @& Window) : IO Int32

/-- Copy the window surface to the screen. Throws on failure.
C: `SDL_UpdateWindowSurface`. -/
@[extern "lean_sdl_update_window_surface"]
opaque updateSurface (self : @& Window) : IO Unit

@[extern "lean_sdl_update_window_surface_rects"]
private opaque updateSurfaceRectsRaw (self : @& Window) (rects : @& ByteArray) : IO Unit

/-- Copy the given rectangles of the window surface to the screen. The rects
are packed into a `ByteArray` (four little-endian `Int32`s each, matching
`sizeof(SDL_Rect) == 16`) so C never reads a Lean structure. Throws on failure.
C: `SDL_UpdateWindowSurfaceRects`. -/
def updateSurfaceRects (self : @& Window) (rects : @& Array Rect) : IO Unit := do
  let mut bytes := ByteArray.emptyWithCapacity (rects.size * 16)
  for r in rects do
    bytes := pushRectLE (pushRectLE (pushRectLE (pushRectLE bytes r.x) r.y) r.w) r.h
  updateSurfaceRectsRaw self bytes

/-- Destroy the window's surface. Any borrowed surface previously fetched with
`getSurface` dangles afterwards — re-fetch it if the window is reused. Throws on
failure. C: `SDL_DestroyWindowSurface`. -/
@[extern "lean_sdl_destroy_window_surface"]
opaque destroySurface (self : @& Window) : IO Unit

/-! ### Grab, mouse confinement, appearance -/

/-- Set keyboard grab (route system keys to the window). Throws on failure.
C: `SDL_SetWindowKeyboardGrab`. -/
@[extern "lean_sdl_set_window_keyboard_grab"]
opaque setKeyboardGrab (self : @& Window) (grabbed : Bool) : IO Unit

/-- Whether keyboard grab is enabled. C: `SDL_GetWindowKeyboardGrab`. -/
@[extern "lean_sdl_get_window_keyboard_grab"]
opaque getKeyboardGrab (self : @& Window) : IO Bool

/-- Set mouse grab (confine the cursor to the window). Throws on failure.
C: `SDL_SetWindowMouseGrab`. -/
@[extern "lean_sdl_set_window_mouse_grab"]
opaque setMouseGrab (self : @& Window) (grabbed : Bool) : IO Unit

/-- Whether mouse grab is enabled. C: `SDL_GetWindowMouseGrab`. -/
@[extern "lean_sdl_get_window_mouse_grab"]
opaque getMouseGrab (self : @& Window) : IO Bool

@[extern "lean_sdl_set_window_mouse_rect"]
private opaque setMouseRectRaw (self : @& Window)
  (hasRect : UInt8) (x y w h : Int32) : IO Unit

/-- Confine the mouse to `rect` (in window coordinates); `none` clears the
confinement. Throws on failure. C: `SDL_SetWindowMouseRect`. -/
def setMouseRect (self : @& Window) (rect : Option Rect) : IO Unit :=
  let (hasR, x, y, w, h) := rectArgs rect
  setMouseRectRaw self hasR x y w h

/-- The mouse confinement rectangle, or `none` if the mouse is not confined.
C: `SDL_GetWindowMouseRect`. -/
@[extern "lean_sdl_get_window_mouse_rect"]
opaque getMouseRect (self : @& Window) : IO (Option Rect)

/-- Set the window opacity (`0.0` transparent … `1.0` opaque). Throws on
failure. C: `SDL_SetWindowOpacity`. -/
@[extern "lean_sdl_set_window_opacity"]
opaque setOpacity (self : @& Window) (opacity : Float32) : IO Unit

/-- The window opacity. Throws on failure (`-1.0` is the error sentinel).
C: `SDL_GetWindowOpacity`. -/
@[extern "lean_sdl_get_window_opacity"]
opaque getOpacity (self : @& Window) : IO Float32

@[extern "lean_sdl_set_window_parent"]
private opaque setParentRaw (self : @& Window) (parent : @& Option Window) : IO Unit

/-- Set the parent of the window; `none` makes it top-level. Note: re-parenting
does not transfer the Lean-side reference a popup pins on its creation parent
(harmless over-retention). Throws on failure. C: `SDL_SetWindowParent`. -/
def setParent (self : @& Window) (parent : Option Window) : IO Unit :=
  setParentRaw self parent

/-- Set whether the window is modal to its parent. Throws on failure.
C: `SDL_SetWindowModal`. -/
@[extern "lean_sdl_set_window_modal"]
opaque setModal (self : @& Window) (modal : Bool) : IO Unit

/-- Set whether the window can be focused. Throws on failure.
C: `SDL_SetWindowFocusable`. -/
@[extern "lean_sdl_set_window_focusable"]
opaque setFocusable (self : @& Window) (focusable : Bool) : IO Unit

/-- Show the system window menu at `(x, y)` in window coordinates. Throws on
failure. C: `SDL_ShowWindowSystemMenu`. -/
@[extern "lean_sdl_show_window_system_menu"]
opaque showSystemMenu (self : @& Window) (x y : Int32) : IO Unit

@[extern "lean_sdl_set_window_shape"]
private opaque setShapeRaw (self : @& Window) (shape : @& Option Surface) : IO Unit

/-- Set the window shape from a surface (SDL copies it); `none` removes the
shape. The window must have been created with `WindowFlags.transparent`. Throws
on failure. C: `SDL_SetWindowShape`. -/
def setShape (self : @& Window) (shape : Option Surface) : IO Unit :=
  setShapeRaw self shape

@[extern "lean_sdl_flash_window"]
private opaque flashRaw (self : @& Window) (operation : UInt32) : IO Unit

/-- Request the window flash for attention. Throws on failure.
C: `SDL_FlashWindow`. -/
def flash (self : @& Window) (operation : FlashOperation) : IO Unit :=
  flashRaw self operation.val

@[extern "lean_sdl_set_window_progress_state"]
private opaque setProgressStateRaw (self : @& Window) (state : UInt32) : IO Unit

/-- Set the taskbar/dock progress-bar state for the window. Throws on failure.
C: `SDL_SetWindowProgressState`. -/
def setProgressState (self : @& Window) (state : ProgressState) : IO Unit :=
  setProgressStateRaw self state.val

@[extern "lean_sdl_get_window_progress_state"]
private opaque getProgressStateRaw (self : @& Window) : IO UInt32

/-- The taskbar/dock progress-bar state for the window. Throws on failure
(`SDL_PROGRESS_STATE_INVALID`). C: `SDL_GetWindowProgressState`. -/
def getProgressState (self : @& Window) : IO ProgressState := do
  return ProgressState.ofVal? (← getProgressStateRaw self) |>.getD .none

/-- Set the taskbar/dock progress value (`0.0`–`1.0`). Throws on failure.
C: `SDL_SetWindowProgressValue`. -/
@[extern "lean_sdl_set_window_progress_value"]
opaque setProgressValue (self : @& Window) (value : Float32) : IO Unit

/-- The taskbar/dock progress value. Throws on failure (a negative value is the
error sentinel). C: `SDL_GetWindowProgressValue`. -/
@[extern "lean_sdl_get_window_progress_value"]
opaque getProgressValue (self : @& Window) : IO Float32

end Window

/-! ## Screensaver -/

/-- Whether the screensaver is currently enabled. C: `SDL_ScreenSaverEnabled`. -/
@[extern "lean_sdl_screen_saver_enabled"]
opaque screenSaverEnabled : IO Bool

/-- Allow the screensaver to run while the app is active. Throws on failure.
C: `SDL_EnableScreenSaver`. -/
@[extern "lean_sdl_enable_screen_saver"]
opaque enableScreenSaver : IO Unit

/-- Prevent the screensaver from running while the app is active. Throws on
failure. C: `SDL_DisableScreenSaver`. -/
@[extern "lean_sdl_disable_screen_saver"]
opaque disableScreenSaver : IO Unit

/-! ## OpenGL -/

@[extern "lean_sdl_gl_load_library"]
private opaque glLoadLibraryRaw (path : @& Option String) : IO Unit

/-- Load an OpenGL library (`none` loads the default). Throws on failure.
C: `SDL_GL_LoadLibrary`. -/
def glLoadLibrary (path : Option String := none) : IO Unit :=
  glLoadLibraryRaw path

/-- Unload the OpenGL library loaded with `glLoadLibrary`.
C: `SDL_GL_UnloadLibrary`. -/
@[extern "lean_sdl_gl_unload_library"]
opaque glUnloadLibrary : IO Unit

/-- Whether an OpenGL extension is supported by the current context.
C: `SDL_GL_ExtensionSupported`. -/
@[extern "lean_sdl_gl_extension_supported"]
opaque glExtensionSupported (extension : @& String) : IO Bool

/-- Reset all OpenGL context attributes to their default values.
C: `SDL_GL_ResetAttributes`. -/
@[extern "lean_sdl_gl_reset_attributes"]
opaque glResetAttributes : IO Unit

@[extern "lean_sdl_gl_set_attribute"]
private opaque glSetAttributeRaw (attr : UInt32) (value : Int32) : IO Unit

/-- Set an OpenGL context attribute (before window/context creation). See the
`GLProfile`/`GLContextFlag` constants for typed values. Throws on failure.
C: `SDL_GL_SetAttribute`. -/
def glSetAttribute (attr : GLAttr) (value : Int32) : IO Unit :=
  glSetAttributeRaw attr.val value

@[extern "lean_sdl_gl_get_attribute"]
private opaque glGetAttributeRaw (attr : UInt32) : IO Int32

/-- The current value of an OpenGL context attribute. Throws on failure.
C: `SDL_GL_GetAttribute`. -/
def glGetAttribute (attr : GLAttr) : IO Int32 :=
  glGetAttributeRaw attr.val

/-- Create an OpenGL context for the window and make it current. The context
pins the window (owned reference). Throws on failure. C: `SDL_GL_CreateContext`. -/
@[extern "lean_sdl_gl_create_context"]
opaque glCreateContext (window : @& Window) : IO GLContext

/-- Set the OpenGL context current for the window. Throws on failure.
C: `SDL_GL_MakeCurrent`. -/
@[extern "lean_sdl_gl_make_current"]
opaque glMakeCurrent (window : @& Window) (context : @& GLContext) : IO Unit

/-- The window with the current OpenGL context, or `none`. Returns the same
handle the window was created with. C: `SDL_GL_GetCurrentWindow`. -/
@[extern "lean_sdl_gl_get_current_window"]
opaque glGetCurrentWindow : IO (Option Window)

/-- Set the OpenGL swap interval (0 = immediate, 1 = vsync, -1 = adaptive).
Throws on failure. C: `SDL_GL_SetSwapInterval`. -/
@[extern "lean_sdl_gl_set_swap_interval"]
opaque glSetSwapInterval (interval : Int32) : IO Unit

/-- The current OpenGL swap interval. Throws on failure.
C: `SDL_GL_GetSwapInterval`. -/
@[extern "lean_sdl_gl_get_swap_interval"]
opaque glGetSwapInterval : IO Int32

/-- Swap the OpenGL buffers for a double-buffered window. Throws on failure.
C: `SDL_GL_SwapWindow`. -/
@[extern "lean_sdl_gl_swap_window"]
opaque glSwapWindow (window : @& Window) : IO Unit

namespace GLContext

/-- Destroy the OpenGL context (do not use the handle afterwards). On failure
the context still exists, so this throws *without* invalidating the handle.
C: `SDL_GL_DestroyContext`. -/
@[extern "lean_sdl_gl_destroy_context"]
opaque destroy (context : @& GLContext) : IO Unit

end GLContext

end Sdl
