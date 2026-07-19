import Sdl
import Tests.Harness

namespace Tests.Mouse
open Sdl Tests.Harness

/-- Mouse-state and cursor tests (run under `SDL_VIDEO_DRIVER=dummy`). Exercises
the device queries, the cached mouse state (strict), the global/relative state
and warps/capture (tolerated on the dummy driver), cursor creation/set/query,
the generic cursor-visibility flag (strict), relative-mouse mode, and the
`MouseButtonFlags.mask` helper. -/
def run : IO Unit := do
  Sdl.init .video
  let win ← createWindow "mouse" 64 64

  -- devices
  let _ ← hasMouse
  check "hasMouse no-throw" true
  let _ ← getMice
  check "getMice no-throw" true
  let _ ← getMouseFocus
  check "getMouseFocus no-throw" true

  -- state
  let (flags, _, _) ← getMouseState
  check "getMouseState flags == none" (flags == .none)
  let _ ← getRelativeMouseState
  check "getRelativeMouseState no-throw" true
  try
    let _ ← getGlobalMouseState
    check "getGlobalMouseState no-throw (tolerated)" true
  catch _ =>
    check "getGlobalMouseState unsupported on dummy (tolerated)" true

  -- warps / capture
  win.warpMouse 10 10
  check "warpMouse no-throw" true
  try
    warpMouseGlobal 10 10
    check "warpMouseGlobal no-throw (tolerated)" true
  catch _ =>
    check "warpMouseGlobal unsupported on dummy (tolerated)" true
  try
    captureMouse true
    captureMouse false
    check "captureMouse no-throw (tolerated)" true
  catch _ =>
    check "captureMouse unsupported on dummy (tolerated)" true

  -- cursors: a hand-built transparent 16x16 bitmap (2 bytes/row * 16 rows)
  let mut bytes := ByteArray.emptyWithCapacity 32
  for _ in [0:32] do
    bytes := bytes.push 0
  try
    let cur ← createCursor bytes bytes 16 16 0 0
    setCursor cur
    check "getCursor isSome after setCursor" ((← getCursor).isSome)
    -- identity + safety: the returned handle is the retained active cursor, so
    -- it stays valid even after the active slot moves on to another cursor
    let got ← getCursor
    let cur2 ← createCursor bytes bytes 16 16 0 0
    setCursor cur2
    match got with
    | some g => setCursor g  -- would deref a freed cursor before the fix
    | none => check "getCursor identity handle usable" false
    setCursor cur2
    redrawCursor
    check "createCursor/setCursor/redrawCursor no-throw" true
  catch _ =>
    check "cursor create/set unsupported on dummy (tolerated)" true
  try
    let _ ← createSystemCursor .crosshair
    check "createSystemCursor no-throw (tolerated)" true
  catch _ =>
    check "createSystemCursor unsupported on dummy (tolerated)" true
  try
    let _ ← getDefaultCursor
    check "getDefaultCursor no-throw (tolerated)" true
  catch _ =>
    check "getDefaultCursor unsupported on dummy (tolerated)" true

  -- cursor visibility (generic SDL state)
  hideCursor
  check "cursorVisible false after hide" (!(← cursorVisible))
  showCursor
  check "cursorVisible true after show" (← cursorVisible)

  -- relative mouse mode
  try
    win.setRelativeMouseMode true
    check "relativeMouseMode true (tolerated)" (← win.relativeMouseMode)
    win.setRelativeMouseMode false
  catch _ =>
    check "relativeMouseMode unsupported on dummy (tolerated)" true

  -- flag mask helper
  check "MouseButtonFlags.mask .x2 == .x2" (MouseButtonFlags.mask .x2 == .x2)

end Tests.Mouse
