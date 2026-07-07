import Sdl.Core.Macros
import Sdl.Error

/-!
# Initialization and shutdown (`SDL_init.h`), version/platform info
(`SDL_version.h`, `SDL_platform.h`)
-/

namespace Sdl

/-- Subsystem initialization flags. C: `SDL_InitFlags`. -/
sdl_flags InitFlags : UInt32 where
  /-- Implies `events`. C: `SDL_INIT_AUDIO`. -/
  | audio    := 0x00000010
  /-- Implies `events`; main thread only. C: `SDL_INIT_VIDEO`. -/
  | video    := 0x00000020
  /-- Implies `events`. C: `SDL_INIT_JOYSTICK`. -/
  | joystick := 0x00000200
  /-- C: `SDL_INIT_HAPTIC`. -/
  | haptic   := 0x00001000
  /-- Implies `joystick`. C: `SDL_INIT_GAMEPAD`. -/
  | gamepad  := 0x00002000
  /-- C: `SDL_INIT_EVENTS`. -/
  | events   := 0x00004000
  /-- Implies `events`. C: `SDL_INIT_SENSOR`. -/
  | sensor   := 0x00008000
  /-- Implies `events`. C: `SDL_INIT_CAMERA`. -/
  | camera   := 0x00010000

/-- Result of an app lifecycle step (`Sdl.App`). C: `SDL_AppResult`. -/
sdl_enum AppResult : UInt32 where
  | «continue» => 0  -- C: SDL_APP_CONTINUE
  | success    => 1  -- C: SDL_APP_SUCCESS
  | failure    => 2  -- C: SDL_APP_FAILURE

@[extern "lean_sdl_init"]
private opaque initRaw (flags : UInt32) : IO Unit

/-- Initialize the subsystems in `flags`. Call on the main thread.
C: `SDL_Init`. -/
def init (flags : InitFlags) : IO Unit :=
  initRaw flags.val

@[extern "lean_sdl_init_sub_system"]
private opaque initSubSystemRaw (flags : UInt32) : IO Unit

/-- Initialize specific subsystems (reference-counted against
`quitSubSystem`). C: `SDL_InitSubSystem`. -/
def initSubSystem (flags : InitFlags) : IO Unit :=
  initSubSystemRaw flags.val

@[extern "lean_sdl_quit_sub_system"]
private opaque quitSubSystemRaw (flags : UInt32) : IO Unit

/-- Shut down specific subsystems. C: `SDL_QuitSubSystem`. -/
def quitSubSystem (flags : InitFlags) : IO Unit :=
  quitSubSystemRaw flags.val

@[extern "lean_sdl_was_init"]
private opaque wasInitRaw (flags : UInt32) : IO UInt32

/-- Which of the queried subsystems are currently initialized (query all with
the default `.none`). C: `SDL_WasInit`. -/
def wasInit (flags : InitFlags := .none) : IO InitFlags :=
  return ⟨← wasInitRaw flags.val⟩

/-- Shut down all SDL subsystems. Call on the main thread. C: `SDL_Quit`. -/
@[extern "lean_sdl_quit"]
opaque quit : IO Unit

/-- Whether this is the thread that ran `main`. C: `SDL_IsMainThread`. -/
@[extern "lean_sdl_is_main_thread"]
opaque isMainThread : IO Bool

@[extern "lean_sdl_run_on_main_thread"]
private opaque runOnMainThreadRaw (f : IO Unit) (waitComplete : Bool) : IO Unit

/-- Run `f` on the main thread during event processing. If called *on* the main
thread, `f` runs immediately (synchronously). If called from another thread, it
is queued and runs the next time the main thread processes events — so the main
thread must be pumping events (`Sdl.pumpEvents`) for it to fire; with
`waitComplete := true` (the default) this call blocks until it has.

Any exception raised by `f` is swallowed (there is nowhere for it to propagate
from an SDL callback) and logged via `SDL_Log`. Throws if SDL could not schedule
the call. Beware deadlocks: do not have the main thread wait on this thread while
calling with `waitComplete := true`. C: `SDL_RunOnMainThread`. -/
def runOnMainThread (f : IO Unit) (waitComplete : Bool := true) : IO Unit :=
  runOnMainThreadRaw f waitComplete

/-- Set basic app metadata (shown by the OS in audio mixers, about dialogs…).
Call before `Sdl.init`. C: `SDL_SetAppMetadata`. -/
@[extern "lean_sdl_set_app_metadata"]
opaque setAppMetadata (appName appVersion appIdentifier : @& String) : IO Unit

/-- Set one metadata property (`SDL_PROP_APP_METADATA_*` names). Call before
`Sdl.init`. C: `SDL_SetAppMetadataProperty`. -/
@[extern "lean_sdl_set_app_metadata_property"]
opaque setAppMetadataProperty (name value : @& String) : IO Unit

/-- Get one metadata property. C: `SDL_GetAppMetadataProperty`. -/
@[extern "lean_sdl_get_app_metadata_property"]
opaque getAppMetadataProperty (name : @& String) : IO (Option String)

/-- SDL version triple. C: `SDL_GetVersion` packs it as
`major * 1000000 + minor * 1000 + micro`. -/
structure Version where
  major : UInt32
  minor : UInt32
  micro : UInt32
deriving BEq, Repr, Inhabited

instance : ToString Version where
  toString v := s!"{v.major}.{v.minor}.{v.micro}"

@[extern "lean_sdl_get_version"]
private opaque getVersionRaw : IO UInt32

/-- Version of the dynamically linked SDL library. C: `SDL_GetVersion`. -/
def getVersion : IO Version := do
  let v ← getVersionRaw
  return { major := v / 1000000, minor := (v / 1000) % 1000, micro := v % 1000 }

/-- Source revision of the linked SDL library. C: `SDL_GetRevision`. -/
@[extern "lean_sdl_get_revision"]
opaque getRevision : IO String

/-- Platform name, e.g. `"macOS"`. C: `SDL_GetPlatform`. -/
@[extern "lean_sdl_get_platform"]
opaque getPlatform : IO String

end Sdl
