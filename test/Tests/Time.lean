import Sdl
import Tests.Harness

namespace Tests.Time
open Sdl Tests.Harness

/-- Clock query, UTC and Windows-FILETIME round-trips, and the pure calendar
helpers (values checked against the header's documented ranges: `getDayOfWeek`
is [0-6] with 0=Sunday, `getDayOfYear` is [0-365] with Jan 1 = day 0). -/
def run : IO Unit := do
  -- current time is positive (well after the epoch)
  let t ← Sdl.getCurrentTime
  check "getCurrentTime positive" (t.ns > 0)
  -- UTC breakdown round-trips exactly (nanoseconds survive)
  let dt ← t.toDateTime (localTime := false)
  let t2 ← dt.toTime
  check "UTC DateTime round-trip exact" (t2 == t)
  -- Windows FILETIME round-trip (exact at 100ns granularity)
  check "Windows FILETIME round-trip"
    ((Sdl.timeFromWindows t.toWindows).toWindows == t.toWindows)
  -- days in month, leap vs non-leap February
  check "daysInMonth 2024-02 == 29" ((← Sdl.getDaysInMonth 2024 2) == 29)
  check "daysInMonth 2023-02 == 28" ((← Sdl.getDaysInMonth 2023 2) == 28)
  checkThrows "daysInMonth month 13 throws" (Sdl.getDaysInMonth 2024 13)
  -- 2024-01-01 was a Monday; SDL: 0=Sunday so Monday == 1
  check "dayOfWeek 2024-01-01 == 1 (Monday)" ((← Sdl.getDayOfWeek 2024 1 1) == 1)
  -- day of year: Jan 1 is day 0, Feb 1 is day 31 (January has 31 days)
  check "dayOfYear 2024-01-01 == 0" ((← Sdl.getDayOfYear 2024 1 1) == 0)
  check "dayOfYear 2024-02-01 == 31" ((← Sdl.getDayOfYear 2024 2 1) == 31)
  checkThrows "dayOfYear invalid date throws" (Sdl.getDayOfYear 2024 13 40)
  -- locale preferences query succeeds
  let _ ← Sdl.getDateTimeLocalePreferences
  check "getDateTimeLocalePreferences ok" true

end Tests.Time
