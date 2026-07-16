module

public import Sdl.Core.Macros
public meta import Sdl.Core.Macros
public import Sdl.Error
public meta import Sdl.Error

public section

/-!
# Timers and clocks (`SDL_timer.h`)

Wall-clock/monotonic time queries, blocking delays, the pure time-unit
conversion helpers that mirror the header's `SDL_*_TO_*` macros, and callback
timers (`addTimer`/`addTimerNS`/`removeTimer`).

Timer callbacks run on SDL's timer thread (registered with the Lean runtime by
the binding). Do not touch video/render APIs from one, and don't let the last
reference to a video handle die there. `IO.Ref` traffic between a timer callback
and the main thread is safe for single-writer patterns; there is no atomic
read-modify-write across threads.
-/

namespace Sdl

/-- Milliseconds since SDL library initialization. C: `SDL_GetTicks`. -/
@[extern "lean_sdl_get_ticks"]
opaque getTicks : IO UInt64

/-- Nanoseconds since SDL library initialization. C: `SDL_GetTicksNS`. -/
@[extern "lean_sdl_get_ticks_ns"]
opaque getTicksNS : IO UInt64

/-- Current value of the high-resolution counter (units are arbitrary; divide
differences by `getPerformanceFrequency`). C: `SDL_GetPerformanceCounter`. -/
@[extern "lean_sdl_get_performance_counter"]
opaque getPerformanceCounter : IO UInt64

/-- Counts per second of the high-resolution counter.
C: `SDL_GetPerformanceFrequency`. -/
@[extern "lean_sdl_get_performance_frequency"]
opaque getPerformanceFrequency : IO UInt64

/-- Wait at least `ms` milliseconds before returning. C: `SDL_Delay`. -/
@[extern "lean_sdl_delay"]
opaque delay (ms : UInt32) : IO Unit

/-- Wait at least `ns` nanoseconds before returning. C: `SDL_DelayNS`. -/
@[extern "lean_sdl_delay_ns"]
opaque delayNS (ns : UInt64) : IO Unit

/-- Wait at least `ns` nanoseconds, more precisely (busy-waits near the end)
than `delayNS`. C: `SDL_DelayPrecise`. -/
@[extern "lean_sdl_delay_precise"]
opaque delayPrecise (ns : UInt64) : IO Unit

/-! ## Callback timers -/

/-- A timer handle from `addTimer`/`addTimerNS`. `0` is never a valid id.
C: `SDL_TimerID`. -/
sdl_id TimerId : UInt32

@[extern "lean_sdl_add_timer"]
private opaque addTimerRaw (intervalMs : UInt32) (cb : UInt32 → UInt32 → IO UInt32) : IO UInt32

/-- Call `cb id interval` on SDL's timer thread after `intervalMs` milliseconds
(needs no `Sdl.init`). The callback returns the next interval in ms; returning
`0` cancels the timer, as does throwing. Timing is inexact (OS scheduling); the
current interval is passed to the callback. After `removeTimer`, at most one
in-flight invocation may still complete (SDL's own guarantee).
C: `SDL_AddTimer`. -/
def addTimer (intervalMs : UInt32) (cb : TimerId → UInt32 → IO UInt32) : IO TimerId := do
  return ⟨← addTimerRaw intervalMs fun id interval => cb ⟨id⟩ interval⟩

@[extern "lean_sdl_add_timer_ns"]
private opaque addTimerNSRaw (intervalNs : UInt64) (cb : UInt32 → UInt64 → IO UInt64) : IO UInt32

/-- Nanosecond-resolution `addTimer` (same cancellation and threading
contract). C: `SDL_AddTimerNS`. -/
def addTimerNS (intervalNs : UInt64) (cb : TimerId → UInt64 → IO UInt64) : IO TimerId := do
  return ⟨← addTimerNSRaw intervalNs fun id interval => cb ⟨id⟩ interval⟩

@[extern "lean_sdl_remove_timer"]
private opaque removeTimerRaw (id : UInt32) : IO Bool

/-- Remove a timer. Returns `false` if the timer no longer exists (already
removed, or its callback returned `0`/threw) — calling again is a safe no-op.
C: `SDL_RemoveTimer`. -/
def removeTimer (id : TimerId) : IO Bool :=
  removeTimerRaw id.val

/-! ## Time-unit conversions (pure, `UInt64`). -/

/-- Nanoseconds per second. C: `SDL_NS_PER_SECOND`. -/
def nsPerSecond : UInt64 := 1_000_000_000
/-- Nanoseconds per millisecond. C: `SDL_NS_PER_MS`. -/
def nsPerMs : UInt64 := 1_000_000
/-- Nanoseconds per microsecond. C: `SDL_NS_PER_US`. -/
def nsPerUs : UInt64 := 1_000

/-- Seconds → nanoseconds. C: `SDL_SECONDS_TO_NS`. -/
def secondsToNs (s : UInt64) : UInt64 := s * nsPerSecond
#guard secondsToNs 0 == 0
#guard secondsToNs 2 == 2_000_000_000

/-- Nanoseconds → whole seconds (truncating). C: `SDL_NS_TO_SECONDS`. -/
def nsToSeconds (ns : UInt64) : UInt64 := ns / nsPerSecond
#guard nsToSeconds 2_500_000_000 == 2
#guard nsToSeconds 999_999_999 == 0

/-- Milliseconds → nanoseconds. C: `SDL_MS_TO_NS`. -/
def msToNs (ms : UInt64) : UInt64 := ms * nsPerMs
#guard msToNs 5 == 5_000_000

/-- Nanoseconds → whole milliseconds (truncating). C: `SDL_NS_TO_MS`. -/
def nsToMs (ns : UInt64) : UInt64 := ns / nsPerMs
#guard nsToMs 5_000_000 == 5
#guard nsToMs 5_999_999 == 5

/-- Microseconds → nanoseconds. C: `SDL_US_TO_NS`. -/
def usToNs (us : UInt64) : UInt64 := us * nsPerUs
#guard usToNs 3 == 3_000

/-- Nanoseconds → whole microseconds (truncating). C: `SDL_NS_TO_US`. -/
def nsToUs (ns : UInt64) : UInt64 := ns / nsPerUs
#guard nsToUs 3_000 == 3
#guard nsToUs 3_999 == 3

end Sdl

end
