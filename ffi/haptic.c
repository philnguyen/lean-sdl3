/* Shims for Sdl/Haptic.lean (SDL_haptic.h) — partial binding.
 *
 * One external class over the Lean `Haptic` type: an OWNED ROOT whose finalizer
 * runs SDL_CloseHaptic and whose holder owner is always NULL. Haptic.close is a
 * manual destroy that NULLs the holder ptr. SDL's haptic open is NOT documented
 * as refcounted (unlike joystick/gamepad): getHapticFromID still takes a fresh
 * SDL_OpenHaptic reference for shape parity, but the Lean docs warn that closing
 * any handle closes the device for all of them. Safety within the binding comes
 * from SDL_GET_OR_THROW guarding our own NULLed handles.
 *
 * HapticID / HapticEffectID are plain scalars on the Lean side (Uint32 / int);
 * their shims take the raw value. HapticFeatures crosses as a raw Uint32 bitmask
 * decoded in Lean. A HapticEffect is flattened by the Lean wrapper into a fixed
 * order of scalars (one effectType tag folding effect-kind + waveform, one
 * direction-type tag, the 3 direction values, and the per-variant fields with
 * zeros for fields a variant lacks); fill_haptic_effect() memsets an
 * SDL_HapticEffect and fills the right union member by switching on effectType.
 *
 * Skipped (see Sdl/Haptic.lean docstring): SDL_HapticCondition and
 * SDL_HapticCustom effect variants. */
#include "util.h"

/* Owned root: finalizer closes the haptic device. No cross-module consumer, so
 * the class pointer is defined locally (non-static per SDL_DEFINE_CLASS). */
SDL_DEFINE_CLASS(lean_sdl_haptic, SDL_CloseHaptic((SDL_Haptic *)self))

static lean_object *lean_sdl_wrap_haptic(SDL_Haptic *h) {
    return lean_sdl_wrap(lean_sdl_haptic_class, h, NULL);
}

/* Register the class. Called from Sdl/Haptic.lean's `initialize`. */
LEAN_EXPORT lean_obj_res lean_sdl_haptic_register_classes(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    lean_sdl_haptic_class_init();
    return lean_sdl_unit_ok();
}

/* Rebuild an SDL_HapticEffect from the Lean wrapper's flattened scalars. The
 * union member is chosen by switching on effect_type (an SDL_HAPTIC_* value);
 * unrecognized types leave the effect zeroed with just the type set. Small ints
 * arrive as their unsigned width (DESIGN.md ABI note) and are re-cast to Sint16. */
static void fill_haptic_effect(SDL_HapticEffect *eff,
        uint32_t effect_type, uint32_t dir_type, int32_t dir0, int32_t dir1, int32_t dir2,
        uint32_t length, uint16_t delay, uint16_t button, uint16_t interval,
        uint16_t level, uint16_t period, uint16_t magnitude, uint16_t offset, uint16_t phase,
        uint16_t ramp_start, uint16_t ramp_end, uint16_t large_mag, uint16_t small_mag,
        uint16_t attack_length, uint16_t attack_level, uint16_t fade_length, uint16_t fade_level) {
    SDL_memset(eff, 0, sizeof(*eff));
    switch (effect_type) {
        case SDL_HAPTIC_CONSTANT: {
            SDL_HapticConstant *c = &eff->constant;
            c->type = SDL_HAPTIC_CONSTANT;
            c->direction.type = (SDL_HapticDirectionType)dir_type;
            c->direction.dir[0] = dir0; c->direction.dir[1] = dir1; c->direction.dir[2] = dir2;
            c->length = length; c->delay = delay; c->button = button; c->interval = interval;
            c->level = (Sint16)level;
            c->attack_length = attack_length; c->attack_level = attack_level;
            c->fade_length = fade_length; c->fade_level = fade_level;
            break;
        }
        case SDL_HAPTIC_SINE:
        case SDL_HAPTIC_SQUARE:
        case SDL_HAPTIC_TRIANGLE:
        case SDL_HAPTIC_SAWTOOTHUP:
        case SDL_HAPTIC_SAWTOOTHDOWN: {
            SDL_HapticPeriodic *p = &eff->periodic;
            p->type = (SDL_HapticEffectType)effect_type;
            p->direction.type = (SDL_HapticDirectionType)dir_type;
            p->direction.dir[0] = dir0; p->direction.dir[1] = dir1; p->direction.dir[2] = dir2;
            p->length = length; p->delay = delay; p->button = button; p->interval = interval;
            p->period = period; p->magnitude = (Sint16)magnitude; p->offset = (Sint16)offset;
            p->phase = phase;
            p->attack_length = attack_length; p->attack_level = attack_level;
            p->fade_length = fade_length; p->fade_level = fade_level;
            break;
        }
        case SDL_HAPTIC_RAMP: {
            SDL_HapticRamp *r = &eff->ramp;
            r->type = SDL_HAPTIC_RAMP;
            r->direction.type = (SDL_HapticDirectionType)dir_type;
            r->direction.dir[0] = dir0; r->direction.dir[1] = dir1; r->direction.dir[2] = dir2;
            r->length = length; r->delay = delay; r->button = button; r->interval = interval;
            r->start = (Sint16)ramp_start; r->end = (Sint16)ramp_end;
            r->attack_length = attack_length; r->attack_level = attack_level;
            r->fade_length = fade_length; r->fade_level = fade_level;
            break;
        }
        case SDL_HAPTIC_LEFTRIGHT: {
            SDL_HapticLeftRight *lr = &eff->leftright;
            lr->type = SDL_HAPTIC_LEFTRIGHT;
            lr->length = length;
            lr->large_magnitude = large_mag;
            lr->small_magnitude = small_mag;
            break;
        }
        default:
            eff->type = (SDL_HapticEffectType)effect_type;
            break;
    }
}

/* ==================== Top-level functions ==================== */

/* Sdl.getHapticsRaw : IO (Array UInt32)
 * -- C: SDL_GetHaptics (NULL -> throw; SDL_free after copy). */
LEAN_EXPORT lean_obj_res lean_sdl_get_haptics(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    int count = 0;
    SDL_HapticID *ids = SDL_GetHaptics(&count);
    if (!ids) return lean_sdl_throw();
    size_t n = count > 0 ? (size_t)count : 0;
    lean_object *arr = lean_alloc_array(n, n);
    for (size_t i = 0; i < n; i++)
        lean_array_set_core(arr, i, lean_box_uint32((uint32_t)ids[i]));
    SDL_free(ids);
    return lean_io_result_mk_ok(arr);
}

/* Sdl.openHapticRaw (id : UInt32) : IO Haptic -- C: SDL_OpenHaptic (NULL ->
 * throw). */
LEAN_EXPORT lean_obj_res lean_sdl_open_haptic(uint32_t id, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_Haptic *h = SDL_OpenHaptic((SDL_HapticID)id);
    if (!h) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_wrap_haptic(h));
}

/* Sdl.getHapticFromIDRaw (id : UInt32) : IO (Option Haptic)
 * -- C: SDL_GetHapticFromID. NULL -> none; otherwise take a fresh reference via
 * SDL_OpenHaptic(id) and wrap that (see the refcounting warning in the Lean
 * docs). */
LEAN_EXPORT lean_obj_res lean_sdl_get_haptic_from_id(uint32_t id, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_Haptic *h = SDL_GetHapticFromID((SDL_HapticID)id);
    if (!h) return lean_io_result_mk_ok(lean_sdl_none());
    SDL_Haptic *h2 = SDL_OpenHaptic((SDL_HapticID)id);
    if (!h2) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_some(lean_sdl_wrap_haptic(h2)));
}

/* Sdl.isMouseHaptic : IO Bool -- C: SDL_IsMouseHaptic. */
LEAN_EXPORT lean_obj_res lean_sdl_is_mouse_haptic(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(lean_box(SDL_IsMouseHaptic()));
}

/* Sdl.openHapticFromMouse : IO Haptic -- C: SDL_OpenHapticFromMouse (NULL ->
 * throw). */
LEAN_EXPORT lean_obj_res lean_sdl_open_haptic_from_mouse(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_Haptic *h = SDL_OpenHapticFromMouse();
    if (!h) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_wrap_haptic(h));
}

/* Sdl.isJoystickHaptic (joystick : @& Joystick) : IO Bool
 * -- C: SDL_IsJoystickHaptic. */
LEAN_EXPORT lean_obj_res lean_sdl_is_joystick_haptic(b_lean_obj_arg joystick, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Joystick, j, joystick);
    return lean_io_result_mk_ok(lean_box(SDL_IsJoystickHaptic(j)));
}

/* Sdl.openHapticFromJoystick (joystick : @& Joystick) : IO Haptic
 * -- C: SDL_OpenHapticFromJoystick (NULL -> throw). Transfers a real handle. */
LEAN_EXPORT lean_obj_res lean_sdl_open_haptic_from_joystick(b_lean_obj_arg joystick, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Joystick, j, joystick);
    SDL_Haptic *h = SDL_OpenHapticFromJoystick(j);
    if (!h) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_wrap_haptic(h));
}

/* Sdl.HapticID.nameRaw (id : UInt32) : IO String
 * -- C: SDL_GetHapticNameForID (NULL -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_get_haptic_name_for_id(uint32_t id, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    const char *s = SDL_GetHapticNameForID((SDL_HapticID)id);
    if (!s) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_mk_string(s));
}

/* ==================== Haptic methods ==================== */

/* Sdl.Haptic.close : IO Unit -- C: SDL_CloseHaptic (manual destroy; NULL the
 * ptr). */
LEAN_EXPORT lean_obj_res lean_sdl_close_haptic(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    sdl_holder *h = lean_sdl_holder_of(self);
    if (!h->ptr) return lean_sdl_throw_msg("SDL: handle used after destroy/release");
    SDL_CloseHaptic((SDL_Haptic *)h->ptr);
    h->ptr = NULL;
    return lean_sdl_unit_ok();
}

/* Sdl.Haptic.getIDRaw : IO UInt32 -- C: SDL_GetHapticID (0 -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_get_haptic_id(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Haptic, h, self);
    SDL_HapticID id = SDL_GetHapticID(h);
    if (id == 0) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)id));
}

/* Sdl.Haptic.name : IO (Option String)
 * -- C: SDL_GetHapticName (NULL -> none; header: NULL if no name). */
LEAN_EXPORT lean_obj_res lean_sdl_get_haptic_name(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Haptic, h, self);
    return lean_io_result_mk_ok(lean_sdl_option_string(SDL_GetHapticName(h)));
}

/* Sdl.Haptic.maxEffects : IO Int32 -- C: SDL_GetMaxHapticEffects (-1 -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_get_max_haptic_effects(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Haptic, h, self);
    int n = SDL_GetMaxHapticEffects(h);
    if (n < 0) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)n));
}

/* Sdl.Haptic.maxEffectsPlaying : IO Int32
 * -- C: SDL_GetMaxHapticEffectsPlaying (-1 -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_get_max_haptic_effects_playing(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Haptic, h, self);
    int n = SDL_GetMaxHapticEffectsPlaying(h);
    if (n < 0) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)n));
}

/* Sdl.Haptic.featuresRaw : IO UInt32
 * -- C: SDL_GetHapticFeatures (0 -> throw; decoded to HapticFeatures in Lean). */
LEAN_EXPORT lean_obj_res lean_sdl_get_haptic_features(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Haptic, h, self);
    Uint32 f = SDL_GetHapticFeatures(h);
    if (f == 0) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_box_uint32(f));
}

/* Sdl.Haptic.numAxes : IO Int32 -- C: SDL_GetNumHapticAxes (-1 -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_get_num_haptic_axes(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Haptic, h, self);
    int n = SDL_GetNumHapticAxes(h);
    if (n < 0) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)n));
}

/* Sdl.Haptic.effectSupportedRaw (flattened effect) : IO Bool
 * -- C: SDL_HapticEffectSupported. */
LEAN_EXPORT lean_obj_res lean_sdl_haptic_effect_supported(
        b_lean_obj_arg self,
        uint32_t effect_type, uint32_t dir_type, int32_t dir0, int32_t dir1, int32_t dir2,
        uint32_t length, uint16_t delay, uint16_t button, uint16_t interval,
        uint16_t level, uint16_t period, uint16_t magnitude, uint16_t offset, uint16_t phase,
        uint16_t ramp_start, uint16_t ramp_end, uint16_t large_mag, uint16_t small_mag,
        uint16_t attack_length, uint16_t attack_level, uint16_t fade_length, uint16_t fade_level,
        lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Haptic, h, self);
    SDL_HapticEffect eff;
    fill_haptic_effect(&eff, effect_type, dir_type, dir0, dir1, dir2, length, delay, button,
        interval, level, period, magnitude, offset, phase, ramp_start, ramp_end, large_mag,
        small_mag, attack_length, attack_level, fade_length, fade_level);
    return lean_io_result_mk_ok(lean_box(SDL_HapticEffectSupported(h, &eff)));
}

/* Sdl.Haptic.createEffectRaw (flattened effect) : IO Int32
 * -- C: SDL_CreateHapticEffect (-1 -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_create_haptic_effect(
        b_lean_obj_arg self,
        uint32_t effect_type, uint32_t dir_type, int32_t dir0, int32_t dir1, int32_t dir2,
        uint32_t length, uint16_t delay, uint16_t button, uint16_t interval,
        uint16_t level, uint16_t period, uint16_t magnitude, uint16_t offset, uint16_t phase,
        uint16_t ramp_start, uint16_t ramp_end, uint16_t large_mag, uint16_t small_mag,
        uint16_t attack_length, uint16_t attack_level, uint16_t fade_length, uint16_t fade_level,
        lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Haptic, h, self);
    SDL_HapticEffect eff;
    fill_haptic_effect(&eff, effect_type, dir_type, dir0, dir1, dir2, length, delay, button,
        interval, level, period, magnitude, offset, phase, ramp_start, ramp_end, large_mag,
        small_mag, attack_length, attack_level, fade_length, fade_level);
    int id = SDL_CreateHapticEffect(h, &eff);
    if (id < 0) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)id));
}

/* Sdl.Haptic.updateEffectRaw (id : Int32) (flattened effect) : IO Unit
 * -- C: SDL_UpdateHapticEffect (false -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_update_haptic_effect(
        b_lean_obj_arg self, int32_t id,
        uint32_t effect_type, uint32_t dir_type, int32_t dir0, int32_t dir1, int32_t dir2,
        uint32_t length, uint16_t delay, uint16_t button, uint16_t interval,
        uint16_t level, uint16_t period, uint16_t magnitude, uint16_t offset, uint16_t phase,
        uint16_t ramp_start, uint16_t ramp_end, uint16_t large_mag, uint16_t small_mag,
        uint16_t attack_length, uint16_t attack_level, uint16_t fade_length, uint16_t fade_level,
        lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Haptic, h, self);
    SDL_HapticEffect eff;
    fill_haptic_effect(&eff, effect_type, dir_type, dir0, dir1, dir2, length, delay, button,
        interval, level, period, magnitude, offset, phase, ramp_start, ramp_end, large_mag,
        small_mag, attack_length, attack_level, fade_length, fade_level);
    SDL_BOOL_TO_IO(SDL_UpdateHapticEffect(h, (SDL_HapticEffectID)id, &eff));
}

/* Sdl.Haptic.runEffectRaw (id : Int32) (iterations : UInt32) : IO Unit
 * -- C: SDL_RunHapticEffect (false -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_run_haptic_effect(
        b_lean_obj_arg self, int32_t id, uint32_t iterations, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Haptic, h, self);
    SDL_BOOL_TO_IO(SDL_RunHapticEffect(h, (SDL_HapticEffectID)id, iterations));
}

/* Sdl.Haptic.stopEffectRaw (id : Int32) : IO Unit
 * -- C: SDL_StopHapticEffect (false -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_stop_haptic_effect(
        b_lean_obj_arg self, int32_t id, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Haptic, h, self);
    SDL_BOOL_TO_IO(SDL_StopHapticEffect(h, (SDL_HapticEffectID)id));
}

/* Sdl.Haptic.destroyEffectRaw (id : Int32) : IO Unit
 * -- C: SDL_DestroyHapticEffect (void). */
LEAN_EXPORT lean_obj_res lean_sdl_destroy_haptic_effect(
        b_lean_obj_arg self, int32_t id, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Haptic, h, self);
    SDL_DestroyHapticEffect(h, (SDL_HapticEffectID)id);
    return lean_sdl_unit_ok();
}

/* Sdl.Haptic.effectStatusRaw (id : Int32) : IO Bool
 * -- C: SDL_GetHapticEffectStatus (false if not playing or status unsupported). */
LEAN_EXPORT lean_obj_res lean_sdl_get_haptic_effect_status(
        b_lean_obj_arg self, int32_t id, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Haptic, h, self);
    return lean_io_result_mk_ok(lean_box(SDL_GetHapticEffectStatus(h, (SDL_HapticEffectID)id)));
}

/* Sdl.Haptic.setGain (gain : Int32) : IO Unit
 * -- C: SDL_SetHapticGain (false -> throw; needs SDL_HAPTIC_GAIN). */
LEAN_EXPORT lean_obj_res lean_sdl_set_haptic_gain(b_lean_obj_arg self, int32_t gain, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Haptic, h, self);
    SDL_BOOL_TO_IO(SDL_SetHapticGain(h, (int)gain));
}

/* Sdl.Haptic.setAutocenter (autocenter : Int32) : IO Unit
 * -- C: SDL_SetHapticAutocenter (false -> throw; needs SDL_HAPTIC_AUTOCENTER). */
LEAN_EXPORT lean_obj_res lean_sdl_set_haptic_autocenter(
        b_lean_obj_arg self, int32_t autocenter, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Haptic, h, self);
    SDL_BOOL_TO_IO(SDL_SetHapticAutocenter(h, (int)autocenter));
}

/* Sdl.Haptic.pause : IO Unit -- C: SDL_PauseHaptic (false -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_pause_haptic(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Haptic, h, self);
    SDL_BOOL_TO_IO(SDL_PauseHaptic(h));
}

/* Sdl.Haptic.resume : IO Unit -- C: SDL_ResumeHaptic (false -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_resume_haptic(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Haptic, h, self);
    SDL_BOOL_TO_IO(SDL_ResumeHaptic(h));
}

/* Sdl.Haptic.stopEffects : IO Unit -- C: SDL_StopHapticEffects (false -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_stop_haptic_effects(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Haptic, h, self);
    SDL_BOOL_TO_IO(SDL_StopHapticEffects(h));
}

/* Sdl.Haptic.rumbleSupported : IO Bool -- C: SDL_HapticRumbleSupported. */
LEAN_EXPORT lean_obj_res lean_sdl_haptic_rumble_supported(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Haptic, h, self);
    return lean_io_result_mk_ok(lean_box(SDL_HapticRumbleSupported(h)));
}

/* Sdl.Haptic.initRumble : IO Unit -- C: SDL_InitHapticRumble (false -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_init_haptic_rumble(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Haptic, h, self);
    SDL_BOOL_TO_IO(SDL_InitHapticRumble(h));
}

/* Sdl.Haptic.playRumble (strength : Float32) (lengthMs : UInt32) : IO Unit
 * -- C: SDL_PlayHapticRumble (false -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_play_haptic_rumble(
        b_lean_obj_arg self, float strength, uint32_t length_ms, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Haptic, h, self);
    SDL_BOOL_TO_IO(SDL_PlayHapticRumble(h, strength, length_ms));
}

/* Sdl.Haptic.stopRumble : IO Unit -- C: SDL_StopHapticRumble (false -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_stop_haptic_rumble(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Haptic, h, self);
    SDL_BOOL_TO_IO(SDL_StopHapticRumble(h));
}
