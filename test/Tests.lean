import Sdl
import Tests.Harness
import Tests.Properties
import Tests.Hints
import Tests.Log
import Tests.Timer
import Tests.Guid
import Tests.Time
import Tests.Filesystem
import Tests.AsyncIO
import Tests.Storage
import Tests.Process
import Tests.LoadSo
import Tests.System
import Tests.CpuInfo
import Tests.Power
import Tests.Locale
import Tests.BlendMode
import Tests.Pixels
import Tests.IOStream
import Tests.Surface
import Tests.Video
import Tests.Tray
import Tests.Clipboard
import Tests.Keyboard
import Tests.Mouse
import Tests.TouchPen
import Tests.Events
import Tests.Render
import Tests.Audio
import Tests.Input
import Tests.Gamepad
import Tests.Camera
import Tests.Gpu
import Tests.GpuPipeline
import Tests.Ttf
import Tests.App
import Tests.Callbacks

/-!
# Runtime test entry point

Exercises the modules against the linked SDL3. Run headless with
`SDL_VIDEO_DRIVER=dummy SDL_AUDIO_DRIVER=dummy lake exe test`. Every group up to
and including `Surface` runs without `Sdl.init`; the `Video` group is the first
that calls `Sdl.init .video` (and does not `Sdl.quit` afterwards).
-/

open Tests

def main : IO UInt32 := do
  Harness.group "Properties" Properties.run
  Harness.group "Hints" Hints.run
  Harness.group "Log" Log.run
  Harness.group "Timer" Timer.run
  Harness.group "Guid" Guid.run
  Harness.group "Time" Time.run
  Harness.group "Filesystem" Filesystem.run
  Harness.group "AsyncIO" AsyncIO.run
  Harness.group "Storage" Storage.run
  Harness.group "Process" Process.run
  Harness.group "LoadSo" LoadSo.run
  Harness.group "System" System.run
  Harness.group "CpuInfo" CpuInfo.run
  Harness.group "Power" Power.run
  Harness.group "Locale" Locale.run
  Harness.group "BlendMode" BlendMode.run
  Harness.group "Pixels" Pixels.run
  Harness.group "IOStream" IOStream.run
  Harness.group "Surface" Surface.run
  Harness.group "Video" Video.run
  Harness.group "Tray" Tray.run
  Harness.group "Clipboard" Clipboard.run
  Harness.group "Keyboard" Keyboard.run
  Harness.group "Mouse" Mouse.run
  Harness.group "TouchPen" TouchPen.run
  Harness.group "Events" Events.run
  Harness.group "Render" Render.run
  Harness.group "Audio" Audio.run
  Harness.group "Input" Input.run
  Harness.group "Gamepad" Gamepad.run
  Harness.group "Camera" Camera.run
  Harness.group "Gpu" Gpu.run
  Harness.group "GpuPipeline" GpuPipeline.run
  Harness.group "Ttf" Ttf.run
  Harness.group "App" App.run
  Harness.group "Callbacks" Callbacks.run
  Harness.summary
