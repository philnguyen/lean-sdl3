/* Shims for Sdl/Gamepad.lean (SDL_gamepad.h).
 *
 * One external class over the Lean `Gamepad` type: an OWNED ROOT whose
 * finalizer runs SDL_CloseGamepad and whose holder owner is always NULL.
 * Gamepad.close is a manual destroy that NULLs the holder ptr. SDL refcounts
 * gamepads internally, so every handle the binding hands out took its own
 * SDL_OpenGamepad reference and independent handles never alias each other's
 * lifetime; getGamepadFromID / getGamepadFromPlayerIndex re-open (ref-bump)
 * and wrap the fresh reference.
 *
 * Gamepad.getJoystick hands out a `Joystick` (lean_sdl_joystick_class from
 * classes.h): SDL_GetGamepadJoystick returns a borrowed pointer owned by the
 * gamepad, so we take our own reference via SDL_OpenJoystick(id) and wrap that
 * — it safely outlives the gamepad.
 *
 * JoystickId is a plain Uint32 on the Lean side; its *ForID shims take the raw
 * id. GamepadType / GamepadButton / GamepadAxis / GamepadButtonLabel cross the
 * boundary as their raw scalar (UInt32 / UInt8); the Lean wrapper decodes them.
 * Int16 axis values cross as uint16_t bits (DESIGN.md ABI note).
 * SDL_GamepadBinding (a tagged union of unions) is flattened per element into
 * scalars and rebuilt into GamepadBinding by the @[export]ed Lean maker
 * lean_sdl_mk_gamepad_binding. */
#include "util.h"
#include "classes.h"

/* Owned root: finalizer closes the gamepad. No cross-module consumer, so the
 * class pointer is defined locally (non-static per SDL_DEFINE_CLASS). */
SDL_DEFINE_CLASS(lean_sdl_gamepad, SDL_CloseGamepad((SDL_Gamepad *)self))

static lean_object *lean_sdl_wrap_gamepad(SDL_Gamepad *g) {
    return lean_sdl_wrap(lean_sdl_gamepad_class, g, NULL);
}

/* Build a `(a, b)` Lean pair (Prod). Consumes ownership of a and b. */
static lean_object *lean_sdl_pair(lean_object *a, lean_object *b) {
    lean_object *o = lean_alloc_ctor(0, 2, 0);
    lean_ctor_set(o, 0, a);
    lean_ctor_set(o, 1, b);
    return o;
}

/* A 16-byte SDL_GUID -> ByteArray. */
static lean_object *lean_sdl_guid_bytes(SDL_GUID guid) {
    lean_object *arr = lean_alloc_sarray(1, sizeof(guid.data), sizeof(guid.data));
    SDL_memcpy(lean_sarray_cptr(arr), guid.data, sizeof(guid.data));
    return arr;
}

/* @[export]ed pure Lean maker: rebuild GamepadBinding from flattened scalars.
 * ABI: Lean's generated C uses uint32_t for Int32 params; the signed intN_t
 * here has identical width/registers and preserves the bits. */
extern lean_object *lean_sdl_mk_gamepad_binding(
    uint32_t in_type, int32_t in_a, int32_t in_b, int32_t in_c,
    uint32_t out_type, uint32_t out_button_or_axis, int32_t out_min, int32_t out_max);

/* Register the class. Called from Sdl/Gamepad.lean's `initialize`. */
LEAN_EXPORT lean_obj_res lean_sdl_gamepad_register_classes(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    lean_sdl_gamepad_class_init();
    return lean_sdl_unit_ok();
}

/* ==================== Top-level functions ==================== */

/* Sdl.addGamepadMapping (mapping : @& String) : IO Bool
 * -- C: SDL_AddGamepadMapping (1 -> true/new, 0 -> false/updated, -1 -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_add_gamepad_mapping(b_lean_obj_arg mapping, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    int r = SDL_AddGamepadMapping(lean_string_cstr(mapping));
    if (r < 0) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_box(r == 1));
}

/* Sdl.addGamepadMappingsFromIORaw (src : @& IOStream) : IO Int32
 * -- C: SDL_AddGamepadMappingsFromIO with closeio = false (Lean owns the
 * stream); -1 -> throw. */
LEAN_EXPORT lean_obj_res lean_sdl_add_gamepad_mappings_from_io(b_lean_obj_arg src, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_IOStream, io, src);
    int n = SDL_AddGamepadMappingsFromIO(io, false);
    if (n < 0) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)n));
}

/* Sdl.addGamepadMappingsFromFile (path : @& String) : IO Int32
 * -- C: SDL_AddGamepadMappingsFromFile (-1 -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_add_gamepad_mappings_from_file(b_lean_obj_arg path, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    int n = SDL_AddGamepadMappingsFromFile(lean_string_cstr(path));
    if (n < 0) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)n));
}

/* Sdl.reloadGamepadMappings : IO Unit -- C: SDL_ReloadGamepadMappings (false ->
 * throw). */
LEAN_EXPORT lean_obj_res lean_sdl_reload_gamepad_mappings(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_BOOL_TO_IO(SDL_ReloadGamepadMappings());
}

/* Sdl.getGamepadMappings : IO (Array String)
 * -- C: SDL_GetGamepadMappings (NULL -> throw; single allocation freed once
 * after copying the strings). */
LEAN_EXPORT lean_obj_res lean_sdl_get_gamepad_mappings(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    int count = 0;
    char **maps = SDL_GetGamepadMappings(&count);
    if (!maps) return lean_sdl_throw();
    size_t n = count > 0 ? (size_t)count : 0;
    lean_object *arr = lean_alloc_array(n, n);
    for (size_t i = 0; i < n; i++)
        lean_array_set_core(arr, i, lean_sdl_mk_string(maps[i]));
    SDL_free(maps);
    return lean_io_result_mk_ok(arr);
}

/* Sdl.getGamepadMappingForGUIDRaw (guid : @& ByteArray) : IO String
 * -- C: SDL_GetGamepadMappingForGUID (NULL -> throw; SDL_free after copy). */
LEAN_EXPORT lean_obj_res lean_sdl_get_gamepad_mapping_for_guid(b_lean_obj_arg bytes, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GUID guid;
    SDL_zero(guid);
    size_t sz = lean_sarray_size(bytes);
    size_t k = sz < sizeof(guid.data) ? sz : sizeof(guid.data);
    SDL_memcpy(guid.data, lean_sarray_cptr((lean_object *)bytes), k);
    char *s = SDL_GetGamepadMappingForGUID(guid);
    if (!s) return lean_sdl_throw();
    lean_object *str = lean_mk_string(s);
    SDL_free(s);
    return lean_io_result_mk_ok(str);
}

/* Sdl.setGamepadMappingRaw (id : UInt32) (mapping : @& Option String) : IO Unit
 * -- C: SDL_SetGamepadMapping (none -> NULL resets to default; false -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_set_gamepad_mapping(
        uint32_t id, b_lean_obj_arg mapping, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    const char *m = lean_is_scalar(mapping) ? NULL : lean_string_cstr(lean_ctor_get(mapping, 0));
    SDL_BOOL_TO_IO(SDL_SetGamepadMapping((SDL_JoystickID)id, m));
}

/* Sdl.hasGamepad : IO Bool -- C: SDL_HasGamepad. */
LEAN_EXPORT lean_obj_res lean_sdl_has_gamepad(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(lean_box(SDL_HasGamepad()));
}

/* Sdl.getGamepadsRaw : IO (Array UInt32)
 * -- C: SDL_GetGamepads (NULL -> throw; SDL_free after copy). */
LEAN_EXPORT lean_obj_res lean_sdl_get_gamepads(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    int count = 0;
    SDL_JoystickID *ids = SDL_GetGamepads(&count);
    if (!ids) return lean_sdl_throw();
    size_t n = count > 0 ? (size_t)count : 0;
    lean_object *arr = lean_alloc_array(n, n);
    for (size_t i = 0; i < n; i++)
        lean_array_set_core(arr, i, lean_box_uint32((uint32_t)ids[i]));
    SDL_free(ids);
    return lean_io_result_mk_ok(arr);
}

/* Sdl.isGamepadRaw (id : UInt32) : IO Bool -- C: SDL_IsGamepad. */
LEAN_EXPORT lean_obj_res lean_sdl_is_gamepad(uint32_t id, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(lean_box(SDL_IsGamepad((SDL_JoystickID)id)));
}

/* Sdl.openGamepadRaw (id : UInt32) : IO Gamepad -- C: SDL_OpenGamepad (NULL ->
 * throw). */
LEAN_EXPORT lean_obj_res lean_sdl_open_gamepad(uint32_t id, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_Gamepad *g = SDL_OpenGamepad((SDL_JoystickID)id);
    if (!g) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_wrap_gamepad(g));
}

/* Sdl.getGamepadFromIDRaw (id : UInt32) : IO (Option Gamepad)
 * -- C: SDL_GetGamepadFromID. NULL -> none; otherwise re-open (ref-bump) and
 * wrap that fresh, independently-owned reference. */
LEAN_EXPORT lean_obj_res lean_sdl_get_gamepad_from_id(uint32_t id, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_Gamepad *g = SDL_GetGamepadFromID((SDL_JoystickID)id);
    if (!g) return lean_io_result_mk_ok(lean_sdl_none());
    SDL_Gamepad *g2 = SDL_OpenGamepad(SDL_GetGamepadID(g));
    if (!g2) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_some(lean_sdl_wrap_gamepad(g2)));
}

/* Sdl.getGamepadFromPlayerIndexRaw (idx : Int32) : IO (Option Gamepad)
 * -- C: SDL_GetGamepadFromPlayerIndex. NULL -> none; otherwise re-open
 * (ref-bump) and wrap that fresh, independently-owned reference. */
LEAN_EXPORT lean_obj_res lean_sdl_get_gamepad_from_player_index(int32_t idx, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_Gamepad *g = SDL_GetGamepadFromPlayerIndex((int)idx);
    if (!g) return lean_io_result_mk_ok(lean_sdl_none());
    SDL_Gamepad *g2 = SDL_OpenGamepad(SDL_GetGamepadID(g));
    if (!g2) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_some(lean_sdl_wrap_gamepad(g2)));
}

/* Sdl.setGamepadEventsEnabled (enabled : Bool) : IO Unit
 * -- C: SDL_SetGamepadEventsEnabled (void). */
LEAN_EXPORT lean_obj_res lean_sdl_set_gamepad_events_enabled(uint8_t enabled, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_SetGamepadEventsEnabled((bool)enabled);
    return lean_sdl_unit_ok();
}

/* Sdl.gamepadEventsEnabled : IO Bool -- C: SDL_GamepadEventsEnabled. */
LEAN_EXPORT lean_obj_res lean_sdl_gamepad_events_enabled(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(lean_box(SDL_GamepadEventsEnabled()));
}

/* Sdl.updateGamepads : IO Unit -- C: SDL_UpdateGamepads (void). */
LEAN_EXPORT lean_obj_res lean_sdl_update_gamepads(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_UpdateGamepads();
    return lean_sdl_unit_ok();
}

/* Sdl.getGamepadTypeFromStringRaw (s : @& String) : IO UInt32
 * -- C: SDL_GetGamepadTypeFromString (UNKNOWN if no match; decoded in Lean). */
LEAN_EXPORT lean_obj_res lean_sdl_get_gamepad_type_from_string(b_lean_obj_arg s, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(
        lean_box_uint32((uint32_t)SDL_GetGamepadTypeFromString(lean_string_cstr(s))));
}

/* Sdl.getGamepadStringForTypeRaw (type : UInt32) : IO (Option String)
 * -- C: SDL_GetGamepadStringForType (NULL -> none). */
LEAN_EXPORT lean_obj_res lean_sdl_get_gamepad_string_for_type(uint32_t type, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(
        lean_sdl_option_string(SDL_GetGamepadStringForType((SDL_GamepadType)type)));
}

/* Sdl.getGamepadAxisFromStringRaw (s : @& String) : IO Int32
 * -- C: SDL_GetGamepadAxisFromString (INVALID = -1; Lean maps to none). */
LEAN_EXPORT lean_obj_res lean_sdl_get_gamepad_axis_from_string(b_lean_obj_arg s, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(
        lean_box_uint32((uint32_t)SDL_GetGamepadAxisFromString(lean_string_cstr(s))));
}

/* Sdl.getGamepadStringForAxisRaw (axis : UInt8) : IO (Option String)
 * -- C: SDL_GetGamepadStringForAxis (NULL -> none). */
LEAN_EXPORT lean_obj_res lean_sdl_get_gamepad_string_for_axis(uint8_t axis, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(
        lean_sdl_option_string(SDL_GetGamepadStringForAxis((SDL_GamepadAxis)axis)));
}

/* Sdl.getGamepadButtonFromStringRaw (s : @& String) : IO Int32
 * -- C: SDL_GetGamepadButtonFromString (INVALID = -1; Lean maps to none). */
LEAN_EXPORT lean_obj_res lean_sdl_get_gamepad_button_from_string(b_lean_obj_arg s, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(
        lean_box_uint32((uint32_t)SDL_GetGamepadButtonFromString(lean_string_cstr(s))));
}

/* Sdl.getGamepadStringForButtonRaw (button : UInt8) : IO (Option String)
 * -- C: SDL_GetGamepadStringForButton (NULL -> none). */
LEAN_EXPORT lean_obj_res lean_sdl_get_gamepad_string_for_button(uint8_t button, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(
        lean_sdl_option_string(SDL_GetGamepadStringForButton((SDL_GamepadButton)button)));
}

/* Sdl.getGamepadButtonLabelForTypeRaw (type : UInt32) (button : UInt8) : IO UInt32
 * -- C: SDL_GetGamepadButtonLabelForType (decoded in Lean). */
LEAN_EXPORT lean_obj_res lean_sdl_get_gamepad_button_label_for_type(
        uint32_t type, uint8_t button, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(lean_box_uint32(
        (uint32_t)SDL_GetGamepadButtonLabelForType((SDL_GamepadType)type, (SDL_GamepadButton)button)));
}

/* ==================== JoystickId (*ForID) methods ==================== */

/* Sdl.JoystickId.gamepadNameRaw (id : UInt32) : IO String
 * -- C: SDL_GetGamepadNameForID (NULL -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_get_gamepad_name_for_id(uint32_t id, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    const char *s = SDL_GetGamepadNameForID((SDL_JoystickID)id);
    if (!s) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_mk_string(s));
}

/* Sdl.JoystickId.gamepadPathRaw (id : UInt32) : IO (Option String)
 * -- C: SDL_GetGamepadPathForID (NULL -> none). */
LEAN_EXPORT lean_obj_res lean_sdl_get_gamepad_path_for_id(uint32_t id, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(lean_sdl_option_string(SDL_GetGamepadPathForID((SDL_JoystickID)id)));
}

/* Sdl.JoystickId.gamepadPlayerIndexRaw (id : UInt32) : IO Int32
 * -- C: SDL_GetGamepadPlayerIndexForID (-1 = unavailable; Lean maps to none). */
LEAN_EXPORT lean_obj_res lean_sdl_get_gamepad_player_index_for_id(uint32_t id, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(
        lean_box_uint32((uint32_t)SDL_GetGamepadPlayerIndexForID((SDL_JoystickID)id)));
}

/* Sdl.JoystickId.gamepadGuidRaw (id : UInt32) : IO ByteArray
 * -- C: SDL_GetGamepadGUIDForID (zero GUID if invalid). */
LEAN_EXPORT lean_obj_res lean_sdl_get_gamepad_guid_for_id(uint32_t id, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(lean_sdl_guid_bytes(SDL_GetGamepadGUIDForID((SDL_JoystickID)id)));
}

/* Sdl.JoystickId.gamepadVendorRaw (id : UInt32) : IO UInt16
 * -- C: SDL_GetGamepadVendorForID (0 = unavailable). */
LEAN_EXPORT lean_obj_res lean_sdl_get_gamepad_vendor_for_id(uint32_t id, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(lean_box((uint16_t)SDL_GetGamepadVendorForID((SDL_JoystickID)id)));
}

/* Sdl.JoystickId.gamepadProductRaw (id : UInt32) : IO UInt16
 * -- C: SDL_GetGamepadProductForID (0 = unavailable). */
LEAN_EXPORT lean_obj_res lean_sdl_get_gamepad_product_for_id(uint32_t id, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(lean_box((uint16_t)SDL_GetGamepadProductForID((SDL_JoystickID)id)));
}

/* Sdl.JoystickId.gamepadProductVersionRaw (id : UInt32) : IO UInt16
 * -- C: SDL_GetGamepadProductVersionForID (0 = unavailable). */
LEAN_EXPORT lean_obj_res lean_sdl_get_gamepad_product_version_for_id(uint32_t id, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(
        lean_box((uint16_t)SDL_GetGamepadProductVersionForID((SDL_JoystickID)id)));
}

/* Sdl.JoystickId.gamepadTypeRaw (id : UInt32) : IO UInt32
 * -- C: SDL_GetGamepadTypeForID (decoded in Lean). */
LEAN_EXPORT lean_obj_res lean_sdl_get_gamepad_type_for_id(uint32_t id, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(
        lean_box_uint32((uint32_t)SDL_GetGamepadTypeForID((SDL_JoystickID)id)));
}

/* Sdl.JoystickId.realGamepadTypeRaw (id : UInt32) : IO UInt32
 * -- C: SDL_GetRealGamepadTypeForID (decoded in Lean). */
LEAN_EXPORT lean_obj_res lean_sdl_get_real_gamepad_type_for_id(uint32_t id, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(
        lean_box_uint32((uint32_t)SDL_GetRealGamepadTypeForID((SDL_JoystickID)id)));
}

/* Sdl.JoystickId.gamepadMappingRaw (id : UInt32) : IO (Option String)
 * -- C: SDL_GetGamepadMappingForID (NULL -> none; SDL_free after copy). */
LEAN_EXPORT lean_obj_res lean_sdl_get_gamepad_mapping_for_id(uint32_t id, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    char *s = SDL_GetGamepadMappingForID((SDL_JoystickID)id);
    if (!s) return lean_io_result_mk_ok(lean_sdl_none());
    lean_object *str = lean_mk_string(s);
    SDL_free(s);
    return lean_io_result_mk_ok(lean_sdl_some(str));
}

/* ==================== Gamepad methods ==================== */

/* Sdl.Gamepad.close : IO Unit -- C: SDL_CloseGamepad (manual destroy; NULL the
 * ptr). */
LEAN_EXPORT lean_obj_res lean_sdl_close_gamepad(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    sdl_holder *h = lean_sdl_holder_of(self);
    if (!h->ptr) return lean_sdl_throw_msg("SDL: handle used after destroy/release");
    SDL_CloseGamepad((SDL_Gamepad *)h->ptr);
    h->ptr = NULL;
    return lean_sdl_unit_ok();
}

/* Sdl.Gamepad.getProperties : IO Properties -- C: SDL_GetGamepadProperties.
 * Borrowed Properties tied to the gamepad (owner = inc'd gamepad external). */
LEAN_EXPORT lean_obj_res lean_sdl_get_gamepad_properties(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Gamepad, g, self);
    SDL_PropertiesID id = SDL_GetGamepadProperties(g);
    if (id == 0) return lean_sdl_throw();
    lean_inc(self);
    return lean_io_result_mk_ok(lean_sdl_wrap_properties_borrowed(id, (lean_object *)self));
}

/* Sdl.Gamepad.getIDRaw : IO UInt32 -- C: SDL_GetGamepadID (0 -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_get_gamepad_id(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Gamepad, g, self);
    SDL_JoystickID id = SDL_GetGamepadID(g);
    if (id == 0) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)id));
}

/* Sdl.Gamepad.nameRaw : IO String -- C: SDL_GetGamepadName (NULL -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_get_gamepad_name(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Gamepad, g, self);
    const char *s = SDL_GetGamepadName(g);
    if (!s) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_mk_string(s));
}

/* Sdl.Gamepad.pathRaw : IO (Option String) -- C: SDL_GetGamepadPath (NULL ->
 * none). */
LEAN_EXPORT lean_obj_res lean_sdl_get_gamepad_path(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Gamepad, g, self);
    return lean_io_result_mk_ok(lean_sdl_option_string(SDL_GetGamepadPath(g)));
}

/* Sdl.Gamepad.getTypeRaw : IO UInt32 -- C: SDL_GetGamepadType (decoded in Lean). */
LEAN_EXPORT lean_obj_res lean_sdl_get_gamepad_type(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Gamepad, g, self);
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)SDL_GetGamepadType(g)));
}

/* Sdl.Gamepad.realTypeRaw : IO UInt32 -- C: SDL_GetRealGamepadType (decoded in
 * Lean). */
LEAN_EXPORT lean_obj_res lean_sdl_get_real_gamepad_type(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Gamepad, g, self);
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)SDL_GetRealGamepadType(g)));
}

/* Sdl.Gamepad.playerIndexRaw : IO Int32
 * -- C: SDL_GetGamepadPlayerIndex (-1 = unavailable; Lean maps to none). */
LEAN_EXPORT lean_obj_res lean_sdl_get_gamepad_player_index(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Gamepad, g, self);
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)SDL_GetGamepadPlayerIndex(g)));
}

/* Sdl.Gamepad.setPlayerIndexRaw (idx : Int32) : IO Unit
 * -- C: SDL_SetGamepadPlayerIndex (idx -1 clears; false -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_set_gamepad_player_index(
        b_lean_obj_arg self, int32_t idx, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Gamepad, g, self);
    SDL_BOOL_TO_IO(SDL_SetGamepadPlayerIndex(g, (int)idx));
}

/* Sdl.Gamepad.vendorRaw : IO UInt16 -- C: SDL_GetGamepadVendor (0 = n/a). */
LEAN_EXPORT lean_obj_res lean_sdl_get_gamepad_vendor(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Gamepad, g, self);
    return lean_io_result_mk_ok(lean_box((uint16_t)SDL_GetGamepadVendor(g)));
}

/* Sdl.Gamepad.productRaw : IO UInt16 -- C: SDL_GetGamepadProduct (0 = n/a). */
LEAN_EXPORT lean_obj_res lean_sdl_get_gamepad_product(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Gamepad, g, self);
    return lean_io_result_mk_ok(lean_box((uint16_t)SDL_GetGamepadProduct(g)));
}

/* Sdl.Gamepad.productVersionRaw : IO UInt16
 * -- C: SDL_GetGamepadProductVersion (0 = n/a). */
LEAN_EXPORT lean_obj_res lean_sdl_get_gamepad_product_version(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Gamepad, g, self);
    return lean_io_result_mk_ok(lean_box((uint16_t)SDL_GetGamepadProductVersion(g)));
}

/* Sdl.Gamepad.firmwareVersionRaw : IO UInt16
 * -- C: SDL_GetGamepadFirmwareVersion (0 = n/a). */
LEAN_EXPORT lean_obj_res lean_sdl_get_gamepad_firmware_version(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Gamepad, g, self);
    return lean_io_result_mk_ok(lean_box((uint16_t)SDL_GetGamepadFirmwareVersion(g)));
}

/* Sdl.Gamepad.serialRaw : IO (Option String)
 * -- C: SDL_GetGamepadSerial (NULL -> none). */
LEAN_EXPORT lean_obj_res lean_sdl_get_gamepad_serial(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Gamepad, g, self);
    return lean_io_result_mk_ok(lean_sdl_option_string(SDL_GetGamepadSerial(g)));
}

/* Sdl.Gamepad.steamHandle : IO UInt64
 * -- C: SDL_GetGamepadSteamHandle (0 = unavailable; kept raw). */
LEAN_EXPORT lean_obj_res lean_sdl_get_gamepad_steam_handle(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Gamepad, g, self);
    return lean_io_result_mk_ok(lean_box_uint64(SDL_GetGamepadSteamHandle(g)));
}

/* Sdl.Gamepad.connectionStateRaw : IO UInt32
 * -- C: SDL_GetGamepadConnectionState (INVALID -> throw; decoded in Lean). */
LEAN_EXPORT lean_obj_res lean_sdl_get_gamepad_connection_state(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Gamepad, g, self);
    SDL_JoystickConnectionState st = SDL_GetGamepadConnectionState(g);
    if (st == SDL_JOYSTICK_CONNECTION_INVALID) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)st));
}

/* Sdl.Gamepad.powerInfoRaw : IO (UInt32 x Int32)
 * -- C: SDL_GetGamepadPowerInfo (SDL_POWERSTATE_ERROR -> throw; percent -1 =
 * unknown, mapped to none in Lean). */
LEAN_EXPORT lean_obj_res lean_sdl_get_gamepad_power_info(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Gamepad, g, self);
    int percent = -1;
    SDL_PowerState st = SDL_GetGamepadPowerInfo(g, &percent);
    if (st == SDL_POWERSTATE_ERROR) return lean_sdl_throw();
    return lean_io_result_mk_ok(
        lean_sdl_pair(lean_box_uint32((uint32_t)st), lean_box_uint32((uint32_t)percent)));
}

/* Sdl.Gamepad.connected : IO Bool -- C: SDL_GamepadConnected. */
LEAN_EXPORT lean_obj_res lean_sdl_gamepad_connected(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Gamepad, g, self);
    return lean_io_result_mk_ok(lean_box(SDL_GamepadConnected(g)));
}

/* Sdl.Gamepad.getJoystick : IO Joystick -- C: SDL_GetGamepadJoystick.
 * SDL returns a borrowed pointer owned by the gamepad; take our own reference
 * via SDL_OpenJoystick(id) and wrap that with the joystick class so it safely
 * outlives the gamepad. */
LEAN_EXPORT lean_obj_res lean_sdl_get_gamepad_joystick(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Gamepad, g, self);
    SDL_Joystick *j = SDL_GetGamepadJoystick(g);
    if (!j) return lean_sdl_throw();
    SDL_Joystick *j2 = SDL_OpenJoystick(SDL_GetJoystickID(j));
    if (!j2) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_wrap(lean_sdl_joystick_class, j2, NULL));
}

/* Sdl.Gamepad.getBindings : IO (Array GamepadBinding)
 * -- C: SDL_GetGamepadBindings (NULL -> throw). Array of pointers is a single
 * allocation freed once after decoding each binding via the Lean maker. */
LEAN_EXPORT lean_obj_res lean_sdl_get_gamepad_bindings(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Gamepad, g, self);
    int count = 0;
    SDL_GamepadBinding **binds = SDL_GetGamepadBindings(g, &count);
    if (!binds) return lean_sdl_throw();
    size_t n = count > 0 ? (size_t)count : 0;
    lean_object *arr = lean_alloc_array(n, n);
    for (size_t i = 0; i < n; i++) {
        SDL_GamepadBinding *b = binds[i];
        int32_t in_a = 0, in_b = 0, in_c = 0;
        switch (b->input_type) {
            case SDL_GAMEPAD_BINDTYPE_BUTTON: in_a = b->input.button; break;
            case SDL_GAMEPAD_BINDTYPE_AXIS:
                in_a = b->input.axis.axis; in_b = b->input.axis.axis_min;
                in_c = b->input.axis.axis_max; break;
            case SDL_GAMEPAD_BINDTYPE_HAT:
                in_a = b->input.hat.hat; in_b = b->input.hat.hat_mask; break;
            default: break;
        }
        uint32_t out_ba = 0;
        int32_t out_min = 0, out_max = 0;
        switch (b->output_type) {
            case SDL_GAMEPAD_BINDTYPE_BUTTON: out_ba = (uint32_t)b->output.button; break;
            case SDL_GAMEPAD_BINDTYPE_AXIS:
                out_ba = (uint32_t)b->output.axis.axis;
                out_min = b->output.axis.axis_min; out_max = b->output.axis.axis_max; break;
            default: break;
        }
        lean_object *elem = lean_sdl_mk_gamepad_binding(
            (uint32_t)b->input_type, in_a, in_b, in_c,
            (uint32_t)b->output_type, out_ba, out_min, out_max);
        lean_array_set_core(arr, i, elem);
    }
    SDL_free(binds);
    return lean_io_result_mk_ok(arr);
}

/* Sdl.Gamepad.getMappingRaw : IO (Option String)
 * -- C: SDL_GetGamepadMapping (NULL -> none; SDL_free after copy). */
LEAN_EXPORT lean_obj_res lean_sdl_get_gamepad_mapping(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Gamepad, g, self);
    char *s = SDL_GetGamepadMapping(g);
    if (!s) return lean_io_result_mk_ok(lean_sdl_none());
    lean_object *str = lean_mk_string(s);
    SDL_free(s);
    return lean_io_result_mk_ok(lean_sdl_some(str));
}

/* Sdl.Gamepad.hasAxisRaw (axis : UInt8) : IO Bool -- C: SDL_GamepadHasAxis. */
LEAN_EXPORT lean_obj_res lean_sdl_gamepad_has_axis(
        b_lean_obj_arg self, uint8_t axis, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Gamepad, g, self);
    return lean_io_result_mk_ok(lean_box(SDL_GamepadHasAxis(g, (SDL_GamepadAxis)axis)));
}

/* Sdl.Gamepad.getAxisRaw (axis : UInt8) : IO Int16 -- C: SDL_GetGamepadAxis
 * (0 conflates value/failure; never throws). */
LEAN_EXPORT lean_obj_res lean_sdl_get_gamepad_axis(
        b_lean_obj_arg self, uint8_t axis, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Gamepad, g, self);
    Sint16 v = SDL_GetGamepadAxis(g, (SDL_GamepadAxis)axis);
    return lean_io_result_mk_ok(lean_box((uint16_t)v));
}

/* Sdl.Gamepad.hasButtonRaw (button : UInt8) : IO Bool -- C: SDL_GamepadHasButton. */
LEAN_EXPORT lean_obj_res lean_sdl_gamepad_has_button(
        b_lean_obj_arg self, uint8_t button, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Gamepad, g, self);
    return lean_io_result_mk_ok(lean_box(SDL_GamepadHasButton(g, (SDL_GamepadButton)button)));
}

/* Sdl.Gamepad.getButtonRaw (button : UInt8) : IO Bool -- C: SDL_GetGamepadButton. */
LEAN_EXPORT lean_obj_res lean_sdl_get_gamepad_button(
        b_lean_obj_arg self, uint8_t button, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Gamepad, g, self);
    return lean_io_result_mk_ok(lean_box(SDL_GetGamepadButton(g, (SDL_GamepadButton)button)));
}

/* Sdl.Gamepad.buttonLabelRaw (button : UInt8) : IO UInt32
 * -- C: SDL_GetGamepadButtonLabel (decoded in Lean). */
LEAN_EXPORT lean_obj_res lean_sdl_get_gamepad_button_label(
        b_lean_obj_arg self, uint8_t button, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Gamepad, g, self);
    return lean_io_result_mk_ok(
        lean_box_uint32((uint32_t)SDL_GetGamepadButtonLabel(g, (SDL_GamepadButton)button)));
}

/* Sdl.Gamepad.numTouchpads : IO Int32 -- C: SDL_GetNumGamepadTouchpads. */
LEAN_EXPORT lean_obj_res lean_sdl_get_num_gamepad_touchpads(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Gamepad, g, self);
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)SDL_GetNumGamepadTouchpads(g)));
}

/* Sdl.Gamepad.numTouchpadFingers (touchpad : Int32) : IO Int32
 * -- C: SDL_GetNumGamepadTouchpadFingers. */
LEAN_EXPORT lean_obj_res lean_sdl_get_num_gamepad_touchpad_fingers(
        b_lean_obj_arg self, int32_t touchpad, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Gamepad, g, self);
    return lean_io_result_mk_ok(
        lean_box_uint32((uint32_t)SDL_GetNumGamepadTouchpadFingers(g, (int)touchpad)));
}

/* Sdl.Gamepad.getTouchpadFinger (touchpad finger : Int32)
 * : IO (Bool x Float32 x Float32 x Float32)
 * -- C: SDL_GetGamepadTouchpadFinger (false -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_get_gamepad_touchpad_finger(
        b_lean_obj_arg self, int32_t touchpad, int32_t finger, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Gamepad, g, self);
    bool down = false;
    float x = 0.0f, y = 0.0f, pressure = 0.0f;
    if (!SDL_GetGamepadTouchpadFinger(g, (int)touchpad, (int)finger, &down, &x, &y, &pressure))
        return lean_sdl_throw();
    lean_object *inner = lean_sdl_pair(lean_box_float32(y), lean_box_float32(pressure));
    lean_object *mid   = lean_sdl_pair(lean_box_float32(x), inner);
    lean_object *outer = lean_sdl_pair(lean_box(down), mid);
    return lean_io_result_mk_ok(outer);
}

/* Sdl.Gamepad.hasSensorRaw (type : UInt32) : IO Bool -- C: SDL_GamepadHasSensor. */
LEAN_EXPORT lean_obj_res lean_sdl_gamepad_has_sensor(
        b_lean_obj_arg self, uint32_t type, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Gamepad, g, self);
    return lean_io_result_mk_ok(lean_box(SDL_GamepadHasSensor(g, (SDL_SensorType)type)));
}

/* Sdl.Gamepad.setSensorEnabledRaw (type : UInt32) (enabled : Bool) : IO Unit
 * -- C: SDL_SetGamepadSensorEnabled (false -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_set_gamepad_sensor_enabled(
        b_lean_obj_arg self, uint32_t type, uint8_t enabled, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Gamepad, g, self);
    SDL_BOOL_TO_IO(SDL_SetGamepadSensorEnabled(g, (SDL_SensorType)type, (bool)enabled));
}

/* Sdl.Gamepad.sensorEnabledRaw (type : UInt32) : IO Bool
 * -- C: SDL_GamepadSensorEnabled. */
LEAN_EXPORT lean_obj_res lean_sdl_gamepad_sensor_enabled(
        b_lean_obj_arg self, uint32_t type, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Gamepad, g, self);
    return lean_io_result_mk_ok(lean_box(SDL_GamepadSensorEnabled(g, (SDL_SensorType)type)));
}

/* Sdl.Gamepad.sensorDataRateRaw (type : UInt32) : IO Float32
 * -- C: SDL_GetGamepadSensorDataRate (0.0 = unavailable; never throws). */
LEAN_EXPORT lean_obj_res lean_sdl_get_gamepad_sensor_data_rate(
        b_lean_obj_arg self, uint32_t type, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Gamepad, g, self);
    return lean_io_result_mk_ok(
        lean_box_float32(SDL_GetGamepadSensorDataRate(g, (SDL_SensorType)type)));
}

/* Sdl.Gamepad.getSensorDataRaw (type : UInt32) (numValues : Int32) : IO FloatArray
 * -- C: SDL_GetGamepadSensorData into a temp float buffer, widened to doubles.
 * numValues < 0 -> throw before alloc; false -> throw. */
LEAN_EXPORT lean_obj_res lean_sdl_get_gamepad_sensor_data(
        b_lean_obj_arg self, uint32_t type, int32_t num_values, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Gamepad, g, self);
    if (num_values < 0)
        return lean_sdl_throw_msg("SDL: getSensorData numValues must be non-negative");
    size_t n = (size_t)num_values;
    float *buf = (float *)SDL_malloc(n ? n * sizeof(float) : 1);
    if (!buf) return lean_sdl_throw_msg("SDL: out of memory");
    if (!SDL_GetGamepadSensorData(g, (SDL_SensorType)type, buf, num_values)) {
        SDL_free(buf);
        return lean_sdl_throw();
    }
    lean_object *arr = lean_alloc_sarray(sizeof(double), n, n);
    double *d = lean_float_array_cptr(arr);
    for (size_t i = 0; i < n; i++) d[i] = (double)buf[i];
    SDL_free(buf);
    return lean_io_result_mk_ok(arr);
}

/* Sdl.Gamepad.rumble (low high : UInt16) (durationMs : UInt32) : IO Bool
 * -- C: SDL_RumbleGamepad (false = unsupported; capability result, not error). */
LEAN_EXPORT lean_obj_res lean_sdl_rumble_gamepad(
        b_lean_obj_arg self, uint16_t low, uint16_t high, uint32_t duration, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Gamepad, g, self);
    return lean_io_result_mk_ok(lean_box(SDL_RumbleGamepad(g, low, high, duration)));
}

/* Sdl.Gamepad.rumbleTriggers (left right : UInt16) (durationMs : UInt32) : IO Bool
 * -- C: SDL_RumbleGamepadTriggers (false = unsupported; capability result). */
LEAN_EXPORT lean_obj_res lean_sdl_rumble_gamepad_triggers(
        b_lean_obj_arg self, uint16_t left, uint16_t right, uint32_t duration, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Gamepad, g, self);
    return lean_io_result_mk_ok(lean_box(SDL_RumbleGamepadTriggers(g, left, right, duration)));
}

/* Sdl.Gamepad.setLED (red green blue : UInt8) : IO Bool
 * -- C: SDL_SetGamepadLED (false = unsupported; capability result). */
LEAN_EXPORT lean_obj_res lean_sdl_set_gamepad_led(
        b_lean_obj_arg self, uint8_t red, uint8_t green, uint8_t blue, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Gamepad, g, self);
    return lean_io_result_mk_ok(lean_box(SDL_SetGamepadLED(g, red, green, blue)));
}

/* Sdl.Gamepad.sendEffect (data : @& ByteArray) : IO Bool
 * -- C: SDL_SendGamepadEffect (false = unsupported; capability result). */
LEAN_EXPORT lean_obj_res lean_sdl_send_gamepad_effect(
        b_lean_obj_arg self, b_lean_obj_arg data, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Gamepad, g, self);
    size_t n = lean_sarray_size(data);
    bool ok = SDL_SendGamepadEffect(g, lean_sarray_cptr((lean_object *)data), (int)n);
    return lean_io_result_mk_ok(lean_box(ok));
}

/* Sdl.Gamepad.appleSFSymbolsNameForButtonRaw (button : UInt8) : IO (Option String)
 * -- C: SDL_GetGamepadAppleSFSymbolsNameForButton (NULL/"" -> none). */
LEAN_EXPORT lean_obj_res lean_sdl_get_gamepad_apple_sf_symbols_name_for_button(
        b_lean_obj_arg self, uint8_t button, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Gamepad, g, self);
    const char *s = SDL_GetGamepadAppleSFSymbolsNameForButton(g, (SDL_GamepadButton)button);
    if (!s || !*s) return lean_io_result_mk_ok(lean_sdl_none());
    return lean_io_result_mk_ok(lean_sdl_some(lean_mk_string(s)));
}

/* Sdl.Gamepad.appleSFSymbolsNameForAxisRaw (axis : UInt8) : IO (Option String)
 * -- C: SDL_GetGamepadAppleSFSymbolsNameForAxis (NULL/"" -> none). */
LEAN_EXPORT lean_obj_res lean_sdl_get_gamepad_apple_sf_symbols_name_for_axis(
        b_lean_obj_arg self, uint8_t axis, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Gamepad, g, self);
    const char *s = SDL_GetGamepadAppleSFSymbolsNameForAxis(g, (SDL_GamepadAxis)axis);
    if (!s || !*s) return lean_io_result_mk_ok(lean_sdl_none());
    return lean_io_result_mk_ok(lean_sdl_some(lean_mk_string(s)));
}
