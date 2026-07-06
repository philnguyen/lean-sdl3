/* Shims for Sdl/Events.lean (SDL_events.h).
 *
 * The event union decode: ONE switch over event->type routes each event to the
 * matching @[export]ed Lean maker (defined in Sdl/Events.lean), passing
 * flattened, unboxed scalars. C never calls lean_alloc_ctor for an event; the
 * Lean compiler owns the Event constructor layout and the raw-type dispatch
 * happens inside the makers (so it is #guard-testable). String fields are
 * copied eagerly here (lean_mk_string / option-string helper) because the C
 * pointers die at the next poll.
 *
 * The forward declarations below MUST match the signatures the Lean compiler
 * generates in .lake/build/ir/Sdl/Events.c (the orchestrator diffs the two).
 * ABI note (docs/DESIGN.md): Lean's generated C uses uint32_t/uint64_t even for
 * Int32/Int64 params; the signed intN_t used here is identical in width and
 * register class, so the bits are preserved. Float32 -> float, Bool -> uint8_t,
 * String/Array String/Option String -> lean_object*. */
#include "util.h"
#include "callbacks.h"
#include "events.h"

/* The decode reinterprets the 128-byte SDL_Event union; pin its ABI size. */
_Static_assert(sizeof(SDL_Event) == 128, "SDL_Event ABI size");

/* ---- Lean-owned event makers (Sdl/Events.lean). Keep in sync with the
 *      generated prototypes in .lake/build/ir/Sdl/Events.c. ---- */
extern lean_object *lean_sdl_mk_event_common(uint32_t type, uint64_t ts);
extern lean_object *lean_sdl_mk_event_display(uint32_t type, uint64_t ts,
    uint32_t display_id, int32_t data1, int32_t data2);
extern lean_object *lean_sdl_mk_event_window(uint32_t type, uint64_t ts,
    uint32_t window_id, int32_t data1, int32_t data2);
extern lean_object *lean_sdl_mk_event_kdevice(uint32_t type, uint64_t ts, uint32_t which);
extern lean_object *lean_sdl_mk_event_key(uint32_t type, uint64_t ts,
    uint32_t window_id, uint32_t which, uint32_t scancode, uint32_t key,
    uint16_t mod, uint16_t raw, uint8_t down, uint8_t repeat);
extern lean_object *lean_sdl_mk_event_text_editing(uint32_t type, uint64_t ts,
    uint32_t window_id, lean_object *text, int32_t start, int32_t length);
extern lean_object *lean_sdl_mk_event_text_editing_candidates(uint32_t type,
    uint64_t ts, uint32_t window_id, lean_object *candidates, int32_t selected,
    uint8_t horizontal);
extern lean_object *lean_sdl_mk_event_text_input(uint32_t type, uint64_t ts,
    uint32_t window_id, lean_object *text);
extern lean_object *lean_sdl_mk_event_mdevice(uint32_t type, uint64_t ts, uint32_t which);
extern lean_object *lean_sdl_mk_event_mouse_motion(uint32_t type, uint64_t ts,
    uint32_t window_id, uint32_t which, uint32_t state, float x, float y,
    float xrel, float yrel);
extern lean_object *lean_sdl_mk_event_mouse_button(uint32_t type, uint64_t ts,
    uint32_t window_id, uint32_t which, uint8_t button, uint8_t down,
    uint8_t clicks, float x, float y);
extern lean_object *lean_sdl_mk_event_mouse_wheel(uint32_t type, uint64_t ts,
    uint32_t window_id, uint32_t which, float x, float y, uint32_t direction,
    float mouse_x, float mouse_y, int32_t integer_x, int32_t integer_y);
extern lean_object *lean_sdl_mk_event_jdevice(uint32_t type, uint64_t ts, uint32_t which);
extern lean_object *lean_sdl_mk_event_jaxis(uint32_t type, uint64_t ts,
    uint32_t which, uint8_t axis, int16_t value);
extern lean_object *lean_sdl_mk_event_jball(uint32_t type, uint64_t ts,
    uint32_t which, uint8_t ball, int16_t xrel, int16_t yrel);
extern lean_object *lean_sdl_mk_event_jhat(uint32_t type, uint64_t ts,
    uint32_t which, uint8_t hat, uint8_t value);
extern lean_object *lean_sdl_mk_event_jbutton(uint32_t type, uint64_t ts,
    uint32_t which, uint8_t button, uint8_t down);
extern lean_object *lean_sdl_mk_event_jbattery(uint32_t type, uint64_t ts,
    uint32_t which, int32_t state, int32_t percent);
extern lean_object *lean_sdl_mk_event_gdevice(uint32_t type, uint64_t ts, uint32_t which);
extern lean_object *lean_sdl_mk_event_gaxis(uint32_t type, uint64_t ts,
    uint32_t which, uint8_t axis, int16_t value);
extern lean_object *lean_sdl_mk_event_gbutton(uint32_t type, uint64_t ts,
    uint32_t which, uint8_t button, uint8_t down);
extern lean_object *lean_sdl_mk_event_gtouchpad(uint32_t type, uint64_t ts,
    uint32_t which, int32_t touchpad, int32_t finger, float x, float y,
    float pressure);
extern lean_object *lean_sdl_mk_event_gsensor(uint32_t type, uint64_t ts,
    uint32_t which, int32_t sensor, float d0, float d1, float d2,
    uint64_t sensor_ts);
extern lean_object *lean_sdl_mk_event_adevice(uint32_t type, uint64_t ts,
    uint32_t which, uint8_t recording);
extern lean_object *lean_sdl_mk_event_cdevice(uint32_t type, uint64_t ts, uint32_t which);
extern lean_object *lean_sdl_mk_event_sensor(uint32_t type, uint64_t ts,
    uint32_t which, float d0, float d1, float d2, float d3, float d4, float d5,
    uint64_t sensor_ts);
extern lean_object *lean_sdl_mk_event_tfinger(uint32_t type, uint64_t ts,
    uint64_t touch_id, uint64_t finger_id, float x, float y, float dx, float dy,
    float pressure, uint32_t window_id);
extern lean_object *lean_sdl_mk_event_pinch(uint32_t type, uint64_t ts,
    float scale, uint32_t window_id);
extern lean_object *lean_sdl_mk_event_pproximity(uint32_t type, uint64_t ts,
    uint32_t window_id, uint32_t which);
extern lean_object *lean_sdl_mk_event_pmotion(uint32_t type, uint64_t ts,
    uint32_t window_id, uint32_t which, uint32_t pen_state, float x, float y);
extern lean_object *lean_sdl_mk_event_ptouch(uint32_t type, uint64_t ts,
    uint32_t window_id, uint32_t which, uint32_t pen_state, float x, float y,
    uint8_t eraser, uint8_t down);
extern lean_object *lean_sdl_mk_event_pbutton(uint32_t type, uint64_t ts,
    uint32_t window_id, uint32_t which, uint32_t pen_state, float x, float y,
    uint8_t button, uint8_t down);
extern lean_object *lean_sdl_mk_event_paxis(uint32_t type, uint64_t ts,
    uint32_t window_id, uint32_t which, uint32_t pen_state, float x, float y,
    uint32_t axis, float value);
extern lean_object *lean_sdl_mk_event_render(uint32_t type, uint64_t ts, uint32_t window_id);
extern lean_object *lean_sdl_mk_event_drop(uint32_t type, uint64_t ts,
    uint32_t window_id, float x, float y, lean_object *source, lean_object *data);
extern lean_object *lean_sdl_mk_event_clipboard(uint32_t type, uint64_t ts,
    uint8_t owner, lean_object *mime_types);
extern lean_object *lean_sdl_mk_event_user(uint32_t type, uint64_t ts,
    uint32_t window_id, int32_t code);

/* Build an `Array String` from an explicitly-counted (not NULL-terminated)
 * C string list; NULL list or n <= 0 yields the empty array. */
static lean_object *lean_sdl_event_string_array(const char *const *xs, int n) {
    size_t count = (xs && n > 0) ? (size_t)n : 0;
    lean_object *arr = lean_alloc_array(count, count);
    for (size_t i = 0; i < count; i++)
        lean_array_set_core(arr, i, lean_sdl_mk_string(xs[i]));
    return arr;
}

/* Decode one SDL_Event into an owned `Sdl.Event` via the matching maker. The
 * Display and Window families are contiguous ranges, routed by range so a
 * future mid-range member still reaches the right maker (which falls back to
 * .unknown for any value it does not itself map). Non-static: declared in
 * ffi/events.h so callback trampolines outside this file can decode too. */
lean_object *lean_sdl_decode_event(const SDL_Event *e) {
    Uint32 t = e->type;

    if (t >= SDL_EVENT_DISPLAY_FIRST && t <= SDL_EVENT_DISPLAY_LAST)
        return lean_sdl_mk_event_display(t, e->display.timestamp,
            (uint32_t)e->display.displayID, e->display.data1, e->display.data2);
    if (t >= SDL_EVENT_WINDOW_FIRST && t <= SDL_EVENT_WINDOW_LAST)
        return lean_sdl_mk_event_window(t, e->window.timestamp,
            (uint32_t)e->window.windowID, e->window.data1, e->window.data2);

    switch (t) {
    /* Application (payloadless) + keymap/screen-keyboard -> SDL_CommonEvent */
    case SDL_EVENT_QUIT:
    case SDL_EVENT_TERMINATING:
    case SDL_EVENT_LOW_MEMORY:
    case SDL_EVENT_WILL_ENTER_BACKGROUND:
    case SDL_EVENT_DID_ENTER_BACKGROUND:
    case SDL_EVENT_WILL_ENTER_FOREGROUND:
    case SDL_EVENT_DID_ENTER_FOREGROUND:
    case SDL_EVENT_LOCALE_CHANGED:
    case SDL_EVENT_SYSTEM_THEME_CHANGED:
    case SDL_EVENT_KEYMAP_CHANGED:
    case SDL_EVENT_SCREEN_KEYBOARD_SHOWN:
    case SDL_EVENT_SCREEN_KEYBOARD_HIDDEN:
        return lean_sdl_mk_event_common(t, e->common.timestamp);

    /* Keyboard */
    case SDL_EVENT_KEY_DOWN:
    case SDL_EVENT_KEY_UP:
        return lean_sdl_mk_event_key(t, e->key.timestamp,
            (uint32_t)e->key.windowID, (uint32_t)e->key.which,
            (uint32_t)e->key.scancode, (uint32_t)e->key.key,
            (uint16_t)e->key.mod, e->key.raw,
            (uint8_t)e->key.down, (uint8_t)e->key.repeat);
    case SDL_EVENT_TEXT_EDITING:
        return lean_sdl_mk_event_text_editing(t, e->edit.timestamp,
            (uint32_t)e->edit.windowID, lean_sdl_mk_string(e->edit.text),
            e->edit.start, e->edit.length);
    case SDL_EVENT_TEXT_EDITING_CANDIDATES:
        return lean_sdl_mk_event_text_editing_candidates(t,
            e->edit_candidates.timestamp, (uint32_t)e->edit_candidates.windowID,
            lean_sdl_event_string_array(e->edit_candidates.candidates,
                                        e->edit_candidates.num_candidates),
            e->edit_candidates.selected_candidate,
            (uint8_t)e->edit_candidates.horizontal);
    case SDL_EVENT_TEXT_INPUT:
        return lean_sdl_mk_event_text_input(t, e->text.timestamp,
            (uint32_t)e->text.windowID, lean_sdl_mk_string(e->text.text));
    case SDL_EVENT_KEYBOARD_ADDED:
    case SDL_EVENT_KEYBOARD_REMOVED:
        return lean_sdl_mk_event_kdevice(t, e->kdevice.timestamp,
            (uint32_t)e->kdevice.which);

    /* Mouse */
    case SDL_EVENT_MOUSE_MOTION:
        return lean_sdl_mk_event_mouse_motion(t, e->motion.timestamp,
            (uint32_t)e->motion.windowID, (uint32_t)e->motion.which,
            (uint32_t)e->motion.state, e->motion.x, e->motion.y,
            e->motion.xrel, e->motion.yrel);
    case SDL_EVENT_MOUSE_BUTTON_DOWN:
    case SDL_EVENT_MOUSE_BUTTON_UP:
        return lean_sdl_mk_event_mouse_button(t, e->button.timestamp,
            (uint32_t)e->button.windowID, (uint32_t)e->button.which,
            e->button.button, (uint8_t)e->button.down, e->button.clicks,
            e->button.x, e->button.y);
    case SDL_EVENT_MOUSE_WHEEL:
        return lean_sdl_mk_event_mouse_wheel(t, e->wheel.timestamp,
            (uint32_t)e->wheel.windowID, (uint32_t)e->wheel.which,
            e->wheel.x, e->wheel.y, (uint32_t)e->wheel.direction,
            e->wheel.mouse_x, e->wheel.mouse_y,
            e->wheel.integer_x, e->wheel.integer_y);
    case SDL_EVENT_MOUSE_ADDED:
    case SDL_EVENT_MOUSE_REMOVED:
        return lean_sdl_mk_event_mdevice(t, e->mdevice.timestamp,
            (uint32_t)e->mdevice.which);

    /* Joystick */
    case SDL_EVENT_JOYSTICK_AXIS_MOTION:
        return lean_sdl_mk_event_jaxis(t, e->jaxis.timestamp,
            (uint32_t)e->jaxis.which, e->jaxis.axis, e->jaxis.value);
    case SDL_EVENT_JOYSTICK_BALL_MOTION:
        return lean_sdl_mk_event_jball(t, e->jball.timestamp,
            (uint32_t)e->jball.which, e->jball.ball, e->jball.xrel, e->jball.yrel);
    case SDL_EVENT_JOYSTICK_HAT_MOTION:
        return lean_sdl_mk_event_jhat(t, e->jhat.timestamp,
            (uint32_t)e->jhat.which, e->jhat.hat, e->jhat.value);
    case SDL_EVENT_JOYSTICK_BUTTON_DOWN:
    case SDL_EVENT_JOYSTICK_BUTTON_UP:
        return lean_sdl_mk_event_jbutton(t, e->jbutton.timestamp,
            (uint32_t)e->jbutton.which, e->jbutton.button, (uint8_t)e->jbutton.down);
    case SDL_EVENT_JOYSTICK_ADDED:
    case SDL_EVENT_JOYSTICK_REMOVED:
    case SDL_EVENT_JOYSTICK_UPDATE_COMPLETE:
        return lean_sdl_mk_event_jdevice(t, e->jdevice.timestamp,
            (uint32_t)e->jdevice.which);
    case SDL_EVENT_JOYSTICK_BATTERY_UPDATED:
        return lean_sdl_mk_event_jbattery(t, e->jbattery.timestamp,
            (uint32_t)e->jbattery.which, (int32_t)e->jbattery.state,
            (int32_t)e->jbattery.percent);

    /* Gamepad */
    case SDL_EVENT_GAMEPAD_AXIS_MOTION:
        return lean_sdl_mk_event_gaxis(t, e->gaxis.timestamp,
            (uint32_t)e->gaxis.which, e->gaxis.axis, e->gaxis.value);
    case SDL_EVENT_GAMEPAD_BUTTON_DOWN:
    case SDL_EVENT_GAMEPAD_BUTTON_UP:
        return lean_sdl_mk_event_gbutton(t, e->gbutton.timestamp,
            (uint32_t)e->gbutton.which, e->gbutton.button, (uint8_t)e->gbutton.down);
    case SDL_EVENT_GAMEPAD_ADDED:
    case SDL_EVENT_GAMEPAD_REMOVED:
    case SDL_EVENT_GAMEPAD_REMAPPED:
    case SDL_EVENT_GAMEPAD_UPDATE_COMPLETE:
    case SDL_EVENT_GAMEPAD_STEAM_HANDLE_UPDATED:
        return lean_sdl_mk_event_gdevice(t, e->gdevice.timestamp,
            (uint32_t)e->gdevice.which);
    case SDL_EVENT_GAMEPAD_TOUCHPAD_DOWN:
    case SDL_EVENT_GAMEPAD_TOUCHPAD_MOTION:
    case SDL_EVENT_GAMEPAD_TOUCHPAD_UP:
        return lean_sdl_mk_event_gtouchpad(t, e->gtouchpad.timestamp,
            (uint32_t)e->gtouchpad.which, e->gtouchpad.touchpad,
            e->gtouchpad.finger, e->gtouchpad.x, e->gtouchpad.y,
            e->gtouchpad.pressure);
    case SDL_EVENT_GAMEPAD_SENSOR_UPDATE:
        return lean_sdl_mk_event_gsensor(t, e->gsensor.timestamp,
            (uint32_t)e->gsensor.which, e->gsensor.sensor,
            e->gsensor.data[0], e->gsensor.data[1], e->gsensor.data[2],
            e->gsensor.sensor_timestamp);

    /* Audio / Camera / Sensor */
    case SDL_EVENT_AUDIO_DEVICE_ADDED:
    case SDL_EVENT_AUDIO_DEVICE_REMOVED:
    case SDL_EVENT_AUDIO_DEVICE_FORMAT_CHANGED:
        return lean_sdl_mk_event_adevice(t, e->adevice.timestamp,
            (uint32_t)e->adevice.which, (uint8_t)e->adevice.recording);
    case SDL_EVENT_CAMERA_DEVICE_ADDED:
    case SDL_EVENT_CAMERA_DEVICE_REMOVED:
    case SDL_EVENT_CAMERA_DEVICE_APPROVED:
    case SDL_EVENT_CAMERA_DEVICE_DENIED:
        return lean_sdl_mk_event_cdevice(t, e->cdevice.timestamp,
            (uint32_t)e->cdevice.which);
    case SDL_EVENT_SENSOR_UPDATE:
        return lean_sdl_mk_event_sensor(t, e->sensor.timestamp,
            (uint32_t)e->sensor.which,
            e->sensor.data[0], e->sensor.data[1], e->sensor.data[2],
            e->sensor.data[3], e->sensor.data[4], e->sensor.data[5],
            e->sensor.sensor_timestamp);

    /* Touch / Pinch */
    case SDL_EVENT_FINGER_DOWN:
    case SDL_EVENT_FINGER_UP:
    case SDL_EVENT_FINGER_MOTION:
    case SDL_EVENT_FINGER_CANCELED:
        return lean_sdl_mk_event_tfinger(t, e->tfinger.timestamp,
            (uint64_t)e->tfinger.touchID, (uint64_t)e->tfinger.fingerID,
            e->tfinger.x, e->tfinger.y, e->tfinger.dx, e->tfinger.dy,
            e->tfinger.pressure, (uint32_t)e->tfinger.windowID);
    case SDL_EVENT_PINCH_BEGIN:
    case SDL_EVENT_PINCH_UPDATE:
    case SDL_EVENT_PINCH_END:
        return lean_sdl_mk_event_pinch(t, e->pinch.timestamp,
            e->pinch.scale, (uint32_t)e->pinch.windowID);

    /* Pen */
    case SDL_EVENT_PEN_PROXIMITY_IN:
    case SDL_EVENT_PEN_PROXIMITY_OUT:
        return lean_sdl_mk_event_pproximity(t, e->pproximity.timestamp,
            (uint32_t)e->pproximity.windowID, (uint32_t)e->pproximity.which);
    case SDL_EVENT_PEN_MOTION:
        return lean_sdl_mk_event_pmotion(t, e->pmotion.timestamp,
            (uint32_t)e->pmotion.windowID, (uint32_t)e->pmotion.which,
            (uint32_t)e->pmotion.pen_state, e->pmotion.x, e->pmotion.y);
    case SDL_EVENT_PEN_DOWN:
    case SDL_EVENT_PEN_UP:
        return lean_sdl_mk_event_ptouch(t, e->ptouch.timestamp,
            (uint32_t)e->ptouch.windowID, (uint32_t)e->ptouch.which,
            (uint32_t)e->ptouch.pen_state, e->ptouch.x, e->ptouch.y,
            (uint8_t)e->ptouch.eraser, (uint8_t)e->ptouch.down);
    case SDL_EVENT_PEN_BUTTON_DOWN:
    case SDL_EVENT_PEN_BUTTON_UP:
        return lean_sdl_mk_event_pbutton(t, e->pbutton.timestamp,
            (uint32_t)e->pbutton.windowID, (uint32_t)e->pbutton.which,
            (uint32_t)e->pbutton.pen_state, e->pbutton.x, e->pbutton.y,
            e->pbutton.button, (uint8_t)e->pbutton.down);
    case SDL_EVENT_PEN_AXIS:
        return lean_sdl_mk_event_paxis(t, e->paxis.timestamp,
            (uint32_t)e->paxis.windowID, (uint32_t)e->paxis.which,
            (uint32_t)e->paxis.pen_state, e->paxis.x, e->paxis.y,
            (uint32_t)e->paxis.axis, e->paxis.value);

    /* Render */
    case SDL_EVENT_RENDER_TARGETS_RESET:
    case SDL_EVENT_RENDER_DEVICE_RESET:
    case SDL_EVENT_RENDER_DEVICE_LOST:
        return lean_sdl_mk_event_render(t, e->render.timestamp,
            (uint32_t)e->render.windowID);

    /* Clipboard */
    case SDL_EVENT_CLIPBOARD_UPDATE:
        return lean_sdl_mk_event_clipboard(t, e->clipboard.timestamp,
            (uint8_t)e->clipboard.owner,
            lean_sdl_event_string_array(e->clipboard.mime_types,
                                        e->clipboard.num_mime_types));

    /* Drag and drop (source/data may be NULL -> Option none) */
    case SDL_EVENT_DROP_FILE:
    case SDL_EVENT_DROP_TEXT:
    case SDL_EVENT_DROP_BEGIN:
    case SDL_EVENT_DROP_COMPLETE:
    case SDL_EVENT_DROP_POSITION:
        return lean_sdl_mk_event_drop(t, e->drop.timestamp,
            (uint32_t)e->drop.windowID, e->drop.x, e->drop.y,
            lean_sdl_option_string(e->drop.source),
            lean_sdl_option_string(e->drop.data));

    default:
        /* User range -> user event; everything else (private/sentinel/...) ->
         * common maker, whose Lean fallback yields .unknown. */
        if (t >= SDL_EVENT_USER)
            return lean_sdl_mk_event_user(t, e->user.timestamp,
                (uint32_t)e->user.windowID, e->user.code);
        return lean_sdl_mk_event_common(t, e->common.timestamp);
    }
}

/* ==================== Event-queue API ==================== */

/* Sdl.pumpEvents : IO Unit -- C: SDL_PumpEvents (void). */
LEAN_EXPORT lean_obj_res lean_sdl_pump_events(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_PumpEvents();
    return lean_sdl_unit_ok();
}

/* Sdl.pollEvent : IO (Option Event)
 * -- C: SDL_PollEvent (false -> none, else some(decode)). */
LEAN_EXPORT lean_obj_res lean_sdl_poll_event(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_Event ev;
    if (!SDL_PollEvent(&ev))
        return lean_io_result_mk_ok(lean_sdl_none());
    return lean_io_result_mk_ok(lean_sdl_some(lean_sdl_decode_event(&ev)));
}

/* Sdl.waitEvent : IO Event -- C: SDL_WaitEvent (false -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_wait_event(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_Event ev;
    if (!SDL_WaitEvent(&ev))
        return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_decode_event(&ev));
}

/* Sdl.waitEventTimeout (timeoutMs : Int32) : IO (Option Event)
 * -- C: SDL_WaitEventTimeout (false -> none). */
LEAN_EXPORT lean_obj_res lean_sdl_wait_event_timeout(int32_t timeout_ms, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_Event ev;
    if (!SDL_WaitEventTimeout(&ev, (Sint32)timeout_ms))
        return lean_io_result_mk_ok(lean_sdl_none());
    return lean_io_result_mk_ok(lean_sdl_some(lean_sdl_decode_event(&ev)));
}

/* Sdl.pushUserEventRaw (type : UInt32) (code : Int32) (windowId : UInt32) : IO Bool
 * -- C: SDL_PushEvent with a zeroed SDL_UserEvent. timestamp left 0 so SDL
 * stamps it on push; returns the raw bool (false = filtered/failed). */
LEAN_EXPORT lean_obj_res lean_sdl_push_user_event(
        uint32_t type, int32_t code, uint32_t window_id, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_Event ev;
    SDL_zero(ev);
    ev.user.type = type;
    ev.user.timestamp = 0;
    ev.user.windowID = (SDL_WindowID)window_id;
    ev.user.code = (Sint32)code;
    bool r = SDL_PushEvent(&ev);
    return lean_io_result_mk_ok(lean_box(r));
}

/* Sdl.registerEventsRaw (count : Int32) : IO UInt32
 * -- C: SDL_RegisterEvents (0 = failure/none). */
LEAN_EXPORT lean_obj_res lean_sdl_register_events(int32_t count, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(
        lean_box_uint32((uint32_t)SDL_RegisterEvents((int)count)));
}

/* Sdl.hasEventRaw (type : UInt32) : IO Bool -- C: SDL_HasEvent. */
LEAN_EXPORT lean_obj_res lean_sdl_has_event(uint32_t type, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(lean_box(SDL_HasEvent(type)));
}

/* Sdl.hasEventsRaw (minType maxType : UInt32) : IO Bool -- C: SDL_HasEvents. */
LEAN_EXPORT lean_obj_res lean_sdl_has_events(
        uint32_t min_type, uint32_t max_type, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(lean_box(SDL_HasEvents(min_type, max_type)));
}

/* Sdl.flushEventRaw (type : UInt32) : IO Unit -- C: SDL_FlushEvent (void). */
LEAN_EXPORT lean_obj_res lean_sdl_flush_event(uint32_t type, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_FlushEvent(type);
    return lean_sdl_unit_ok();
}

/* Sdl.flushEventsRaw (minType maxType : UInt32) : IO Unit
 * -- C: SDL_FlushEvents (void). */
LEAN_EXPORT lean_obj_res lean_sdl_flush_events(
        uint32_t min_type, uint32_t max_type, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_FlushEvents(min_type, max_type);
    return lean_sdl_unit_ok();
}

/* Sdl.setEventEnabledRaw (type : UInt32) (enabled : Bool) : IO Unit
 * -- C: SDL_SetEventEnabled (void). */
LEAN_EXPORT lean_obj_res lean_sdl_set_event_enabled(
        uint32_t type, uint8_t enabled, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_SetEventEnabled(type, enabled != 0);
    return lean_sdl_unit_ok();
}

/* Sdl.eventEnabledRaw (type : UInt32) : IO Bool -- C: SDL_EventEnabled. */
LEAN_EXPORT lean_obj_res lean_sdl_event_enabled(uint32_t type, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(lean_box(SDL_EventEnabled(type)));
}

/* ==================== Event watches and filters ====================
 * Watches: gen-key registry (docs/DESIGN.md "Callbacks" #1) — SDL identifies a
 * watch by the (function, userdata) pair, so the shared trampoline plus the
 * key disambiguates. Filter: locked slot (#2) — SDL keeps exactly one filter.
 * Both trampolines decode the event and run the Lean closure; both can fire on
 * whatever thread generates or pushes the event. */

static sdl_cb_registry lean_sdl_event_watch_registry;

/* Watch closure: Event -> IO Unit. SDL ignores the return value. */
static bool SDLCALL lean_sdl_event_watch_tramp(void *userdata, SDL_Event *event) {
    uint64_t key = (uint64_t)(uintptr_t)userdata;
    lean_sdl_ensure_thread();
    lean_object *fn = lean_sdl_cb_acquire(&lean_sdl_event_watch_registry, key);
    if (!fn) return true; /* removed; possible trailing invocation */
    lean_sdl_io_ignore(lean_apply_2(fn, lean_sdl_decode_event(event), lean_box(0)));
    return true;
}

/* Sdl.addEventWatchRaw (cb : Event -> IO Unit) : IO UInt64
 * -- C: SDL_AddEventWatch. */
LEAN_EXPORT lean_obj_res lean_sdl_add_event_watch(lean_obj_arg fn, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    uint64_t key = lean_sdl_cb_register(&lean_sdl_event_watch_registry, fn, 0);
    if (!SDL_AddEventWatch(lean_sdl_event_watch_tramp, (void *)(uintptr_t)key)) {
        lean_object *f;
        uintptr_t aux;
        if (lean_sdl_cb_take(&lean_sdl_event_watch_registry, key, &f, &aux)) lean_dec(f);
        return lean_sdl_throw();
    }
    return lean_io_result_mk_ok(lean_box_uint64(key));
}

/* Sdl.removeEventWatchRaw (key : UInt64) : IO Bool
 * -- C: SDL_RemoveEventWatch (void; our bool = "was registered"). */
LEAN_EXPORT lean_obj_res lean_sdl_remove_event_watch(uint64_t key, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    lean_object *fn;
    uintptr_t aux;
    bool had = lean_sdl_cb_take(&lean_sdl_event_watch_registry, key, &fn, &aux);
    if (had) {
        SDL_RemoveEventWatch(lean_sdl_event_watch_tramp, (void *)(uintptr_t)key);
        lean_dec(fn);
    }
    return lean_io_result_mk_ok(lean_box(had ? 1 : 0));
}

static sdl_cb_slot lean_sdl_event_filter_slot;

/* Filter closure: Event -> IO Bool (false = drop). Exceptions keep the event
 * (accepting is the conservative default: dropped events are unrecoverable). */
static bool SDLCALL lean_sdl_event_filter_tramp(void *userdata, SDL_Event *event) {
    (void)userdata;
    lean_sdl_ensure_thread();
    lean_object *fn = lean_sdl_slot_acquire(&lean_sdl_event_filter_slot);
    if (!fn) return true; /* filter cleared mid-dispatch */
    return lean_sdl_io_bool_or(
        lean_apply_2(fn, lean_sdl_decode_event(event), lean_box(0)), true);
}

/* Sdl.setEventFilter (cb : Event -> IO Bool) : IO Unit
 * -- C: SDL_SetEventFilter. Slot is filled before SDL sees the trampoline. */
LEAN_EXPORT lean_obj_res lean_sdl_set_event_filter(lean_obj_arg fn, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    lean_sdl_slot_set(&lean_sdl_event_filter_slot, fn);
    SDL_SetEventFilter(lean_sdl_event_filter_tramp, NULL);
    return lean_sdl_unit_ok();
}

/* Sdl.clearEventFilter : IO Unit -- C: SDL_SetEventFilter(NULL, NULL). SDL is
 * unhooked first; a trampoline mid-flight already holds its own closure ref. */
LEAN_EXPORT lean_obj_res lean_sdl_clear_event_filter(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_SetEventFilter(NULL, NULL);
    lean_sdl_slot_clear(&lean_sdl_event_filter_slot);
    return lean_sdl_unit_ok();
}

/* One-shot synchronous queue sweep: the closure itself is the userdata,
 * borrowed for the duration of the SDL_FilterEvents call — no registry. Runs
 * on the calling (Lean) thread, so no ensure-thread dance is needed. */
static bool SDLCALL lean_sdl_filter_events_tramp(void *userdata, SDL_Event *event) {
    lean_object *fn = (lean_object *)userdata;
    lean_inc(fn); /* keep our borrow alive across the consuming apply */
    return lean_sdl_io_bool_or(
        lean_apply_2(fn, lean_sdl_decode_event(event), lean_box(0)), true);
}

/* Sdl.filterEvents (cb : Event -> IO Bool) : IO Unit -- C: SDL_FilterEvents. */
LEAN_EXPORT lean_obj_res lean_sdl_filter_events(lean_obj_arg fn, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_FilterEvents(lean_sdl_filter_events_tramp, fn);
    lean_dec(fn);
    return lean_sdl_unit_ok();
}
