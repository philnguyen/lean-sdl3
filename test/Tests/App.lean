import Sdl
import Tests.Harness

namespace Tests.App
open Sdl Tests.Harness

/-- `iterate`-driven run: counts to 5, ends with `.success`, `quit` sees the
final result exactly once. -/
def iterateDriven : IO Unit := do
  let count ← IO.mkRef (0 : Nat)
  let quitLog ← IO.mkRef (#[] : Array AppResult)
  let app : App Unit := {
    init := fun _ => return (.«continue», some ())
    iterate := fun _ => do
      let n := (← count.get) + 1
      count.set n
      return if n >= 5 then .success else .«continue»
    quit := fun _ r => quitLog.modify (·.push r)
  }
  let code ← app.run
  check "iterate-driven exit code 0" (code == 0)
  check "iterate ran 5 times" ((← count.get) == 5)
  check "quit called once with success" ((← quitLog.get) == #[.success])

/-- Event-driven run: events pushed during `init` are drained (in order)
before the first `iterate`; a terminal result from `event` skips `iterate`
entirely. -/
def eventDriven : IO Unit := do
  let some t ← registerEvents 1
    | check "registerEvents for App test" false
  let seen ← IO.mkRef (0 : Nat)
  let iterated ← IO.mkRef false
  let quitLog ← IO.mkRef (#[] : Array AppResult)
  let app : App Unit := {
    init := fun _ => do
      -- Three user events; the handler ends the loop on the third.
      for code in [(1 : Int32), 2, 3] do
        let _ ← pushUserEvent t (code := code)
      return (.«continue», some ())
    event := fun _ e => do
      match e with
      | .user ty u =>
        if ty == t.val then
          seen.modify (· + 1)
          return if u.code == 3 then .success else .«continue»
        return .«continue»
      | _ => return .«continue»
    iterate := fun _ => do
      iterated.set true
      return .«continue»
    quit := fun _ r => quitLog.modify (·.push r)
  }
  let code ← app.run
  check "event-driven exit code 0" (code == 0)
  check "all three user events dispatched" ((← seen.get) == 3)
  check "iterate never ran (drain ended loop first)" (!(← iterated.get))
  check "quit called once with success" ((← quitLog.get) == #[.success])

/-- Terminal results from `init`, with and without a state. -/
def initOutcomes : IO Unit := do
  -- Failure without state: quit must not run.
  let quitRan ← IO.mkRef false
  let failNoState : App Unit := {
    init := fun _ => return (.failure, none)
    quit := fun _ _ => quitRan.set true
  }
  check "init failure exits 1" ((← failNoState.run) == 1)
  check "quit skipped without state" (!(← quitRan.get))
  -- Success with state: quit runs, loop never entered.
  let quitLog ← IO.mkRef (#[] : Array AppResult)
  let looped ← IO.mkRef false
  let successWithState : App Unit := {
    init := fun _ => return (.success, some ())
    iterate := fun _ => do looped.set true; return .«continue»
    quit := fun _ r => quitLog.modify (·.push r)
  }
  check "init success exits 0" ((← successWithState.run) == 0)
  check "loop never entered on init success" (!(← looped.get))
  check "quit saw init's success" ((← quitLog.get) == #[.success])
  -- `.continue` without a state is a contract violation → failure.
  let violation : App Unit := { init := fun _ => return (.«continue», none) }
  check "continue-without-state exits 1" ((← violation.run) == 1)

/-- An exception in `iterate` still runs `quit` (with `.failure`) exactly
once, then propagates out of `run`. -/
def exceptionInIterate : IO Unit := do
  let quitLog ← IO.mkRef (#[] : Array AppResult)
  let app : App Unit := {
    init := fun _ => return (.«continue», some ())
    iterate := fun _ => throw (IO.userError "boom")
    quit := fun _ r => quitLog.modify (·.push r)
  }
  checkThrows "exception propagates out of run" (app.run)
  check "quit saw failure before rethrow" ((← quitLog.get) == #[.failure])

def run : IO Unit := do
  iterateDriven
  eventDriven
  initOutcomes
  exceptionInIterate

end Tests.App
