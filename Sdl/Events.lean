import Sdl.Core.Macros
import Sdl.Error
import Sdl.Keyboard
import Sdl.Mouse
import Sdl.Touch
import Sdl.Pen
import Sdl.Power
import Sdl.Video

/-!
# Event queue and the `SDL_Event` union (`SDL_events.h`)

The centerpiece of the input story: a total Lean `Event` inductive decoded from
the 128-byte `SDL_Event` C union, plus the event-queue API (poll/wait/push/
pump/flush/enable).

## Decode architecture (`docs/DESIGN.md` §"Event decode")

One C switch (`ffi/events.c`) over `event->type` calls the `@[export]`ed maker
functions below with flattened, unboxed scalars — **C never calls
`lean_alloc_ctor` for an event; the Lean compiler owns constructor layout.**
The raw `type` → constructor dispatch happens in *pure Lean* inside each maker
(so it is `#guard`-testable). Every maker's fallback arm is `.unknown type
⟨timestamp⟩`, so a C/Lean range mismatch can never panic; decoding is total.

String fields are copied eagerly on the C side (`lean_mk_string`) — their C
pointers die at the next poll, so they must not be retained across the FFI
boundary.

## Skipped (with rationale)

* `SDL_PeepEvents` — batch queue surgery (peek/add-at-range); niche and its
  `SDL_EventAction` enum is only used by it.
* `SDL_GetEventFilter` — returns the C function pointer/userdata pair, which is
  always the binding's own trampoline; meaningless in Lean (track your own
  filter if you need it back).
* `SDL_GetWindowFromEvent` — use `Event.windowId` together with
  `Sdl.getWindowFromId`.
* `SDL_GetEventDescription` — needs the raw union post-decode; `Repr` on `Event`
  covers the debugging use.
-/

namespace Sdl

/-! ## ID types for domains whose home subsystem arrives later

These 1-field id wrappers are defined here (rather than in their eventual home
module, M9/M10/M11) because event payloads carry them. -/

/-- A joystick instance id. `0` is never a valid id. Home subsystem arrives in
M10; defined here because event payloads carry it. C: `SDL_JoystickID`. -/
sdl_id JoystickId : UInt32

/-- An audio device instance id. `0` is never a valid id. Home subsystem arrives
in M9; defined here because event payloads carry it. C: `SDL_AudioDeviceID`. -/
sdl_id AudioDeviceId : UInt32

/-- A sensor instance id. `0` is never a valid id. Home subsystem arrives in
M11; defined here because event payloads carry it. C: `SDL_SensorID`. -/
sdl_id SensorId : UInt32

/-- A camera instance id. `0` is never a valid id. Home subsystem arrives in
M11; defined here because event payloads carry it. C: `SDL_CameraID`. -/
sdl_id CameraId : UInt32

/-! ## Event types

`SDL_EventType` is an *open* numeric domain (user events extend it past
`0x8000`), so it is modelled as an `sdl_id` rather than an `sdl_enum`. Every
named member is included EXCEPT the reserved-private range
`SDL_EVENT_PRIVATE0..3` (0x4000–0x4003), the `SDL_EVENT_ENUM_PADDING` sizing
marker, and the `SDL_EVENT_DISPLAY_FIRST`/`_LAST` and
`SDL_EVENT_WINDOW_FIRST`/`_LAST` range aliases (they duplicate the values of
the first/last member of each range). `SDL_EVENT_FIRST`, `SDL_EVENT_LAST`,
`SDL_EVENT_POLL_SENTINEL`, and `SDL_EVENT_USER` are genuine standalone values
and are kept. -/

/-- A kind of event delivered through the queue. Open numeric domain (user
events extend it). C: `SDL_EventType`. -/
sdl_id EventType : UInt32 where
  | first                       := 0x0     -- C: SDL_EVENT_FIRST (range queries)
  -- Application events
  | quit                        := 0x100   -- C: SDL_EVENT_QUIT
  | terminating                 := 0x101   -- C: SDL_EVENT_TERMINATING
  | lowMemory                   := 0x102   -- C: SDL_EVENT_LOW_MEMORY
  | willEnterBackground         := 0x103   -- C: SDL_EVENT_WILL_ENTER_BACKGROUND
  | didEnterBackground          := 0x104   -- C: SDL_EVENT_DID_ENTER_BACKGROUND
  | willEnterForeground         := 0x105   -- C: SDL_EVENT_WILL_ENTER_FOREGROUND
  | didEnterForeground          := 0x106   -- C: SDL_EVENT_DID_ENTER_FOREGROUND
  | localeChanged               := 0x107   -- C: SDL_EVENT_LOCALE_CHANGED
  | systemThemeChanged          := 0x108   -- C: SDL_EVENT_SYSTEM_THEME_CHANGED
  -- Display events
  | displayOrientation          := 0x151   -- C: SDL_EVENT_DISPLAY_ORIENTATION
  | displayAdded                := 0x152   -- C: SDL_EVENT_DISPLAY_ADDED
  | displayRemoved              := 0x153   -- C: SDL_EVENT_DISPLAY_REMOVED
  | displayMoved                := 0x154   -- C: SDL_EVENT_DISPLAY_MOVED
  | displayDesktopModeChanged   := 0x155   -- C: SDL_EVENT_DISPLAY_DESKTOP_MODE_CHANGED
  | displayCurrentModeChanged   := 0x156   -- C: SDL_EVENT_DISPLAY_CURRENT_MODE_CHANGED
  | displayContentScaleChanged  := 0x157   -- C: SDL_EVENT_DISPLAY_CONTENT_SCALE_CHANGED
  | displayUsableBoundsChanged  := 0x158   -- C: SDL_EVENT_DISPLAY_USABLE_BOUNDS_CHANGED
  -- Window events
  | windowShown                 := 0x202   -- C: SDL_EVENT_WINDOW_SHOWN
  | windowHidden                := 0x203   -- C: SDL_EVENT_WINDOW_HIDDEN
  | windowExposed               := 0x204   -- C: SDL_EVENT_WINDOW_EXPOSED
  | windowMoved                 := 0x205   -- C: SDL_EVENT_WINDOW_MOVED
  | windowResized               := 0x206   -- C: SDL_EVENT_WINDOW_RESIZED
  | windowPixelSizeChanged      := 0x207   -- C: SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED
  | windowMetalViewResized      := 0x208   -- C: SDL_EVENT_WINDOW_METAL_VIEW_RESIZED
  | windowMinimized             := 0x209   -- C: SDL_EVENT_WINDOW_MINIMIZED
  | windowMaximized             := 0x20A   -- C: SDL_EVENT_WINDOW_MAXIMIZED
  | windowRestored              := 0x20B   -- C: SDL_EVENT_WINDOW_RESTORED
  | windowMouseEnter            := 0x20C   -- C: SDL_EVENT_WINDOW_MOUSE_ENTER
  | windowMouseLeave            := 0x20D   -- C: SDL_EVENT_WINDOW_MOUSE_LEAVE
  | windowFocusGained           := 0x20E   -- C: SDL_EVENT_WINDOW_FOCUS_GAINED
  | windowFocusLost             := 0x20F   -- C: SDL_EVENT_WINDOW_FOCUS_LOST
  | windowCloseRequested        := 0x210   -- C: SDL_EVENT_WINDOW_CLOSE_REQUESTED
  | windowHitTest               := 0x211   -- C: SDL_EVENT_WINDOW_HIT_TEST
  | windowIccprofChanged        := 0x212   -- C: SDL_EVENT_WINDOW_ICCPROF_CHANGED
  | windowDisplayChanged        := 0x213   -- C: SDL_EVENT_WINDOW_DISPLAY_CHANGED
  | windowDisplayScaleChanged   := 0x214   -- C: SDL_EVENT_WINDOW_DISPLAY_SCALE_CHANGED
  | windowSafeAreaChanged       := 0x215   -- C: SDL_EVENT_WINDOW_SAFE_AREA_CHANGED
  | windowOccluded              := 0x216   -- C: SDL_EVENT_WINDOW_OCCLUDED
  | windowEnterFullscreen       := 0x217   -- C: SDL_EVENT_WINDOW_ENTER_FULLSCREEN
  | windowLeaveFullscreen       := 0x218   -- C: SDL_EVENT_WINDOW_LEAVE_FULLSCREEN
  | windowDestroyed             := 0x219   -- C: SDL_EVENT_WINDOW_DESTROYED
  | windowHdrStateChanged       := 0x21A   -- C: SDL_EVENT_WINDOW_HDR_STATE_CHANGED
  -- Keyboard events
  | keyDown                     := 0x300   -- C: SDL_EVENT_KEY_DOWN
  | keyUp                       := 0x301   -- C: SDL_EVENT_KEY_UP
  | textEditing                 := 0x302   -- C: SDL_EVENT_TEXT_EDITING
  | textInput                   := 0x303   -- C: SDL_EVENT_TEXT_INPUT
  | keymapChanged               := 0x304   -- C: SDL_EVENT_KEYMAP_CHANGED
  | keyboardAdded               := 0x305   -- C: SDL_EVENT_KEYBOARD_ADDED
  | keyboardRemoved             := 0x306   -- C: SDL_EVENT_KEYBOARD_REMOVED
  | textEditingCandidates       := 0x307   -- C: SDL_EVENT_TEXT_EDITING_CANDIDATES
  | screenKeyboardShown         := 0x308   -- C: SDL_EVENT_SCREEN_KEYBOARD_SHOWN
  | screenKeyboardHidden        := 0x309   -- C: SDL_EVENT_SCREEN_KEYBOARD_HIDDEN
  -- Mouse events
  | mouseMotion                 := 0x400   -- C: SDL_EVENT_MOUSE_MOTION
  | mouseButtonDown             := 0x401   -- C: SDL_EVENT_MOUSE_BUTTON_DOWN
  | mouseButtonUp               := 0x402   -- C: SDL_EVENT_MOUSE_BUTTON_UP
  | mouseWheel                  := 0x403   -- C: SDL_EVENT_MOUSE_WHEEL
  | mouseAdded                  := 0x404   -- C: SDL_EVENT_MOUSE_ADDED
  | mouseRemoved                := 0x405   -- C: SDL_EVENT_MOUSE_REMOVED
  -- Joystick events
  | joystickAxisMotion          := 0x600   -- C: SDL_EVENT_JOYSTICK_AXIS_MOTION
  | joystickBallMotion          := 0x601   -- C: SDL_EVENT_JOYSTICK_BALL_MOTION
  | joystickHatMotion           := 0x602   -- C: SDL_EVENT_JOYSTICK_HAT_MOTION
  | joystickButtonDown          := 0x603   -- C: SDL_EVENT_JOYSTICK_BUTTON_DOWN
  | joystickButtonUp            := 0x604   -- C: SDL_EVENT_JOYSTICK_BUTTON_UP
  | joystickAdded               := 0x605   -- C: SDL_EVENT_JOYSTICK_ADDED
  | joystickRemoved             := 0x606   -- C: SDL_EVENT_JOYSTICK_REMOVED
  | joystickBatteryUpdated      := 0x607   -- C: SDL_EVENT_JOYSTICK_BATTERY_UPDATED
  | joystickUpdateComplete      := 0x608   -- C: SDL_EVENT_JOYSTICK_UPDATE_COMPLETE
  -- Gamepad events
  | gamepadAxisMotion           := 0x650   -- C: SDL_EVENT_GAMEPAD_AXIS_MOTION
  | gamepadButtonDown           := 0x651   -- C: SDL_EVENT_GAMEPAD_BUTTON_DOWN
  | gamepadButtonUp             := 0x652   -- C: SDL_EVENT_GAMEPAD_BUTTON_UP
  | gamepadAdded                := 0x653   -- C: SDL_EVENT_GAMEPAD_ADDED
  | gamepadRemoved              := 0x654   -- C: SDL_EVENT_GAMEPAD_REMOVED
  | gamepadRemapped             := 0x655   -- C: SDL_EVENT_GAMEPAD_REMAPPED
  | gamepadTouchpadDown         := 0x656   -- C: SDL_EVENT_GAMEPAD_TOUCHPAD_DOWN
  | gamepadTouchpadMotion       := 0x657   -- C: SDL_EVENT_GAMEPAD_TOUCHPAD_MOTION
  | gamepadTouchpadUp           := 0x658   -- C: SDL_EVENT_GAMEPAD_TOUCHPAD_UP
  | gamepadSensorUpdate         := 0x659   -- C: SDL_EVENT_GAMEPAD_SENSOR_UPDATE
  | gamepadUpdateComplete       := 0x65A   -- C: SDL_EVENT_GAMEPAD_UPDATE_COMPLETE
  | gamepadSteamHandleUpdated   := 0x65B   -- C: SDL_EVENT_GAMEPAD_STEAM_HANDLE_UPDATED
  -- Touch events
  | fingerDown                  := 0x700   -- C: SDL_EVENT_FINGER_DOWN
  | fingerUp                    := 0x701   -- C: SDL_EVENT_FINGER_UP
  | fingerMotion                := 0x702   -- C: SDL_EVENT_FINGER_MOTION
  | fingerCanceled              := 0x703   -- C: SDL_EVENT_FINGER_CANCELED
  -- Pinch events
  | pinchBegin                  := 0x710   -- C: SDL_EVENT_PINCH_BEGIN
  | pinchUpdate                 := 0x711   -- C: SDL_EVENT_PINCH_UPDATE
  | pinchEnd                    := 0x712   -- C: SDL_EVENT_PINCH_END
  -- Clipboard events
  | clipboardUpdate             := 0x900   -- C: SDL_EVENT_CLIPBOARD_UPDATE
  -- Drag and drop events
  | dropFile                    := 0x1000  -- C: SDL_EVENT_DROP_FILE
  | dropText                    := 0x1001  -- C: SDL_EVENT_DROP_TEXT
  | dropBegin                   := 0x1002  -- C: SDL_EVENT_DROP_BEGIN
  | dropComplete                := 0x1003  -- C: SDL_EVENT_DROP_COMPLETE
  | dropPosition                := 0x1004  -- C: SDL_EVENT_DROP_POSITION
  -- Audio hotplug events
  | audioDeviceAdded            := 0x1100  -- C: SDL_EVENT_AUDIO_DEVICE_ADDED
  | audioDeviceRemoved          := 0x1101  -- C: SDL_EVENT_AUDIO_DEVICE_REMOVED
  | audioDeviceFormatChanged    := 0x1102  -- C: SDL_EVENT_AUDIO_DEVICE_FORMAT_CHANGED
  -- Sensor events
  | sensorUpdate                := 0x1200  -- C: SDL_EVENT_SENSOR_UPDATE
  -- Pressure-sensitive pen events
  | penProximityIn              := 0x1300  -- C: SDL_EVENT_PEN_PROXIMITY_IN
  | penProximityOut             := 0x1301  -- C: SDL_EVENT_PEN_PROXIMITY_OUT
  | penDown                     := 0x1302  -- C: SDL_EVENT_PEN_DOWN
  | penUp                       := 0x1303  -- C: SDL_EVENT_PEN_UP
  | penButtonDown               := 0x1304  -- C: SDL_EVENT_PEN_BUTTON_DOWN
  | penButtonUp                 := 0x1305  -- C: SDL_EVENT_PEN_BUTTON_UP
  | penMotion                   := 0x1306  -- C: SDL_EVENT_PEN_MOTION
  | penAxis                     := 0x1307  -- C: SDL_EVENT_PEN_AXIS
  -- Camera hotplug events
  | cameraDeviceAdded           := 0x1400  -- C: SDL_EVENT_CAMERA_DEVICE_ADDED
  | cameraDeviceRemoved         := 0x1401  -- C: SDL_EVENT_CAMERA_DEVICE_REMOVED
  | cameraDeviceApproved        := 0x1402  -- C: SDL_EVENT_CAMERA_DEVICE_APPROVED
  | cameraDeviceDenied          := 0x1403  -- C: SDL_EVENT_CAMERA_DEVICE_DENIED
  -- Render events
  | renderTargetsReset          := 0x2000  -- C: SDL_EVENT_RENDER_TARGETS_RESET
  | renderDeviceReset           := 0x2001  -- C: SDL_EVENT_RENDER_DEVICE_RESET
  | renderDeviceLost            := 0x2002  -- C: SDL_EVENT_RENDER_DEVICE_LOST
  -- Internal
  | pollSentinel                := 0x7F00  -- C: SDL_EVENT_POLL_SENTINEL (internal)
  -- User-registrable range
  | user                        := 0x8000  -- C: SDL_EVENT_USER (first user-registrable value)
  | last                        := 0xFFFF  -- C: SDL_EVENT_LAST (range queries)

/-! ## Payload structures

One structure per `SDL_*Event` C struct family. All fields are in C declaration
order with `timestamp : UInt64` (nanoseconds, `SDL_GetTicksNS` clock) first; the
`type`, `reserved`, and `padding*` fields are dropped (constructor identity
carries the type, except for `.user`/`.unknown` which keep the raw type as a
separate constructor argument). -/

/-- Fields shared by every payloadless event. C: `SDL_CommonEvent`. -/
structure CommonEvent where
  /-- Event timestamp, in nanoseconds (`SDL_GetTicksNS` clock). -/
  timestamp : UInt64
deriving Repr, BEq, Inhabited

/-- Display state change event. C: `SDL_DisplayEvent`. -/
structure DisplayEvent where
  timestamp : UInt64
  displayId : DisplayId
  data1 : Int32
  data2 : Int32
deriving Repr, BEq, Inhabited

/-- Window state change event. C: `SDL_WindowEvent`. -/
structure WindowEvent where
  timestamp : UInt64
  windowId : WindowId
  data1 : Int32
  data2 : Int32
deriving Repr, BEq, Inhabited

/-- Keyboard hotplug event. C: `SDL_KeyboardDeviceEvent`. -/
structure KeyboardDeviceEvent where
  timestamp : UInt64
  which : KeyboardId
deriving Repr, BEq, Inhabited

/-- Keyboard key press/release event. `key` is the layout+`SDL_HINT_KEYCODE_OPTIONS`
mapped keycode; `raw` is the platform scancode. C: `SDL_KeyboardEvent`. -/
structure KeyboardEvent where
  timestamp : UInt64
  windowId : WindowId
  which : KeyboardId
  scancode : Scancode
  key : Keycode
  mod : Keymod
  raw : UInt16
  down : Bool
  «repeat» : Bool
deriving Repr, BEq, Inhabited

/-- Keyboard text editing (IME composition) event. C: `SDL_TextEditingEvent`. -/
structure TextEditingEvent where
  timestamp : UInt64
  windowId : WindowId
  text : String
  start : Int32
  length : Int32
deriving Repr, BEq, Inhabited

/-- Keyboard IME candidates event. C: `SDL_TextEditingCandidatesEvent`. -/
structure TextEditingCandidatesEvent where
  timestamp : UInt64
  windowId : WindowId
  candidates : Array String
  selectedCandidate : Int32
  horizontal : Bool
deriving Repr, BEq, Inhabited

/-- Keyboard text input event. C: `SDL_TextInputEvent`. -/
structure TextInputEvent where
  timestamp : UInt64
  windowId : WindowId
  text : String
deriving Repr, BEq, Inhabited

/-- Mouse hotplug event. C: `SDL_MouseDeviceEvent`. -/
structure MouseDeviceEvent where
  timestamp : UInt64
  which : MouseId
deriving Repr, BEq, Inhabited

/-- Mouse motion event. C: `SDL_MouseMotionEvent`. -/
structure MouseMotionEvent where
  timestamp : UInt64
  windowId : WindowId
  which : MouseId
  state : MouseButtonFlags
  x : Float32
  y : Float32
  xrel : Float32
  yrel : Float32
deriving Repr, BEq, Inhabited

/-- Mouse button press/release event. C: `SDL_MouseButtonEvent`. -/
structure MouseButtonEvent where
  timestamp : UInt64
  windowId : WindowId
  which : MouseId
  button : MouseButton
  down : Bool
  clicks : UInt8
  x : Float32
  y : Float32
deriving Repr, BEq, Inhabited

/-- Mouse wheel motion event. C: `SDL_MouseWheelEvent`. -/
structure MouseWheelEvent where
  timestamp : UInt64
  windowId : WindowId
  which : MouseId
  x : Float32
  y : Float32
  direction : MouseWheelDirection
  mouseX : Float32
  mouseY : Float32
  integerX : Int32
  integerY : Int32
deriving Repr, BEq, Inhabited

/-- Joystick hotplug/update event. C: `SDL_JoyDeviceEvent`. -/
structure JoyDeviceEvent where
  timestamp : UInt64
  which : JoystickId
deriving Repr, BEq, Inhabited

/-- Joystick axis motion event. C: `SDL_JoyAxisEvent`. -/
structure JoyAxisEvent where
  timestamp : UInt64
  which : JoystickId
  axis : UInt8
  value : Int16
deriving Repr, BEq, Inhabited

/-- Joystick trackball motion event. C: `SDL_JoyBallEvent`. -/
structure JoyBallEvent where
  timestamp : UInt64
  which : JoystickId
  ball : UInt8
  xrel : Int16
  yrel : Int16
deriving Repr, BEq, Inhabited

/-- Joystick hat position change event. `value` holds `SDL_HAT_*` bits (the
named constants land in M10). C: `SDL_JoyHatEvent`. -/
structure JoyHatEvent where
  timestamp : UInt64
  which : JoystickId
  hat : UInt8
  value : UInt8
deriving Repr, BEq, Inhabited

/-- Joystick button press/release event. C: `SDL_JoyButtonEvent`. -/
structure JoyButtonEvent where
  timestamp : UInt64
  which : JoystickId
  button : UInt8
  down : Bool
deriving Repr, BEq, Inhabited

/-- Joystick battery level change event. C: `SDL_JoyBatteryEvent`. -/
structure JoyBatteryEvent where
  timestamp : UInt64
  which : JoystickId
  state : PowerState
  percent : Int32
deriving Repr, BEq, Inhabited

/-- Gamepad hotplug/update event. C: `SDL_GamepadDeviceEvent`. -/
structure GamepadDeviceEvent where
  timestamp : UInt64
  which : JoystickId
deriving Repr, BEq, Inhabited

/-- Gamepad axis motion event (`axis` is an `SDL_GamepadAxis`, mapped in M10).
C: `SDL_GamepadAxisEvent`. -/
structure GamepadAxisEvent where
  timestamp : UInt64
  which : JoystickId
  axis : UInt8
  value : Int16
deriving Repr, BEq, Inhabited

/-- Gamepad button press/release event (`button` is an `SDL_GamepadButton`,
mapped in M10). C: `SDL_GamepadButtonEvent`. -/
structure GamepadButtonEvent where
  timestamp : UInt64
  which : JoystickId
  button : UInt8
  down : Bool
deriving Repr, BEq, Inhabited

/-- Gamepad touchpad touch/motion event. C: `SDL_GamepadTouchpadEvent`. -/
structure GamepadTouchpadEvent where
  timestamp : UInt64
  which : JoystickId
  touchpad : Int32
  finger : Int32
  x : Float32
  y : Float32
  pressure : Float32
deriving Repr, BEq, Inhabited

/-- Gamepad sensor update event. C: `SDL_GamepadSensorEvent`. -/
structure GamepadSensorEvent where
  timestamp : UInt64
  which : JoystickId
  sensor : Int32
  data0 : Float32
  data1 : Float32
  data2 : Float32
  sensorTimestamp : UInt64
deriving Repr, BEq, Inhabited

/-- Audio device hotplug/format-change event. C: `SDL_AudioDeviceEvent`. -/
structure AudioDeviceEvent where
  timestamp : UInt64
  which : AudioDeviceId
  recording : Bool
deriving Repr, BEq, Inhabited

/-- Camera device hotplug/approval event. C: `SDL_CameraDeviceEvent`. -/
structure CameraDeviceEvent where
  timestamp : UInt64
  which : CameraId
deriving Repr, BEq, Inhabited

/-- Sensor update event. C: `SDL_SensorEvent`. -/
structure SensorEvent where
  timestamp : UInt64
  which : SensorId
  data0 : Float32
  data1 : Float32
  data2 : Float32
  data3 : Float32
  data4 : Float32
  data5 : Float32
  sensorTimestamp : UInt64
deriving Repr, BEq, Inhabited

/-- User-defined event. The C `data1`/`data2` pointers are deliberately dropped
(no sound way to carry a raw pointer across the FFI boundary).
C: `SDL_UserEvent`. -/
structure UserEvent where
  timestamp : UInt64
  windowId : WindowId
  code : Int32
deriving Repr, BEq, Inhabited

/-- Touch finger event. Coordinates are normalized. C: `SDL_TouchFingerEvent`. -/
structure TouchFingerEvent where
  timestamp : UInt64
  touchId : TouchId
  fingerId : FingerId
  x : Float32
  y : Float32
  dx : Float32
  dy : Float32
  pressure : Float32
  windowId : WindowId
deriving Repr, BEq, Inhabited

/-- Pinch gesture event. C: `SDL_PinchFingerEvent`. -/
structure PinchFingerEvent where
  timestamp : UInt64
  scale : Float32
  windowId : WindowId
deriving Repr, BEq, Inhabited

/-- Pen proximity in/out event. C: `SDL_PenProximityEvent`. -/
structure PenProximityEvent where
  timestamp : UInt64
  windowId : WindowId
  which : PenId
deriving Repr, BEq, Inhabited

/-- Pen motion event. C: `SDL_PenMotionEvent`. -/
structure PenMotionEvent where
  timestamp : UInt64
  windowId : WindowId
  which : PenId
  penState : PenInputFlags
  x : Float32
  y : Float32
deriving Repr, BEq, Inhabited

/-- Pen touch/lift event. C: `SDL_PenTouchEvent`. -/
structure PenTouchEvent where
  timestamp : UInt64
  windowId : WindowId
  which : PenId
  penState : PenInputFlags
  x : Float32
  y : Float32
  eraser : Bool
  down : Bool
deriving Repr, BEq, Inhabited

/-- Pen button press/release event. C: `SDL_PenButtonEvent`. -/
structure PenButtonEvent where
  timestamp : UInt64
  windowId : WindowId
  which : PenId
  penState : PenInputFlags
  x : Float32
  y : Float32
  button : UInt8
  down : Bool
deriving Repr, BEq, Inhabited

/-- Pen axis (pressure/angle) event. C: `SDL_PenAxisEvent`. -/
structure PenAxisEvent where
  timestamp : UInt64
  windowId : WindowId
  which : PenId
  penState : PenInputFlags
  x : Float32
  y : Float32
  axis : PenAxis
  value : Float32
deriving Repr, BEq, Inhabited

/-- Renderer reset/lost event. C: `SDL_RenderEvent`. -/
structure RenderEvent where
  timestamp : UInt64
  windowId : WindowId
deriving Repr, BEq, Inhabited

/-- Drag-and-drop event. `source`/`data` are `none` for the begin/complete
phases (SDL sends a NULL filename). C: `SDL_DropEvent`. -/
structure DropEvent where
  timestamp : UInt64
  windowId : WindowId
  x : Float32
  y : Float32
  source : Option String
  data : Option String
deriving Repr, BEq, Inhabited

/-- Clipboard-changed event. C: `SDL_ClipboardEvent`. -/
structure ClipboardEvent where
  timestamp : UInt64
  owner : Bool
  mimeTypes : Array String
deriving Repr, BEq, Inhabited

/-! ## The `Event` inductive

One constructor per mapped `SDL_EventType` (families share a payload structure),
plus `.user (type) …` for the user-registrable range and `.unknown (type) …` for
everything else, so decoding the union is total. -/

/-- A decoded SDL event. Total: any type not mapped to a specific constructor
becomes `.user` (for `0x8000 ≤ type ≤ 0xFFFF`) or `.unknown` (everything else,
including the reserved private range and the poll sentinel). C: `SDL_Event`. -/
inductive Event where
  -- Application events (payloadless; SDL_CommonEvent)
  | quit (e : CommonEvent)                         -- C: SDL_EVENT_QUIT
  | terminating (e : CommonEvent)                  -- C: SDL_EVENT_TERMINATING
  | lowMemory (e : CommonEvent)                    -- C: SDL_EVENT_LOW_MEMORY
  | willEnterBackground (e : CommonEvent)          -- C: SDL_EVENT_WILL_ENTER_BACKGROUND
  | didEnterBackground (e : CommonEvent)           -- C: SDL_EVENT_DID_ENTER_BACKGROUND
  | willEnterForeground (e : CommonEvent)          -- C: SDL_EVENT_WILL_ENTER_FOREGROUND
  | didEnterForeground (e : CommonEvent)           -- C: SDL_EVENT_DID_ENTER_FOREGROUND
  | localeChanged (e : CommonEvent)                -- C: SDL_EVENT_LOCALE_CHANGED
  | systemThemeChanged (e : CommonEvent)           -- C: SDL_EVENT_SYSTEM_THEME_CHANGED
  | keymapChanged (e : CommonEvent)                -- C: SDL_EVENT_KEYMAP_CHANGED
  | screenKeyboardShown (e : CommonEvent)          -- C: SDL_EVENT_SCREEN_KEYBOARD_SHOWN
  | screenKeyboardHidden (e : CommonEvent)         -- C: SDL_EVENT_SCREEN_KEYBOARD_HIDDEN
  -- Display events (SDL_DisplayEvent)
  | displayOrientation (e : DisplayEvent)          -- C: SDL_EVENT_DISPLAY_ORIENTATION
  | displayAdded (e : DisplayEvent)                -- C: SDL_EVENT_DISPLAY_ADDED
  | displayRemoved (e : DisplayEvent)              -- C: SDL_EVENT_DISPLAY_REMOVED
  | displayMoved (e : DisplayEvent)                -- C: SDL_EVENT_DISPLAY_MOVED
  | displayDesktopModeChanged (e : DisplayEvent)   -- C: SDL_EVENT_DISPLAY_DESKTOP_MODE_CHANGED
  | displayCurrentModeChanged (e : DisplayEvent)   -- C: SDL_EVENT_DISPLAY_CURRENT_MODE_CHANGED
  | displayContentScaleChanged (e : DisplayEvent)  -- C: SDL_EVENT_DISPLAY_CONTENT_SCALE_CHANGED
  | displayUsableBoundsChanged (e : DisplayEvent)  -- C: SDL_EVENT_DISPLAY_USABLE_BOUNDS_CHANGED
  -- Window events (SDL_WindowEvent)
  | windowShown (e : WindowEvent)                  -- C: SDL_EVENT_WINDOW_SHOWN
  | windowHidden (e : WindowEvent)                 -- C: SDL_EVENT_WINDOW_HIDDEN
  | windowExposed (e : WindowEvent)                -- C: SDL_EVENT_WINDOW_EXPOSED
  | windowMoved (e : WindowEvent)                  -- C: SDL_EVENT_WINDOW_MOVED
  | windowResized (e : WindowEvent)                -- C: SDL_EVENT_WINDOW_RESIZED
  | windowPixelSizeChanged (e : WindowEvent)       -- C: SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED
  | windowMetalViewResized (e : WindowEvent)       -- C: SDL_EVENT_WINDOW_METAL_VIEW_RESIZED
  | windowMinimized (e : WindowEvent)              -- C: SDL_EVENT_WINDOW_MINIMIZED
  | windowMaximized (e : WindowEvent)              -- C: SDL_EVENT_WINDOW_MAXIMIZED
  | windowRestored (e : WindowEvent)               -- C: SDL_EVENT_WINDOW_RESTORED
  | windowMouseEnter (e : WindowEvent)             -- C: SDL_EVENT_WINDOW_MOUSE_ENTER
  | windowMouseLeave (e : WindowEvent)             -- C: SDL_EVENT_WINDOW_MOUSE_LEAVE
  | windowFocusGained (e : WindowEvent)            -- C: SDL_EVENT_WINDOW_FOCUS_GAINED
  | windowFocusLost (e : WindowEvent)              -- C: SDL_EVENT_WINDOW_FOCUS_LOST
  | windowCloseRequested (e : WindowEvent)         -- C: SDL_EVENT_WINDOW_CLOSE_REQUESTED
  | windowHitTest (e : WindowEvent)                -- C: SDL_EVENT_WINDOW_HIT_TEST
  | windowIccprofChanged (e : WindowEvent)         -- C: SDL_EVENT_WINDOW_ICCPROF_CHANGED
  | windowDisplayChanged (e : WindowEvent)         -- C: SDL_EVENT_WINDOW_DISPLAY_CHANGED
  | windowDisplayScaleChanged (e : WindowEvent)    -- C: SDL_EVENT_WINDOW_DISPLAY_SCALE_CHANGED
  | windowSafeAreaChanged (e : WindowEvent)        -- C: SDL_EVENT_WINDOW_SAFE_AREA_CHANGED
  | windowOccluded (e : WindowEvent)               -- C: SDL_EVENT_WINDOW_OCCLUDED
  | windowEnterFullscreen (e : WindowEvent)        -- C: SDL_EVENT_WINDOW_ENTER_FULLSCREEN
  | windowLeaveFullscreen (e : WindowEvent)        -- C: SDL_EVENT_WINDOW_LEAVE_FULLSCREEN
  | windowDestroyed (e : WindowEvent)              -- C: SDL_EVENT_WINDOW_DESTROYED
  | windowHdrStateChanged (e : WindowEvent)        -- C: SDL_EVENT_WINDOW_HDR_STATE_CHANGED
  -- Keyboard events
  | keyDown (e : KeyboardEvent)                    -- C: SDL_EVENT_KEY_DOWN
  | keyUp (e : KeyboardEvent)                      -- C: SDL_EVENT_KEY_UP
  | textEditing (e : TextEditingEvent)             -- C: SDL_EVENT_TEXT_EDITING
  | textInput (e : TextInputEvent)                 -- C: SDL_EVENT_TEXT_INPUT
  | keyboardAdded (e : KeyboardDeviceEvent)        -- C: SDL_EVENT_KEYBOARD_ADDED
  | keyboardRemoved (e : KeyboardDeviceEvent)      -- C: SDL_EVENT_KEYBOARD_REMOVED
  | textEditingCandidates (e : TextEditingCandidatesEvent) -- C: SDL_EVENT_TEXT_EDITING_CANDIDATES
  -- Mouse events
  | mouseMotion (e : MouseMotionEvent)             -- C: SDL_EVENT_MOUSE_MOTION
  | mouseButtonDown (e : MouseButtonEvent)         -- C: SDL_EVENT_MOUSE_BUTTON_DOWN
  | mouseButtonUp (e : MouseButtonEvent)           -- C: SDL_EVENT_MOUSE_BUTTON_UP
  | mouseWheel (e : MouseWheelEvent)               -- C: SDL_EVENT_MOUSE_WHEEL
  | mouseAdded (e : MouseDeviceEvent)              -- C: SDL_EVENT_MOUSE_ADDED
  | mouseRemoved (e : MouseDeviceEvent)            -- C: SDL_EVENT_MOUSE_REMOVED
  -- Joystick events
  | joystickAxisMotion (e : JoyAxisEvent)          -- C: SDL_EVENT_JOYSTICK_AXIS_MOTION
  | joystickBallMotion (e : JoyBallEvent)          -- C: SDL_EVENT_JOYSTICK_BALL_MOTION
  | joystickHatMotion (e : JoyHatEvent)            -- C: SDL_EVENT_JOYSTICK_HAT_MOTION
  | joystickButtonDown (e : JoyButtonEvent)        -- C: SDL_EVENT_JOYSTICK_BUTTON_DOWN
  | joystickButtonUp (e : JoyButtonEvent)          -- C: SDL_EVENT_JOYSTICK_BUTTON_UP
  | joystickAdded (e : JoyDeviceEvent)             -- C: SDL_EVENT_JOYSTICK_ADDED
  | joystickRemoved (e : JoyDeviceEvent)           -- C: SDL_EVENT_JOYSTICK_REMOVED
  | joystickBatteryUpdated (e : JoyBatteryEvent)   -- C: SDL_EVENT_JOYSTICK_BATTERY_UPDATED
  | joystickUpdateComplete (e : JoyDeviceEvent)    -- C: SDL_EVENT_JOYSTICK_UPDATE_COMPLETE
  -- Gamepad events
  | gamepadAxisMotion (e : GamepadAxisEvent)       -- C: SDL_EVENT_GAMEPAD_AXIS_MOTION
  | gamepadButtonDown (e : GamepadButtonEvent)     -- C: SDL_EVENT_GAMEPAD_BUTTON_DOWN
  | gamepadButtonUp (e : GamepadButtonEvent)       -- C: SDL_EVENT_GAMEPAD_BUTTON_UP
  | gamepadAdded (e : GamepadDeviceEvent)          -- C: SDL_EVENT_GAMEPAD_ADDED
  | gamepadRemoved (e : GamepadDeviceEvent)        -- C: SDL_EVENT_GAMEPAD_REMOVED
  | gamepadRemapped (e : GamepadDeviceEvent)       -- C: SDL_EVENT_GAMEPAD_REMAPPED
  | gamepadTouchpadDown (e : GamepadTouchpadEvent) -- C: SDL_EVENT_GAMEPAD_TOUCHPAD_DOWN
  | gamepadTouchpadMotion (e : GamepadTouchpadEvent) -- C: SDL_EVENT_GAMEPAD_TOUCHPAD_MOTION
  | gamepadTouchpadUp (e : GamepadTouchpadEvent)   -- C: SDL_EVENT_GAMEPAD_TOUCHPAD_UP
  | gamepadSensorUpdate (e : GamepadSensorEvent)   -- C: SDL_EVENT_GAMEPAD_SENSOR_UPDATE
  | gamepadUpdateComplete (e : GamepadDeviceEvent) -- C: SDL_EVENT_GAMEPAD_UPDATE_COMPLETE
  | gamepadSteamHandleUpdated (e : GamepadDeviceEvent) -- C: SDL_EVENT_GAMEPAD_STEAM_HANDLE_UPDATED
  -- Touch events
  | fingerDown (e : TouchFingerEvent)              -- C: SDL_EVENT_FINGER_DOWN
  | fingerUp (e : TouchFingerEvent)                -- C: SDL_EVENT_FINGER_UP
  | fingerMotion (e : TouchFingerEvent)            -- C: SDL_EVENT_FINGER_MOTION
  | fingerCanceled (e : TouchFingerEvent)          -- C: SDL_EVENT_FINGER_CANCELED
  -- Pinch events
  | pinchBegin (e : PinchFingerEvent)              -- C: SDL_EVENT_PINCH_BEGIN
  | pinchUpdate (e : PinchFingerEvent)             -- C: SDL_EVENT_PINCH_UPDATE
  | pinchEnd (e : PinchFingerEvent)                -- C: SDL_EVENT_PINCH_END
  -- Clipboard events
  | clipboardUpdate (e : ClipboardEvent)           -- C: SDL_EVENT_CLIPBOARD_UPDATE
  -- Drag and drop events
  | dropFile (e : DropEvent)                       -- C: SDL_EVENT_DROP_FILE
  | dropText (e : DropEvent)                       -- C: SDL_EVENT_DROP_TEXT
  | dropBegin (e : DropEvent)                      -- C: SDL_EVENT_DROP_BEGIN
  | dropComplete (e : DropEvent)                   -- C: SDL_EVENT_DROP_COMPLETE
  | dropPosition (e : DropEvent)                   -- C: SDL_EVENT_DROP_POSITION
  -- Audio hotplug events
  | audioDeviceAdded (e : AudioDeviceEvent)        -- C: SDL_EVENT_AUDIO_DEVICE_ADDED
  | audioDeviceRemoved (e : AudioDeviceEvent)      -- C: SDL_EVENT_AUDIO_DEVICE_REMOVED
  | audioDeviceFormatChanged (e : AudioDeviceEvent) -- C: SDL_EVENT_AUDIO_DEVICE_FORMAT_CHANGED
  -- Sensor events
  | sensorUpdate (e : SensorEvent)                 -- C: SDL_EVENT_SENSOR_UPDATE
  -- Pressure-sensitive pen events
  | penProximityIn (e : PenProximityEvent)         -- C: SDL_EVENT_PEN_PROXIMITY_IN
  | penProximityOut (e : PenProximityEvent)        -- C: SDL_EVENT_PEN_PROXIMITY_OUT
  | penDown (e : PenTouchEvent)                    -- C: SDL_EVENT_PEN_DOWN
  | penUp (e : PenTouchEvent)                      -- C: SDL_EVENT_PEN_UP
  | penButtonDown (e : PenButtonEvent)             -- C: SDL_EVENT_PEN_BUTTON_DOWN
  | penButtonUp (e : PenButtonEvent)               -- C: SDL_EVENT_PEN_BUTTON_UP
  | penMotion (e : PenMotionEvent)                 -- C: SDL_EVENT_PEN_MOTION
  | penAxis (e : PenAxisEvent)                     -- C: SDL_EVENT_PEN_AXIS
  -- Camera hotplug events
  | cameraDeviceAdded (e : CameraDeviceEvent)      -- C: SDL_EVENT_CAMERA_DEVICE_ADDED
  | cameraDeviceRemoved (e : CameraDeviceEvent)    -- C: SDL_EVENT_CAMERA_DEVICE_REMOVED
  | cameraDeviceApproved (e : CameraDeviceEvent)   -- C: SDL_EVENT_CAMERA_DEVICE_APPROVED
  | cameraDeviceDenied (e : CameraDeviceEvent)     -- C: SDL_EVENT_CAMERA_DEVICE_DENIED
  -- Render events
  | renderTargetsReset (e : RenderEvent)           -- C: SDL_EVENT_RENDER_TARGETS_RESET
  | renderDeviceReset (e : RenderEvent)            -- C: SDL_EVENT_RENDER_DEVICE_RESET
  | renderDeviceLost (e : RenderEvent)             -- C: SDL_EVENT_RENDER_DEVICE_LOST
  -- User-registrable range and total-decode fallback
  | user (type : UInt32) (e : UserEvent)           -- C: SDL_EVENT_USER .. SDL_EVENT_LAST
  | unknown (type : UInt32) (e : CommonEvent)      -- C: any unmapped type (private/sentinel/...)
deriving Repr, BEq, Inhabited

namespace Event

/-- The event timestamp, in nanoseconds (`SDL_GetTicksNS` clock). Total. -/
def timestamp : Event → UInt64
  | .quit e | .terminating e | .lowMemory e | .willEnterBackground e
  | .didEnterBackground e | .willEnterForeground e | .didEnterForeground e
  | .localeChanged e | .systemThemeChanged e | .keymapChanged e
  | .screenKeyboardShown e | .screenKeyboardHidden e => e.timestamp
  | .displayOrientation e | .displayAdded e | .displayRemoved e | .displayMoved e
  | .displayDesktopModeChanged e | .displayCurrentModeChanged e
  | .displayContentScaleChanged e | .displayUsableBoundsChanged e => e.timestamp
  | .windowShown e | .windowHidden e | .windowExposed e | .windowMoved e
  | .windowResized e | .windowPixelSizeChanged e | .windowMetalViewResized e
  | .windowMinimized e | .windowMaximized e | .windowRestored e
  | .windowMouseEnter e | .windowMouseLeave e | .windowFocusGained e
  | .windowFocusLost e | .windowCloseRequested e | .windowHitTest e
  | .windowIccprofChanged e | .windowDisplayChanged e | .windowDisplayScaleChanged e
  | .windowSafeAreaChanged e | .windowOccluded e | .windowEnterFullscreen e
  | .windowLeaveFullscreen e | .windowDestroyed e | .windowHdrStateChanged e => e.timestamp
  | .keyDown e | .keyUp e => e.timestamp
  | .textEditing e => e.timestamp
  | .textInput e => e.timestamp
  | .keyboardAdded e | .keyboardRemoved e => e.timestamp
  | .textEditingCandidates e => e.timestamp
  | .mouseMotion e => e.timestamp
  | .mouseButtonDown e | .mouseButtonUp e => e.timestamp
  | .mouseWheel e => e.timestamp
  | .mouseAdded e | .mouseRemoved e => e.timestamp
  | .joystickAxisMotion e => e.timestamp
  | .joystickBallMotion e => e.timestamp
  | .joystickHatMotion e => e.timestamp
  | .joystickButtonDown e | .joystickButtonUp e => e.timestamp
  | .joystickAdded e | .joystickRemoved e | .joystickUpdateComplete e => e.timestamp
  | .joystickBatteryUpdated e => e.timestamp
  | .gamepadAxisMotion e => e.timestamp
  | .gamepadButtonDown e | .gamepadButtonUp e => e.timestamp
  | .gamepadAdded e | .gamepadRemoved e | .gamepadRemapped e
  | .gamepadUpdateComplete e | .gamepadSteamHandleUpdated e => e.timestamp
  | .gamepadTouchpadDown e | .gamepadTouchpadMotion e | .gamepadTouchpadUp e => e.timestamp
  | .gamepadSensorUpdate e => e.timestamp
  | .audioDeviceAdded e | .audioDeviceRemoved e | .audioDeviceFormatChanged e => e.timestamp
  | .cameraDeviceAdded e | .cameraDeviceRemoved e | .cameraDeviceApproved e
  | .cameraDeviceDenied e => e.timestamp
  | .sensorUpdate e => e.timestamp
  | .fingerDown e | .fingerUp e | .fingerMotion e | .fingerCanceled e => e.timestamp
  | .pinchBegin e | .pinchUpdate e | .pinchEnd e => e.timestamp
  | .penProximityIn e | .penProximityOut e => e.timestamp
  | .penMotion e => e.timestamp
  | .penDown e | .penUp e => e.timestamp
  | .penButtonDown e | .penButtonUp e => e.timestamp
  | .penAxis e => e.timestamp
  | .renderTargetsReset e | .renderDeviceReset e | .renderDeviceLost e => e.timestamp
  | .dropFile e | .dropText e | .dropBegin e | .dropComplete e | .dropPosition e => e.timestamp
  | .clipboardUpdate e => e.timestamp
  | .user _ e => e.timestamp
  | .unknown _ e => e.timestamp

/-- The window a decoded event refers to, or `none` for events that carry no
window. Payloads with a `windowID` field (window/keyboard/text*/mouse*/touch/
pinch/pen*/render/drop/user) yield `some`; the rest (common/display/hotplug/
joystick/gamepad/audio/sensor/camera/clipboard/unknown) yield `none`. -/
def windowId : Event → Option WindowId
  | .windowShown e | .windowHidden e | .windowExposed e | .windowMoved e
  | .windowResized e | .windowPixelSizeChanged e | .windowMetalViewResized e
  | .windowMinimized e | .windowMaximized e | .windowRestored e
  | .windowMouseEnter e | .windowMouseLeave e | .windowFocusGained e
  | .windowFocusLost e | .windowCloseRequested e | .windowHitTest e
  | .windowIccprofChanged e | .windowDisplayChanged e | .windowDisplayScaleChanged e
  | .windowSafeAreaChanged e | .windowOccluded e | .windowEnterFullscreen e
  | .windowLeaveFullscreen e | .windowDestroyed e | .windowHdrStateChanged e => some e.windowId
  | .keyDown e | .keyUp e => some e.windowId
  | .textEditing e => some e.windowId
  | .textInput e => some e.windowId
  | .textEditingCandidates e => some e.windowId
  | .mouseMotion e => some e.windowId
  | .mouseButtonDown e | .mouseButtonUp e => some e.windowId
  | .mouseWheel e => some e.windowId
  | .fingerDown e | .fingerUp e | .fingerMotion e | .fingerCanceled e => some e.windowId
  | .pinchBegin e | .pinchUpdate e | .pinchEnd e => some e.windowId
  | .penProximityIn e | .penProximityOut e => some e.windowId
  | .penMotion e => some e.windowId
  | .penDown e | .penUp e => some e.windowId
  | .penButtonDown e | .penButtonUp e => some e.windowId
  | .penAxis e => some e.windowId
  | .renderTargetsReset e | .renderDeviceReset e | .renderDeviceLost e => some e.windowId
  | .dropFile e | .dropText e | .dropBegin e | .dropComplete e | .dropPosition e => some e.windowId
  | .user _ e => some e.windowId
  | _ => none

end Event

/-! ## Makers (`@[export]`, dispatch-in-Lean)

One maker per payload family. The first two parameters are always
`(type : UInt32) (ts : UInt64)`; the maker dispatches on `type` with literal
patterns and falls back to `.unknown type ⟨ts⟩` on any unmapped value, so a
C/Lean range mismatch can never panic. Called from `ffi/events.c` with
flattened, unboxed scalars (Bool arrives as `uint8_t`, `String`/`Array String`/
`Option String` as `lean_obj_arg`). -/

/-- Maker for payloadless (`SDL_CommonEvent`) events. 12-way dispatch. Also
serves as the decode default for non-user unmapped types (→ `.unknown`). -/
@[export lean_sdl_mk_event_common]
private def mkEventCommon (type : UInt32) (ts : UInt64) : Event :=
  let e : CommonEvent := ⟨ts⟩
  match type with
  | 0x100 => .quit e                 -- C: SDL_EVENT_QUIT
  | 0x101 => .terminating e          -- C: SDL_EVENT_TERMINATING
  | 0x102 => .lowMemory e            -- C: SDL_EVENT_LOW_MEMORY
  | 0x103 => .willEnterBackground e  -- C: SDL_EVENT_WILL_ENTER_BACKGROUND
  | 0x104 => .didEnterBackground e   -- C: SDL_EVENT_DID_ENTER_BACKGROUND
  | 0x105 => .willEnterForeground e  -- C: SDL_EVENT_WILL_ENTER_FOREGROUND
  | 0x106 => .didEnterForeground e   -- C: SDL_EVENT_DID_ENTER_FOREGROUND
  | 0x107 => .localeChanged e        -- C: SDL_EVENT_LOCALE_CHANGED
  | 0x108 => .systemThemeChanged e   -- C: SDL_EVENT_SYSTEM_THEME_CHANGED
  | 0x304 => .keymapChanged e        -- C: SDL_EVENT_KEYMAP_CHANGED
  | 0x308 => .screenKeyboardShown e  -- C: SDL_EVENT_SCREEN_KEYBOARD_SHOWN
  | 0x309 => .screenKeyboardHidden e -- C: SDL_EVENT_SCREEN_KEYBOARD_HIDDEN
  | _ => .unknown type e

#guard mkEventCommon 0x100 5 == .quit ⟨5⟩
#guard mkEventCommon 0x309 5 == .screenKeyboardHidden ⟨5⟩
#guard mkEventCommon 0x4000 5 == .unknown 0x4000 ⟨5⟩

/-- Maker for `SDL_DisplayEvent` events. 8-way dispatch (0x151–0x158). -/
@[export lean_sdl_mk_event_display]
private def mkEventDisplay (type : UInt32) (ts : UInt64) (displayId : UInt32)
    (data1 data2 : Int32) : Event :=
  let e : DisplayEvent := ⟨ts, ⟨displayId⟩, data1, data2⟩
  match type with
  | 0x151 => .displayOrientation e         -- C: SDL_EVENT_DISPLAY_ORIENTATION
  | 0x152 => .displayAdded e               -- C: SDL_EVENT_DISPLAY_ADDED
  | 0x153 => .displayRemoved e             -- C: SDL_EVENT_DISPLAY_REMOVED
  | 0x154 => .displayMoved e               -- C: SDL_EVENT_DISPLAY_MOVED
  | 0x155 => .displayDesktopModeChanged e  -- C: SDL_EVENT_DISPLAY_DESKTOP_MODE_CHANGED
  | 0x156 => .displayCurrentModeChanged e  -- C: SDL_EVENT_DISPLAY_CURRENT_MODE_CHANGED
  | 0x157 => .displayContentScaleChanged e -- C: SDL_EVENT_DISPLAY_CONTENT_SCALE_CHANGED
  | 0x158 => .displayUsableBoundsChanged e -- C: SDL_EVENT_DISPLAY_USABLE_BOUNDS_CHANGED
  | _ => .unknown type ⟨ts⟩

#guard mkEventDisplay 0x151 5 7 1 2 == .displayOrientation ⟨5, ⟨7⟩, 1, 2⟩
#guard mkEventDisplay 0x999 5 7 1 2 == .unknown 0x999 ⟨5⟩

/-- Maker for `SDL_WindowEvent` events. 25-way dispatch (0x202–0x21A). -/
@[export lean_sdl_mk_event_window]
private def mkEventWindow (type : UInt32) (ts : UInt64) (windowId : UInt32)
    (data1 data2 : Int32) : Event :=
  let e : WindowEvent := ⟨ts, ⟨windowId⟩, data1, data2⟩
  match type with
  | 0x202 => .windowShown e              -- C: SDL_EVENT_WINDOW_SHOWN
  | 0x203 => .windowHidden e             -- C: SDL_EVENT_WINDOW_HIDDEN
  | 0x204 => .windowExposed e            -- C: SDL_EVENT_WINDOW_EXPOSED
  | 0x205 => .windowMoved e              -- C: SDL_EVENT_WINDOW_MOVED
  | 0x206 => .windowResized e            -- C: SDL_EVENT_WINDOW_RESIZED
  | 0x207 => .windowPixelSizeChanged e   -- C: SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED
  | 0x208 => .windowMetalViewResized e   -- C: SDL_EVENT_WINDOW_METAL_VIEW_RESIZED
  | 0x209 => .windowMinimized e          -- C: SDL_EVENT_WINDOW_MINIMIZED
  | 0x20A => .windowMaximized e          -- C: SDL_EVENT_WINDOW_MAXIMIZED
  | 0x20B => .windowRestored e           -- C: SDL_EVENT_WINDOW_RESTORED
  | 0x20C => .windowMouseEnter e         -- C: SDL_EVENT_WINDOW_MOUSE_ENTER
  | 0x20D => .windowMouseLeave e         -- C: SDL_EVENT_WINDOW_MOUSE_LEAVE
  | 0x20E => .windowFocusGained e        -- C: SDL_EVENT_WINDOW_FOCUS_GAINED
  | 0x20F => .windowFocusLost e          -- C: SDL_EVENT_WINDOW_FOCUS_LOST
  | 0x210 => .windowCloseRequested e     -- C: SDL_EVENT_WINDOW_CLOSE_REQUESTED
  | 0x211 => .windowHitTest e            -- C: SDL_EVENT_WINDOW_HIT_TEST
  | 0x212 => .windowIccprofChanged e     -- C: SDL_EVENT_WINDOW_ICCPROF_CHANGED
  | 0x213 => .windowDisplayChanged e     -- C: SDL_EVENT_WINDOW_DISPLAY_CHANGED
  | 0x214 => .windowDisplayScaleChanged e -- C: SDL_EVENT_WINDOW_DISPLAY_SCALE_CHANGED
  | 0x215 => .windowSafeAreaChanged e    -- C: SDL_EVENT_WINDOW_SAFE_AREA_CHANGED
  | 0x216 => .windowOccluded e           -- C: SDL_EVENT_WINDOW_OCCLUDED
  | 0x217 => .windowEnterFullscreen e    -- C: SDL_EVENT_WINDOW_ENTER_FULLSCREEN
  | 0x218 => .windowLeaveFullscreen e    -- C: SDL_EVENT_WINDOW_LEAVE_FULLSCREEN
  | 0x219 => .windowDestroyed e          -- C: SDL_EVENT_WINDOW_DESTROYED
  | 0x21A => .windowHdrStateChanged e    -- C: SDL_EVENT_WINDOW_HDR_STATE_CHANGED
  | _ => .unknown type ⟨ts⟩

#guard mkEventWindow 0x202 9 5 0 0 == .windowShown ⟨9, ⟨5⟩, 0, 0⟩
#guard mkEventWindow 0x2FF 9 5 0 0 == .unknown 0x2FF ⟨9⟩

/-- Maker for `SDL_KeyboardDeviceEvent` events (keyboard hotplug). -/
@[export lean_sdl_mk_event_kdevice]
private def mkEventKdevice (type : UInt32) (ts : UInt64) (which : UInt32) : Event :=
  let e : KeyboardDeviceEvent := ⟨ts, ⟨which⟩⟩
  match type with
  | 0x305 => .keyboardAdded e   -- C: SDL_EVENT_KEYBOARD_ADDED
  | 0x306 => .keyboardRemoved e -- C: SDL_EVENT_KEYBOARD_REMOVED
  | _ => .unknown type ⟨ts⟩

#guard mkEventKdevice 0x305 5 7 == .keyboardAdded ⟨5, ⟨7⟩⟩
#guard mkEventKdevice 0x999 5 7 == .unknown 0x999 ⟨5⟩

/-- Maker for `SDL_KeyboardEvent` events. `scancode`/`key` are `sdl_id`
wrappers; `mod` is a `Keymod` flag set. -/
@[export lean_sdl_mk_event_key]
private def mkEventKey (type : UInt32) (ts : UInt64)
    (windowId which scancode key : UInt32) (mod : UInt16) (raw : UInt16)
    (down «repeat» : Bool) : Event :=
  let e : KeyboardEvent :=
    ⟨ts, ⟨windowId⟩, ⟨which⟩, ⟨scancode⟩, ⟨key⟩, ⟨mod⟩, raw, down, «repeat»⟩
  match type with
  | 0x300 => .keyDown e -- C: SDL_EVENT_KEY_DOWN
  | 0x301 => .keyUp e   -- C: SDL_EVENT_KEY_UP
  | _ => .unknown type ⟨ts⟩

#guard mkEventKey 0x300 5 9 7 4 0x61 0 3 true false
        == .keyDown ⟨5, ⟨9⟩, ⟨7⟩, ⟨4⟩, ⟨0x61⟩, ⟨0⟩, 3, true, false⟩
#guard mkEventKey 0x999 5 9 7 4 0x61 0 3 true false == .unknown 0x999 ⟨5⟩

/-- Maker for `SDL_TextEditingEvent` events. -/
@[export lean_sdl_mk_event_text_editing]
private def mkEventTextEditing (type : UInt32) (ts : UInt64) (windowId : UInt32)
    (text : String) (start length : Int32) : Event :=
  match type with
  | 0x302 => .textEditing ⟨ts, ⟨windowId⟩, text, start, length⟩ -- C: SDL_EVENT_TEXT_EDITING
  | _ => .unknown type ⟨ts⟩

#guard mkEventTextEditing 0x302 5 9 "hi" 0 2 == .textEditing ⟨5, ⟨9⟩, "hi", 0, 2⟩
#guard mkEventTextEditing 0x999 5 9 "hi" 0 2 == .unknown 0x999 ⟨5⟩

/-- Maker for `SDL_TextEditingCandidatesEvent` events. -/
@[export lean_sdl_mk_event_text_editing_candidates]
private def mkEventTextEditingCandidates (type : UInt32) (ts : UInt64)
    (windowId : UInt32) (candidates : Array String) (selected : Int32)
    (horizontal : Bool) : Event :=
  match type with
  | 0x307 => .textEditingCandidates ⟨ts, ⟨windowId⟩, candidates, selected, horizontal⟩
    -- C: SDL_EVENT_TEXT_EDITING_CANDIDATES
  | _ => .unknown type ⟨ts⟩

#guard mkEventTextEditingCandidates 0x307 5 9 #["a", "b"] 1 true
        == .textEditingCandidates ⟨5, ⟨9⟩, #["a", "b"], 1, true⟩
#guard mkEventTextEditingCandidates 0x999 5 9 #[] 0 false == .unknown 0x999 ⟨5⟩

/-- Maker for `SDL_TextInputEvent` events. -/
@[export lean_sdl_mk_event_text_input]
private def mkEventTextInput (type : UInt32) (ts : UInt64) (windowId : UInt32)
    (text : String) : Event :=
  match type with
  | 0x303 => .textInput ⟨ts, ⟨windowId⟩, text⟩ -- C: SDL_EVENT_TEXT_INPUT
  | _ => .unknown type ⟨ts⟩

#guard mkEventTextInput 0x303 5 9 "hi" == .textInput ⟨5, ⟨9⟩, "hi"⟩
#guard mkEventTextInput 0x999 5 9 "hi" == .unknown 0x999 ⟨5⟩

/-- Maker for `SDL_MouseDeviceEvent` events (mouse hotplug). -/
@[export lean_sdl_mk_event_mdevice]
private def mkEventMdevice (type : UInt32) (ts : UInt64) (which : UInt32) : Event :=
  let e : MouseDeviceEvent := ⟨ts, ⟨which⟩⟩
  match type with
  | 0x404 => .mouseAdded e   -- C: SDL_EVENT_MOUSE_ADDED
  | 0x405 => .mouseRemoved e -- C: SDL_EVENT_MOUSE_REMOVED
  | _ => .unknown type ⟨ts⟩

#guard mkEventMdevice 0x404 5 7 == .mouseAdded ⟨5, ⟨7⟩⟩
#guard mkEventMdevice 0x999 5 7 == .unknown 0x999 ⟨5⟩

/-- Maker for `SDL_MouseMotionEvent` events. -/
@[export lean_sdl_mk_event_mouse_motion]
private def mkEventMouseMotion (type : UInt32) (ts : UInt64)
    (windowId which state : UInt32) (x y xrel yrel : Float32) : Event :=
  match type with
  | 0x400 => .mouseMotion ⟨ts, ⟨windowId⟩, ⟨which⟩, ⟨state⟩, x, y, xrel, yrel⟩
    -- C: SDL_EVENT_MOUSE_MOTION
  | _ => .unknown type ⟨ts⟩

#guard mkEventMouseMotion 0x400 5 9 7 1 1.5 2.5 0.5 0.25
        == .mouseMotion ⟨5, ⟨9⟩, ⟨7⟩, ⟨1⟩, 1.5, 2.5, 0.5, 0.25⟩
#guard mkEventMouseMotion 0x999 5 9 7 1 0 0 0 0 == .unknown 0x999 ⟨5⟩

/-- Maker for `SDL_MouseButtonEvent` events. -/
@[export lean_sdl_mk_event_mouse_button]
private def mkEventMouseButton (type : UInt32) (ts : UInt64)
    (windowId which : UInt32) (button : UInt8) (down : Bool) (clicks : UInt8)
    (x y : Float32) : Event :=
  let e : MouseButtonEvent := ⟨ts, ⟨windowId⟩, ⟨which⟩, ⟨button⟩, down, clicks, x, y⟩
  match type with
  | 0x401 => .mouseButtonDown e -- C: SDL_EVENT_MOUSE_BUTTON_DOWN
  | 0x402 => .mouseButtonUp e   -- C: SDL_EVENT_MOUSE_BUTTON_UP
  | _ => .unknown type ⟨ts⟩

#guard mkEventMouseButton 0x401 5 9 7 1 true 2 1.5 2.5
        == .mouseButtonDown ⟨5, ⟨9⟩, ⟨7⟩, ⟨1⟩, true, 2, 1.5, 2.5⟩
#guard mkEventMouseButton 0x999 5 9 7 1 true 2 0 0 == .unknown 0x999 ⟨5⟩

/-- Maker for `SDL_MouseWheelEvent` events. `direction` is decoded with the
total `MouseWheelDirection.ofVal?.getD .normal` (the sentinel never appears in a
real event). -/
@[export lean_sdl_mk_event_mouse_wheel]
private def mkEventMouseWheel (type : UInt32) (ts : UInt64) (windowId which : UInt32)
    (x y : Float32) (direction : UInt32) (mouseX mouseY : Float32)
    (integerX integerY : Int32) : Event :=
  match type with
  | 0x403 => .mouseWheel ⟨ts, ⟨windowId⟩, ⟨which⟩, x, y,
      MouseWheelDirection.ofVal? direction |>.getD .normal, mouseX, mouseY,
      integerX, integerY⟩ -- C: SDL_EVENT_MOUSE_WHEEL
  | _ => .unknown type ⟨ts⟩

#guard mkEventMouseWheel 0x403 5 9 7 1.5 2.5 1 3.5 4.5 1 2
        == .mouseWheel ⟨5, ⟨9⟩, ⟨7⟩, 1.5, 2.5, .flipped, 3.5, 4.5, 1, 2⟩
#guard mkEventMouseWheel 0x999 5 9 7 0 0 0 0 0 0 0 == .unknown 0x999 ⟨5⟩

/-- Maker for `SDL_JoyDeviceEvent` events (joystick hotplug/update). 3-way. -/
@[export lean_sdl_mk_event_jdevice]
private def mkEventJdevice (type : UInt32) (ts : UInt64) (which : UInt32) : Event :=
  let e : JoyDeviceEvent := ⟨ts, ⟨which⟩⟩
  match type with
  | 0x605 => .joystickAdded e          -- C: SDL_EVENT_JOYSTICK_ADDED
  | 0x606 => .joystickRemoved e        -- C: SDL_EVENT_JOYSTICK_REMOVED
  | 0x608 => .joystickUpdateComplete e -- C: SDL_EVENT_JOYSTICK_UPDATE_COMPLETE
  | _ => .unknown type ⟨ts⟩

#guard mkEventJdevice 0x605 5 7 == .joystickAdded ⟨5, ⟨7⟩⟩
#guard mkEventJdevice 0x999 5 7 == .unknown 0x999 ⟨5⟩

/-- Maker for `SDL_JoyAxisEvent` events. -/
@[export lean_sdl_mk_event_jaxis]
private def mkEventJaxis (type : UInt32) (ts : UInt64) (which : UInt32)
    (axis : UInt8) (value : Int16) : Event :=
  match type with
  | 0x600 => .joystickAxisMotion ⟨ts, ⟨which⟩, axis, value⟩ -- C: SDL_EVENT_JOYSTICK_AXIS_MOTION
  | _ => .unknown type ⟨ts⟩

#guard mkEventJaxis 0x600 5 7 2 (-3) == .joystickAxisMotion ⟨5, ⟨7⟩, 2, -3⟩
#guard mkEventJaxis 0x999 5 7 2 0 == .unknown 0x999 ⟨5⟩

/-- Maker for `SDL_JoyBallEvent` events. -/
@[export lean_sdl_mk_event_jball]
private def mkEventJball (type : UInt32) (ts : UInt64) (which : UInt32)
    (ball : UInt8) (xrel yrel : Int16) : Event :=
  match type with
  | 0x601 => .joystickBallMotion ⟨ts, ⟨which⟩, ball, xrel, yrel⟩ -- C: SDL_EVENT_JOYSTICK_BALL_MOTION
  | _ => .unknown type ⟨ts⟩

#guard mkEventJball 0x601 5 7 1 (-2) 3 == .joystickBallMotion ⟨5, ⟨7⟩, 1, -2, 3⟩
#guard mkEventJball 0x999 5 7 1 0 0 == .unknown 0x999 ⟨5⟩

/-- Maker for `SDL_JoyHatEvent` events. -/
@[export lean_sdl_mk_event_jhat]
private def mkEventJhat (type : UInt32) (ts : UInt64) (which : UInt32)
    (hat value : UInt8) : Event :=
  match type with
  | 0x602 => .joystickHatMotion ⟨ts, ⟨which⟩, hat, value⟩ -- C: SDL_EVENT_JOYSTICK_HAT_MOTION
  | _ => .unknown type ⟨ts⟩

#guard mkEventJhat 0x602 5 7 1 2 == .joystickHatMotion ⟨5, ⟨7⟩, 1, 2⟩
#guard mkEventJhat 0x999 5 7 1 2 == .unknown 0x999 ⟨5⟩

/-- Maker for `SDL_JoyButtonEvent` events. -/
@[export lean_sdl_mk_event_jbutton]
private def mkEventJbutton (type : UInt32) (ts : UInt64) (which : UInt32)
    (button : UInt8) (down : Bool) : Event :=
  let e : JoyButtonEvent := ⟨ts, ⟨which⟩, button, down⟩
  match type with
  | 0x603 => .joystickButtonDown e -- C: SDL_EVENT_JOYSTICK_BUTTON_DOWN
  | 0x604 => .joystickButtonUp e   -- C: SDL_EVENT_JOYSTICK_BUTTON_UP
  | _ => .unknown type ⟨ts⟩

#guard mkEventJbutton 0x603 5 7 1 true == .joystickButtonDown ⟨5, ⟨7⟩, 1, true⟩
#guard mkEventJbutton 0x999 5 7 1 true == .unknown 0x999 ⟨5⟩

/-- Maker for `SDL_JoyBatteryEvent` events. `state` is decoded with the total
`PowerState.ofVal?.getD .unknown` (bit-cast `Int32`→`UInt32` first); the error
sentinel never appears in a real event. -/
@[export lean_sdl_mk_event_jbattery]
private def mkEventJbattery (type : UInt32) (ts : UInt64) (which : UInt32)
    (state : Int32) (percent : Int32) : Event :=
  match type with
  | 0x607 => .joystickBatteryUpdated
      ⟨ts, ⟨which⟩, PowerState.ofVal? state.toUInt32 |>.getD .unknown, percent⟩
    -- C: SDL_EVENT_JOYSTICK_BATTERY_UPDATED
  | _ => .unknown type ⟨ts⟩

#guard mkEventJbattery 0x607 5 7 1 42 == .joystickBatteryUpdated ⟨5, ⟨7⟩, .onBattery, 42⟩
#guard mkEventJbattery 0x999 5 7 1 42 == .unknown 0x999 ⟨5⟩

/-- Maker for `SDL_GamepadDeviceEvent` events (gamepad hotplug/update). 5-way. -/
@[export lean_sdl_mk_event_gdevice]
private def mkEventGdevice (type : UInt32) (ts : UInt64) (which : UInt32) : Event :=
  let e : GamepadDeviceEvent := ⟨ts, ⟨which⟩⟩
  match type with
  | 0x653 => .gamepadAdded e                -- C: SDL_EVENT_GAMEPAD_ADDED
  | 0x654 => .gamepadRemoved e              -- C: SDL_EVENT_GAMEPAD_REMOVED
  | 0x655 => .gamepadRemapped e             -- C: SDL_EVENT_GAMEPAD_REMAPPED
  | 0x65A => .gamepadUpdateComplete e       -- C: SDL_EVENT_GAMEPAD_UPDATE_COMPLETE
  | 0x65B => .gamepadSteamHandleUpdated e   -- C: SDL_EVENT_GAMEPAD_STEAM_HANDLE_UPDATED
  | _ => .unknown type ⟨ts⟩

#guard mkEventGdevice 0x65B 5 7 == .gamepadSteamHandleUpdated ⟨5, ⟨7⟩⟩
#guard mkEventGdevice 0x999 5 7 == .unknown 0x999 ⟨5⟩

/-- Maker for `SDL_GamepadAxisEvent` events. -/
@[export lean_sdl_mk_event_gaxis]
private def mkEventGaxis (type : UInt32) (ts : UInt64) (which : UInt32)
    (axis : UInt8) (value : Int16) : Event :=
  match type with
  | 0x650 => .gamepadAxisMotion ⟨ts, ⟨which⟩, axis, value⟩ -- C: SDL_EVENT_GAMEPAD_AXIS_MOTION
  | _ => .unknown type ⟨ts⟩

#guard mkEventGaxis 0x650 5 7 2 (-3) == .gamepadAxisMotion ⟨5, ⟨7⟩, 2, -3⟩
#guard mkEventGaxis 0x999 5 7 2 0 == .unknown 0x999 ⟨5⟩

/-- Maker for `SDL_GamepadButtonEvent` events. -/
@[export lean_sdl_mk_event_gbutton]
private def mkEventGbutton (type : UInt32) (ts : UInt64) (which : UInt32)
    (button : UInt8) (down : Bool) : Event :=
  let e : GamepadButtonEvent := ⟨ts, ⟨which⟩, button, down⟩
  match type with
  | 0x651 => .gamepadButtonDown e -- C: SDL_EVENT_GAMEPAD_BUTTON_DOWN
  | 0x652 => .gamepadButtonUp e   -- C: SDL_EVENT_GAMEPAD_BUTTON_UP
  | _ => .unknown type ⟨ts⟩

#guard mkEventGbutton 0x651 5 7 1 true == .gamepadButtonDown ⟨5, ⟨7⟩, 1, true⟩
#guard mkEventGbutton 0x999 5 7 1 true == .unknown 0x999 ⟨5⟩

/-- Maker for `SDL_GamepadTouchpadEvent` events. 3-way. -/
@[export lean_sdl_mk_event_gtouchpad]
private def mkEventGtouchpad (type : UInt32) (ts : UInt64) (which : UInt32)
    (touchpad finger : Int32) (x y pressure : Float32) : Event :=
  let e : GamepadTouchpadEvent := ⟨ts, ⟨which⟩, touchpad, finger, x, y, pressure⟩
  match type with
  | 0x656 => .gamepadTouchpadDown e   -- C: SDL_EVENT_GAMEPAD_TOUCHPAD_DOWN
  | 0x657 => .gamepadTouchpadMotion e -- C: SDL_EVENT_GAMEPAD_TOUCHPAD_MOTION
  | 0x658 => .gamepadTouchpadUp e     -- C: SDL_EVENT_GAMEPAD_TOUCHPAD_UP
  | _ => .unknown type ⟨ts⟩

#guard mkEventGtouchpad 0x657 5 7 1 2 1.5 2.5 0.5
        == .gamepadTouchpadMotion ⟨5, ⟨7⟩, 1, 2, 1.5, 2.5, 0.5⟩
#guard mkEventGtouchpad 0x999 5 7 1 2 0 0 0 == .unknown 0x999 ⟨5⟩

/-- Maker for `SDL_GamepadSensorEvent` events. -/
@[export lean_sdl_mk_event_gsensor]
private def mkEventGsensor (type : UInt32) (ts : UInt64) (which : UInt32)
    (sensor : Int32) (d0 d1 d2 : Float32) (sensorTs : UInt64) : Event :=
  match type with
  | 0x659 => .gamepadSensorUpdate ⟨ts, ⟨which⟩, sensor, d0, d1, d2, sensorTs⟩
    -- C: SDL_EVENT_GAMEPAD_SENSOR_UPDATE
  | _ => .unknown type ⟨ts⟩

#guard mkEventGsensor 0x659 5 7 1 1.5 2.5 3.5 99
        == .gamepadSensorUpdate ⟨5, ⟨7⟩, 1, 1.5, 2.5, 3.5, 99⟩
#guard mkEventGsensor 0x999 5 7 1 0 0 0 0 == .unknown 0x999 ⟨5⟩

/-- Maker for `SDL_AudioDeviceEvent` events. 3-way. -/
@[export lean_sdl_mk_event_adevice]
private def mkEventAdevice (type : UInt32) (ts : UInt64) (which : UInt32)
    (recording : Bool) : Event :=
  let e : AudioDeviceEvent := ⟨ts, ⟨which⟩, recording⟩
  match type with
  | 0x1100 => .audioDeviceAdded e         -- C: SDL_EVENT_AUDIO_DEVICE_ADDED
  | 0x1101 => .audioDeviceRemoved e       -- C: SDL_EVENT_AUDIO_DEVICE_REMOVED
  | 0x1102 => .audioDeviceFormatChanged e -- C: SDL_EVENT_AUDIO_DEVICE_FORMAT_CHANGED
  | _ => .unknown type ⟨ts⟩

#guard mkEventAdevice 0x1100 5 7 true == .audioDeviceAdded ⟨5, ⟨7⟩, true⟩
#guard mkEventAdevice 0x999 5 7 true == .unknown 0x999 ⟨5⟩

/-- Maker for `SDL_CameraDeviceEvent` events. 4-way. -/
@[export lean_sdl_mk_event_cdevice]
private def mkEventCdevice (type : UInt32) (ts : UInt64) (which : UInt32) : Event :=
  let e : CameraDeviceEvent := ⟨ts, ⟨which⟩⟩
  match type with
  | 0x1400 => .cameraDeviceAdded e    -- C: SDL_EVENT_CAMERA_DEVICE_ADDED
  | 0x1401 => .cameraDeviceRemoved e  -- C: SDL_EVENT_CAMERA_DEVICE_REMOVED
  | 0x1402 => .cameraDeviceApproved e -- C: SDL_EVENT_CAMERA_DEVICE_APPROVED
  | 0x1403 => .cameraDeviceDenied e   -- C: SDL_EVENT_CAMERA_DEVICE_DENIED
  | _ => .unknown type ⟨ts⟩

#guard mkEventCdevice 0x1402 5 7 == .cameraDeviceApproved ⟨5, ⟨7⟩⟩
#guard mkEventCdevice 0x999 5 7 == .unknown 0x999 ⟨5⟩

/-- Maker for `SDL_SensorEvent` events. -/
@[export lean_sdl_mk_event_sensor]
private def mkEventSensor (type : UInt32) (ts : UInt64) (which : UInt32)
    (d0 d1 d2 d3 d4 d5 : Float32) (sensorTs : UInt64) : Event :=
  match type with
  | 0x1200 => .sensorUpdate ⟨ts, ⟨which⟩, d0, d1, d2, d3, d4, d5, sensorTs⟩
    -- C: SDL_EVENT_SENSOR_UPDATE
  | _ => .unknown type ⟨ts⟩

#guard mkEventSensor 0x1200 5 7 1 2 3 4 5 6 99
        == .sensorUpdate ⟨5, ⟨7⟩, 1, 2, 3, 4, 5, 6, 99⟩
#guard mkEventSensor 0x999 5 7 0 0 0 0 0 0 0 == .unknown 0x999 ⟨5⟩

/-- Maker for `SDL_TouchFingerEvent` events. 4-way. -/
@[export lean_sdl_mk_event_tfinger]
private def mkEventTfinger (type : UInt32) (ts : UInt64) (touchId fingerId : UInt64)
    (x y dx dy pressure : Float32) (windowId : UInt32) : Event :=
  let e : TouchFingerEvent := ⟨ts, ⟨touchId⟩, ⟨fingerId⟩, x, y, dx, dy, pressure, ⟨windowId⟩⟩
  match type with
  | 0x700 => .fingerDown e     -- C: SDL_EVENT_FINGER_DOWN
  | 0x701 => .fingerUp e       -- C: SDL_EVENT_FINGER_UP
  | 0x702 => .fingerMotion e   -- C: SDL_EVENT_FINGER_MOTION
  | 0x703 => .fingerCanceled e -- C: SDL_EVENT_FINGER_CANCELED
  | _ => .unknown type ⟨ts⟩

#guard mkEventTfinger 0x700 5 3 4 1.5 2.5 0.5 0.25 0.75 9
        == .fingerDown ⟨5, ⟨3⟩, ⟨4⟩, 1.5, 2.5, 0.5, 0.25, 0.75, ⟨9⟩⟩
#guard mkEventTfinger 0x999 5 3 4 0 0 0 0 0 9 == .unknown 0x999 ⟨5⟩

/-- Maker for `SDL_PinchFingerEvent` events. 3-way. -/
@[export lean_sdl_mk_event_pinch]
private def mkEventPinch (type : UInt32) (ts : UInt64) (scale : Float32)
    (windowId : UInt32) : Event :=
  let e : PinchFingerEvent := ⟨ts, scale, ⟨windowId⟩⟩
  match type with
  | 0x710 => .pinchBegin e  -- C: SDL_EVENT_PINCH_BEGIN
  | 0x711 => .pinchUpdate e -- C: SDL_EVENT_PINCH_UPDATE
  | 0x712 => .pinchEnd e    -- C: SDL_EVENT_PINCH_END
  | _ => .unknown type ⟨ts⟩

#guard mkEventPinch 0x711 5 1.5 9 == .pinchUpdate ⟨5, 1.5, ⟨9⟩⟩
#guard mkEventPinch 0x999 5 1.5 9 == .unknown 0x999 ⟨5⟩

/-- Maker for `SDL_PenProximityEvent` events. -/
@[export lean_sdl_mk_event_pproximity]
private def mkEventPproximity (type : UInt32) (ts : UInt64) (windowId which : UInt32) : Event :=
  let e : PenProximityEvent := ⟨ts, ⟨windowId⟩, ⟨which⟩⟩
  match type with
  | 0x1300 => .penProximityIn e  -- C: SDL_EVENT_PEN_PROXIMITY_IN
  | 0x1301 => .penProximityOut e -- C: SDL_EVENT_PEN_PROXIMITY_OUT
  | _ => .unknown type ⟨ts⟩

#guard mkEventPproximity 0x1300 5 9 7 == .penProximityIn ⟨5, ⟨9⟩, ⟨7⟩⟩
#guard mkEventPproximity 0x999 5 9 7 == .unknown 0x999 ⟨5⟩

/-- Maker for `SDL_PenMotionEvent` events. -/
@[export lean_sdl_mk_event_pmotion]
private def mkEventPmotion (type : UInt32) (ts : UInt64) (windowId which penState : UInt32)
    (x y : Float32) : Event :=
  match type with
  | 0x1306 => .penMotion ⟨ts, ⟨windowId⟩, ⟨which⟩, ⟨penState⟩, x, y⟩ -- C: SDL_EVENT_PEN_MOTION
  | _ => .unknown type ⟨ts⟩

#guard mkEventPmotion 0x1306 5 9 7 1 1.5 2.5 == .penMotion ⟨5, ⟨9⟩, ⟨7⟩, ⟨1⟩, 1.5, 2.5⟩
#guard mkEventPmotion 0x999 5 9 7 1 0 0 == .unknown 0x999 ⟨5⟩

/-- Maker for `SDL_PenTouchEvent` events. -/
@[export lean_sdl_mk_event_ptouch]
private def mkEventPtouch (type : UInt32) (ts : UInt64) (windowId which penState : UInt32)
    (x y : Float32) (eraser down : Bool) : Event :=
  let e : PenTouchEvent := ⟨ts, ⟨windowId⟩, ⟨which⟩, ⟨penState⟩, x, y, eraser, down⟩
  match type with
  | 0x1302 => .penDown e -- C: SDL_EVENT_PEN_DOWN
  | 0x1303 => .penUp e   -- C: SDL_EVENT_PEN_UP
  | _ => .unknown type ⟨ts⟩

#guard mkEventPtouch 0x1302 5 9 7 1 1.5 2.5 false true
        == .penDown ⟨5, ⟨9⟩, ⟨7⟩, ⟨1⟩, 1.5, 2.5, false, true⟩
#guard mkEventPtouch 0x999 5 9 7 1 0 0 false true == .unknown 0x999 ⟨5⟩

/-- Maker for `SDL_PenButtonEvent` events. -/
@[export lean_sdl_mk_event_pbutton]
private def mkEventPbutton (type : UInt32) (ts : UInt64) (windowId which penState : UInt32)
    (x y : Float32) (button : UInt8) (down : Bool) : Event :=
  let e : PenButtonEvent := ⟨ts, ⟨windowId⟩, ⟨which⟩, ⟨penState⟩, x, y, button, down⟩
  match type with
  | 0x1304 => .penButtonDown e -- C: SDL_EVENT_PEN_BUTTON_DOWN
  | 0x1305 => .penButtonUp e   -- C: SDL_EVENT_PEN_BUTTON_UP
  | _ => .unknown type ⟨ts⟩

#guard mkEventPbutton 0x1304 5 9 7 1 1.5 2.5 2 true
        == .penButtonDown ⟨5, ⟨9⟩, ⟨7⟩, ⟨1⟩, 1.5, 2.5, 2, true⟩
#guard mkEventPbutton 0x999 5 9 7 1 0 0 2 true == .unknown 0x999 ⟨5⟩

/-- Maker for `SDL_PenAxisEvent` events. `axis` decoded with the total
`PenAxis.ofVal`. -/
@[export lean_sdl_mk_event_paxis]
private def mkEventPaxis (type : UInt32) (ts : UInt64) (windowId which penState : UInt32)
    (x y : Float32) (axis : UInt32) (value : Float32) : Event :=
  match type with
  | 0x1307 => .penAxis ⟨ts, ⟨windowId⟩, ⟨which⟩, ⟨penState⟩, x, y, PenAxis.ofVal axis, value⟩
    -- C: SDL_EVENT_PEN_AXIS
  | _ => .unknown type ⟨ts⟩

#guard mkEventPaxis 0x1307 5 9 7 1 1.5 2.5 0 0.5
        == .penAxis ⟨5, ⟨9⟩, ⟨7⟩, ⟨1⟩, 1.5, 2.5, .pressure, 0.5⟩
#guard mkEventPaxis 0x999 5 9 7 1 0 0 0 0 == .unknown 0x999 ⟨5⟩

/-- Maker for `SDL_RenderEvent` events. 3-way. -/
@[export lean_sdl_mk_event_render]
private def mkEventRender (type : UInt32) (ts : UInt64) (windowId : UInt32) : Event :=
  let e : RenderEvent := ⟨ts, ⟨windowId⟩⟩
  match type with
  | 0x2000 => .renderTargetsReset e -- C: SDL_EVENT_RENDER_TARGETS_RESET
  | 0x2001 => .renderDeviceReset e  -- C: SDL_EVENT_RENDER_DEVICE_RESET
  | 0x2002 => .renderDeviceLost e   -- C: SDL_EVENT_RENDER_DEVICE_LOST
  | _ => .unknown type ⟨ts⟩

#guard mkEventRender 0x2000 5 9 == .renderTargetsReset ⟨5, ⟨9⟩⟩
#guard mkEventRender 0x999 5 9 == .unknown 0x999 ⟨5⟩

/-- Maker for `SDL_DropEvent` events. 5-way. `source`/`data` are `none` for the
begin/complete phases (SDL passes a NULL filename). -/
@[export lean_sdl_mk_event_drop]
private def mkEventDrop (type : UInt32) (ts : UInt64) (windowId : UInt32)
    (x y : Float32) (source data : Option String) : Event :=
  let e : DropEvent := ⟨ts, ⟨windowId⟩, x, y, source, data⟩
  match type with
  | 0x1000 => .dropFile e     -- C: SDL_EVENT_DROP_FILE
  | 0x1001 => .dropText e     -- C: SDL_EVENT_DROP_TEXT
  | 0x1002 => .dropBegin e    -- C: SDL_EVENT_DROP_BEGIN
  | 0x1003 => .dropComplete e -- C: SDL_EVENT_DROP_COMPLETE
  | 0x1004 => .dropPosition e -- C: SDL_EVENT_DROP_POSITION
  | _ => .unknown type ⟨ts⟩

#guard mkEventDrop 0x1000 5 9 1.5 2.5 (some "a") (some "/b")
        == .dropFile ⟨5, ⟨9⟩, 1.5, 2.5, some "a", some "/b"⟩
#guard mkEventDrop 0x1002 5 9 0 0 none none == .dropBegin ⟨5, ⟨9⟩, 0, 0, none, none⟩
#guard mkEventDrop 0x999 5 9 0 0 none none == .unknown 0x999 ⟨5⟩

/-- Maker for `SDL_ClipboardEvent` events. -/
@[export lean_sdl_mk_event_clipboard]
private def mkEventClipboard (type : UInt32) (ts : UInt64) (owner : Bool)
    (mimeTypes : Array String) : Event :=
  match type with
  | 0x900 => .clipboardUpdate ⟨ts, owner, mimeTypes⟩ -- C: SDL_EVENT_CLIPBOARD_UPDATE
  | _ => .unknown type ⟨ts⟩

#guard mkEventClipboard 0x900 5 true #["text/plain"]
        == .clipboardUpdate ⟨5, true, #["text/plain"]⟩
#guard mkEventClipboard 0x999 5 false #[] == .unknown 0x999 ⟨5⟩

/-- Maker for `SDL_UserEvent` events (type in `0x8000 .. 0xFFFF`). The raw
`type` is preserved in the `.user` constructor. -/
@[export lean_sdl_mk_event_user]
private def mkEventUser (type : UInt32) (ts : UInt64) (windowId : UInt32)
    (code : Int32) : Event :=
  .user type ⟨ts, ⟨windowId⟩, code⟩ -- C: SDL_EVENT_USER .. SDL_EVENT_LAST

#guard mkEventUser 0x8000 5 9 42 == .user 0x8000 ⟨5, ⟨9⟩, 42⟩

/-! ## Event-queue API

All main-thread; each shim runs `SDL_SHIM_PROLOGUE()`. -/

/-- Pump the event loop, gathering input-device events onto the queue. Rarely
needed directly (`pollEvent`/`waitEvent` pump implicitly). Main thread only.
C: `SDL_PumpEvents`. -/
@[extern "lean_sdl_pump_events"]
opaque pumpEvents : IO Unit

/-- Poll for the next pending event, removing it from the queue; `none` if the
queue is empty. Pumps the queue implicitly. Main thread only.
C: `SDL_PollEvent`. -/
@[extern "lean_sdl_poll_event"]
opaque pollEvent : IO (Option Event)

/-- Wait indefinitely for the next event, removing it from the queue. Throws on
a wait error. Main thread only. C: `SDL_WaitEvent`. -/
@[extern "lean_sdl_wait_event"]
opaque waitEvent : IO Event

/-- Wait up to `timeoutMs` milliseconds for the next event; `none` if the
timeout elapses with no event. Main thread only. C: `SDL_WaitEventTimeout`. -/
@[extern "lean_sdl_wait_event_timeout"]
opaque waitEventTimeout (timeoutMs : Int32) : IO (Option Event)

@[extern "lean_sdl_push_user_event"]
private opaque pushUserEventRaw (type : UInt32) (code : Int32) (windowId : UInt32) : IO Bool

/-- Push a user event onto the queue. The event is `SDL_zero`'d then filled with
`type`, `code`, and `windowId`; its timestamp is left 0 so SDL stamps it on
push. Returns the raw `SDL_PushEvent` result (`false` = filtered out or the push
failed; it does *not* throw). `type` should come from `registerEvents`.
C: `SDL_PushEvent` with an `SDL_UserEvent`. -/
def pushUserEvent (type : EventType) (code : Int32 := 0) (windowId : WindowId := ⟨0⟩) :
    IO Bool :=
  pushUserEventRaw type.val code windowId.val

@[extern "lean_sdl_register_events"]
private opaque registerEventsRaw (count : Int32) : IO UInt32

/-- Allocate `count` contiguous user-event types and return the first, or `none`
if `count` is invalid or not enough user types remain. C: `SDL_RegisterEvents`. -/
def registerEvents (count : Int32 := 1) : IO (Option EventType) := do
  let t ← registerEventsRaw count
  return if t == 0 then none else some ⟨t⟩

@[extern "lean_sdl_has_event"]
private opaque hasEventRaw (type : UInt32) : IO Bool

/-- Whether any event of `type` is currently on the queue. C: `SDL_HasEvent`. -/
def hasEvent (type : EventType) : IO Bool :=
  hasEventRaw type.val

@[extern "lean_sdl_has_events"]
private opaque hasEventsRaw (minType maxType : UInt32) : IO Bool

/-- Whether any event with `minType ≤ type ≤ maxType` is currently on the queue.
C: `SDL_HasEvents`. -/
def hasEvents (minType : EventType := .first) (maxType : EventType := .last) : IO Bool :=
  hasEventsRaw minType.val maxType.val

@[extern "lean_sdl_flush_event"]
private opaque flushEventRaw (type : UInt32) : IO Unit

/-- Remove all queued events of `type`. C: `SDL_FlushEvent`. -/
def flushEvent (type : EventType) : IO Unit :=
  flushEventRaw type.val

@[extern "lean_sdl_flush_events"]
private opaque flushEventsRaw (minType maxType : UInt32) : IO Unit

/-- Remove all queued events with `minType ≤ type ≤ maxType`.
C: `SDL_FlushEvents`. -/
def flushEvents (minType : EventType := .first) (maxType : EventType := .last) : IO Unit :=
  flushEventsRaw minType.val maxType.val

@[extern "lean_sdl_set_event_enabled"]
private opaque setEventEnabledRaw (type : UInt32) (enabled : Bool) : IO Unit

/-- Enable or disable processing of events of `type`.

Note (verified against SDL's source): events pushed with `pushUserEvent`
BYPASS the enabled check — enablement is enforced only at SDL's own event
*generation* sites, so a disabled type can still be pushed and polled by the
app. Disabling a type additionally FLUSHES any pending events of that type from
the queue. So do not rely on this to drop app-pushed events; use it to stop SDL
from generating a category (and to clear pending ones). C: `SDL_SetEventEnabled`. -/
def setEventEnabled (type : EventType) (enabled : Bool) : IO Unit :=
  setEventEnabledRaw type.val enabled

@[extern "lean_sdl_event_enabled"]
private opaque eventEnabledRaw (type : UInt32) : IO Bool

/-- Whether events of `type` are currently being processed by SDL.
C: `SDL_EventEnabled`. -/
def eventEnabled (type : EventType) : IO Bool :=
  eventEnabledRaw type.val

/-! ## Event watches and filters

Both kinds of callback receive a *decoded copy* of the event — unlike C, they
cannot mutate the event in the queue. Both may run on whatever thread generates
or pushes the event (SDL threads are registered with the Lean runtime by the
binding); keep them fast, and never touch video/render APIs from one. -/

/-- Identifies an event watch from `addEventWatch` for later removal. This is a
binding-local key, not an SDL id (SDL identifies watches by a C
function/userdata pair). -/
sdl_id EventWatchId : UInt64

@[extern "lean_sdl_add_event_watch"]
private opaque addEventWatchRaw (cb : Event → IO Unit) : IO UInt64

/-- Call `cb` for every event as it enters the queue (and immediately for
events that bypass it, e.g. quit signals). Runs on the thread posting the
event, *during* the push — before `pushUserEvent` returns, the watch has run.
Watches do not see events dropped by the filter (`setEventFilter`) or disabled
types; exceptions in `cb` are swallowed. C: `SDL_AddEventWatch`. -/
def addEventWatch (cb : Event → IO Unit) : IO EventWatchId := do
  return ⟨← addEventWatchRaw cb⟩

@[extern "lean_sdl_remove_event_watch"]
private opaque removeEventWatchRaw (key : UInt64) : IO Bool

/-- Remove an event watch. Returns `false` (a safe no-op) if `id` was already
removed. At most one in-flight invocation may still complete on another thread.
C: `SDL_RemoveEventWatch`. -/
def removeEventWatch (id : EventWatchId) : IO Bool :=
  removeEventWatchRaw id.val

/-- Install `cb` as the one global event filter: every candidate event is
offered to it *before* entering the queue, and is dropped (unrecoverably) when
`cb` returns `false`. Replaces any previous filter. Runs synchronously on the
generating/pushing thread — a dropped push makes `pushUserEvent` return
`false`, and watches never see dropped events. Exceptions in `cb` keep the
event. Events already sitting in the queue are not re-filtered (use
`filterEvents` for those). C: `SDL_SetEventFilter`. -/
@[extern "lean_sdl_set_event_filter"]
opaque setEventFilter (cb : Event → IO Bool) : IO Unit

/-- Remove the filter installed by `setEventFilter` (a no-op if none).
C: `SDL_SetEventFilter(NULL, NULL)`. -/
@[extern "lean_sdl_clear_event_filter"]
opaque clearEventFilter : IO Unit

/-- Run `cb` once over every event currently in the queue, on the calling
thread, removing those for which it returns `false`. Exceptions keep the
event. C: `SDL_FilterEvents`. -/
@[extern "lean_sdl_filter_events"]
opaque filterEvents (cb : Event → IO Bool) : IO Unit

end Sdl
