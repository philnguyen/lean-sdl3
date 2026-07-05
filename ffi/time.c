/* Shims for Sdl/Time.lean (SDL_time.h).
 *
 * `SDL_Time` is a Sint64 nanosecond count; the raw externs traffic in that
 * flat int64 and the Lean wrappers pack it into `Time`. Structure results
 * (`DateTime`, the locale-prefs pair) are built by the @[export]ed Lean makers
 * below, so C never lays out a Lean structure. */
#include "util.h"

/* Lean-owned makers (see Sdl/Time.lean). */
extern lean_object *lean_sdl_mk_date_time(
    int32_t year, int32_t month, int32_t day, int32_t hour, int32_t minute,
    int32_t second, int32_t nanosecond, int32_t day_of_week, int32_t utc_offset);
extern lean_object *lean_sdl_mk_time_locale_prefs(uint32_t date_format, uint32_t time_format);

/* Sdl.getCurrentTimeRaw : IO Int64 -- C: SDL_GetCurrentTime */
LEAN_EXPORT lean_obj_res lean_sdl_get_current_time(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_Time ticks = 0;
    if (!SDL_GetCurrentTime(&ticks)) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_box_uint64((uint64_t)ticks));
}

/* Sdl.timeToDateTimeRaw (ns : Int64) (localTime : Bool) : IO DateTime
 * -- C: SDL_TimeToDateTime */
LEAN_EXPORT lean_obj_res lean_sdl_time_to_date_time(
        int64_t ns, uint8_t local_time, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_DateTime dt;
    if (!SDL_TimeToDateTime((SDL_Time)ns, &dt, local_time != 0)) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_mk_date_time(
        dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second,
        dt.nanosecond, dt.day_of_week, dt.utc_offset));
}

/* Sdl.dateTimeToTimeRaw (9 Int32s) : IO Int64 -- C: SDL_DateTimeToTime */
LEAN_EXPORT lean_obj_res lean_sdl_date_time_to_time(
        int32_t year, int32_t month, int32_t day, int32_t hour, int32_t minute,
        int32_t second, int32_t nanosecond, int32_t day_of_week, int32_t utc_offset,
        lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_DateTime dt;
    dt.year = year; dt.month = month; dt.day = day; dt.hour = hour;
    dt.minute = minute; dt.second = second; dt.nanosecond = nanosecond;
    dt.day_of_week = day_of_week; dt.utc_offset = utc_offset;
    SDL_Time ticks = 0;
    if (!SDL_DateTimeToTime(&dt, &ticks)) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_box_uint64((uint64_t)ticks));
}

/* Sdl.timeToWindowsRaw (ns : Int64) : UInt64 -- C: SDL_TimeToWindows (pure).
 * Packs dwHighDateTime in the high 32 bits, dwLowDateTime in the low 32. */
LEAN_EXPORT uint64_t lean_sdl_time_to_windows(int64_t ns) {
    SDL_SHIM_PROLOGUE();
    Uint32 low = 0, high = 0;
    SDL_TimeToWindows((SDL_Time)ns, &low, &high);
    return ((uint64_t)high << 32) | (uint64_t)low;
}

/* Sdl.timeFromWindowsRaw (filetime : UInt64) : Int64
 * -- C: SDL_TimeFromWindows (pure). Unpacks the packed FILETIME. */
LEAN_EXPORT int64_t lean_sdl_time_from_windows(uint64_t filetime) {
    SDL_SHIM_PROLOGUE();
    Uint32 low = (Uint32)(filetime & 0xFFFFFFFFu);
    Uint32 high = (Uint32)(filetime >> 32);
    return (int64_t)SDL_TimeFromWindows(low, high);
}

/* Sdl.getDaysInMonth (year month : Int32) : IO Int32 -- C: SDL_GetDaysInMonth */
LEAN_EXPORT lean_obj_res lean_sdl_get_days_in_month(
        int32_t year, int32_t month, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    int r = SDL_GetDaysInMonth((int)year, (int)month);
    if (r < 0) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)r));
}

/* Sdl.getDayOfYear (year month day : Int32) : IO Int32 -- C: SDL_GetDayOfYear */
LEAN_EXPORT lean_obj_res lean_sdl_get_day_of_year(
        int32_t year, int32_t month, int32_t day, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    int r = SDL_GetDayOfYear((int)year, (int)month, (int)day);
    if (r < 0) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)r));
}

/* Sdl.getDayOfWeek (year month day : Int32) : IO Int32 -- C: SDL_GetDayOfWeek */
LEAN_EXPORT lean_obj_res lean_sdl_get_day_of_week(
        int32_t year, int32_t month, int32_t day, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    int r = SDL_GetDayOfWeek((int)year, (int)month, (int)day);
    if (r < 0) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)r));
}

/* Sdl.getDateTimeLocalePreferencesRaw : IO (DateFormat × TimeFormat)
 * -- C: SDL_GetDateTimeLocalePreferences. Both out params are requested. */
LEAN_EXPORT lean_obj_res lean_sdl_get_date_time_locale_preferences(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_DateFormat df = SDL_DATE_FORMAT_YYYYMMDD;
    SDL_TimeFormat tf = SDL_TIME_FORMAT_24HR;
    if (!SDL_GetDateTimeLocalePreferences(&df, &tf)) return lean_sdl_throw();
    return lean_io_result_mk_ok(
        lean_sdl_mk_time_locale_prefs((uint32_t)df, (uint32_t)tf));
}
