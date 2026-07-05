import Sdl
import Tests.Harness

namespace Tests.Hints
open Sdl Tests.Harness

/-- Uses hint names unlikely to have an environment override so `resetHint`
observably returns to `none`. -/
def run : IO Unit := do
  -- setHint → getHint round-trip
  Sdl.setHint "SDL_LEAN_SDL3_TEST_HINT" "value1"
  check "setHint/getHint round-trip" ((← Sdl.getHint "SDL_LEAN_SDL3_TEST_HINT") == some "value1")
  -- getHint of unset garbage name = none
  check "getHint unset = none" ((← Sdl.getHint "SDL_LEAN_SDL3_NONEXISTENT_HINT_XYZ") == none)
  -- getHintBoolean respects default
  check "getHintBoolean default true"  (← Sdl.getHintBoolean "SDL_LEAN_SDL3_UNSET_BOOL" true)
  check "getHintBoolean default false" (!(← Sdl.getHintBoolean "SDL_LEAN_SDL3_UNSET_BOOL" false))
  Sdl.setHint "SDL_LEAN_SDL3_TEST_BOOL" "1"
  check "getHintBoolean set true" (← Sdl.getHintBoolean "SDL_LEAN_SDL3_TEST_BOOL" false)
  -- setHintWithPriority
  Sdl.setHintWithPriority "SDL_LEAN_SDL3_TEST_PRIO" "hi" .override
  check "setHintWithPriority" ((← Sdl.getHint "SDL_LEAN_SDL3_TEST_PRIO") == some "hi")
  -- resetHint: getHint returns none after reset (no env override)
  Sdl.resetHint "SDL_LEAN_SDL3_TEST_HINT"
  check "resetHint clears" ((← Sdl.getHint "SDL_LEAN_SDL3_TEST_HINT") == none)
  -- a known hint-name constant is a nonempty string
  check "Hint constant nonempty" (!Sdl.Hint.appId.isEmpty)

end Tests.Hints
