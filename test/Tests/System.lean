import Sdl
import Tests.Harness

/-!
# System (platform) runtime tests

No `Sdl.init` needed. `isTablet`/`isTV` should be `false` on a desktop Mac;
`getSandbox` should decode without throwing (expected `.none` locally).

Also exercises `Sdl.runOnMainThread` (from `Sdl/Init.lean`): once on the main
thread, and once queued from a background task while the main thread pumps.
-/

namespace Tests.System
open Sdl Tests.Harness

def run : IO Unit := do
  check "isTablet == false on desktop" (!(← isTablet))
  check "isTV == false on desktop" (!(← isTV))
  let sb ← getSandbox
  check "getSandbox decodes (expected .none locally)" (sb == .none)
  IO.println s!"  (getSandbox observed: {repr sb})"

  -- runOnMainThread on the main thread runs synchronously.
  let ref ← IO.mkRef false
  runOnMainThread (do ref.set true) (waitComplete := true)
  check "runOnMainThread (main thread) ran the callback" (← ref.get)

  -- runOnMainThread queued from a background task: the main thread must pump.
  -- Requires SDL initialized so a main-thread callback queue exists.
  Sdl.initSubSystem .events
  let ref2 ← IO.mkRef false
  let t ← IO.asTask (do runOnMainThread (do ref2.set (← isMainThread)) (waitComplete := true))
  let mut waited := 0
  while !(← IO.hasFinished t) && waited < 1000 do
    pumpEvents
    Sdl.delay 5
    waited := waited + 1
  match t.get with
  | .ok _ => check "runOnMainThread (background) ran on the main thread" (← ref2.get)
  | .error _ => check "runOnMainThread (background) task did not error" false
  Sdl.quitSubSystem .events

end Tests.System
