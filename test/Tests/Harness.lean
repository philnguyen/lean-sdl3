import Sdl

/-!
# Minimal runtime test harness

No framework: `check`/`checkThrows` report one line per assertion and bump a
global failure counter; `group` runs a module's tests, turning an unexpected
throw into a failure instead of aborting the run; `summary` returns the process
exit code (1 if anything failed).
-/

namespace Tests.Harness

/-- Global failure counter. -/
initialize failures : IO.Ref Nat ← IO.mkRef 0

/-- Record a pass/fail for a boolean condition. -/
def check (name : String) (cond : Bool) : IO Unit := do
  if cond then
    IO.println s!"ok {name}"
  else
    IO.eprintln s!"FAIL {name}"
    failures.modify (· + 1)

/-- Passes iff `act` throws an `IO` error. -/
def checkThrows {α : Type} (name : String) (act : IO α) : IO Unit := do
  let threw ← try
      let _ ← act
      pure false
    catch _ =>
      pure true
  check name threw

/-- Run one module's tests; an unexpected throw is a failure, not an abort.
When the `SDL_LEAN_TEST_GROUP` env var is set, groups with a different name are
skipped — used for real-driver spot runs of a single group (e.g. `Gpu`) without
the window-opening groups running under the real video driver. -/
def group (name : String) (body : IO Unit) : IO Unit := do
  if let some only ← IO.getEnv "SDL_LEAN_TEST_GROUP" then
    if only != name then
      return
  IO.println s!"-- {name} --"
  try
    body
  catch e =>
    IO.eprintln s!"FAIL {name} raised: {e}"
    failures.modify (· + 1)

/-- Final tally; exit code 1 iff any check failed. -/
def summary : IO UInt32 := do
  let n ← failures.get
  if n == 0 then
    IO.println "\nAll tests passed."
    return 0
  else
    IO.eprintln s!"\n{n} test(s) FAILED."
    return 1

end Tests.Harness
