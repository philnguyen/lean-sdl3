import Sdl
import Tests.Harness

/-!
# Camera runtime tests

Run under the **dummy** camera driver (`SDL_CAMERA_DRIVER=dummy`), which
initializes headless and exposes zero devices — so open/acquire/frame paths
cannot be exercised at runtime and are verified by review only. These tests
cover driver enumeration, the (empty but non-failing) device list, the
error/throw behavior of every id-level query against a bogus id, and the
`CameraPermissionState.ofInt?` round-trip.

Never point at the real `coremedia` driver: it triggers a macOS permission
prompt.
-/

namespace Tests.Camera
open Sdl Tests.Harness

/-- Driver enumeration and the empty (but non-throwing) device list. -/
def driverTests : IO Unit := do
  check "getNumCameraDrivers ≥ 1" ((← getNumCameraDrivers) ≥ 1)
  check "cameraDrivers contains dummy" ((← cameraDrivers).contains "dummy")
  check "currentCameraDriver == some dummy" ((← currentCameraDriver) == some "dummy")
  check "getCameras == #[] (empty, not a throw)" ((← getCameras) == #[])

/-- Every id-level query throws for a bogus instance id (the last exercises the
`SDL_GetCameraPosition` ClearError disambiguation: 0 == a valid `unknown`, so
the shim must consult the error string to know it failed). -/
def bogusIdTests : IO Unit := do
  let bogus : CameraId := ⟨0xDEADBEEF⟩
  checkThrows "CameraId.name bogus id throws" bogus.name
  checkThrows "CameraId.supportedFormats bogus id throws" bogus.supportedFormats
  checkThrows "openCamera bogus id throws" (openCamera bogus)
  checkThrows "CameraId.position bogus id throws (ClearError trick)" bogus.position

/-- `CameraPermissionState.ofInt?` round-trips the three C values and rejects
out-of-range input (also covered by `#guard`s in `Sdl/Camera.lean`). -/
def permissionStateTests : IO Unit := do
  check "ofInt? -1 == denied"   (CameraPermissionState.ofInt? (-1) == some .denied)
  check "ofInt? 0 == pending"   (CameraPermissionState.ofInt? 0 == some .pending)
  check "ofInt? 1 == approved"  (CameraPermissionState.ofInt? 1 == some .approved)
  check "ofInt? 5 == none"      (CameraPermissionState.ofInt? 5 == none)

/-- Camera tests (run under `SDL_VIDEO_DRIVER=dummy SDL_AUDIO_DRIVER=dummy`).
Forces the dummy camera driver via a hint, initializes the camera subsystem,
runs the checks, then quits just the camera subsystem at the end. -/
def run : IO Unit := do
  -- `SDL_SetHint` fails when the same-named env var is already set (env takes
  -- priority), so only set the hint when the smoke-script env isn't present.
  if (← IO.getEnv "SDL_CAMERA_DRIVER").isNone then
    Sdl.setHint Sdl.Hint.cameraDriver "dummy"
  Sdl.initSubSystem .camera
  driverTests
  bogusIdTests
  permissionStateTests
  Sdl.quitSubSystem .camera

end Tests.Camera
