module

public import Sdl.Core.Macros
public meta import Sdl.Core.Macros
public import Sdl.Error
public meta import Sdl.Error

public section

/-!
# Configuration hints (`SDL_hints.h`)

String-keyed configuration variables. Hint-name constants live in the
`Sdl.Hint` namespace (`Sdl.Hint.appId = "SDL_APP_ID"`), one per
`SDL_HINT_*` `#define` in the header.
-/

namespace Sdl

/-- Priority of a hint override. C: `SDL_HintPriority`. -/
sdl_enum HintPriority : UInt32 where
  | default  => 0  -- C: SDL_HINT_DEFAULT
  | normal   => 1  -- C: SDL_HINT_NORMAL
  | override => 2  -- C: SDL_HINT_OVERRIDE

/-- Set a hint (at `.normal` priority; environment overrides win).
C: `SDL_SetHint`. -/
@[extern "lean_sdl_set_hint"]
opaque setHint (name value : @& String) : IO Unit

@[extern "lean_sdl_set_hint_with_priority"]
private opaque setHintWithPriorityRaw (name value : @& String) (priority : UInt32) : IO Unit

/-- Set a hint with an explicit priority. C: `SDL_SetHintWithPriority`. -/
def setHintWithPriority (name value : @& String) (priority : HintPriority) : IO Unit :=
  setHintWithPriorityRaw name value priority.val

/-- Reset a hint to its default (re-reading the environment).
C: `SDL_ResetHint`. -/
@[extern "lean_sdl_reset_hint"]
opaque resetHint (name : @& String) : IO Unit

/-- Reset all hints to their defaults. C: `SDL_ResetHints`. -/
@[extern "lean_sdl_reset_hints"]
opaque resetHints : IO Unit

/-- Current value of a hint, or `none` if unset (not an error).
C: `SDL_GetHint`. -/
@[extern "lean_sdl_get_hint"]
opaque getHint (name : @& String) : IO (Option String)

/-- Boolean value of a hint, or `defaultValue` if unset/unparseable.
C: `SDL_GetHintBoolean`. -/
@[extern "lean_sdl_get_hint_boolean"]
opaque getHintBoolean (name : @& String) (defaultValue : Bool := false) : IO Bool

/-- Identifies a hint callback from `addHintCallback` for later removal
(binding-local key, not an SDL id). -/
sdl_id HintCallbackId : UInt64

@[extern "lean_sdl_add_hint_callback"]
private opaque addHintCallbackRaw (name : @& String)
    (cb : String → Option String → Option String → IO Unit) : IO UInt64

/-- Call `cb name oldValue newValue` whenever the hint `name` changes — and
once, synchronously, during this call with the hint's current value. Runs on
the thread that sets the hint; exceptions in `cb` are swallowed.
C: `SDL_AddHintCallback`. -/
def addHintCallback (name : String)
    (cb : (name : String) → (oldValue newValue : Option String) → IO Unit) :
    IO HintCallbackId := do
  return ⟨← addHintCallbackRaw name cb⟩

@[extern "lean_sdl_remove_hint_callback"]
private opaque removeHintCallbackRaw (id : UInt64) : IO Bool

/-- Remove a hint callback. Returns `false` (a safe no-op) if `id` was already
removed. C: `SDL_RemoveHintCallback`. -/
def removeHintCallback (id : HintCallbackId) : IO Bool :=
  removeHintCallbackRaw id.val

/-! Hint-name string constants (one per `SDL_HINT_*` in `SDL_hints.h`). -/
namespace Hint

/-- C: `SDL_HINT_ALLOW_ALT_TAB_WHILE_GRABBED`. -/
def allowAltTabWhileGrabbed : String := "SDL_ALLOW_ALT_TAB_WHILE_GRABBED"
/-- C: `SDL_HINT_ANDROID_ALLOW_RECREATE_ACTIVITY`. -/
def androidAllowRecreateActivity : String := "SDL_ANDROID_ALLOW_RECREATE_ACTIVITY"
/-- C: `SDL_HINT_ANDROID_BLOCK_ON_PAUSE`. -/
def androidBlockOnPause : String := "SDL_ANDROID_BLOCK_ON_PAUSE"
/-- C: `SDL_HINT_ANDROID_LOW_LATENCY_AUDIO`. -/
def androidLowLatencyAudio : String := "SDL_ANDROID_LOW_LATENCY_AUDIO"
/-- C: `SDL_HINT_ANDROID_TRAP_BACK_BUTTON`. -/
def androidTrapBackButton : String := "SDL_ANDROID_TRAP_BACK_BUTTON"
/-- C: `SDL_HINT_APP_ID`. -/
def appId : String := "SDL_APP_ID"
/-- C: `SDL_HINT_APP_NAME`. -/
def appName : String := "SDL_APP_NAME"
/-- C: `SDL_HINT_APPLE_TV_CONTROLLER_UI_EVENTS`. -/
def appleTvControllerUiEvents : String := "SDL_APPLE_TV_CONTROLLER_UI_EVENTS"
/-- C: `SDL_HINT_APPLE_TV_REMOTE_ALLOW_ROTATION`. -/
def appleTvRemoteAllowRotation : String := "SDL_APPLE_TV_REMOTE_ALLOW_ROTATION"
/-- C: `SDL_HINT_AUDIO_ALSA_DEFAULT_DEVICE`. -/
def audioAlsaDefaultDevice : String := "SDL_AUDIO_ALSA_DEFAULT_DEVICE"
/-- C: `SDL_HINT_AUDIO_ALSA_DEFAULT_PLAYBACK_DEVICE`. -/
def audioAlsaDefaultPlaybackDevice : String := "SDL_AUDIO_ALSA_DEFAULT_PLAYBACK_DEVICE"
/-- C: `SDL_HINT_AUDIO_ALSA_DEFAULT_RECORDING_DEVICE`. -/
def audioAlsaDefaultRecordingDevice : String := "SDL_AUDIO_ALSA_DEFAULT_RECORDING_DEVICE"
/-- C: `SDL_HINT_AUDIO_CATEGORY`. -/
def audioCategory : String := "SDL_AUDIO_CATEGORY"
/-- C: `SDL_HINT_AUDIO_CHANNELS`. -/
def audioChannels : String := "SDL_AUDIO_CHANNELS"
/-- C: `SDL_HINT_AUDIO_DEVICE_APP_ICON_NAME`. -/
def audioDeviceAppIconName : String := "SDL_AUDIO_DEVICE_APP_ICON_NAME"
/-- C: `SDL_HINT_AUDIO_DEVICE_SAMPLE_FRAMES`. -/
def audioDeviceSampleFrames : String := "SDL_AUDIO_DEVICE_SAMPLE_FRAMES"
/-- C: `SDL_HINT_AUDIO_DEVICE_STREAM_NAME`. -/
def audioDeviceStreamName : String := "SDL_AUDIO_DEVICE_STREAM_NAME"
/-- C: `SDL_HINT_AUDIO_DEVICE_STREAM_ROLE`. -/
def audioDeviceStreamRole : String := "SDL_AUDIO_DEVICE_STREAM_ROLE"
/-- C: `SDL_HINT_AUDIO_DEVICE_RAW_STREAM`. -/
def audioDeviceRawStream : String := "SDL_AUDIO_DEVICE_RAW_STREAM"
/-- C: `SDL_HINT_AUDIO_DISK_INPUT_FILE`. -/
def audioDiskInputFile : String := "SDL_AUDIO_DISK_INPUT_FILE"
/-- C: `SDL_HINT_AUDIO_DISK_OUTPUT_FILE`. -/
def audioDiskOutputFile : String := "SDL_AUDIO_DISK_OUTPUT_FILE"
/-- C: `SDL_HINT_AUDIO_DISK_TIMESCALE`. -/
def audioDiskTimescale : String := "SDL_AUDIO_DISK_TIMESCALE"
/-- C: `SDL_HINT_AUDIO_DRIVER`. -/
def audioDriver : String := "SDL_AUDIO_DRIVER"
/-- C: `SDL_HINT_AUDIO_DUMMY_TIMESCALE`. -/
def audioDummyTimescale : String := "SDL_AUDIO_DUMMY_TIMESCALE"
/-- C: `SDL_HINT_AUDIO_FORMAT`. -/
def audioFormat : String := "SDL_AUDIO_FORMAT"
/-- C: `SDL_HINT_AUDIO_FREQUENCY`. -/
def audioFrequency : String := "SDL_AUDIO_FREQUENCY"
/-- C: `SDL_HINT_AUDIO_INCLUDE_MONITORS`. -/
def audioIncludeMonitors : String := "SDL_AUDIO_INCLUDE_MONITORS"
/-- C: `SDL_HINT_AUTO_UPDATE_JOYSTICKS`. -/
def autoUpdateJoysticks : String := "SDL_AUTO_UPDATE_JOYSTICKS"
/-- C: `SDL_HINT_AUTO_UPDATE_SENSORS`. -/
def autoUpdateSensors : String := "SDL_AUTO_UPDATE_SENSORS"
/-- C: `SDL_HINT_BMP_SAVE_LEGACY_FORMAT`. -/
def bmpSaveLegacyFormat : String := "SDL_BMP_SAVE_LEGACY_FORMAT"
/-- C: `SDL_HINT_CAMERA_DRIVER`. -/
def cameraDriver : String := "SDL_CAMERA_DRIVER"
/-- C: `SDL_HINT_CPU_FEATURE_MASK`. -/
def cpuFeatureMask : String := "SDL_CPU_FEATURE_MASK"
/-- C: `SDL_HINT_JOYSTICK_DIRECTINPUT`. -/
def joystickDirectinput : String := "SDL_JOYSTICK_DIRECTINPUT"
/-- C: `SDL_HINT_FILE_DIALOG_DRIVER`. -/
def fileDialogDriver : String := "SDL_FILE_DIALOG_DRIVER"
/-- C: `SDL_HINT_DISPLAY_USABLE_BOUNDS`. -/
def displayUsableBounds : String := "SDL_DISPLAY_USABLE_BOUNDS"
/-- C: `SDL_HINT_INVALID_PARAM_CHECKS`. -/
def invalidParamChecks : String := "SDL_INVALID_PARAM_CHECKS"
/-- C: `SDL_HINT_EMSCRIPTEN_ASYNCIFY`. -/
def emscriptenAsyncify : String := "SDL_EMSCRIPTEN_ASYNCIFY"
/-- C: `SDL_HINT_EMSCRIPTEN_CANVAS_SELECTOR`. -/
def emscriptenCanvasSelector : String := "SDL_EMSCRIPTEN_CANVAS_SELECTOR"
/-- C: `SDL_HINT_EMSCRIPTEN_KEYBOARD_ELEMENT`. -/
def emscriptenKeyboardElement : String := "SDL_EMSCRIPTEN_KEYBOARD_ELEMENT"
/-- C: `SDL_HINT_ENABLE_SCREEN_KEYBOARD`. -/
def enableScreenKeyboard : String := "SDL_ENABLE_SCREEN_KEYBOARD"
/-- C: `SDL_HINT_EVDEV_DEVICES`. -/
def evdevDevices : String := "SDL_EVDEV_DEVICES"
/-- C: `SDL_HINT_EVENT_LOGGING`. -/
def eventLogging : String := "SDL_EVENT_LOGGING"
/-- C: `SDL_HINT_FORCE_RAISEWINDOW`. -/
def forceRaisewindow : String := "SDL_FORCE_RAISEWINDOW"
/-- C: `SDL_HINT_FRAMEBUFFER_ACCELERATION`. -/
def framebufferAcceleration : String := "SDL_FRAMEBUFFER_ACCELERATION"
/-- C: `SDL_HINT_GAMECONTROLLERCONFIG`. -/
def gamecontrollerconfig : String := "SDL_GAMECONTROLLERCONFIG"
/-- C: `SDL_HINT_GAMECONTROLLERCONFIG_FILE`. -/
def gamecontrollerconfigFile : String := "SDL_GAMECONTROLLERCONFIG_FILE"
/-- C: `SDL_HINT_GAMECONTROLLERTYPE`. -/
def gamecontrollertype : String := "SDL_GAMECONTROLLERTYPE"
/-- C: `SDL_HINT_GAMECONTROLLER_IGNORE_DEVICES`. -/
def gamecontrollerIgnoreDevices : String := "SDL_GAMECONTROLLER_IGNORE_DEVICES"
/-- C: `SDL_HINT_GAMECONTROLLER_IGNORE_DEVICES_EXCEPT`. -/
def gamecontrollerIgnoreDevicesExcept : String := "SDL_GAMECONTROLLER_IGNORE_DEVICES_EXCEPT"
/-- C: `SDL_HINT_GAMECONTROLLER_SENSOR_FUSION`. -/
def gamecontrollerSensorFusion : String := "SDL_GAMECONTROLLER_SENSOR_FUSION"
/-- C: `SDL_HINT_GDK_TEXTINPUT_DEFAULT_TEXT`. -/
def gdkTextinputDefaultText : String := "SDL_GDK_TEXTINPUT_DEFAULT_TEXT"
/-- C: `SDL_HINT_GDK_TEXTINPUT_DESCRIPTION`. -/
def gdkTextinputDescription : String := "SDL_GDK_TEXTINPUT_DESCRIPTION"
/-- C: `SDL_HINT_GDK_TEXTINPUT_MAX_LENGTH`. -/
def gdkTextinputMaxLength : String := "SDL_GDK_TEXTINPUT_MAX_LENGTH"
/-- C: `SDL_HINT_GDK_TEXTINPUT_SCOPE`. -/
def gdkTextinputScope : String := "SDL_GDK_TEXTINPUT_SCOPE"
/-- C: `SDL_HINT_GDK_TEXTINPUT_TITLE`. -/
def gdkTextinputTitle : String := "SDL_GDK_TEXTINPUT_TITLE"
/-- C: `SDL_HINT_HIDAPI_LIBUSB`. -/
def hidapiLibusb : String := "SDL_HIDAPI_LIBUSB"
/-- C: `SDL_HINT_HIDAPI_LIBUSB_GAMECUBE`. -/
def hidapiLibusbGamecube : String := "SDL_HIDAPI_LIBUSB_GAMECUBE"
/-- C: `SDL_HINT_HIDAPI_LIBUSB_WHITELIST`. -/
def hidapiLibusbWhitelist : String := "SDL_HIDAPI_LIBUSB_WHITELIST"
/-- C: `SDL_HINT_HIDAPI_UDEV`. -/
def hidapiUdev : String := "SDL_HIDAPI_UDEV"
/-- C: `SDL_HINT_GPU_DRIVER`. -/
def gpuDriver : String := "SDL_GPU_DRIVER"
/-- C: `SDL_HINT_HIDAPI_ENUMERATE_ONLY_CONTROLLERS`. -/
def hidapiEnumerateOnlyControllers : String := "SDL_HIDAPI_ENUMERATE_ONLY_CONTROLLERS"
/-- C: `SDL_HINT_HIDAPI_IGNORE_DEVICES`. -/
def hidapiIgnoreDevices : String := "SDL_HIDAPI_IGNORE_DEVICES"
/-- C: `SDL_HINT_IME_IMPLEMENTED_UI`. -/
def imeImplementedUi : String := "SDL_IME_IMPLEMENTED_UI"
/-- C: `SDL_HINT_IOS_HIDE_HOME_INDICATOR`. -/
def iosHideHomeIndicator : String := "SDL_IOS_HIDE_HOME_INDICATOR"
/-- C: `SDL_HINT_JOYSTICK_ALLOW_BACKGROUND_EVENTS`. -/
def joystickAllowBackgroundEvents : String := "SDL_JOYSTICK_ALLOW_BACKGROUND_EVENTS"
/-- C: `SDL_HINT_JOYSTICK_ARCADESTICK_DEVICES`. -/
def joystickArcadestickDevices : String := "SDL_JOYSTICK_ARCADESTICK_DEVICES"
/-- C: `SDL_HINT_JOYSTICK_ARCADESTICK_DEVICES_EXCLUDED`. -/
def joystickArcadestickDevicesExcluded : String := "SDL_JOYSTICK_ARCADESTICK_DEVICES_EXCLUDED"
/-- C: `SDL_HINT_JOYSTICK_BLACKLIST_DEVICES`. -/
def joystickBlacklistDevices : String := "SDL_JOYSTICK_BLACKLIST_DEVICES"
/-- C: `SDL_HINT_JOYSTICK_BLACKLIST_DEVICES_EXCLUDED`. -/
def joystickBlacklistDevicesExcluded : String := "SDL_JOYSTICK_BLACKLIST_DEVICES_EXCLUDED"
/-- C: `SDL_HINT_JOYSTICK_DEVICE`. -/
def joystickDevice : String := "SDL_JOYSTICK_DEVICE"
/-- C: `SDL_HINT_JOYSTICK_ENHANCED_REPORTS`. -/
def joystickEnhancedReports : String := "SDL_JOYSTICK_ENHANCED_REPORTS"
/-- C: `SDL_HINT_JOYSTICK_FLIGHTSTICK_DEVICES`. -/
def joystickFlightstickDevices : String := "SDL_JOYSTICK_FLIGHTSTICK_DEVICES"
/-- C: `SDL_HINT_JOYSTICK_FLIGHTSTICK_DEVICES_EXCLUDED`. -/
def joystickFlightstickDevicesExcluded : String := "SDL_JOYSTICK_FLIGHTSTICK_DEVICES_EXCLUDED"
/-- C: `SDL_HINT_JOYSTICK_GAMEINPUT`. -/
def joystickGameinput : String := "SDL_JOYSTICK_GAMEINPUT"
/-- C: `SDL_HINT_JOYSTICK_GAMEINPUT_RAW`. -/
def joystickGameinputRaw : String := "SDL_JOYSTICK_GAMEINPUT_RAW"
/-- C: `SDL_HINT_JOYSTICK_GAMECUBE_DEVICES`. -/
def joystickGamecubeDevices : String := "SDL_JOYSTICK_GAMECUBE_DEVICES"
/-- C: `SDL_HINT_JOYSTICK_GAMECUBE_DEVICES_EXCLUDED`. -/
def joystickGamecubeDevicesExcluded : String := "SDL_JOYSTICK_GAMECUBE_DEVICES_EXCLUDED"
/-- C: `SDL_HINT_JOYSTICK_HIDAPI`. -/
def joystickHidapi : String := "SDL_JOYSTICK_HIDAPI"
/-- C: `SDL_HINT_JOYSTICK_HIDAPI_COMBINE_JOY_CONS`. -/
def joystickHidapiCombineJoyCons : String := "SDL_JOYSTICK_HIDAPI_COMBINE_JOY_CONS"
/-- C: `SDL_HINT_JOYSTICK_HIDAPI_GAMECUBE`. -/
def joystickHidapiGamecube : String := "SDL_JOYSTICK_HIDAPI_GAMECUBE"
/-- C: `SDL_HINT_JOYSTICK_HIDAPI_GAMECUBE_RUMBLE_BRAKE`. -/
def joystickHidapiGamecubeRumbleBrake : String := "SDL_JOYSTICK_HIDAPI_GAMECUBE_RUMBLE_BRAKE"
/-- C: `SDL_HINT_JOYSTICK_HIDAPI_JOY_CONS`. -/
def joystickHidapiJoyCons : String := "SDL_JOYSTICK_HIDAPI_JOY_CONS"
/-- C: `SDL_HINT_JOYSTICK_HIDAPI_JOYCON_HOME_LED`. -/
def joystickHidapiJoyconHomeLed : String := "SDL_JOYSTICK_HIDAPI_JOYCON_HOME_LED"
/-- C: `SDL_HINT_JOYSTICK_HIDAPI_LUNA`. -/
def joystickHidapiLuna : String := "SDL_JOYSTICK_HIDAPI_LUNA"
/-- C: `SDL_HINT_JOYSTICK_HIDAPI_NINTENDO_CLASSIC`. -/
def joystickHidapiNintendoClassic : String := "SDL_JOYSTICK_HIDAPI_NINTENDO_CLASSIC"
/-- C: `SDL_HINT_JOYSTICK_HIDAPI_PS3`. -/
def joystickHidapiPs3 : String := "SDL_JOYSTICK_HIDAPI_PS3"
/-- C: `SDL_HINT_JOYSTICK_HIDAPI_PS3_SIXAXIS_DRIVER`. -/
def joystickHidapiPs3SixaxisDriver : String := "SDL_JOYSTICK_HIDAPI_PS3_SIXAXIS_DRIVER"
/-- C: `SDL_HINT_JOYSTICK_HIDAPI_PS4`. -/
def joystickHidapiPs4 : String := "SDL_JOYSTICK_HIDAPI_PS4"
/-- C: `SDL_HINT_JOYSTICK_HIDAPI_PS4_REPORT_INTERVAL`. -/
def joystickHidapiPs4ReportInterval : String := "SDL_JOYSTICK_HIDAPI_PS4_REPORT_INTERVAL"
/-- C: `SDL_HINT_JOYSTICK_HIDAPI_PS5`. -/
def joystickHidapiPs5 : String := "SDL_JOYSTICK_HIDAPI_PS5"
/-- C: `SDL_HINT_JOYSTICK_HIDAPI_PS5_PLAYER_LED`. -/
def joystickHidapiPs5PlayerLed : String := "SDL_JOYSTICK_HIDAPI_PS5_PLAYER_LED"
/-- C: `SDL_HINT_JOYSTICK_HIDAPI_SHIELD`. -/
def joystickHidapiShield : String := "SDL_JOYSTICK_HIDAPI_SHIELD"
/-- C: `SDL_HINT_JOYSTICK_HIDAPI_STADIA`. -/
def joystickHidapiStadia : String := "SDL_JOYSTICK_HIDAPI_STADIA"
/-- C: `SDL_HINT_JOYSTICK_HIDAPI_STEAM`. -/
def joystickHidapiSteam : String := "SDL_JOYSTICK_HIDAPI_STEAM"
/-- C: `SDL_HINT_JOYSTICK_HIDAPI_STEAM_HOME_LED`. -/
def joystickHidapiSteamHomeLed : String := "SDL_JOYSTICK_HIDAPI_STEAM_HOME_LED"
/-- C: `SDL_HINT_JOYSTICK_HIDAPI_STEAMDECK`. -/
def joystickHidapiSteamdeck : String := "SDL_JOYSTICK_HIDAPI_STEAMDECK"
/-- C: `SDL_HINT_JOYSTICK_HIDAPI_STEAM_HORI`. -/
def joystickHidapiSteamHori : String := "SDL_JOYSTICK_HIDAPI_STEAM_HORI"
/-- C: `SDL_HINT_JOYSTICK_HIDAPI_LG4FF`. -/
def joystickHidapiLg4ff : String := "SDL_JOYSTICK_HIDAPI_LG4FF"
/-- C: `SDL_HINT_JOYSTICK_HIDAPI_8BITDO`. -/
def joystickHidapi8bitdo : String := "SDL_JOYSTICK_HIDAPI_8BITDO"
/-- C: `SDL_HINT_JOYSTICK_HIDAPI_SINPUT`. -/
def joystickHidapiSinput : String := "SDL_JOYSTICK_HIDAPI_SINPUT"
/-- C: `SDL_HINT_JOYSTICK_HIDAPI_ZUIKI`. -/
def joystickHidapiZuiki : String := "SDL_JOYSTICK_HIDAPI_ZUIKI"
/-- C: `SDL_HINT_JOYSTICK_HIDAPI_FLYDIGI`. -/
def joystickHidapiFlydigi : String := "SDL_JOYSTICK_HIDAPI_FLYDIGI"
/-- C: `SDL_HINT_JOYSTICK_HIDAPI_SWITCH`. -/
def joystickHidapiSwitch : String := "SDL_JOYSTICK_HIDAPI_SWITCH"
/-- C: `SDL_HINT_JOYSTICK_HIDAPI_SWITCH_HOME_LED`. -/
def joystickHidapiSwitchHomeLed : String := "SDL_JOYSTICK_HIDAPI_SWITCH_HOME_LED"
/-- C: `SDL_HINT_JOYSTICK_HIDAPI_SWITCH_PLAYER_LED`. -/
def joystickHidapiSwitchPlayerLed : String := "SDL_JOYSTICK_HIDAPI_SWITCH_PLAYER_LED"
/-- C: `SDL_HINT_JOYSTICK_HIDAPI_SWITCH2`. -/
def joystickHidapiSwitch2 : String := "SDL_JOYSTICK_HIDAPI_SWITCH2"
/-- C: `SDL_HINT_JOYSTICK_HIDAPI_VERTICAL_JOY_CONS`. -/
def joystickHidapiVerticalJoyCons : String := "SDL_JOYSTICK_HIDAPI_VERTICAL_JOY_CONS"
/-- C: `SDL_HINT_JOYSTICK_HIDAPI_WII`. -/
def joystickHidapiWii : String := "SDL_JOYSTICK_HIDAPI_WII"
/-- C: `SDL_HINT_JOYSTICK_HIDAPI_WII_PLAYER_LED`. -/
def joystickHidapiWiiPlayerLed : String := "SDL_JOYSTICK_HIDAPI_WII_PLAYER_LED"
/-- C: `SDL_HINT_JOYSTICK_HIDAPI_XBOX`. -/
def joystickHidapiXbox : String := "SDL_JOYSTICK_HIDAPI_XBOX"
/-- C: `SDL_HINT_JOYSTICK_HIDAPI_XBOX_360`. -/
def joystickHidapiXbox360 : String := "SDL_JOYSTICK_HIDAPI_XBOX_360"
/-- C: `SDL_HINT_JOYSTICK_HIDAPI_XBOX_360_PLAYER_LED`. -/
def joystickHidapiXbox360PlayerLed : String := "SDL_JOYSTICK_HIDAPI_XBOX_360_PLAYER_LED"
/-- C: `SDL_HINT_JOYSTICK_HIDAPI_XBOX_360_WIRELESS`. -/
def joystickHidapiXbox360Wireless : String := "SDL_JOYSTICK_HIDAPI_XBOX_360_WIRELESS"
/-- C: `SDL_HINT_JOYSTICK_HIDAPI_XBOX_ONE`. -/
def joystickHidapiXboxOne : String := "SDL_JOYSTICK_HIDAPI_XBOX_ONE"
/-- C: `SDL_HINT_JOYSTICK_HIDAPI_XBOX_ONE_HOME_LED`. -/
def joystickHidapiXboxOneHomeLed : String := "SDL_JOYSTICK_HIDAPI_XBOX_ONE_HOME_LED"
/-- C: `SDL_HINT_JOYSTICK_HIDAPI_GIP`. -/
def joystickHidapiGip : String := "SDL_JOYSTICK_HIDAPI_GIP"
/-- C: `SDL_HINT_JOYSTICK_HIDAPI_GIP_RESET_FOR_METADATA`. -/
def joystickHidapiGipResetForMetadata : String := "SDL_JOYSTICK_HIDAPI_GIP_RESET_FOR_METADATA"
/-- C: `SDL_HINT_JOYSTICK_IOKIT`. -/
def joystickIokit : String := "SDL_JOYSTICK_IOKIT"
/-- C: `SDL_HINT_JOYSTICK_LINUX_CLASSIC`. -/
def joystickLinuxClassic : String := "SDL_JOYSTICK_LINUX_CLASSIC"
/-- C: `SDL_HINT_JOYSTICK_LINUX_DEADZONES`. -/
def joystickLinuxDeadzones : String := "SDL_JOYSTICK_LINUX_DEADZONES"
/-- C: `SDL_HINT_JOYSTICK_LINUX_DIGITAL_HATS`. -/
def joystickLinuxDigitalHats : String := "SDL_JOYSTICK_LINUX_DIGITAL_HATS"
/-- C: `SDL_HINT_JOYSTICK_LINUX_HAT_DEADZONES`. -/
def joystickLinuxHatDeadzones : String := "SDL_JOYSTICK_LINUX_HAT_DEADZONES"
/-- C: `SDL_HINT_JOYSTICK_MFI`. -/
def joystickMfi : String := "SDL_JOYSTICK_MFI"
/-- C: `SDL_HINT_JOYSTICK_RAWINPUT`. -/
def joystickRawinput : String := "SDL_JOYSTICK_RAWINPUT"
/-- C: `SDL_HINT_JOYSTICK_RAWINPUT_CORRELATE_XINPUT`. -/
def joystickRawinputCorrelateXinput : String := "SDL_JOYSTICK_RAWINPUT_CORRELATE_XINPUT"
/-- C: `SDL_HINT_JOYSTICK_ROG_CHAKRAM`. -/
def joystickRogChakram : String := "SDL_JOYSTICK_ROG_CHAKRAM"
/-- C: `SDL_HINT_JOYSTICK_THREAD`. -/
def joystickThread : String := "SDL_JOYSTICK_THREAD"
/-- C: `SDL_HINT_JOYSTICK_THROTTLE_DEVICES`. -/
def joystickThrottleDevices : String := "SDL_JOYSTICK_THROTTLE_DEVICES"
/-- C: `SDL_HINT_JOYSTICK_THROTTLE_DEVICES_EXCLUDED`. -/
def joystickThrottleDevicesExcluded : String := "SDL_JOYSTICK_THROTTLE_DEVICES_EXCLUDED"
/-- C: `SDL_HINT_JOYSTICK_WGI`. -/
def joystickWgi : String := "SDL_JOYSTICK_WGI"
/-- C: `SDL_HINT_JOYSTICK_WHEEL_DEVICES`. -/
def joystickWheelDevices : String := "SDL_JOYSTICK_WHEEL_DEVICES"
/-- C: `SDL_HINT_JOYSTICK_WHEEL_DEVICES_EXCLUDED`. -/
def joystickWheelDevicesExcluded : String := "SDL_JOYSTICK_WHEEL_DEVICES_EXCLUDED"
/-- C: `SDL_HINT_JOYSTICK_ZERO_CENTERED_DEVICES`. -/
def joystickZeroCenteredDevices : String := "SDL_JOYSTICK_ZERO_CENTERED_DEVICES"
/-- C: `SDL_HINT_JOYSTICK_HAPTIC_AXES`. -/
def joystickHapticAxes : String := "SDL_JOYSTICK_HAPTIC_AXES"
/-- C: `SDL_HINT_KEYCODE_OPTIONS`. -/
def keycodeOptions : String := "SDL_KEYCODE_OPTIONS"
/-- C: `SDL_HINT_KMSDRM_DEVICE_INDEX`. -/
def kmsdrmDeviceIndex : String := "SDL_KMSDRM_DEVICE_INDEX"
/-- C: `SDL_HINT_KMSDRM_REQUIRE_DRM_MASTER`. -/
def kmsdrmRequireDrmMaster : String := "SDL_KMSDRM_REQUIRE_DRM_MASTER"
/-- C: `SDL_HINT_KMSDRM_ATOMIC`. -/
def kmsdrmAtomic : String := "SDL_KMSDRM_ATOMIC"
/-- C: `SDL_HINT_LOGGING`. -/
def logging : String := "SDL_LOGGING"
/-- C: `SDL_HINT_MAC_BACKGROUND_APP`. -/
def macBackgroundApp : String := "SDL_MAC_BACKGROUND_APP"
/-- C: `SDL_HINT_MAC_CTRL_CLICK_EMULATE_RIGHT_CLICK`. -/
def macCtrlClickEmulateRightClick : String := "SDL_MAC_CTRL_CLICK_EMULATE_RIGHT_CLICK"
/-- C: `SDL_HINT_MAC_OPENGL_ASYNC_DISPATCH`. -/
def macOpenglAsyncDispatch : String := "SDL_MAC_OPENGL_ASYNC_DISPATCH"
/-- C: `SDL_HINT_MAC_OPTION_AS_ALT`. -/
def macOptionAsAlt : String := "SDL_MAC_OPTION_AS_ALT"
/-- C: `SDL_HINT_MAC_SCROLL_MOMENTUM`. -/
def macScrollMomentum : String := "SDL_MAC_SCROLL_MOMENTUM"
/-- C: `SDL_HINT_MAC_PRESS_AND_HOLD`. -/
def macPressAndHold : String := "SDL_MAC_PRESS_AND_HOLD"
/-- C: `SDL_HINT_MAIN_CALLBACK_RATE`. -/
def mainCallbackRate : String := "SDL_MAIN_CALLBACK_RATE"
/-- C: `SDL_HINT_MOUSE_AUTO_CAPTURE`. -/
def mouseAutoCapture : String := "SDL_MOUSE_AUTO_CAPTURE"
/-- C: `SDL_HINT_MOUSE_DOUBLE_CLICK_RADIUS`. -/
def mouseDoubleClickRadius : String := "SDL_MOUSE_DOUBLE_CLICK_RADIUS"
/-- C: `SDL_HINT_MOUSE_DOUBLE_CLICK_TIME`. -/
def mouseDoubleClickTime : String := "SDL_MOUSE_DOUBLE_CLICK_TIME"
/-- C: `SDL_HINT_MOUSE_DEFAULT_SYSTEM_CURSOR`. -/
def mouseDefaultSystemCursor : String := "SDL_MOUSE_DEFAULT_SYSTEM_CURSOR"
/-- C: `SDL_HINT_MOUSE_DPI_SCALE_CURSORS`. -/
def mouseDpiScaleCursors : String := "SDL_MOUSE_DPI_SCALE_CURSORS"
/-- C: `SDL_HINT_MOUSE_EMULATE_WARP_WITH_RELATIVE`. -/
def mouseEmulateWarpWithRelative : String := "SDL_MOUSE_EMULATE_WARP_WITH_RELATIVE"
/-- C: `SDL_HINT_MOUSE_FOCUS_CLICKTHROUGH`. -/
def mouseFocusClickthrough : String := "SDL_MOUSE_FOCUS_CLICKTHROUGH"
/-- C: `SDL_HINT_MOUSE_NORMAL_SPEED_SCALE`. -/
def mouseNormalSpeedScale : String := "SDL_MOUSE_NORMAL_SPEED_SCALE"
/-- C: `SDL_HINT_MOUSE_RELATIVE_MODE_CENTER`. -/
def mouseRelativeModeCenter : String := "SDL_MOUSE_RELATIVE_MODE_CENTER"
/-- C: `SDL_HINT_MOUSE_RELATIVE_SPEED_SCALE`. -/
def mouseRelativeSpeedScale : String := "SDL_MOUSE_RELATIVE_SPEED_SCALE"
/-- C: `SDL_HINT_MOUSE_RELATIVE_SYSTEM_SCALE`. -/
def mouseRelativeSystemScale : String := "SDL_MOUSE_RELATIVE_SYSTEM_SCALE"
/-- C: `SDL_HINT_MOUSE_RELATIVE_WARP_MOTION`. -/
def mouseRelativeWarpMotion : String := "SDL_MOUSE_RELATIVE_WARP_MOTION"
/-- C: `SDL_HINT_MOUSE_RELATIVE_CURSOR_VISIBLE`. -/
def mouseRelativeCursorVisible : String := "SDL_MOUSE_RELATIVE_CURSOR_VISIBLE"
/-- C: `SDL_HINT_MOUSE_TOUCH_EVENTS`. -/
def mouseTouchEvents : String := "SDL_MOUSE_TOUCH_EVENTS"
/-- C: `SDL_HINT_MUTE_CONSOLE_KEYBOARD`. -/
def muteConsoleKeyboard : String := "SDL_MUTE_CONSOLE_KEYBOARD"
/-- C: `SDL_HINT_NO_SIGNAL_HANDLERS`. -/
def noSignalHandlers : String := "SDL_NO_SIGNAL_HANDLERS"
/-- C: `SDL_HINT_OPENGL_LIBRARY`. -/
def openglLibrary : String := "SDL_OPENGL_LIBRARY"
/-- C: `SDL_HINT_EGL_LIBRARY`. -/
def eglLibrary : String := "SDL_EGL_LIBRARY"
/-- C: `SDL_HINT_OPENGL_ES_DRIVER`. -/
def openglEsDriver : String := "SDL_OPENGL_ES_DRIVER"
/-- C: `SDL_HINT_OPENGL_FORCE_SRGB_FRAMEBUFFER`. -/
def openglForceSrgbFramebuffer : String := "SDL_OPENGL_FORCE_SRGB_FRAMEBUFFER"
/-- C: `SDL_HINT_OPENVR_LIBRARY`. -/
def openvrLibrary : String := "SDL_OPENVR_LIBRARY"
/-- C: `SDL_HINT_ORIENTATIONS`. -/
def orientations : String := "SDL_ORIENTATIONS"
/-- C: `SDL_HINT_POLL_SENTINEL`. -/
def pollSentinel : String := "SDL_POLL_SENTINEL"
/-- C: `SDL_HINT_PREFERRED_LOCALES`. -/
def preferredLocales : String := "SDL_PREFERRED_LOCALES"
/-- C: `SDL_HINT_QUIT_ON_LAST_WINDOW_CLOSE`. -/
def quitOnLastWindowClose : String := "SDL_QUIT_ON_LAST_WINDOW_CLOSE"
/-- C: `SDL_HINT_RENDER_DIRECT3D_THREADSAFE`. -/
def renderDirect3dThreadsafe : String := "SDL_RENDER_DIRECT3D_THREADSAFE"
/-- C: `SDL_HINT_RENDER_DIRECT3D11_DEBUG`. -/
def renderDirect3d11Debug : String := "SDL_RENDER_DIRECT3D11_DEBUG"
/-- C: `SDL_HINT_RENDER_DIRECT3D11_WARP`. -/
def renderDirect3d11Warp : String := "SDL_RENDER_DIRECT3D11_WARP"
/-- C: `SDL_HINT_RENDER_VULKAN_DEBUG`. -/
def renderVulkanDebug : String := "SDL_RENDER_VULKAN_DEBUG"
/-- C: `SDL_HINT_RENDER_GPU_DEBUG`. -/
def renderGpuDebug : String := "SDL_RENDER_GPU_DEBUG"
/-- C: `SDL_HINT_RENDER_GPU_LOW_POWER`. -/
def renderGpuLowPower : String := "SDL_RENDER_GPU_LOW_POWER"
/-- C: `SDL_HINT_RENDER_DRIVER`. -/
def renderDriver : String := "SDL_RENDER_DRIVER"
/-- C: `SDL_HINT_RENDER_LINE_METHOD`. -/
def renderLineMethod : String := "SDL_RENDER_LINE_METHOD"
/-- C: `SDL_HINT_RENDER_METAL_PREFER_LOW_POWER_DEVICE`. -/
def renderMetalPreferLowPowerDevice : String := "SDL_RENDER_METAL_PREFER_LOW_POWER_DEVICE"
/-- C: `SDL_HINT_RENDER_VSYNC`. -/
def renderVsync : String := "SDL_RENDER_VSYNC"
/-- C: `SDL_HINT_RETURN_KEY_HIDES_IME`. -/
def returnKeyHidesIme : String := "SDL_RETURN_KEY_HIDES_IME"
/-- C: `SDL_HINT_ROG_GAMEPAD_MICE`. -/
def rogGamepadMice : String := "SDL_ROG_GAMEPAD_MICE"
/-- C: `SDL_HINT_ROG_GAMEPAD_MICE_EXCLUDED`. -/
def rogGamepadMiceExcluded : String := "SDL_ROG_GAMEPAD_MICE_EXCLUDED"
/-- C: `SDL_HINT_PS2_GS_WIDTH`. -/
def ps2GsWidth : String := "SDL_PS2_GS_WIDTH"
/-- C: `SDL_HINT_PS2_GS_HEIGHT`. -/
def ps2GsHeight : String := "SDL_PS2_GS_HEIGHT"
/-- C: `SDL_HINT_PS2_GS_PROGRESSIVE`. -/
def ps2GsProgressive : String := "SDL_PS2_GS_PROGRESSIVE"
/-- C: `SDL_HINT_PS2_GS_MODE`. -/
def ps2GsMode : String := "SDL_PS2_GS_MODE"
/-- C: `SDL_HINT_RPI_VIDEO_LAYER`. -/
def rpiVideoLayer : String := "SDL_RPI_VIDEO_LAYER"
/-- C: `SDL_HINT_SCREENSAVER_INHIBIT_ACTIVITY_NAME`. -/
def screensaverInhibitActivityName : String := "SDL_SCREENSAVER_INHIBIT_ACTIVITY_NAME"
/-- C: `SDL_HINT_SHUTDOWN_DBUS_ON_QUIT`. -/
def shutdownDbusOnQuit : String := "SDL_SHUTDOWN_DBUS_ON_QUIT"
/-- C: `SDL_HINT_STORAGE_TITLE_DRIVER`. -/
def storageTitleDriver : String := "SDL_STORAGE_TITLE_DRIVER"
/-- C: `SDL_HINT_STORAGE_USER_DRIVER`. -/
def storageUserDriver : String := "SDL_STORAGE_USER_DRIVER"
/-- C: `SDL_HINT_THREAD_FORCE_REALTIME_TIME_CRITICAL`. -/
def threadForceRealtimeTimeCritical : String := "SDL_THREAD_FORCE_REALTIME_TIME_CRITICAL"
/-- C: `SDL_HINT_THREAD_PRIORITY_POLICY`. -/
def threadPriorityPolicy : String := "SDL_THREAD_PRIORITY_POLICY"
/-- C: `SDL_HINT_TIMER_RESOLUTION`. -/
def timerResolution : String := "SDL_TIMER_RESOLUTION"
/-- C: `SDL_HINT_TOUCH_MOUSE_EVENTS`. -/
def touchMouseEvents : String := "SDL_TOUCH_MOUSE_EVENTS"
/-- C: `SDL_HINT_TRACKPAD_IS_TOUCH_ONLY`. -/
def trackpadIsTouchOnly : String := "SDL_TRACKPAD_IS_TOUCH_ONLY"
/-- C: `SDL_HINT_TV_REMOTE_AS_JOYSTICK`. -/
def tvRemoteAsJoystick : String := "SDL_TV_REMOTE_AS_JOYSTICK"
/-- C: `SDL_HINT_VIDEO_ALLOW_SCREENSAVER`. -/
def videoAllowScreensaver : String := "SDL_VIDEO_ALLOW_SCREENSAVER"
/-- C: `SDL_HINT_VIDEO_DISPLAY_PRIORITY`. -/
def videoDisplayPriority : String := "SDL_VIDEO_DISPLAY_PRIORITY"
/-- C: `SDL_HINT_VIDEO_DOUBLE_BUFFER`. -/
def videoDoubleBuffer : String := "SDL_VIDEO_DOUBLE_BUFFER"
/-- C: `SDL_HINT_VIDEO_DRIVER`. -/
def videoDriver : String := "SDL_VIDEO_DRIVER"
/-- C: `SDL_HINT_VIDEO_DUMMY_SAVE_FRAMES`. -/
def videoDummySaveFrames : String := "SDL_VIDEO_DUMMY_SAVE_FRAMES"
/-- C: `SDL_HINT_VIDEO_EGL_ALLOW_GETDISPLAY_FALLBACK`. -/
def videoEglAllowGetdisplayFallback : String := "SDL_VIDEO_EGL_ALLOW_GETDISPLAY_FALLBACK"
/-- C: `SDL_HINT_VIDEO_FORCE_EGL`. -/
def videoForceEgl : String := "SDL_VIDEO_FORCE_EGL"
/-- C: `SDL_HINT_VIDEO_MAC_FULLSCREEN_SPACES`. -/
def videoMacFullscreenSpaces : String := "SDL_VIDEO_MAC_FULLSCREEN_SPACES"
/-- C: `SDL_HINT_VIDEO_MAC_FULLSCREEN_MENU_VISIBILITY`. -/
def videoMacFullscreenMenuVisibility : String := "SDL_VIDEO_MAC_FULLSCREEN_MENU_VISIBILITY"
/-- C: `SDL_HINT_VIDEO_METAL_AUTO_RESIZE_DRAWABLE`. -/
def videoMetalAutoResizeDrawable : String := "SDL_VIDEO_METAL_AUTO_RESIZE_DRAWABLE"
/-- C: `SDL_HINT_VIDEO_MATCH_EXCLUSIVE_MODE_ON_MOVE`. -/
def videoMatchExclusiveModeOnMove : String := "SDL_VIDEO_MATCH_EXCLUSIVE_MODE_ON_MOVE"
/-- C: `SDL_HINT_VIDEO_MINIMIZE_ON_FOCUS_LOSS`. -/
def videoMinimizeOnFocusLoss : String := "SDL_VIDEO_MINIMIZE_ON_FOCUS_LOSS"
/-- C: `SDL_HINT_VIDEO_OFFSCREEN_SAVE_FRAMES`. -/
def videoOffscreenSaveFrames : String := "SDL_VIDEO_OFFSCREEN_SAVE_FRAMES"
/-- C: `SDL_HINT_VIDEO_SYNC_WINDOW_OPERATIONS`. -/
def videoSyncWindowOperations : String := "SDL_VIDEO_SYNC_WINDOW_OPERATIONS"
/-- C: `SDL_HINT_VIDEO_WAYLAND_ALLOW_LIBDECOR`. -/
def videoWaylandAllowLibdecor : String := "SDL_VIDEO_WAYLAND_ALLOW_LIBDECOR"
/-- C: `SDL_HINT_VIDEO_WAYLAND_MODE_EMULATION`. -/
def videoWaylandModeEmulation : String := "SDL_VIDEO_WAYLAND_MODE_EMULATION"
/-- C: `SDL_HINT_VIDEO_WAYLAND_MODE_SCALING`. -/
def videoWaylandModeScaling : String := "SDL_VIDEO_WAYLAND_MODE_SCALING"
/-- C: `SDL_HINT_VIDEO_WAYLAND_PREFER_LIBDECOR`. -/
def videoWaylandPreferLibdecor : String := "SDL_VIDEO_WAYLAND_PREFER_LIBDECOR"
/-- C: `SDL_HINT_VIDEO_WAYLAND_SCALE_TO_DISPLAY`. -/
def videoWaylandScaleToDisplay : String := "SDL_VIDEO_WAYLAND_SCALE_TO_DISPLAY"
/-- C: `SDL_HINT_VIDEO_WIN_D3DCOMPILER`. -/
def videoWinD3dcompiler : String := "SDL_VIDEO_WIN_D3DCOMPILER"
/-- C: `SDL_HINT_VIDEO_X11_ENABLE_XSYNC_EXT`. -/
def videoX11EnableXsyncExt : String := "SDL_VIDEO_X11_ENABLE_XSYNC_EXT"
/-- C: `SDL_HINT_VIDEO_X11_EXTERNAL_WINDOW_INPUT`. -/
def videoX11ExternalWindowInput : String := "SDL_VIDEO_X11_EXTERNAL_WINDOW_INPUT"
/-- C: `SDL_HINT_VIDEO_X11_NET_WM_BYPASS_COMPOSITOR`. -/
def videoX11NetWmBypassCompositor : String := "SDL_VIDEO_X11_NET_WM_BYPASS_COMPOSITOR"
/-- C: `SDL_HINT_VIDEO_X11_NET_WM_PING`. -/
def videoX11NetWmPing : String := "SDL_VIDEO_X11_NET_WM_PING"
/-- C: `SDL_HINT_VIDEO_X11_NODIRECTCOLOR`. -/
def videoX11Nodirectcolor : String := "SDL_VIDEO_X11_NODIRECTCOLOR"
/-- C: `SDL_HINT_VIDEO_X11_SCALING_FACTOR`. -/
def videoX11ScalingFactor : String := "SDL_VIDEO_X11_SCALING_FACTOR"
/-- C: `SDL_HINT_VIDEO_X11_VISUALID`. -/
def videoX11Visualid : String := "SDL_VIDEO_X11_VISUALID"
/-- C: `SDL_HINT_VIDEO_X11_WINDOW_VISUALID`. -/
def videoX11WindowVisualid : String := "SDL_VIDEO_X11_WINDOW_VISUALID"
/-- C: `SDL_HINT_VIDEO_X11_XRANDR`. -/
def videoX11Xrandr : String := "SDL_VIDEO_X11_XRANDR"
/-- C: `SDL_HINT_VITA_ENABLE_BACK_TOUCH`. -/
def vitaEnableBackTouch : String := "SDL_VITA_ENABLE_BACK_TOUCH"
/-- C: `SDL_HINT_VITA_ENABLE_FRONT_TOUCH`. -/
def vitaEnableFrontTouch : String := "SDL_VITA_ENABLE_FRONT_TOUCH"
/-- C: `SDL_HINT_VITA_MODULE_PATH`. -/
def vitaModulePath : String := "SDL_VITA_MODULE_PATH"
/-- C: `SDL_HINT_VITA_PVR_INIT`. -/
def vitaPvrInit : String := "SDL_VITA_PVR_INIT"
/-- C: `SDL_HINT_VITA_RESOLUTION`. -/
def vitaResolution : String := "SDL_VITA_RESOLUTION"
/-- C: `SDL_HINT_VITA_PVR_OPENGL`. -/
def vitaPvrOpengl : String := "SDL_VITA_PVR_OPENGL"
/-- C: `SDL_HINT_VITA_TOUCH_MOUSE_DEVICE`. -/
def vitaTouchMouseDevice : String := "SDL_VITA_TOUCH_MOUSE_DEVICE"
/-- C: `SDL_HINT_VULKAN_DISPLAY`. -/
def vulkanDisplay : String := "SDL_VULKAN_DISPLAY"
/-- C: `SDL_HINT_VULKAN_LIBRARY`. -/
def vulkanLibrary : String := "SDL_VULKAN_LIBRARY"
/-- C: `SDL_HINT_WAVE_FACT_CHUNK`. -/
def waveFactChunk : String := "SDL_WAVE_FACT_CHUNK"
/-- C: `SDL_HINT_WAVE_CHUNK_LIMIT`. -/
def waveChunkLimit : String := "SDL_WAVE_CHUNK_LIMIT"
/-- C: `SDL_HINT_WAVE_RIFF_CHUNK_SIZE`. -/
def waveRiffChunkSize : String := "SDL_WAVE_RIFF_CHUNK_SIZE"
/-- C: `SDL_HINT_WAVE_TRUNCATION`. -/
def waveTruncation : String := "SDL_WAVE_TRUNCATION"
/-- C: `SDL_HINT_WINDOW_ACTIVATE_WHEN_RAISED`. -/
def windowActivateWhenRaised : String := "SDL_WINDOW_ACTIVATE_WHEN_RAISED"
/-- C: `SDL_HINT_WINDOW_ACTIVATE_WHEN_SHOWN`. -/
def windowActivateWhenShown : String := "SDL_WINDOW_ACTIVATE_WHEN_SHOWN"
/-- C: `SDL_HINT_WINDOW_ALLOW_TOPMOST`. -/
def windowAllowTopmost : String := "SDL_WINDOW_ALLOW_TOPMOST"
/-- C: `SDL_HINT_WINDOW_FRAME_USABLE_WHILE_CURSOR_HIDDEN`. -/
def windowFrameUsableWhileCursorHidden : String := "SDL_WINDOW_FRAME_USABLE_WHILE_CURSOR_HIDDEN"
/-- C: `SDL_HINT_WINDOWS_CLOSE_ON_ALT_F4`. -/
def windowsCloseOnAltF4 : String := "SDL_WINDOWS_CLOSE_ON_ALT_F4"
/-- C: `SDL_HINT_WINDOWS_ENABLE_MENU_MNEMONICS`. -/
def windowsEnableMenuMnemonics : String := "SDL_WINDOWS_ENABLE_MENU_MNEMONICS"
/-- C: `SDL_HINT_WINDOWS_ENABLE_MESSAGELOOP`. -/
def windowsEnableMessageloop : String := "SDL_WINDOWS_ENABLE_MESSAGELOOP"
/-- C: `SDL_HINT_WINDOWS_GAMEINPUT`. -/
def windowsGameinput : String := "SDL_WINDOWS_GAMEINPUT"
/-- C: `SDL_HINT_WINDOWS_RAW_KEYBOARD`. -/
def windowsRawKeyboard : String := "SDL_WINDOWS_RAW_KEYBOARD"
/-- C: `SDL_HINT_WINDOWS_RAW_KEYBOARD_EXCLUDE_HOTKEYS`. -/
def windowsRawKeyboardExcludeHotkeys : String := "SDL_WINDOWS_RAW_KEYBOARD_EXCLUDE_HOTKEYS"
/-- C: `SDL_HINT_WINDOWS_RAW_KEYBOARD_INPUTSINK`. -/
def windowsRawKeyboardInputsink : String := "SDL_WINDOWS_RAW_KEYBOARD_INPUTSINK"
/-- C: `SDL_HINT_WINDOWS_FORCE_SEMAPHORE_KERNEL`. -/
def windowsForceSemaphoreKernel : String := "SDL_WINDOWS_FORCE_SEMAPHORE_KERNEL"
/-- C: `SDL_HINT_WINDOWS_INTRESOURCE_ICON`. -/
def windowsIntresourceIcon : String := "SDL_WINDOWS_INTRESOURCE_ICON"
/-- C: `SDL_HINT_WINDOWS_INTRESOURCE_ICON_SMALL`. -/
def windowsIntresourceIconSmall : String := "SDL_WINDOWS_INTRESOURCE_ICON_SMALL"
/-- C: `SDL_HINT_WINDOWS_USE_D3D9EX`. -/
def windowsUseD3d9ex : String := "SDL_WINDOWS_USE_D3D9EX"
/-- C: `SDL_HINT_WINDOWS_ERASE_BACKGROUND_MODE`. -/
def windowsEraseBackgroundMode : String := "SDL_WINDOWS_ERASE_BACKGROUND_MODE"
/-- C: `SDL_HINT_X11_FORCE_OVERRIDE_REDIRECT`. -/
def x11ForceOverrideRedirect : String := "SDL_X11_FORCE_OVERRIDE_REDIRECT"
/-- C: `SDL_HINT_X11_WINDOW_TYPE`. -/
def x11WindowType : String := "SDL_X11_WINDOW_TYPE"
/-- C: `SDL_HINT_X11_XCB_LIBRARY`. -/
def x11XcbLibrary : String := "SDL_X11_XCB_LIBRARY"
/-- C: `SDL_HINT_XINPUT_ENABLED`. -/
def xinputEnabled : String := "SDL_XINPUT_ENABLED"
/-- C: `SDL_HINT_ASSERT`. -/
def assert : String := "SDL_ASSERT"
/-- C: `SDL_HINT_PEN_MOUSE_EVENTS`. -/
def penMouseEvents : String := "SDL_PEN_MOUSE_EVENTS"
/-- C: `SDL_HINT_PEN_TOUCH_EVENTS`. -/
def penTouchEvents : String := "SDL_PEN_TOUCH_EVENTS"

end Hint
end Sdl

end
