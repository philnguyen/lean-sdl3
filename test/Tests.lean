import Sdl
import Tests.Harness
import Tests.Properties
import Tests.Hints
import Tests.Log
import Tests.Timer

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
  Harness.summary
