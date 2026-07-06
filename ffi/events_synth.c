/* Test-only: fabricates each SDL_Event family for decode round-trip tests.
 * Linked into every exe via the static shim archive; a few hundred bytes of
 * dead weight outside the test executable.
 *
 * Each shim takes the same flattened scalars as the corresponding maker (minus
 * String/Array args), SDL_zero's an SDL_Event, assigns the fields, and pushes
 * it; a false SDL_PushEvent becomes an IO error. String-bearing families use
 * fixed static storage: SDL_PushEvent copies only the 128-byte union, so the C
 * pointers inside must outlive the later poll, which static storage guarantees.
 *
 * These are declared as `private opaque` externs inside test/Tests/Events.lean;
 * they are not part of the public API. */
#include "util.h"

/* Static string storage that must outlive the poll (see file header). */
static const char lean_sdl_synth_text[] = "sdl-lean synthetic";
static const char *const lean_sdl_synth_candidates[] = { "alpha", "beta" };
static const char lean_sdl_synth_drop_source[] = "synthetic-source";
static const char lean_sdl_synth_drop_data[] = "/tmp/synthetic.txt";
static const char *lean_sdl_synth_mime[] = { "text/plain", "text/html" };

/* ---- payloadless / common ---- */
LEAN_EXPORT lean_obj_res lean_sdl_test_push_common(uint32_t type, uint64_t ts, lean_obj_arg w) {
    (void)w; SDL_SHIM_PROLOGUE();
    SDL_Event ev; SDL_zero(ev);
    ev.type = type;
    ev.common.timestamp = ts;
    SDL_BOOL_TO_IO(SDL_PushEvent(&ev));
}

/* ---- display ---- */
LEAN_EXPORT lean_obj_res lean_sdl_test_push_display(
        uint32_t type, uint64_t ts, uint32_t display_id, int32_t data1,
        int32_t data2, lean_obj_arg w) {
    (void)w; SDL_SHIM_PROLOGUE();
    SDL_Event ev; SDL_zero(ev);
    ev.type = type;
    ev.display.timestamp = ts;
    ev.display.displayID = (SDL_DisplayID)display_id;
    ev.display.data1 = data1;
    ev.display.data2 = data2;
    SDL_BOOL_TO_IO(SDL_PushEvent(&ev));
}

/* ---- window ---- */
LEAN_EXPORT lean_obj_res lean_sdl_test_push_window(
        uint32_t type, uint64_t ts, uint32_t window_id, int32_t data1,
        int32_t data2, lean_obj_arg w) {
    (void)w; SDL_SHIM_PROLOGUE();
    SDL_Event ev; SDL_zero(ev);
    ev.type = type;
    ev.window.timestamp = ts;
    ev.window.windowID = (SDL_WindowID)window_id;
    ev.window.data1 = data1;
    ev.window.data2 = data2;
    SDL_BOOL_TO_IO(SDL_PushEvent(&ev));
}

/* ---- keyboard device ---- */
LEAN_EXPORT lean_obj_res lean_sdl_test_push_kdevice(
        uint32_t type, uint64_t ts, uint32_t which, lean_obj_arg w) {
    (void)w; SDL_SHIM_PROLOGUE();
    SDL_Event ev; SDL_zero(ev);
    ev.type = type;
    ev.kdevice.timestamp = ts;
    ev.kdevice.which = (SDL_KeyboardID)which;
    SDL_BOOL_TO_IO(SDL_PushEvent(&ev));
}

/* ---- key ---- */
LEAN_EXPORT lean_obj_res lean_sdl_test_push_key(
        uint32_t type, uint64_t ts, uint32_t window_id, uint32_t which,
        uint32_t scancode, uint32_t key, uint16_t mod, uint16_t raw,
        uint8_t down, uint8_t repeat, lean_obj_arg w) {
    (void)w; SDL_SHIM_PROLOGUE();
    SDL_Event ev; SDL_zero(ev);
    ev.type = type;
    ev.key.timestamp = ts;
    ev.key.windowID = (SDL_WindowID)window_id;
    ev.key.which = (SDL_KeyboardID)which;
    ev.key.scancode = (SDL_Scancode)scancode;
    ev.key.key = (SDL_Keycode)key;
    ev.key.mod = (SDL_Keymod)mod;
    ev.key.raw = raw;
    ev.key.down = down != 0;
    ev.key.repeat = repeat != 0;
    SDL_BOOL_TO_IO(SDL_PushEvent(&ev));
}

/* ---- text editing (static text) ---- */
LEAN_EXPORT lean_obj_res lean_sdl_test_push_text_editing(
        uint32_t type, uint64_t ts, uint32_t window_id, int32_t start,
        int32_t length, lean_obj_arg w) {
    (void)w; SDL_SHIM_PROLOGUE();
    SDL_Event ev; SDL_zero(ev);
    ev.type = type;
    ev.edit.timestamp = ts;
    ev.edit.windowID = (SDL_WindowID)window_id;
    ev.edit.text = lean_sdl_synth_text;
    ev.edit.start = start;
    ev.edit.length = length;
    SDL_BOOL_TO_IO(SDL_PushEvent(&ev));
}

/* ---- text editing candidates (static list "alpha","beta") ---- */
LEAN_EXPORT lean_obj_res lean_sdl_test_push_text_editing_candidates(
        uint32_t type, uint64_t ts, uint32_t window_id, int32_t selected,
        uint8_t horizontal, lean_obj_arg w) {
    (void)w; SDL_SHIM_PROLOGUE();
    SDL_Event ev; SDL_zero(ev);
    ev.type = type;
    ev.edit_candidates.timestamp = ts;
    ev.edit_candidates.windowID = (SDL_WindowID)window_id;
    ev.edit_candidates.candidates = lean_sdl_synth_candidates;
    ev.edit_candidates.num_candidates = 2;
    ev.edit_candidates.selected_candidate = selected;
    ev.edit_candidates.horizontal = horizontal != 0;
    SDL_BOOL_TO_IO(SDL_PushEvent(&ev));
}

/* ---- text input (static text) ---- */
LEAN_EXPORT lean_obj_res lean_sdl_test_push_text_input(
        uint32_t type, uint64_t ts, uint32_t window_id, lean_obj_arg w) {
    (void)w; SDL_SHIM_PROLOGUE();
    SDL_Event ev; SDL_zero(ev);
    ev.type = type;
    ev.text.timestamp = ts;
    ev.text.windowID = (SDL_WindowID)window_id;
    ev.text.text = lean_sdl_synth_text;
    SDL_BOOL_TO_IO(SDL_PushEvent(&ev));
}

/* ---- mouse device ---- */
LEAN_EXPORT lean_obj_res lean_sdl_test_push_mdevice(
        uint32_t type, uint64_t ts, uint32_t which, lean_obj_arg w) {
    (void)w; SDL_SHIM_PROLOGUE();
    SDL_Event ev; SDL_zero(ev);
    ev.type = type;
    ev.mdevice.timestamp = ts;
    ev.mdevice.which = (SDL_MouseID)which;
    SDL_BOOL_TO_IO(SDL_PushEvent(&ev));
}

/* ---- mouse motion ---- */
LEAN_EXPORT lean_obj_res lean_sdl_test_push_mouse_motion(
        uint32_t type, uint64_t ts, uint32_t window_id, uint32_t which,
        uint32_t state, float x, float y, float xrel, float yrel, lean_obj_arg w) {
    (void)w; SDL_SHIM_PROLOGUE();
    SDL_Event ev; SDL_zero(ev);
    ev.type = type;
    ev.motion.timestamp = ts;
    ev.motion.windowID = (SDL_WindowID)window_id;
    ev.motion.which = (SDL_MouseID)which;
    ev.motion.state = (SDL_MouseButtonFlags)state;
    ev.motion.x = x; ev.motion.y = y;
    ev.motion.xrel = xrel; ev.motion.yrel = yrel;
    SDL_BOOL_TO_IO(SDL_PushEvent(&ev));
}

/* ---- mouse button ---- */
LEAN_EXPORT lean_obj_res lean_sdl_test_push_mouse_button(
        uint32_t type, uint64_t ts, uint32_t window_id, uint32_t which,
        uint8_t button, uint8_t down, uint8_t clicks, float x, float y,
        lean_obj_arg w) {
    (void)w; SDL_SHIM_PROLOGUE();
    SDL_Event ev; SDL_zero(ev);
    ev.type = type;
    ev.button.timestamp = ts;
    ev.button.windowID = (SDL_WindowID)window_id;
    ev.button.which = (SDL_MouseID)which;
    ev.button.button = button;
    ev.button.down = down != 0;
    ev.button.clicks = clicks;
    ev.button.x = x; ev.button.y = y;
    SDL_BOOL_TO_IO(SDL_PushEvent(&ev));
}

/* ---- mouse wheel ---- */
LEAN_EXPORT lean_obj_res lean_sdl_test_push_mouse_wheel(
        uint32_t type, uint64_t ts, uint32_t window_id, uint32_t which,
        float x, float y, uint32_t direction, float mouse_x, float mouse_y,
        int32_t integer_x, int32_t integer_y, lean_obj_arg w) {
    (void)w; SDL_SHIM_PROLOGUE();
    SDL_Event ev; SDL_zero(ev);
    ev.type = type;
    ev.wheel.timestamp = ts;
    ev.wheel.windowID = (SDL_WindowID)window_id;
    ev.wheel.which = (SDL_MouseID)which;
    ev.wheel.x = x; ev.wheel.y = y;
    ev.wheel.direction = (SDL_MouseWheelDirection)direction;
    ev.wheel.mouse_x = mouse_x; ev.wheel.mouse_y = mouse_y;
    ev.wheel.integer_x = integer_x; ev.wheel.integer_y = integer_y;
    SDL_BOOL_TO_IO(SDL_PushEvent(&ev));
}

/* ---- joystick device ---- */
LEAN_EXPORT lean_obj_res lean_sdl_test_push_jdevice(
        uint32_t type, uint64_t ts, uint32_t which, lean_obj_arg w) {
    (void)w; SDL_SHIM_PROLOGUE();
    SDL_Event ev; SDL_zero(ev);
    ev.type = type;
    ev.jdevice.timestamp = ts;
    ev.jdevice.which = (SDL_JoystickID)which;
    SDL_BOOL_TO_IO(SDL_PushEvent(&ev));
}

/* ---- joystick axis ---- */
LEAN_EXPORT lean_obj_res lean_sdl_test_push_jaxis(
        uint32_t type, uint64_t ts, uint32_t which, uint8_t axis, int16_t value,
        lean_obj_arg w) {
    (void)w; SDL_SHIM_PROLOGUE();
    SDL_Event ev; SDL_zero(ev);
    ev.type = type;
    ev.jaxis.timestamp = ts;
    ev.jaxis.which = (SDL_JoystickID)which;
    ev.jaxis.axis = axis;
    ev.jaxis.value = value;
    SDL_BOOL_TO_IO(SDL_PushEvent(&ev));
}

/* ---- joystick ball ---- */
LEAN_EXPORT lean_obj_res lean_sdl_test_push_jball(
        uint32_t type, uint64_t ts, uint32_t which, uint8_t ball,
        int16_t xrel, int16_t yrel, lean_obj_arg w) {
    (void)w; SDL_SHIM_PROLOGUE();
    SDL_Event ev; SDL_zero(ev);
    ev.type = type;
    ev.jball.timestamp = ts;
    ev.jball.which = (SDL_JoystickID)which;
    ev.jball.ball = ball;
    ev.jball.xrel = xrel; ev.jball.yrel = yrel;
    SDL_BOOL_TO_IO(SDL_PushEvent(&ev));
}

/* ---- joystick hat ---- */
LEAN_EXPORT lean_obj_res lean_sdl_test_push_jhat(
        uint32_t type, uint64_t ts, uint32_t which, uint8_t hat, uint8_t value,
        lean_obj_arg w) {
    (void)w; SDL_SHIM_PROLOGUE();
    SDL_Event ev; SDL_zero(ev);
    ev.type = type;
    ev.jhat.timestamp = ts;
    ev.jhat.which = (SDL_JoystickID)which;
    ev.jhat.hat = hat;
    ev.jhat.value = value;
    SDL_BOOL_TO_IO(SDL_PushEvent(&ev));
}

/* ---- joystick button ---- */
LEAN_EXPORT lean_obj_res lean_sdl_test_push_jbutton(
        uint32_t type, uint64_t ts, uint32_t which, uint8_t button, uint8_t down,
        lean_obj_arg w) {
    (void)w; SDL_SHIM_PROLOGUE();
    SDL_Event ev; SDL_zero(ev);
    ev.type = type;
    ev.jbutton.timestamp = ts;
    ev.jbutton.which = (SDL_JoystickID)which;
    ev.jbutton.button = button;
    ev.jbutton.down = down != 0;
    SDL_BOOL_TO_IO(SDL_PushEvent(&ev));
}

/* ---- joystick battery ---- */
LEAN_EXPORT lean_obj_res lean_sdl_test_push_jbattery(
        uint32_t type, uint64_t ts, uint32_t which, int32_t state,
        int32_t percent, lean_obj_arg w) {
    (void)w; SDL_SHIM_PROLOGUE();
    SDL_Event ev; SDL_zero(ev);
    ev.type = type;
    ev.jbattery.timestamp = ts;
    ev.jbattery.which = (SDL_JoystickID)which;
    ev.jbattery.state = (SDL_PowerState)state;
    ev.jbattery.percent = percent;
    SDL_BOOL_TO_IO(SDL_PushEvent(&ev));
}

/* ---- gamepad device ---- */
LEAN_EXPORT lean_obj_res lean_sdl_test_push_gdevice(
        uint32_t type, uint64_t ts, uint32_t which, lean_obj_arg w) {
    (void)w; SDL_SHIM_PROLOGUE();
    SDL_Event ev; SDL_zero(ev);
    ev.type = type;
    ev.gdevice.timestamp = ts;
    ev.gdevice.which = (SDL_JoystickID)which;
    SDL_BOOL_TO_IO(SDL_PushEvent(&ev));
}

/* ---- gamepad axis ---- */
LEAN_EXPORT lean_obj_res lean_sdl_test_push_gaxis(
        uint32_t type, uint64_t ts, uint32_t which, uint8_t axis, int16_t value,
        lean_obj_arg w) {
    (void)w; SDL_SHIM_PROLOGUE();
    SDL_Event ev; SDL_zero(ev);
    ev.type = type;
    ev.gaxis.timestamp = ts;
    ev.gaxis.which = (SDL_JoystickID)which;
    ev.gaxis.axis = axis;
    ev.gaxis.value = value;
    SDL_BOOL_TO_IO(SDL_PushEvent(&ev));
}

/* ---- gamepad button ---- */
LEAN_EXPORT lean_obj_res lean_sdl_test_push_gbutton(
        uint32_t type, uint64_t ts, uint32_t which, uint8_t button, uint8_t down,
        lean_obj_arg w) {
    (void)w; SDL_SHIM_PROLOGUE();
    SDL_Event ev; SDL_zero(ev);
    ev.type = type;
    ev.gbutton.timestamp = ts;
    ev.gbutton.which = (SDL_JoystickID)which;
    ev.gbutton.button = button;
    ev.gbutton.down = down != 0;
    SDL_BOOL_TO_IO(SDL_PushEvent(&ev));
}

/* ---- gamepad touchpad ---- */
LEAN_EXPORT lean_obj_res lean_sdl_test_push_gtouchpad(
        uint32_t type, uint64_t ts, uint32_t which, int32_t touchpad,
        int32_t finger, float x, float y, float pressure, lean_obj_arg w) {
    (void)w; SDL_SHIM_PROLOGUE();
    SDL_Event ev; SDL_zero(ev);
    ev.type = type;
    ev.gtouchpad.timestamp = ts;
    ev.gtouchpad.which = (SDL_JoystickID)which;
    ev.gtouchpad.touchpad = touchpad;
    ev.gtouchpad.finger = finger;
    ev.gtouchpad.x = x; ev.gtouchpad.y = y; ev.gtouchpad.pressure = pressure;
    SDL_BOOL_TO_IO(SDL_PushEvent(&ev));
}

/* ---- gamepad sensor ---- */
LEAN_EXPORT lean_obj_res lean_sdl_test_push_gsensor(
        uint32_t type, uint64_t ts, uint32_t which, int32_t sensor,
        float d0, float d1, float d2, uint64_t sensor_ts, lean_obj_arg w) {
    (void)w; SDL_SHIM_PROLOGUE();
    SDL_Event ev; SDL_zero(ev);
    ev.type = type;
    ev.gsensor.timestamp = ts;
    ev.gsensor.which = (SDL_JoystickID)which;
    ev.gsensor.sensor = sensor;
    ev.gsensor.data[0] = d0; ev.gsensor.data[1] = d1; ev.gsensor.data[2] = d2;
    ev.gsensor.sensor_timestamp = sensor_ts;
    SDL_BOOL_TO_IO(SDL_PushEvent(&ev));
}

/* ---- audio device ---- */
LEAN_EXPORT lean_obj_res lean_sdl_test_push_adevice(
        uint32_t type, uint64_t ts, uint32_t which, uint8_t recording,
        lean_obj_arg w) {
    (void)w; SDL_SHIM_PROLOGUE();
    SDL_Event ev; SDL_zero(ev);
    ev.type = type;
    ev.adevice.timestamp = ts;
    ev.adevice.which = (SDL_AudioDeviceID)which;
    ev.adevice.recording = recording != 0;
    SDL_BOOL_TO_IO(SDL_PushEvent(&ev));
}

/* ---- camera device ---- */
LEAN_EXPORT lean_obj_res lean_sdl_test_push_cdevice(
        uint32_t type, uint64_t ts, uint32_t which, lean_obj_arg w) {
    (void)w; SDL_SHIM_PROLOGUE();
    SDL_Event ev; SDL_zero(ev);
    ev.type = type;
    ev.cdevice.timestamp = ts;
    ev.cdevice.which = (SDL_CameraID)which;
    SDL_BOOL_TO_IO(SDL_PushEvent(&ev));
}

/* ---- sensor ---- */
LEAN_EXPORT lean_obj_res lean_sdl_test_push_sensor(
        uint32_t type, uint64_t ts, uint32_t which,
        float d0, float d1, float d2, float d3, float d4, float d5,
        uint64_t sensor_ts, lean_obj_arg w) {
    (void)w; SDL_SHIM_PROLOGUE();
    SDL_Event ev; SDL_zero(ev);
    ev.type = type;
    ev.sensor.timestamp = ts;
    ev.sensor.which = (SDL_SensorID)which;
    ev.sensor.data[0] = d0; ev.sensor.data[1] = d1; ev.sensor.data[2] = d2;
    ev.sensor.data[3] = d3; ev.sensor.data[4] = d4; ev.sensor.data[5] = d5;
    ev.sensor.sensor_timestamp = sensor_ts;
    SDL_BOOL_TO_IO(SDL_PushEvent(&ev));
}

/* ---- touch finger ---- */
LEAN_EXPORT lean_obj_res lean_sdl_test_push_tfinger(
        uint32_t type, uint64_t ts, uint64_t touch_id, uint64_t finger_id,
        float x, float y, float dx, float dy, float pressure,
        uint32_t window_id, lean_obj_arg w) {
    (void)w; SDL_SHIM_PROLOGUE();
    SDL_Event ev; SDL_zero(ev);
    ev.type = type;
    ev.tfinger.timestamp = ts;
    ev.tfinger.touchID = (SDL_TouchID)touch_id;
    ev.tfinger.fingerID = (SDL_FingerID)finger_id;
    ev.tfinger.x = x; ev.tfinger.y = y;
    ev.tfinger.dx = dx; ev.tfinger.dy = dy;
    ev.tfinger.pressure = pressure;
    ev.tfinger.windowID = (SDL_WindowID)window_id;
    SDL_BOOL_TO_IO(SDL_PushEvent(&ev));
}

/* ---- pinch ---- */
LEAN_EXPORT lean_obj_res lean_sdl_test_push_pinch(
        uint32_t type, uint64_t ts, float scale, uint32_t window_id, lean_obj_arg w) {
    (void)w; SDL_SHIM_PROLOGUE();
    SDL_Event ev; SDL_zero(ev);
    ev.type = type;
    ev.pinch.timestamp = ts;
    ev.pinch.scale = scale;
    ev.pinch.windowID = (SDL_WindowID)window_id;
    SDL_BOOL_TO_IO(SDL_PushEvent(&ev));
}

/* ---- pen proximity ---- */
LEAN_EXPORT lean_obj_res lean_sdl_test_push_pproximity(
        uint32_t type, uint64_t ts, uint32_t window_id, uint32_t which,
        lean_obj_arg w) {
    (void)w; SDL_SHIM_PROLOGUE();
    SDL_Event ev; SDL_zero(ev);
    ev.type = type;
    ev.pproximity.timestamp = ts;
    ev.pproximity.windowID = (SDL_WindowID)window_id;
    ev.pproximity.which = (SDL_PenID)which;
    SDL_BOOL_TO_IO(SDL_PushEvent(&ev));
}

/* ---- pen motion ---- */
LEAN_EXPORT lean_obj_res lean_sdl_test_push_pmotion(
        uint32_t type, uint64_t ts, uint32_t window_id, uint32_t which,
        uint32_t pen_state, float x, float y, lean_obj_arg w) {
    (void)w; SDL_SHIM_PROLOGUE();
    SDL_Event ev; SDL_zero(ev);
    ev.type = type;
    ev.pmotion.timestamp = ts;
    ev.pmotion.windowID = (SDL_WindowID)window_id;
    ev.pmotion.which = (SDL_PenID)which;
    ev.pmotion.pen_state = (SDL_PenInputFlags)pen_state;
    ev.pmotion.x = x; ev.pmotion.y = y;
    SDL_BOOL_TO_IO(SDL_PushEvent(&ev));
}

/* ---- pen touch ---- */
LEAN_EXPORT lean_obj_res lean_sdl_test_push_ptouch(
        uint32_t type, uint64_t ts, uint32_t window_id, uint32_t which,
        uint32_t pen_state, float x, float y, uint8_t eraser, uint8_t down,
        lean_obj_arg w) {
    (void)w; SDL_SHIM_PROLOGUE();
    SDL_Event ev; SDL_zero(ev);
    ev.type = type;
    ev.ptouch.timestamp = ts;
    ev.ptouch.windowID = (SDL_WindowID)window_id;
    ev.ptouch.which = (SDL_PenID)which;
    ev.ptouch.pen_state = (SDL_PenInputFlags)pen_state;
    ev.ptouch.x = x; ev.ptouch.y = y;
    ev.ptouch.eraser = eraser != 0;
    ev.ptouch.down = down != 0;
    SDL_BOOL_TO_IO(SDL_PushEvent(&ev));
}

/* ---- pen button ---- */
LEAN_EXPORT lean_obj_res lean_sdl_test_push_pbutton(
        uint32_t type, uint64_t ts, uint32_t window_id, uint32_t which,
        uint32_t pen_state, float x, float y, uint8_t button, uint8_t down,
        lean_obj_arg w) {
    (void)w; SDL_SHIM_PROLOGUE();
    SDL_Event ev; SDL_zero(ev);
    ev.type = type;
    ev.pbutton.timestamp = ts;
    ev.pbutton.windowID = (SDL_WindowID)window_id;
    ev.pbutton.which = (SDL_PenID)which;
    ev.pbutton.pen_state = (SDL_PenInputFlags)pen_state;
    ev.pbutton.x = x; ev.pbutton.y = y;
    ev.pbutton.button = button;
    ev.pbutton.down = down != 0;
    SDL_BOOL_TO_IO(SDL_PushEvent(&ev));
}

/* ---- pen axis ---- */
LEAN_EXPORT lean_obj_res lean_sdl_test_push_paxis(
        uint32_t type, uint64_t ts, uint32_t window_id, uint32_t which,
        uint32_t pen_state, float x, float y, uint32_t axis, float value,
        lean_obj_arg w) {
    (void)w; SDL_SHIM_PROLOGUE();
    SDL_Event ev; SDL_zero(ev);
    ev.type = type;
    ev.paxis.timestamp = ts;
    ev.paxis.windowID = (SDL_WindowID)window_id;
    ev.paxis.which = (SDL_PenID)which;
    ev.paxis.pen_state = (SDL_PenInputFlags)pen_state;
    ev.paxis.x = x; ev.paxis.y = y;
    ev.paxis.axis = (SDL_PenAxis)axis;
    ev.paxis.value = value;
    SDL_BOOL_TO_IO(SDL_PushEvent(&ev));
}

/* ---- render ---- */
LEAN_EXPORT lean_obj_res lean_sdl_test_push_render(
        uint32_t type, uint64_t ts, uint32_t window_id, lean_obj_arg w) {
    (void)w; SDL_SHIM_PROLOGUE();
    SDL_Event ev; SDL_zero(ev);
    ev.type = type;
    ev.render.timestamp = ts;
    ev.render.windowID = (SDL_WindowID)window_id;
    SDL_BOOL_TO_IO(SDL_PushEvent(&ev));
}

/* ---- drop (has_strings=0 exercises the Option-none path) ---- */
LEAN_EXPORT lean_obj_res lean_sdl_test_push_drop(
        uint32_t type, uint64_t ts, uint32_t window_id, float x, float y,
        uint8_t has_strings, lean_obj_arg w) {
    (void)w; SDL_SHIM_PROLOGUE();
    SDL_Event ev; SDL_zero(ev);
    ev.type = type;
    ev.drop.timestamp = ts;
    ev.drop.windowID = (SDL_WindowID)window_id;
    ev.drop.x = x; ev.drop.y = y;
    if (has_strings) {
        ev.drop.source = lean_sdl_synth_drop_source;
        ev.drop.data = lean_sdl_synth_drop_data;
    } else {
        ev.drop.source = NULL;
        ev.drop.data = NULL;
    }
    SDL_BOOL_TO_IO(SDL_PushEvent(&ev));
}

/* ---- clipboard (static mime list) ---- */
LEAN_EXPORT lean_obj_res lean_sdl_test_push_clipboard(
        uint32_t type, uint64_t ts, uint8_t owner, lean_obj_arg w) {
    (void)w; SDL_SHIM_PROLOGUE();
    SDL_Event ev; SDL_zero(ev);
    ev.type = type;
    ev.clipboard.timestamp = ts;
    ev.clipboard.owner = owner != 0;
    ev.clipboard.mime_types = lean_sdl_synth_mime;
    ev.clipboard.num_mime_types = 2;
    SDL_BOOL_TO_IO(SDL_PushEvent(&ev));
}
