module

public import Sdl.Core.Macros
public meta import Sdl.Core.Macros
public import Sdl.Error
public meta import Sdl.Error

public section

/-!
# Realtime clock and calendar (`SDL_time.h`)

`Time` is nanoseconds since the Unix epoch (UTC); `DateTime` is a broken-down
calendar time. Several conversions are pure; the clock query and the
date/time conversions are `IO` (they can fail on out-of-range input).
-/

namespace Sdl

/-- A moment in time as nanoseconds since the Unix epoch (Jan 1 1970, UTC).
C: `SDL_Time` (a `Sint64`). -/
structure Time where
  /-- Nanoseconds since the Unix epoch. -/
  ns : Int64
deriving BEq, Repr, Inhabited

instance : LT Time := ⟨fun a b => a.ns < b.ns⟩
instance : LE Time := ⟨fun a b => a.ns ≤ b.ns⟩
instance : Ord Time := ⟨fun a b => compare a.ns.toInt b.ns.toInt⟩

/-- Preferred date format of the system locale. C: `SDL_DateFormat`. -/
sdl_enum DateFormat : UInt32 where
  | yyyymmdd => 0  -- C: SDL_DATE_FORMAT_YYYYMMDD (Year/Month/Day)
  | ddmmyyyy => 1  -- C: SDL_DATE_FORMAT_DDMMYYYY (Day/Month/Year)
  | mmddyyyy => 2  -- C: SDL_DATE_FORMAT_MMDDYYYY (Month/Day/Year)

/-- Preferred time format of the system locale. C: `SDL_TimeFormat`. -/
sdl_enum TimeFormat : UInt32 where
  | «24hr» => 0  -- C: SDL_TIME_FORMAT_24HR
  | «12hr» => 1  -- C: SDL_TIME_FORMAT_12HR

/-- A calendar date and time broken into components. C: `SDL_DateTime`.

Field ranges (per the C docs): `month` [1-12], `day` [1-31], `hour` [0-23],
`minute` [0-59], `second` [0-60] (leap second), `nanosecond` [0-999999999],
`dayOfWeek` [0-6] with 0 being Sunday, `utcOffset` seconds east of UTC. -/
structure DateTime where
  /-- Year. -/
  year : Int32
  /-- Month [1-12]. -/
  month : Int32
  /-- Day of the month [1-31]. -/
  day : Int32
  /-- Hour [0-23]. -/
  hour : Int32
  /-- Minute [0-59]. -/
  minute : Int32
  /-- Seconds [0-60]. -/
  second : Int32
  /-- Nanoseconds [0-999999999]. -/
  nanosecond : Int32
  /-- Day of the week [0-6], 0 being Sunday. -/
  dayOfWeek : Int32
  /-- Seconds east of UTC. -/
  utcOffset : Int32
deriving BEq, Repr, Inhabited

/-- Maker called from C to hand a `DateTime` back to Lean (flattened scalars).
C: builds the result of `SDL_TimeToDateTime`. -/
@[export lean_sdl_mk_date_time]
private def mkDateTime (year month day hour minute second nanosecond dayOfWeek utcOffset : Int32) :
    DateTime :=
  { year, month, day, hour, minute, second, nanosecond, dayOfWeek, utcOffset }

/-- Maker for `getDateTimeLocalePreferences`: decodes the two raw enum values
(falling back to sane defaults on unknown values). -/
@[export lean_sdl_mk_time_locale_prefs]
private def mkTimeLocalePrefs (dateFormat timeFormat : UInt32) : DateFormat × TimeFormat :=
  (DateFormat.ofVal? dateFormat |>.getD .yyyymmdd,
   TimeFormat.ofVal? timeFormat |>.getD .«24hr»)

@[extern "lean_sdl_get_current_time"]
private opaque getCurrentTimeRaw : IO Int64

/-- Current system realtime clock value. C: `SDL_GetCurrentTime`. -/
def getCurrentTime : IO Time := do
  return ⟨← getCurrentTimeRaw⟩

@[extern "lean_sdl_time_to_date_time"]
private opaque timeToDateTimeRaw (ns : Int64) (localTime : Bool) : IO DateTime

/-- Break `t` into calendar components, in local time by default (UTC if
`localTime := false`). C: `SDL_TimeToDateTime`. -/
def Time.toDateTime (t : Time) (localTime : Bool := true) : IO DateTime :=
  timeToDateTimeRaw t.ns localTime

@[extern "lean_sdl_date_time_to_time"]
private opaque dateTimeToTimeRaw
  (year month day hour minute second nanosecond dayOfWeek utcOffset : Int32) : IO Int64

/-- Convert calendar components back to a `Time`. The `dayOfWeek` field is
ignored by SDL. C: `SDL_DateTimeToTime`. -/
def DateTime.toTime (dt : DateTime) : IO Time := do
  return ⟨← dateTimeToTimeRaw dt.year dt.month dt.day dt.hour dt.minute dt.second
    dt.nanosecond dt.dayOfWeek dt.utcOffset⟩

@[extern "lean_sdl_time_to_windows"]
private opaque timeToWindowsRaw (ns : Int64) : UInt64

/-- Convert to a Windows `FILETIME` (100-nanosecond intervals since Jan 1
1601), packed as one `UInt64` with the high 32 bits as `dwHighDateTime` and the
low 32 bits as `dwLowDateTime`. C: `SDL_TimeToWindows`. -/
def Time.toWindows (t : Time) : UInt64 := timeToWindowsRaw t.ns

@[extern "lean_sdl_time_from_windows"]
private opaque timeFromWindowsRaw (filetime : UInt64) : Int64

/-- Convert a Windows `FILETIME` (packed as by `Time.toWindows`: high 32 bits
`dwHighDateTime`, low 32 bits `dwLowDateTime`) to a `Time`.
C: `SDL_TimeFromWindows`. -/
def timeFromWindows (filetime : UInt64) : Time := ⟨timeFromWindowsRaw filetime⟩

/-- Number of days in `month` [1-12] of `year`. Throws on an invalid month.
C: `SDL_GetDaysInMonth` (returns -1 on failure). -/
@[extern "lean_sdl_get_days_in_month"]
opaque getDaysInMonth (year month : Int32) : IO Int32

/-- Day of the year [0-365] for the given date (Jan 1 is day 0). Throws on an
invalid date. C: `SDL_GetDayOfYear` (returns -1 on failure). -/
@[extern "lean_sdl_get_day_of_year"]
opaque getDayOfYear (year month day : Int32) : IO Int32

/-- Day of the week [0-6] for the given date, 0 being Sunday. Throws on an
invalid date. C: `SDL_GetDayOfWeek` (returns -1 on failure). -/
@[extern "lean_sdl_get_day_of_week"]
opaque getDayOfWeek (year month day : Int32) : IO Int32

@[extern "lean_sdl_get_date_time_locale_preferences"]
private opaque getDateTimeLocalePreferencesRaw : IO (DateFormat × TimeFormat)

/-- The system locale's preferred date and time formats.
C: `SDL_GetDateTimeLocalePreferences`. -/
def getDateTimeLocalePreferences : IO (DateFormat × TimeFormat) :=
  getDateTimeLocalePreferencesRaw

end Sdl

end
