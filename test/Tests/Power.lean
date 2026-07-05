import Sdl
import Tests.Harness

namespace Tests.Power
open Sdl Tests.Harness

/-- The single power query succeeds, and a reported percentage is in [0,100]. -/
def run : IO Unit := do
  let info ← Sdl.getPowerInfo
  check "getPowerInfo succeeds" true
  match info.percent with
  | some p => check "percent in [0,100]" (p >= 0 && p <= 100)
  | none   => check "percent unknown (ok)" true

end Tests.Power
