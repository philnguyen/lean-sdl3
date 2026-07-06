import Sdl
import Tests.Harness
import Tests.Properties
import Tests.Hints
import Tests.Log
import Tests.Timer
import Tests.Guid
import Tests.Time
import Tests.Filesystem
import Tests.CpuInfo
import Tests.Power
import Tests.Locale
import Tests.BlendMode
import Tests.Pixels

/-!
# Runtime test entry point

Exercises the M2 modules against the linked SDL3. Run headless with
`SDL_VIDEO_DRIVER=dummy SDL_AUDIO_DRIVER=dummy lake exe test`. None of these
subsystems require `Sdl.init`.
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
  Harness.group "CpuInfo" CpuInfo.run
  Harness.group "Power" Power.run
  Harness.group "Locale" Locale.run
  Harness.group "BlendMode" BlendMode.run
  Harness.group "Pixels" Pixels.run
  Harness.summary
