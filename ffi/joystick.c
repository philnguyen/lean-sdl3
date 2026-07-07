/* Shims for Sdl/Joystick.lean (SDL_joystick.h).
 *
 * One external class over the Lean `Joystick` type: an OWNED ROOT whose
 * finalizer runs SDL_CloseJoystick and whose holder owner is always NULL.
 * Joystick.close is a manual destroy that NULLs the holder ptr. The class
 * pointer is non-static (declared in ffi/classes.h) but has no cross-module
 * consumer yet; SDL refcounts joysticks internally, so every handle the binding
 * hands out took its own SDL_OpenJoystick reference and independent handles
 * never alias each other's lifetime.
 *
 * getJoystickFromID / getJoystickFromPlayerIndex do not own the manager's
 * internal handle: they re-open the joystick (SDL_OpenJoystick on its id bumps
 * SDL's internal refcount) and wrap that fresh, independently-owned reference.
 *
 * JoystickId is a plain Uint32 on the Lean side (reused from Sdl/Events.lean);
 * its shims take the raw id. JoystickType / JoystickConnectionState / Hat cross
 * the boundary as their raw scalar; the Lean wrapper decodes them. Int16 axis
 * values cross as uint16_t bits (DESIGN.md ABI note). The virtual-joystick
 * descriptor is flattened by the Lean wrapper into scalars + parallel arrays;
 * this shim rebuilds SDL_VirtualJoystickDesc with SDL_INIT_INTERFACE and points
 * its touchpads/sensors at temporary arrays. The desc's callback fields are not
 * bound (see Sdl/Joystick.lean's module docstring). */
#include "util.h"
#include "classes.h"

/* Owned root: finalizer closes the joystick. Defines the non-static
 * lean_sdl_joystick_class declared in classes.h. */
SDL_DEFINE_CLASS(lean_sdl_joystick, SDL_CloseJoystick((SDL_Joystick *)self))

static lean_object *lean_sdl_wrap_joystick(SDL_Joystick *j) {
    return lean_sdl_wrap(lean_sdl_joystick_class, j, NULL);
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

/* Register the class. Called from Sdl/Joystick.lean's `initialize`. */
LEAN_EXPORT lean_obj_res lean_sdl_joystick_register_classes(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    lean_sdl_joystick_class_init();
    return lean_sdl_unit_ok();
}

/* ==================== Top-level functions ==================== */

/* Sdl.lockJoysticks : IO Unit -- C: SDL_LockJoysticks (void). */
LEAN_EXPORT lean_obj_res lean_sdl_lock_joysticks(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_LockJoysticks();
    return lean_sdl_unit_ok();
}

/* Sdl.unlockJoysticks : IO Unit -- C: SDL_UnlockJoysticks (void). */
LEAN_EXPORT lean_obj_res lean_sdl_unlock_joysticks(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_UnlockJoysticks();
    return lean_sdl_unit_ok();
}

/* Sdl.hasJoystick : IO Bool -- C: SDL_HasJoystick. */
LEAN_EXPORT lean_obj_res lean_sdl_has_joystick(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(lean_box(SDL_HasJoystick()));
}

/* Sdl.getJoysticksRaw : IO (Array UInt32) -- C: SDL_GetJoysticks (NULL -> throw;
 * SDL_free after copy). */
LEAN_EXPORT lean_obj_res lean_sdl_get_joysticks(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    int count = 0;
    SDL_JoystickID *ids = SDL_GetJoysticks(&count);
    if (!ids) return lean_sdl_throw();
    size_t n = count > 0 ? (size_t)count : 0;
    lean_object *arr = lean_alloc_array(n, n);
    for (size_t i = 0; i < n; i++)
        lean_array_set_core(arr, i, lean_box_uint32((uint32_t)ids[i]));
    SDL_free(ids);
    return lean_io_result_mk_ok(arr);
}

/* Sdl.openJoystickRaw (id : UInt32) : IO Joystick
 * -- C: SDL_OpenJoystick (NULL -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_open_joystick(uint32_t id, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_Joystick *j = SDL_OpenJoystick((SDL_JoystickID)id);
    if (!j) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_wrap_joystick(j));
}

/* Sdl.getJoystickFromIDRaw (id : UInt32) : IO (Option Joystick)
 * -- C: SDL_GetJoystickFromID. NULL -> none; otherwise re-open (ref-bump) and
 * wrap that fresh, independently-owned reference. */
LEAN_EXPORT lean_obj_res lean_sdl_get_joystick_from_id(uint32_t id, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_Joystick *j = SDL_GetJoystickFromID((SDL_JoystickID)id);
    if (!j) return lean_io_result_mk_ok(lean_sdl_none());
    SDL_Joystick *j2 = SDL_OpenJoystick(SDL_GetJoystickID(j));
    if (!j2) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_some(lean_sdl_wrap_joystick(j2)));
}

/* Sdl.getJoystickFromPlayerIndexRaw (idx : Int32) : IO (Option Joystick)
 * -- C: SDL_GetJoystickFromPlayerIndex. NULL -> none; otherwise re-open
 * (ref-bump) and wrap that fresh, independently-owned reference. */
LEAN_EXPORT lean_obj_res lean_sdl_get_joystick_from_player_index(int32_t idx, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_Joystick *j = SDL_GetJoystickFromPlayerIndex((int)idx);
    if (!j) return lean_io_result_mk_ok(lean_sdl_none());
    SDL_Joystick *j2 = SDL_OpenJoystick(SDL_GetJoystickID(j));
    if (!j2) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_some(lean_sdl_wrap_joystick(j2)));
}

/* Sdl.attachVirtualJoystickRaw : IO UInt32 -- C: SDL_AttachVirtualJoystick.
 * The Lean wrapper flattens VirtualJoystickDesc into scalars plus the parallel
 * touchpadFingers / sensorTypes / sensorRates arrays; rebuild the desc here with
 * SDL_INIT_INTERFACE (which zeroes and versions it, matching the Lean field
 * defaults) and temporary touchpad/sensor arrays. 0 -> throw. */
LEAN_EXPORT lean_obj_res lean_sdl_attach_virtual_joystick(
        uint16_t type, uint16_t vendor_id, uint16_t product_id,
        uint16_t naxes, uint16_t nbuttons, uint16_t nballs, uint16_t nhats,
        uint32_t button_mask, uint32_t axis_mask,
        b_lean_obj_arg name, b_lean_obj_arg touchpad_fingers,
        b_lean_obj_arg sensor_types, b_lean_obj_arg sensor_rates,
        lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_VirtualJoystickDesc d;
    SDL_INIT_INTERFACE(&d);
    d.type = type;
    d.vendor_id = vendor_id;
    d.product_id = product_id;
    d.naxes = naxes;
    d.nbuttons = nbuttons;
    d.nballs = nballs;
    d.nhats = nhats;
    d.button_mask = button_mask;
    d.axis_mask = axis_mask;
    d.name = lean_is_scalar(name) ? NULL : lean_string_cstr(lean_ctor_get(name, 0));

    size_t nt = lean_array_size(touchpad_fingers);
    SDL_VirtualJoystickTouchpadDesc *tp = NULL;
    if (nt) {
        tp = (SDL_VirtualJoystickTouchpadDesc *)SDL_calloc(nt, sizeof(*tp));
        for (size_t i = 0; i < nt; i++)
            tp[i].nfingers = (Uint16)lean_unbox(lean_array_get_core(touchpad_fingers, i));
    }
    d.ntouchpads = (Uint16)nt;
    d.touchpads = tp;

    size_t ns = lean_array_size(sensor_types);
    const double *rates = lean_float_array_cptr((lean_object *)sensor_rates);
    SDL_VirtualJoystickSensorDesc *sd = NULL;
    if (ns) {
        sd = (SDL_VirtualJoystickSensorDesc *)SDL_calloc(ns, sizeof(*sd));
        for (size_t i = 0; i < ns; i++) {
            sd[i].type = (SDL_SensorType)lean_unbox_uint32(lean_array_get_core(sensor_types, i));
            sd[i].rate = (float)rates[i];
        }
    }
    d.nsensors = (Uint16)ns;
    d.sensors = sd;

    SDL_JoystickID id = SDL_AttachVirtualJoystick(&d);
    SDL_free(tp);
    SDL_free(sd);
    if (id == 0) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)id));
}

/* Sdl.detachVirtualJoystickRaw (id : UInt32) : IO Unit
 * -- C: SDL_DetachVirtualJoystick (false -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_detach_virtual_joystick(uint32_t id, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_BOOL_TO_IO(SDL_DetachVirtualJoystick((SDL_JoystickID)id));
}

/* Sdl.isJoystickVirtualRaw (id : UInt32) : IO Bool -- C: SDL_IsJoystickVirtual. */
LEAN_EXPORT lean_obj_res lean_sdl_is_joystick_virtual(uint32_t id, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(lean_box(SDL_IsJoystickVirtual((SDL_JoystickID)id)));
}

/* Sdl.setJoystickEventsEnabled (enabled : Bool) : IO Unit
 * -- C: SDL_SetJoystickEventsEnabled (void). */
LEAN_EXPORT lean_obj_res lean_sdl_set_joystick_events_enabled(uint8_t enabled, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_SetJoystickEventsEnabled((bool)enabled);
    return lean_sdl_unit_ok();
}

/* Sdl.joystickEventsEnabled : IO Bool -- C: SDL_JoystickEventsEnabled. */
LEAN_EXPORT lean_obj_res lean_sdl_joystick_events_enabled(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(lean_box(SDL_JoystickEventsEnabled()));
}

/* Sdl.updateJoysticks : IO Unit -- C: SDL_UpdateJoysticks (void). */
LEAN_EXPORT lean_obj_res lean_sdl_update_joysticks(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_UpdateJoysticks();
    return lean_sdl_unit_ok();
}

/* Sdl.getJoystickGUIDInfoRaw (bytes : @& ByteArray)
 * : IO (UInt16 x UInt16 x UInt16 x UInt16)
 * -- C: SDL_GetJoystickGUIDInfo (vendor, product, version, crc16; void). */
LEAN_EXPORT lean_obj_res lean_sdl_get_joystick_guid_info(b_lean_obj_arg bytes, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GUID guid;
    SDL_zero(guid);
    size_t n = lean_sarray_size(bytes);
    size_t k = n < sizeof(guid.data) ? n : sizeof(guid.data);
    SDL_memcpy(guid.data, lean_sarray_cptr((lean_object *)bytes), k);
    Uint16 vendor = 0, product = 0, version = 0, crc16 = 0;
    SDL_GetJoystickGUIDInfo(guid, &vendor, &product, &version, &crc16);
    lean_object *inner = lean_sdl_pair(lean_box((uint16_t)version), lean_box((uint16_t)crc16));
    lean_object *mid   = lean_sdl_pair(lean_box((uint16_t)product), inner);
    lean_object *outer = lean_sdl_pair(lean_box((uint16_t)vendor), mid);
    return lean_io_result_mk_ok(outer);
}

/* ==================== JoystickId (*ForID) methods ==================== */

/* Sdl.JoystickId.nameRaw (id : UInt32) : IO String
 * -- C: SDL_GetJoystickNameForID (NULL -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_get_joystick_name_for_id(uint32_t id, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    const char *s = SDL_GetJoystickNameForID((SDL_JoystickID)id);
    if (!s) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_mk_string(s));
}

/* Sdl.JoystickId.pathRaw (id : UInt32) : IO (Option String)
 * -- C: SDL_GetJoystickPathForID (NULL -> none). */
LEAN_EXPORT lean_obj_res lean_sdl_get_joystick_path_for_id(uint32_t id, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(lean_sdl_option_string(SDL_GetJoystickPathForID((SDL_JoystickID)id)));
}

/* Sdl.JoystickId.playerIndexRaw (id : UInt32) : IO Int32
 * -- C: SDL_GetJoystickPlayerIndexForID (-1 = unavailable; Lean maps to none). */
LEAN_EXPORT lean_obj_res lean_sdl_get_joystick_player_index_for_id(uint32_t id, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(
        lean_box_uint32((uint32_t)SDL_GetJoystickPlayerIndexForID((SDL_JoystickID)id)));
}

/* Sdl.JoystickId.guidRaw (id : UInt32) : IO ByteArray
 * -- C: SDL_GetJoystickGUIDForID (zero GUID if invalid). */
LEAN_EXPORT lean_obj_res lean_sdl_get_joystick_guid_for_id(uint32_t id, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(lean_sdl_guid_bytes(SDL_GetJoystickGUIDForID((SDL_JoystickID)id)));
}

/* Sdl.JoystickId.vendorRaw (id : UInt32) : IO UInt16
 * -- C: SDL_GetJoystickVendorForID (0 = unavailable). */
LEAN_EXPORT lean_obj_res lean_sdl_get_joystick_vendor_for_id(uint32_t id, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(lean_box((uint16_t)SDL_GetJoystickVendorForID((SDL_JoystickID)id)));
}

/* Sdl.JoystickId.productRaw (id : UInt32) : IO UInt16
 * -- C: SDL_GetJoystickProductForID (0 = unavailable). */
LEAN_EXPORT lean_obj_res lean_sdl_get_joystick_product_for_id(uint32_t id, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(lean_box((uint16_t)SDL_GetJoystickProductForID((SDL_JoystickID)id)));
}

/* Sdl.JoystickId.productVersionRaw (id : UInt32) : IO UInt16
 * -- C: SDL_GetJoystickProductVersionForID (0 = unavailable). */
LEAN_EXPORT lean_obj_res lean_sdl_get_joystick_product_version_for_id(uint32_t id, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(
        lean_box((uint16_t)SDL_GetJoystickProductVersionForID((SDL_JoystickID)id)));
}

/* Sdl.JoystickId.getTypeRaw (id : UInt32) : IO UInt32
 * -- C: SDL_GetJoystickTypeForID (UNKNOWN if invalid; decoded in Lean). */
LEAN_EXPORT lean_obj_res lean_sdl_get_joystick_type_for_id(uint32_t id, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(
        lean_box_uint32((uint32_t)SDL_GetJoystickTypeForID((SDL_JoystickID)id)));
}

/* ==================== Joystick methods ==================== */

/* Sdl.Joystick.close : IO Unit -- C: SDL_CloseJoystick (manual destroy; NULL the
 * ptr). */
LEAN_EXPORT lean_obj_res lean_sdl_close_joystick(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    sdl_holder *h = lean_sdl_holder_of(self);
    if (!h->ptr) return lean_sdl_throw_msg("SDL: handle used after destroy/release");
    SDL_CloseJoystick((SDL_Joystick *)h->ptr);
    h->ptr = NULL;
    return lean_sdl_unit_ok();
}

/* Sdl.Joystick.getProperties : IO Properties -- C: SDL_GetJoystickProperties.
 * Borrowed Properties tied to the joystick (owner = inc'd joystick external). */
LEAN_EXPORT lean_obj_res lean_sdl_get_joystick_properties(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Joystick, j, self);
    SDL_PropertiesID id = SDL_GetJoystickProperties(j);
    if (id == 0) return lean_sdl_throw();
    lean_inc(self);
    return lean_io_result_mk_ok(lean_sdl_wrap_properties_borrowed(id, (lean_object *)self));
}

/* Sdl.Joystick.nameRaw : IO String -- C: SDL_GetJoystickName (NULL -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_get_joystick_name(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Joystick, j, self);
    const char *s = SDL_GetJoystickName(j);
    if (!s) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_mk_string(s));
}

/* Sdl.Joystick.pathRaw : IO (Option String) -- C: SDL_GetJoystickPath (NULL ->
 * none). */
LEAN_EXPORT lean_obj_res lean_sdl_get_joystick_path(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Joystick, j, self);
    return lean_io_result_mk_ok(lean_sdl_option_string(SDL_GetJoystickPath(j)));
}

/* Sdl.Joystick.playerIndexRaw : IO Int32
 * -- C: SDL_GetJoystickPlayerIndex (-1 = unavailable; Lean maps to none). */
LEAN_EXPORT lean_obj_res lean_sdl_get_joystick_player_index(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Joystick, j, self);
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)SDL_GetJoystickPlayerIndex(j)));
}

/* Sdl.Joystick.setPlayerIndexRaw (idx : Int32) : IO Unit
 * -- C: SDL_SetJoystickPlayerIndex (idx -1 clears; false -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_set_joystick_player_index(
        b_lean_obj_arg self, int32_t idx, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Joystick, j, self);
    SDL_BOOL_TO_IO(SDL_SetJoystickPlayerIndex(j, (int)idx));
}

/* Sdl.Joystick.guidRaw : IO ByteArray -- C: SDL_GetJoystickGUID. */
LEAN_EXPORT lean_obj_res lean_sdl_get_joystick_guid(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Joystick, j, self);
    return lean_io_result_mk_ok(lean_sdl_guid_bytes(SDL_GetJoystickGUID(j)));
}

/* Sdl.Joystick.vendorRaw : IO UInt16 -- C: SDL_GetJoystickVendor (0 = n/a). */
LEAN_EXPORT lean_obj_res lean_sdl_get_joystick_vendor(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Joystick, j, self);
    return lean_io_result_mk_ok(lean_box((uint16_t)SDL_GetJoystickVendor(j)));
}

/* Sdl.Joystick.productRaw : IO UInt16 -- C: SDL_GetJoystickProduct (0 = n/a). */
LEAN_EXPORT lean_obj_res lean_sdl_get_joystick_product(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Joystick, j, self);
    return lean_io_result_mk_ok(lean_box((uint16_t)SDL_GetJoystickProduct(j)));
}

/* Sdl.Joystick.productVersionRaw : IO UInt16
 * -- C: SDL_GetJoystickProductVersion (0 = n/a). */
LEAN_EXPORT lean_obj_res lean_sdl_get_joystick_product_version(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Joystick, j, self);
    return lean_io_result_mk_ok(lean_box((uint16_t)SDL_GetJoystickProductVersion(j)));
}

/* Sdl.Joystick.firmwareVersionRaw : IO UInt16
 * -- C: SDL_GetJoystickFirmwareVersion (0 = n/a). */
LEAN_EXPORT lean_obj_res lean_sdl_get_joystick_firmware_version(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Joystick, j, self);
    return lean_io_result_mk_ok(lean_box((uint16_t)SDL_GetJoystickFirmwareVersion(j)));
}

/* Sdl.Joystick.serialRaw : IO (Option String)
 * -- C: SDL_GetJoystickSerial (NULL -> none). */
LEAN_EXPORT lean_obj_res lean_sdl_get_joystick_serial(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Joystick, j, self);
    return lean_io_result_mk_ok(lean_sdl_option_string(SDL_GetJoystickSerial(j)));
}

/* Sdl.Joystick.getTypeRaw : IO UInt32 -- C: SDL_GetJoystickType (decoded in
 * Lean). */
LEAN_EXPORT lean_obj_res lean_sdl_get_joystick_type(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Joystick, j, self);
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)SDL_GetJoystickType(j)));
}

/* Sdl.Joystick.connected : IO Bool -- C: SDL_JoystickConnected. */
LEAN_EXPORT lean_obj_res lean_sdl_joystick_connected(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Joystick, j, self);
    return lean_io_result_mk_ok(lean_box(SDL_JoystickConnected(j)));
}

/* Sdl.Joystick.getIDRaw : IO UInt32 -- C: SDL_GetJoystickID (0 -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_get_joystick_id(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Joystick, j, self);
    SDL_JoystickID id = SDL_GetJoystickID(j);
    if (id == 0) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)id));
}

/* Sdl.Joystick.numAxes : IO Int32 -- C: SDL_GetNumJoystickAxes (-1 -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_get_num_joystick_axes(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Joystick, j, self);
    int n = SDL_GetNumJoystickAxes(j);
    if (n < 0) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)n));
}

/* Sdl.Joystick.numBalls : IO Int32 -- C: SDL_GetNumJoystickBalls (-1 -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_get_num_joystick_balls(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Joystick, j, self);
    int n = SDL_GetNumJoystickBalls(j);
    if (n < 0) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)n));
}

/* Sdl.Joystick.numHats : IO Int32 -- C: SDL_GetNumJoystickHats (-1 -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_get_num_joystick_hats(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Joystick, j, self);
    int n = SDL_GetNumJoystickHats(j);
    if (n < 0) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)n));
}

/* Sdl.Joystick.numButtons : IO Int32 -- C: SDL_GetNumJoystickButtons (-1 ->
 * throw). */
LEAN_EXPORT lean_obj_res lean_sdl_get_num_joystick_buttons(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Joystick, j, self);
    int n = SDL_GetNumJoystickButtons(j);
    if (n < 0) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)n));
}

/* Sdl.Joystick.getAxis (axis : Int32) : IO Int16 -- C: SDL_GetJoystickAxis.
 * SDL conflates a genuine 0 with failure, so this never throws. */
LEAN_EXPORT lean_obj_res lean_sdl_get_joystick_axis(b_lean_obj_arg self, int32_t axis, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Joystick, j, self);
    Sint16 v = SDL_GetJoystickAxis(j, (int)axis);
    return lean_io_result_mk_ok(lean_box((uint16_t)v));
}

/* Sdl.Joystick.getAxisInitialState (axis : Int32) : IO (Option Int16)
 * -- C: SDL_GetJoystickAxisInitialState (false -> none). */
LEAN_EXPORT lean_obj_res lean_sdl_get_joystick_axis_initial_state(
        b_lean_obj_arg self, int32_t axis, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Joystick, j, self);
    Sint16 st = 0;
    if (!SDL_GetJoystickAxisInitialState(j, (int)axis, &st))
        return lean_io_result_mk_ok(lean_sdl_none());
    return lean_io_result_mk_ok(lean_sdl_some(lean_box((uint16_t)st)));
}

/* Sdl.Joystick.getBall (ball : Int32) : IO (Int32 x Int32)
 * -- C: SDL_GetJoystickBall (false -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_get_joystick_ball(
        b_lean_obj_arg self, int32_t ball, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Joystick, j, self);
    int dx = 0, dy = 0;
    if (!SDL_GetJoystickBall(j, (int)ball, &dx, &dy)) return lean_sdl_throw();
    return lean_io_result_mk_ok(
        lean_sdl_pair(lean_box_uint32((uint32_t)dx), lean_box_uint32((uint32_t)dy)));
}

/* Sdl.Joystick.getHatRaw (hat : Int32) : IO UInt8 -- C: SDL_GetJoystickHat. */
LEAN_EXPORT lean_obj_res lean_sdl_get_joystick_hat(b_lean_obj_arg self, int32_t hat, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Joystick, j, self);
    return lean_io_result_mk_ok(lean_box(SDL_GetJoystickHat(j, (int)hat)));
}

/* Sdl.Joystick.getButton (button : Int32) : IO Bool -- C: SDL_GetJoystickButton. */
LEAN_EXPORT lean_obj_res lean_sdl_get_joystick_button(
        b_lean_obj_arg self, int32_t button, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Joystick, j, self);
    return lean_io_result_mk_ok(lean_box(SDL_GetJoystickButton(j, (int)button)));
}

/* Sdl.Joystick.rumble (low high : UInt16) (durationMs : UInt32) : IO Bool
 * -- C: SDL_RumbleJoystick (false = unsupported; capability result, not error). */
LEAN_EXPORT lean_obj_res lean_sdl_rumble_joystick(
        b_lean_obj_arg self, uint16_t low, uint16_t high, uint32_t duration, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Joystick, j, self);
    return lean_io_result_mk_ok(lean_box(SDL_RumbleJoystick(j, low, high, duration)));
}

/* Sdl.Joystick.rumbleTriggers (left right : UInt16) (durationMs : UInt32) : IO Bool
 * -- C: SDL_RumbleJoystickTriggers (false = unsupported; capability result). */
LEAN_EXPORT lean_obj_res lean_sdl_rumble_joystick_triggers(
        b_lean_obj_arg self, uint16_t left, uint16_t right, uint32_t duration, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Joystick, j, self);
    return lean_io_result_mk_ok(lean_box(SDL_RumbleJoystickTriggers(j, left, right, duration)));
}

/* Sdl.Joystick.setLED (red green blue : UInt8) : IO Bool
 * -- C: SDL_SetJoystickLED (false = unsupported; capability result). */
LEAN_EXPORT lean_obj_res lean_sdl_set_joystick_led(
        b_lean_obj_arg self, uint8_t red, uint8_t green, uint8_t blue, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Joystick, j, self);
    return lean_io_result_mk_ok(lean_box(SDL_SetJoystickLED(j, red, green, blue)));
}

/* Sdl.Joystick.sendEffect (data : @& ByteArray) : IO Bool
 * -- C: SDL_SendJoystickEffect (false = unsupported; capability result). */
LEAN_EXPORT lean_obj_res lean_sdl_send_joystick_effect(
        b_lean_obj_arg self, b_lean_obj_arg data, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Joystick, j, self);
    size_t n = lean_sarray_size(data);
    bool ok = SDL_SendJoystickEffect(j, lean_sarray_cptr((lean_object *)data), (int)n);
    return lean_io_result_mk_ok(lean_box(ok));
}

/* Sdl.Joystick.connectionStateRaw : IO UInt32
 * -- C: SDL_GetJoystickConnectionState (INVALID -> throw; decoded in Lean). */
LEAN_EXPORT lean_obj_res lean_sdl_get_joystick_connection_state(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Joystick, j, self);
    SDL_JoystickConnectionState st = SDL_GetJoystickConnectionState(j);
    if (st == SDL_JOYSTICK_CONNECTION_INVALID) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)st));
}

/* Sdl.Joystick.powerInfoRaw : IO (UInt32 x Int32)
 * -- C: SDL_GetJoystickPowerInfo (SDL_POWERSTATE_ERROR -> throw; percent -1 =
 * unknown, mapped to none in Lean). */
LEAN_EXPORT lean_obj_res lean_sdl_get_joystick_power_info(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Joystick, j, self);
    int percent = -1;
    SDL_PowerState st = SDL_GetJoystickPowerInfo(j, &percent);
    if (st == SDL_POWERSTATE_ERROR) return lean_sdl_throw();
    return lean_io_result_mk_ok(
        lean_sdl_pair(lean_box_uint32((uint32_t)st), lean_box_uint32((uint32_t)percent)));
}

/* Sdl.Joystick.setVirtualAxisRaw (axis : Int32) (value : Int16) : IO Unit
 * -- C: SDL_SetJoystickVirtualAxis (false -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_set_joystick_virtual_axis(
        b_lean_obj_arg self, int32_t axis, uint16_t value, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Joystick, j, self);
    SDL_BOOL_TO_IO(SDL_SetJoystickVirtualAxis(j, (int)axis, (Sint16)value));
}

/* Sdl.Joystick.setVirtualBallRaw (ball : Int32) (xrel yrel : Int16) : IO Unit
 * -- C: SDL_SetJoystickVirtualBall (false -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_set_joystick_virtual_ball(
        b_lean_obj_arg self, int32_t ball, uint16_t xrel, uint16_t yrel, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Joystick, j, self);
    SDL_BOOL_TO_IO(SDL_SetJoystickVirtualBall(j, (int)ball, (Sint16)xrel, (Sint16)yrel));
}

/* Sdl.Joystick.setVirtualButtonRaw (button : Int32) (down : Bool) : IO Unit
 * -- C: SDL_SetJoystickVirtualButton (false -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_set_joystick_virtual_button(
        b_lean_obj_arg self, int32_t button, uint8_t down, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Joystick, j, self);
    SDL_BOOL_TO_IO(SDL_SetJoystickVirtualButton(j, (int)button, (bool)down));
}

/* Sdl.Joystick.setVirtualHatRaw (hat : Int32) (value : UInt8) : IO Unit
 * -- C: SDL_SetJoystickVirtualHat (false -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_set_joystick_virtual_hat(
        b_lean_obj_arg self, int32_t hat, uint8_t value, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Joystick, j, self);
    SDL_BOOL_TO_IO(SDL_SetJoystickVirtualHat(j, (int)hat, value));
}

/* Sdl.Joystick.setVirtualTouchpadRaw (touchpad finger : Int32) (down : Bool)
 * (x y pressure : Float32) : IO Unit
 * -- C: SDL_SetJoystickVirtualTouchpad (false -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_set_joystick_virtual_touchpad(
        b_lean_obj_arg self, int32_t touchpad, int32_t finger, uint8_t down,
        float x, float y, float pressure, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Joystick, j, self);
    SDL_BOOL_TO_IO(SDL_SetJoystickVirtualTouchpad(
        j, (int)touchpad, (int)finger, (bool)down, x, y, pressure));
}

/* Sdl.Joystick.sendVirtualSensorDataRaw (type : UInt32) (sensorTimestampNs :
 * UInt64) (data : @& FloatArray) : IO Unit
 * -- C: SDL_SendJoystickVirtualSensorData (doubles narrowed to a temp float
 * buffer; false -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_send_joystick_virtual_sensor_data(
        b_lean_obj_arg self, uint32_t type, uint64_t ts, b_lean_obj_arg data, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Joystick, j, self);
    size_t n = lean_sarray_size(data);
    const double *src = lean_float_array_cptr((lean_object *)data);
    float *buf = (float *)SDL_malloc(n ? n * sizeof(float) : 1);
    for (size_t i = 0; i < n; i++) buf[i] = (float)src[i];
    bool ok = SDL_SendJoystickVirtualSensorData(j, (SDL_SensorType)type, ts, buf, (int)n);
    SDL_free(buf);
    if (!ok) return lean_sdl_throw();
    return lean_sdl_unit_ok();
}
