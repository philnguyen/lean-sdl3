import Sdl
import Tests.Harness

namespace Tests.Video
open Sdl Tests.Harness

set_option maxRecDepth 4096 in
/-- Video subsystem tests (run under `SDL_VIDEO_DRIVER=dummy`). Initializes the
video subsystem, then exercises drivers/theme, displays and display modes,
window creation + registry identity, window state round-trips, the window
surface life cycle, grab/mouse-rect/opacity, the screensaver, GL attribute
storage, and a tolerated popup-window probe. This is the first test group that
calls `Sdl.init`; it does not `Sdl.quit` afterwards. -/
def run : IO Unit := do
  Sdl.init .video

  -- drivers / theme
  check "getNumVideoDrivers >= 1" ((← getNumVideoDrivers) >= 1)
  check "getVideoDrivers contains dummy" ((← getVideoDrivers).contains "dummy")
  check "getCurrentVideoDriver == some dummy" ((← getCurrentVideoDriver) == some "dummy")
  let _ ← getSystemTheme
  check "getSystemTheme no-throw" true

  -- displays
  let displays ← getDisplays
  check "getDisplays nonempty" (!displays.isEmpty)
  let primary ← getPrimaryDisplay
  check "getPrimaryDisplay is a member" (displays.contains primary)
  check "display name nonempty" (!(← primary.name).isEmpty)
  check "display bounds w > 0" ((← primary.bounds).w > 0)
  check "display usableBounds w > 0" ((← primary.usableBounds).w > 0)
  let _ ← primary.naturalOrientation
  let _ ← primary.currentOrientation
  check "orientations no-throw" true
  check "display contentScale > 0" ((← primary.contentScale) > 0)
  let desktop ← primary.desktopMode
  check "desktopMode w > 0" (desktop.w > 0)
  check "desktopMode displayId round-trips" (desktop.displayId == primary)
  let _ ← primary.currentMode
  check "currentMode no-throw" true
  let _ ← primary.fullscreenModes
  check "fullscreenModes no-throw (dummy may be empty)" true
  let _ ← getDisplayForPoint ⟨0, 0⟩
  check "getDisplayForPoint no-throw" true

  -- window creation & registry identity
  let win ← createWindow "lean-sdl3 test" 320 240
  check "window id != 0" ((← win.id).val != 0)
  let wid ← win.id
  let fromId ← getWindowFromId wid
  win.setTitle "probe"
  match fromId with
  | some w2 =>
    check "getWindowFromId is some" true
    check "registry identity gate (fromId observes same window)"
      ((← w2.getTitle) == "probe")
  | none => check "getWindowFromId is some" false

  -- title / position / size round-trips (dummy honors exact positions)
  win.setTitle "lean-sdl3"
  check "title round-trip" ((← win.getTitle) == "lean-sdl3")
  win.setPosition 40 60
  check "position round-trip" ((← win.getPosition) == (40, 60))
  win.setMinimumSize 100 80
  check "minimumSize round-trip" ((← win.getMinimumSize) == (100, 80))
  win.setMaximumSize 800 600
  check "maximumSize round-trip" ((← win.getMaximumSize) == (800, 600))

  -- pixel density / scale (dummy: density 1.0)
  check "getSizeInPixels == getSize" ((← win.getSizeInPixels) == (← win.getSize))
  check "pixelDensity == 1.0" ((← win.pixelDensity) == 1.0)
  check "displayScale > 0" ((← win.displayScale) > 0)

  -- flags: not fullscreen, not minimized initially
  let fl ← win.flags
  check "no fullscreen flag initially" (!fl.has .fullscreen)
  check "no minimized flag initially" (!fl.has .minimized)

  -- misc queries
  let _ ← win.pixelFormat
  check "pixelFormat no-throw" true
  check "getSafeArea w > 0" ((← win.getSafeArea).w > 0)
  win.setAspectRatio 0 0
  let _ ← win.getAspectRatio
  check "getAspectRatio no-throw after setAspectRatio 0 0" true

  -- window surface life cycle (window is 320 wide)
  check "hasSurface false initially" (!(← win.hasSurface))
  let surf ← win.getSurface
  check "hasSurface true after getSurface" (← win.hasSurface)
  check "window surface width == 320" ((← surf.width) == 320)
  surf.fillRect none (← surf.mapRGBA 0 0 0 255)
  win.updateSurface
  check "updateSurface no-throw" true
  win.updateSurfaceRects #[⟨0, 0, 10, 10⟩]
  check "updateSurfaceRects no-throw" true
  win.destroySurface
  check "hasSurface false after destroySurface" (!(← win.hasSurface))

  -- window properties: set/read a custom string property through the M2 API
  let props ← win.getProperties
  props.setStringProperty "lean_sdl.test.key" "hello"
  check "window property round-trip"
    ((← props.getStringProperty "lean_sdl.test.key") == "hello")

  -- keyboard / mouse grab round-trips
  win.setKeyboardGrab true
  check "keyboardGrab true" (← win.getKeyboardGrab)
  win.setKeyboardGrab false
  check "keyboardGrab false" (!(← win.getKeyboardGrab))
  win.setMouseGrab true
  check "mouseGrab true" (← win.getMouseGrab)
  win.setMouseGrab false
  check "mouseGrab false" (!(← win.getMouseGrab))

  -- mouse confinement rect: none by default; the some/none round-trip is
  -- tolerated (the dummy driver's SetWindowMouseRect reports "not supported")
  check "mouseRect none by default" ((← win.getMouseRect) == none)
  try
    win.setMouseRect (some ⟨0, 0, 10, 10⟩)
    check "mouseRect some round-trip" ((← win.getMouseRect) == some ⟨0, 0, 10, 10⟩)
    win.setMouseRect none
    check "mouseRect none clears" ((← win.getMouseRect) == none)
  catch _ =>
    check "setMouseRect unsupported on dummy (tolerated)" true

  -- opacity
  check "opacity == 1.0" ((← win.getOpacity) == 1.0)

  -- screensaver: `disableScreenSaver` + query are observable, but the dummy
  -- driver's real suspend hook reports "not supported" from `enableScreenSaver`
  -- (SDL suspends the screensaver by default on video init), so tolerate it
  try
    disableScreenSaver
    check "screensaver disabled" (!(← screenSaverEnabled))
    enableScreenSaver
    check "screensaver enabled" (← screenSaverEnabled)
  catch _ =>
    check "screensaver toggle unsupported on dummy (tolerated)" true

  -- GL attribute storage: tolerated, because the dummy driver has no dynamic
  -- GL support ("No dynamic GL support in current SDL video driver (dummy)")
  try
    glSetAttribute .redSize 5
    check "glGetAttribute redSize == 5" ((← glGetAttribute .redSize) == 5)
    glResetAttributes
    check "glResetAttributes no-throw" true
  catch _ =>
    check "GL attribute API unsupported on dummy (tolerated)" true

  -- popup window: tolerated on the dummy driver
  win.setTitle "parent-probe"
  try
    let popup ← createPopupWindow win 10 10 50 50 .tooltip
    match (← popup.parent) with
    | some par =>
      check "popup parent identity via title probe" ((← par.getTitle) == "parent-probe")
    | none => check "popup parent identity via title probe" false
  catch _ =>
    check "popup unsupported on dummy (tolerated)" true

  -- size round-trip (after the surface tests so the window stays 320 wide above)
  win.setSize 400 300
  check "size round-trip" ((← win.getSize) == (400, 300))

  -- show / hide / raise / sync smoke
  win.«show»
  win.raise
  win.sync
  win.hide
  check "show/hide/raise/sync no-throw" true

end Tests.Video
