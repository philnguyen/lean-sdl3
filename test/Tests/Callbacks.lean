import Sdl
import Tests.Harness

/-!
# M6 callback-bridge tests

Exercises every Lean-closure-as-SDL-callback bridge. Timer callbacks fire on
SDL's timer thread; all cross-thread `IO.Ref` traffic here is single-writer
(the callback writes, the main thread only reads), which is the documented-safe
pattern. Runs after the `Video`/`Events` groups (video already initialized).
-/

namespace Tests.Callbacks
open Sdl Tests.Harness

/-- Poll `p` every 5 ms until it holds or `timeoutMs` elapses. -/
partial def waitUntil (timeoutMs : UInt64) (p : IO Bool) : IO Bool := do
  let deadline := (← Sdl.getTicks) + timeoutMs
  let rec loop : IO Bool := do
    if (← p) then return true
    if (← Sdl.getTicks) > deadline then return false
    Sdl.delay 5
    loop
  loop

def timerTests : IO Unit := do
  -- A repeating timer that self-cancels (returns 0) on its third firing.
  let count ← IO.mkRef (0 : Nat)
  let id ← Sdl.addTimer 5 fun _ _ => do
    let n := (← count.get) + 1
    count.set n
    return (if n >= 3 then 0 else 5)
  check "timer fires repeatedly" (← waitUntil 2000 (return (← count.get) >= 3))
  Sdl.delay 50
  check "timer self-cancel stops it" ((← count.get) == 3)
  check "removeTimer after self-cancel = false" (!(← Sdl.removeTimer id))

  -- Explicit removal, then idempotent second removal.
  let id2 ← Sdl.addTimer 3600000 fun _ _ => return 3600000
  check "removeTimer live timer = true" (← Sdl.removeTimer id2)
  check "removeTimer again = false" (!(← Sdl.removeTimer id2))

  -- A throwing callback cancels its timer (and stays canceled).
  let fired ← IO.mkRef (0 : Nat)
  let _ ← Sdl.addTimer 5 fun _ _ => do
    fired.modify (· + 1)
    throw (IO.userError "deliberate test throw")
  check "throwing timer fired" (← waitUntil 2000 (return (← fired.get) >= 1))
  Sdl.delay 50
  check "throwing timer canceled" ((← fired.get) == 1)

  -- Nanosecond variant, one-shot.
  let nsFired ← IO.mkRef (0 : Nat)
  let _ ← Sdl.addTimerNS 2000000 fun _ _ => do
    nsFired.modify (· + 1)
    return 0
  check "addTimerNS one-shot fired" (← waitUntil 2000 (return (← nsFired.get) == 1))

  -- Remove-while-firing stress: a fast timer runs hot while 50 short-lived
  -- timers are added and removed; then the fast one is removed and must stop.
  let hot ← IO.mkRef (0 : Nat)
  let fast ← Sdl.addTimer 1 fun _ _ => do
    hot.modify (· + 1)
    return 1
  for _ in [0:50] do
    let t ← Sdl.addTimer 1 fun _ _ => return 1
    let _ ← Sdl.removeTimer t
  let _ ← Sdl.removeTimer fast
  Sdl.delay 20 -- allow at most one in-flight trailing invocation to land
  let settled ← hot.get
  Sdl.delay 50
  check "remove-while-firing stress: removed timer stays stopped"
    ((← hot.get) == settled)

def eventWatchFilterTests : IO Unit := do
  Sdl.init .video
  Sdl.pumpEvents
  Sdl.flushEvents
  let some tA ← Sdl.registerEvents 2
    | check "registerEvents for watch tests" false
  let tB : Sdl.EventType := ⟨tA.val + 1⟩

  -- Watches run synchronously during the push (same thread here).
  let seen ← IO.mkRef (#[] : Array UInt32)
  let watch ← Sdl.addEventWatch fun e => do
    if let .user t _ := e then seen.modify (·.push t)
  let seen2 ← IO.mkRef (0 : Nat)
  let watch2 ← Sdl.addEventWatch fun _ => seen2.modify (· + 1)
  check "push accepted (no filter)" (← Sdl.pushUserEvent tA)
  check "watch saw pushed event" ((← seen.get) == #[tA.val])
  check "second watch fired too" ((← seen2.get) == 1)
  Sdl.flushEvents

  -- Filter drops tA, keeps everything else; watches must not see drops.
  Sdl.setEventFilter fun e =>
    match e with
    | .user t _ => return t != tA.val
    | _ => return true
  check "filtered push reports false" (!(← Sdl.pushUserEvent tA))
  check "filtered event not queued" (!(← Sdl.hasEvent tA))
  check "watch did not see filtered event" ((← seen.get) == #[tA.val])
  check "filter passes other type" (← Sdl.pushUserEvent tB)
  check "watch saw passing event" ((← seen.get) == #[tA.val, tB.val])
  Sdl.clearEventFilter
  check "push accepted after clearEventFilter" (← Sdl.pushUserEvent tA)
  Sdl.flushEvents

  -- Watch removal is effective and idempotent.
  check "removeEventWatch = true" (← Sdl.removeEventWatch watch)
  check "removeEventWatch again = false" (!(← Sdl.removeEventWatch watch))
  let _ ← Sdl.pushUserEvent tA
  check "removed watch no longer fires" ((← seen.get) == #[tA.val, tB.val, tA.val])
  check "surviving watch still fires" ((← seen2.get) >= 4)
  let _ ← Sdl.removeEventWatch watch2
  Sdl.flushEvents

  -- filterEvents: one-shot sweep removes only what the callback rejects.
  let _ ← Sdl.pushUserEvent tA
  let _ ← Sdl.pushUserEvent tA
  let _ ← Sdl.pushUserEvent tB
  Sdl.filterEvents fun e =>
    match e with
    | .user t _ => return t == tB.val
    | _ => return true
  check "filterEvents removed rejected type" (!(← Sdl.hasEvent tA))
  check "filterEvents kept accepted type" (← Sdl.hasEvent tB)
  Sdl.flushEvents

def run : IO Unit := do
  timerTests
  eventWatchFilterTests

end Tests.Callbacks
