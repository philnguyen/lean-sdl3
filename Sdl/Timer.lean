import Sdl.Core.Macros
import Sdl.Error

/-!
# Timers and clocks (`SDL_timer.h`)

Wall-clock/monotonic time queries, blocking delays, and the pure time-unit
conversion helpers that mirror the header's `SDL_*_TO_*` macros.

Skipped: `SDL_AddTimer`, `SDL_AddTimerNS`, `SDL_RemoveTimer` — need a callback
bridge; deferred to the M6 callbacks milestone.
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
