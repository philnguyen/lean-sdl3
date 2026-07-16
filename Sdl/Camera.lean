module

public import Sdl.Core.Macros
public meta import Sdl.Core.Macros
public import Sdl.Error
public meta import Sdl.Error
public import Sdl.Properties
public meta import Sdl.Properties
public import Sdl.Pixels
public meta import Sdl.Pixels
public import Sdl.Surface
public meta import Sdl.Surface
public import Sdl.Events
public meta import Sdl.Events

public section

/-!
# Cameras (`SDL_camera.h`)

Video capture: enumerate, query, and open camera devices, then pull
`SDL_Surface` frames as they arrive. `SDL_Init` must have been called with
`SDL_INIT_CAMERA` before opening cameras.

## Ownership

`Camera` is an **owned root, finalizer-only**: the finalizer runs
`SDL_CloseCamera` and the holder's `owner` is always `NULL`. There is
deliberately **no** `Camera.close`: a frame acquired from a camera holds an
*owned* reference to the camera's external object (release-to-source
archetype), and reference-counting order guarantees every frame is released
before the camera is closed. Exposing a manual close would let a frame be left
pointing at a freed camera. `SDL_Camera` is *not* internally refcounted, so no
"re-open by id" convenience exists.

A **camera frame** is an `SDL_Surface *` owned by the camera. It is surfaced to
Lean as a plain `Surface` backed by a distinct external class
(`lean_sdl_camera_frame`) whose finalizer calls `SDL_ReleaseCameraFrame` rather
than `SDL_DestroySurface`. `Camera.releaseFrame` is a manual release that NULLs
the handle (later `Surface` ops on it throw); frames are also released at GC,
but prompt release matters — SDL keeps only a small FIFO of frame buffers.
-/

namespace Sdl

-- `CameraId` (C: `SDL_CameraID`) is defined in `Sdl/Events.lean` because event
-- payloads carry it; this module extends its namespace with the id-level
-- queries.

/-- The details of an output format for a camera device. C: `SDL_CameraSpec`. -/
structure CameraSpec where
  /-- Frame pixel format. -/
  format : PixelFormat
  /-- Frame colorspace. -/
  colorspace : Colorspace
  /-- Frame width, in pixels. -/
  width : Int32
  /-- Frame height, in pixels. -/
  height : Int32
  /-- Frame rate numerator (`num / denom == FPS`). -/
  framerateNumerator : Int32
  /-- Frame rate denominator (`num / denom == FPS`). -/
  framerateDenominator : Int32
deriving Repr, Inhabited, BEq

/-- Maker called from C to hand a `CameraSpec` back to Lean (flattened scalars;
the raw format/colorspace values are decoded with the total `ofVal`). -/
@[export lean_sdl_mk_camera_spec]
private def mkCameraSpec (format colorspace : UInt32)
    (width height num den : Int32) : CameraSpec :=
  { format := PixelFormat.ofVal format, colorspace := Colorspace.ofVal colorspace,
    width, height, framerateNumerator := num, framerateDenominator := den }

/-- The position of a camera in relation to the system device. C:
`SDL_CameraPosition`. -/
sdl_enum CameraPosition : UInt32 where
  | unknown     => 0  -- C: SDL_CAMERA_POSITION_UNKNOWN
  | frontFacing => 1  -- C: SDL_CAMERA_POSITION_FRONT_FACING
  | backFacing  => 2  -- C: SDL_CAMERA_POSITION_BACK_FACING

/-- The current state of a request for camera access. C:
`SDL_CameraPermissionState`. C values: `denied = -1`, `pending = 0`,
`approved = 1` (a negative member → hand-rolled instead of `sdl_enum`, whose
raw type is `UInt32`). -/
inductive CameraPermissionState where
  | denied | pending | approved
deriving Repr, BEq, Inhabited, DecidableEq

/-- Decode the raw C `SDL_CameraPermissionState` (an `int`). The shim returns
the raw `Int32`; the wrapper throws on `none` (unreachable in practice, as SDL
only ever returns `-1`/`0`/`1`). -/
def CameraPermissionState.ofInt? (v : Int32) : Option CameraPermissionState :=
  if v == -1 then some .denied
  else if v == 0 then some .pending
  else if v == 1 then some .approved
  else none

#guard CameraPermissionState.ofInt? (-1) == some .denied
#guard CameraPermissionState.ofInt? 0 == some .pending
#guard CameraPermissionState.ofInt? 1 == some .approved
#guard CameraPermissionState.ofInt? 5 == none

/-- An opened camera device. C: `SDL_Camera`. -/
sdl_opaque Camera

@[extern "lean_sdl_camera_register_classes"]
private opaque registerClasses : IO Unit

initialize registerClasses

/-- Maker called from C to pair an acquired frame `Surface` with its timestamp,
so C never lays out a `Prod` constructor (precedent: `mkScancodeKeymod`). -/
@[export lean_sdl_mk_surface_timestamp]
private def mkSurfaceTimestamp (s : Surface) (ts : UInt64) : Surface × UInt64 := (s, ts)

/-! ## Drivers -/

/-- The number of camera drivers compiled into SDL.
C: `SDL_GetNumCameraDrivers`. -/
@[extern "lean_sdl_get_num_camera_drivers"]
opaque getNumCameraDrivers : IO Int32

/-- The name of the built-in camera driver at `index` (a simple low-ASCII id
like `"coremedia"`/`"v4l2"`), or `none` if `index` is out of range.
C: `SDL_GetCameraDriver`. -/
@[extern "lean_sdl_get_camera_driver"]
opaque getCameraDriver (index : Int32) : IO (Option String)

/-- The names of all built-in camera drivers, in initialization-check order.
Convenience loop over `getNumCameraDrivers` / `getCameraDriver`. -/
def cameraDrivers : IO (Array String) := do
  let n ← getNumCameraDrivers
  let mut drivers := #[]
  for i in [0:n.toNatClampNeg] do
    if let some name ← getCameraDriver (Int32.ofNat i) then
      drivers := drivers.push name
  return drivers

/-- The name of the currently initialized camera driver, or `none` if the
camera subsystem is not initialized. C: `SDL_GetCurrentCameraDriver`. -/
@[extern "lean_sdl_get_current_camera_driver"]
opaque currentCameraDriver : IO (Option String)

/-! ## Enumeration and opening -/

@[extern "lean_sdl_get_cameras"]
private opaque getCamerasRaw : IO (Array UInt32)

/-- The currently-connected camera devices. Throws on failure (an *empty* array
is a normal result, not a failure). C: `SDL_GetCameras`. -/
def getCameras : IO (Array CameraId) := do
  return (← getCamerasRaw).map (⟨·⟩)

@[extern "lean_sdl_open_camera"]
private opaque openCameraRaw (id : UInt32) (hasSpec : UInt8)
  (format colorspace : UInt32) (w h num den : Int32) : IO Camera

/-- Open a camera device. With `spec = none`, SDL chooses a native format (query
it with `Camera.getFormat`); otherwise SDL converts frames to the requested
`spec`. The camera is not usable until the user approves access — poll
`Camera.getPermissionState` or wait for an approval event. Throws if `id` is not
valid. C: `SDL_OpenCamera`. -/
def openCamera (id : CameraId) (spec : Option CameraSpec := none) : IO Camera :=
  match spec with
  | some s => openCameraRaw id.val 1 s.format.val s.colorspace.val
      s.width s.height s.framerateNumerator s.framerateDenominator
  | none => openCameraRaw id.val 0 0 0 0 0 0 0

namespace CameraId

@[extern "lean_sdl_get_camera_name"]
private opaque nameRaw (id : UInt32) : IO String

/-- The human-readable device name for a camera. Throws if the id is not valid.
C: `SDL_GetCameraName`. -/
def name (self : CameraId) : IO String := nameRaw self.val

@[extern "lean_sdl_get_camera_position"]
private opaque positionRaw (id : UInt32) : IO UInt32

/-- The position of the camera in relation to the system (front/back facing on
mobile devices; usually `unknown` on desktops). Throws if the id is not valid.

Note: `SDL_GetCameraPosition` returns `0` (`unknown`, a *valid* value) both for
a genuine "unknown" camera and on error, distinguishing them only via
`SDL_GetError`. The shim clears the error first and treats a `0` result with a
non-empty error string as a failure. C: `SDL_GetCameraPosition`. -/
def position (self : CameraId) : IO CameraPosition := do
  match CameraPosition.ofVal? (← positionRaw self.val) with
  | some p => pure p
  | none => throw (IO.userError "SDL: unknown camera position value")

@[extern "lean_sdl_get_camera_supported_formats"]
private opaque supportedFormatsRaw (id : UInt32) : IO (Array CameraSpec)

/-- The native formats/sizes a camera supports without conversion. May legally
be empty (e.g. on Emscripten, or before the device is opened on some backends).
Throws if the id is not valid. C: `SDL_GetCameraSupportedFormats`. -/
def supportedFormats (self : CameraId) : IO (Array CameraSpec) :=
  supportedFormatsRaw self.val

end CameraId

namespace Camera

@[extern "lean_sdl_get_camera_permission_state"]
private opaque getPermissionStateRaw (self : @& Camera) : IO Int32

/-- Whether camera access has been approved by the user: `pending` while
waiting, `approved` once granted, `denied` if refused. Throws only on the
unreachable case of an unrecognized raw value. C:
`SDL_GetCameraPermissionState`. -/
def getPermissionState (self : @& Camera) : IO CameraPermissionState := do
  match CameraPermissionState.ofInt? (← getPermissionStateRaw self) with
  | some s => pure s
  | none => throw (IO.userError "SDL: unknown camera permission state")

@[extern "lean_sdl_get_camera_id"]
private opaque getIDRaw (self : @& Camera) : IO UInt32

/-- The instance id of the opened camera. Throws (`0`) on failure.
C: `SDL_GetCameraID`. -/
def getID (self : @& Camera) : IO CameraId := do return ⟨← getIDRaw self⟩

/-- The properties associated with the camera. Borrowed: tied to the camera's
lifetime, never destroyed from Lean. Throws on failure.
C: `SDL_GetCameraProperties`. -/
@[extern "lean_sdl_get_camera_properties"]
opaque getProperties (self : @& Camera) : IO Properties

/-- The spec the camera is using to generate images (may differ from the native
hardware format if SDL is converting). Throws on failure — notably while the
system is still waiting for the user to approve access.
C: `SDL_GetCameraFormat`. -/
@[extern "lean_sdl_get_camera_format"]
opaque getFormat (self : @& Camera) : IO CameraSpec

/-- Acquire the next available frame together with its timestamp (nanoseconds),
or `none` if no new frame is ready yet (a non-blocking poll; `none` is normal,
not an error — it also occurs while access is still pending). A newly-opened
camera commonly delivers several black or under-exposed frames first, so drop
the first few if capturing automatically. Release the frame promptly with
`releaseFrame` (or let GC do it) so SDL can reuse its small frame pool.
C: `SDL_AcquireCameraFrame`. -/
@[extern "lean_sdl_acquire_camera_frame"]
opaque acquireFrame (self : @& Camera) : IO (Option (Surface × UInt64))

/-- Release a frame previously returned by `acquireFrame`, returning its buffer
to the camera. The `Surface` must not be used afterwards. Prompt release
matters: SDL keeps only a small FIFO of frame buffers and may drop incoming
frames if they are not returned in time. Throws if `frame` is not a camera
frame, was already released, or does not belong to this camera.
C: `SDL_ReleaseCameraFrame`. -/
@[extern "lean_sdl_release_camera_frame"]
opaque releaseFrame (self : @& Camera) (frame : @& Surface) : IO Unit

end Camera
end Sdl

end
