import Sdl
import Tests.Harness

namespace Tests.Timer
open Sdl Tests.Harness

/-- Ticks/perf-counter queries, delays advancing the clock, and one runtime
sanity check of the (already `#guard`ed) conversion helpers. -/
def run : IO Unit := do
  -- getTicks / getTicksNS nonzero and monotone across a 10 ms delay
  let t0 ← Sdl.getTicks
  let n0 ← Sdl.getTicksNS
  Sdl.delay 10
  let t1 ← Sdl.getTicks
  let n1 ← Sdl.getTicksNS
  check "getTicks advanced across delay 10" (t1 > t0)
  check "getTicksNS monotone across delay 10" (n1 >= n0)
  check "getTicks nonzero" (t1 != 0)
  -- delayNS(5_000_000) makes getTicksNS advance >= 2 ms (loose, CI-safe)
  let m0 ← Sdl.getTicksNS
  Sdl.delayNS 5_000_000
  let m1 ← Sdl.getTicksNS
  check "delayNS advances >= 2ms" (m1 - m0 >= 2_000_000)
  -- perf counter / frequency nonzero
  check "perf frequency nonzero" ((← Sdl.getPerformanceFrequency) != 0)
  check "perf counter nonzero" ((← Sdl.getPerformanceCounter) != 0)
  -- conversion helpers spot-check (runtime sanity; compile-time #guards cover more)
  check "secondsToNs" (Sdl.secondsToNs 1 == 1_000_000_000)
  check "ms<->ns round-trip" (Sdl.nsToMs (Sdl.msToNs 7) == 7)

end Tests.Timer
