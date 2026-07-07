/* Shims for Sdl/Audio.lean (SDL_audio.h).
 *
 * One external class over the Lean `AudioStream` type: an OWNED ROOT whose
 * finalizer runs SDL_DestroyAudioStream (which also unbinds it and, for a
 * stream from SDL_OpenAudioDeviceStream, closes the device opened alongside
 * it). AudioStream.destroy is a manual destroy that NULLs the holder ptr, so
 * later use is a clean IO error.
 *
 * The holder is EXTENDED beyond sdl_holder with two callback slots (get_cb /
 * put_cb): the M9 callback pass fills them under SDL_LockAudioStream and the
 * finalizer releases them after destroying the stream. The first two fields
 * alias sdl_holder, so SDL_GET_OR_THROW / lean_sdl_holder_of / the unbind
 * array-builder all work through the sdl_holder view unchanged. Because of the
 * extra fields (and their locked-slot lifetime) this class does NOT use
 * SDL_DEFINE_CLASS.
 *
 * AudioDeviceID is a plain Uint32 on the Lean side (sdl_id); its shims take the
 * raw id. AudioSpec crosses the boundary flattened: params as scalars, results
 * via the @[export]ed lean_sdl_mk_audio_spec maker, so C never lays out a Lean
 * structure. Tuple results are built with lean_alloc_ctor(0, 2, 0). */
#include "util.h"
#include "classes.h"
#include "callbacks.h"

/* ---------- Extended AudioStream holder (see docs/DESIGN.md) ---------- */

/* Extended holder: per-stream callback closures (M9 callback pass) live with
 * the stream so they can be replaced under SDL_LockAudioStream and released
 * after SDL_DestroyAudioStream. First two fields alias sdl_holder, so
 * SDL_GET_OR_THROW / lean_sdl_holder_of work unchanged. */
typedef struct {
    void        *ptr;    /* SDL_AudioStream*; NULL after manual destroy */
    lean_object *owner;  /* always NULL for audio streams */
    sdl_cb_slot  get_cb; /* SDL_SetAudioStreamGetCallback closure (M9b) */
    sdl_cb_slot  put_cb; /* SDL_SetAudioStreamPutCallback closure (M9b) */
} sdl_audio_stream_holder;

static void lean_sdl_audio_stream_finalize(void *data) {
    sdl_audio_stream_holder *h = (sdl_audio_stream_holder *)data;
    /* Destroy first: SDL guarantees no callback is running or will run after
     * this returns. Only then release the closures. */
    if (h->ptr) SDL_DestroyAudioStream((SDL_AudioStream *)h->ptr);
    lean_sdl_slot_clear(&h->get_cb);
    lean_sdl_slot_clear(&h->put_cb);
    if (h->owner) lean_dec(h->owner);
    free(h);
}

static void lean_sdl_audio_stream_foreach(void *data, b_lean_obj_arg fn) {
    sdl_audio_stream_holder *h = (sdl_audio_stream_holder *)data;
    lean_object *targets[3] = { NULL, NULL, NULL };
    SDL_LockMutex(lean_sdl_cb_mutex);
    if (h->owner)     { lean_inc(h->owner);     targets[0] = h->owner; }
    if (h->get_cb.fn) { lean_inc(h->get_cb.fn); targets[1] = h->get_cb.fn; }
    if (h->put_cb.fn) { lean_inc(h->put_cb.fn); targets[2] = h->put_cb.fn; }
    SDL_UnlockMutex(lean_sdl_cb_mutex);
    for (int i = 0; i < 3; i++) {
        if (!targets[i]) continue;
        lean_inc(fn);
        lean_object *r = lean_apply_1((lean_object *)fn, targets[i]);
        lean_dec(r);
    }
}

lean_external_class *lean_sdl_audio_stream_class = NULL;

/* Borrowed-class wrapper passed to stream callbacks (defined with the other
 * callback machinery at the bottom of this file): never destroys the stream;
 * the dispatching trampoline NULLs its ptr when the callback returns, so a
 * stored handle throws instead of dangling. */
extern lean_external_class *lean_sdl_audio_stream_borrowed_class;
static void lean_sdl_audio_stream_borrowed_class_init(void);

/* Drop a registered postmix closure for `devid` (defined with the postmix
 * machinery below; used by AudioDeviceID.close). */
static void lean_sdl_audio_drop_postmix(uint32_t devid);

static lean_object *lean_sdl_wrap_audio_stream(SDL_AudioStream *s) {
    sdl_audio_stream_holder *h = calloc(1, sizeof(*h));
    h->ptr = s;
    return lean_alloc_external(lean_sdl_audio_stream_class, h);
}

/* Register the class. Called from Sdl/Audio.lean's `initialize`. */
LEAN_EXPORT lean_obj_res lean_sdl_audio_register_classes(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    lean_sdl_audio_stream_class = lean_register_external_class(
        lean_sdl_audio_stream_finalize, lean_sdl_audio_stream_foreach);
    lean_sdl_audio_stream_borrowed_class_init();
    return lean_sdl_unit_ok();
}

/* ---------- Lean makers / small builders ---------- */

/* Sdl.mkAudioSpec: hand a flattened AudioSpec back to Lean. */
extern lean_object *lean_sdl_mk_audio_spec(uint32_t format, int32_t channels, int32_t freq);

static lean_object *lean_sdl_audio_spec_obj(const SDL_AudioSpec *s) {
    return lean_sdl_mk_audio_spec((uint32_t)s->format, (int32_t)s->channels, (int32_t)s->freq);
}

/* Build a `(a, b)` Lean pair (Prod). Consumes ownership of a and b. */
static lean_object *lean_sdl_pair(lean_object *a, lean_object *b) {
    lean_object *o = lean_alloc_ctor(0, 2, 0);
    lean_ctor_set(o, 0, a);
    lean_ctor_set(o, 1, b);
    return o;
}

/* An `int[count]` from C -> `Option (Array Int32)` (NULL -> none = default
 * order). SDL_free's the source array. */
static lean_object *lean_sdl_int_array_option(int *map, int count) {
    if (!map) return lean_sdl_none();
    size_t n = count > 0 ? (size_t)count : 0;
    lean_object *arr = lean_alloc_array(n, n);
    for (size_t i = 0; i < n; i++)
        lean_array_set_core(arr, i, lean_box_uint32((uint32_t)map[i]));
    SDL_free(map);
    return lean_sdl_some(arr);
}

/* Build a temp `int[]` from `@& Option (Array Int32)`: none -> (NULL, 0). The
 * returned pointer (if any) must be SDL_free'd by the caller. */
static int *lean_sdl_build_int_map(b_lean_obj_arg opt, int *out_count) {
    if (lean_is_scalar(opt)) { *out_count = 0; return NULL; }
    lean_object *arr = lean_ctor_get(opt, 0);
    size_t n = lean_array_size(arr);
    int *map = (int *)SDL_malloc(n ? n * sizeof(int) : 1);
    for (size_t i = 0; i < n; i++)
        map[i] = (int)(int32_t)lean_unbox_uint32(lean_array_get_core(arr, i));
    *out_count = (int)n;
    return map;
}

/* ==================== Drivers ==================== */

/* Sdl.getNumAudioDrivers : IO Int32 -- C: SDL_GetNumAudioDrivers */
LEAN_EXPORT lean_obj_res lean_sdl_get_num_audio_drivers(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)SDL_GetNumAudioDrivers()));
}

/* Sdl.getAudioDriver (index : Int32) : IO (Option String)
 * -- C: SDL_GetAudioDriver (NULL = out of range). */
LEAN_EXPORT lean_obj_res lean_sdl_get_audio_driver(int32_t index, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(lean_sdl_option_string(SDL_GetAudioDriver((int)index)));
}

/* Sdl.getCurrentAudioDriver : IO (Option String)
 * -- C: SDL_GetCurrentAudioDriver (NULL = audio not initialized). */
LEAN_EXPORT lean_obj_res lean_sdl_get_current_audio_driver(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(lean_sdl_option_string(SDL_GetCurrentAudioDriver()));
}

/* ==================== Device enumeration ==================== */

/* Copy a 0-terminated SDL_AudioDeviceID array into an Array UInt32 (NULL ->
 * throw; SDL_free after copy). */
static lean_obj_res lean_sdl_device_array(SDL_AudioDeviceID *ids, int count) {
    if (!ids) return lean_sdl_throw();
    size_t n = count > 0 ? (size_t)count : 0;
    lean_object *arr = lean_alloc_array(n, n);
    for (size_t i = 0; i < n; i++)
        lean_array_set_core(arr, i, lean_box_uint32((uint32_t)ids[i]));
    SDL_free(ids);
    return lean_io_result_mk_ok(arr);
}

/* Sdl.getAudioPlaybackDevicesRaw : IO (Array UInt32)
 * -- C: SDL_GetAudioPlaybackDevices. */
LEAN_EXPORT lean_obj_res lean_sdl_get_audio_playback_devices(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    int count = 0;
    SDL_AudioDeviceID *ids = SDL_GetAudioPlaybackDevices(&count);
    return lean_sdl_device_array(ids, count);
}

/* Sdl.getAudioRecordingDevicesRaw : IO (Array UInt32)
 * -- C: SDL_GetAudioRecordingDevices. */
LEAN_EXPORT lean_obj_res lean_sdl_get_audio_recording_devices(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    int count = 0;
    SDL_AudioDeviceID *ids = SDL_GetAudioRecordingDevices(&count);
    return lean_sdl_device_array(ids, count);
}

/* ==================== Opening devices and streams ==================== */

/* Sdl.openAudioDeviceRaw : IO UInt32 -- C: SDL_OpenAudioDevice (0 -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_open_audio_device(
        uint32_t devid, uint8_t has_spec, uint32_t format,
        int32_t channels, int32_t freq, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_AudioSpec spec = { (SDL_AudioFormat)format, (int)channels, (int)freq };
    SDL_AudioDeviceID id = SDL_OpenAudioDevice((SDL_AudioDeviceID)devid, has_spec ? &spec : NULL);
    if (id == 0) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)id));
}

/* Sdl.createAudioStreamRaw : IO AudioStream -- C: SDL_CreateAudioStream
 * (both specs nullable; NULL -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_create_audio_stream(
        uint8_t has_src, uint32_t src_format, int32_t src_channels, int32_t src_freq,
        uint8_t has_dst, uint32_t dst_format, int32_t dst_channels, int32_t dst_freq,
        lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_AudioSpec ss = { (SDL_AudioFormat)src_format, (int)src_channels, (int)src_freq };
    SDL_AudioSpec ds = { (SDL_AudioFormat)dst_format, (int)dst_channels, (int)dst_freq };
    SDL_AudioStream *s = SDL_CreateAudioStream(has_src ? &ss : NULL, has_dst ? &ds : NULL);
    if (!s) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_wrap_audio_stream(s));
}

/* Sdl.openAudioDeviceStreamRaw : IO AudioStream -- C: SDL_OpenAudioDeviceStream
 * with a NULL callback (stream callbacks are bound separately). The device
 * starts paused; destroying the stream closes the device. NULL -> throw. */
LEAN_EXPORT lean_obj_res lean_sdl_open_audio_device_stream(
        uint32_t devid, uint8_t has_spec, uint32_t format,
        int32_t channels, int32_t freq, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_AudioSpec spec = { (SDL_AudioFormat)format, (int)channels, (int)freq };
    SDL_AudioStream *s = SDL_OpenAudioDeviceStream(
        (SDL_AudioDeviceID)devid, has_spec ? &spec : NULL, NULL, NULL);
    if (!s) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_wrap_audio_stream(s));
}

/* ==================== WAV loading ==================== */

/* Copy an SDL-owned audio buffer into a fresh ByteArray, SDL_free the buffer,
 * and pair it with the spec. Consumes nothing else. */
static lean_obj_res lean_sdl_wav_result(const SDL_AudioSpec *spec, Uint8 *buf, Uint32 len) {
    lean_object *arr = lean_alloc_sarray(1, (size_t)len, (size_t)len);
    if (len) SDL_memcpy(lean_sarray_cptr(arr), buf, (size_t)len);
    SDL_free(buf);
    return lean_io_result_mk_ok(lean_sdl_pair(lean_sdl_audio_spec_obj(spec), arr));
}

/* Sdl.loadWAV (path : String) : IO (AudioSpec x ByteArray) -- C: SDL_LoadWAV. */
LEAN_EXPORT lean_obj_res lean_sdl_load_wav(b_lean_obj_arg path, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_AudioSpec spec;
    Uint8 *buf = NULL;
    Uint32 len = 0;
    if (!SDL_LoadWAV(lean_string_cstr(path), &spec, &buf, &len)) return lean_sdl_throw();
    return lean_sdl_wav_result(&spec, buf, len);
}

/* Sdl.loadWAVIO (src : IOStream) : IO (AudioSpec x ByteArray)
 * -- C: SDL_LoadWAV_IO with closeio=false (Lean owns the stream). */
LEAN_EXPORT lean_obj_res lean_sdl_load_wav_io(b_lean_obj_arg io, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_IOStream, s, io);
    SDL_AudioSpec spec;
    Uint8 *buf = NULL;
    Uint32 len = 0;
    if (!SDL_LoadWAV_IO(s, false, &spec, &buf, &len)) return lean_sdl_throw();
    return lean_sdl_wav_result(&spec, buf, len);
}

/* ==================== Mixing and conversion ==================== */

/* Sdl.mixAudioRaw (dst src : ByteArray) (format : UInt32) (volume : Float32)
 * : IO ByteArray -- C: SDL_MixAudio. Returns a fresh copy of `dst` with
 * min(|dst|,|src|) bytes of `src` mixed into its start. */
LEAN_EXPORT lean_obj_res lean_sdl_mix_audio(
        b_lean_obj_arg dst, b_lean_obj_arg src, uint32_t format,
        float volume, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    size_t dn = lean_sarray_size(dst);
    size_t sn = lean_sarray_size(src);
    size_t mn = dn < sn ? dn : sn;
    lean_object *out = lean_alloc_sarray(1, dn, dn);
    if (dn) SDL_memcpy(lean_sarray_cptr(out), lean_sarray_cptr((lean_object *)dst), dn);
    if (mn) {
        if (!SDL_MixAudio(lean_sarray_cptr(out), lean_sarray_cptr((lean_object *)src),
                          (SDL_AudioFormat)format, (Uint32)mn, volume)) {
            lean_dec(out);
            return lean_sdl_throw();
        }
    }
    return lean_io_result_mk_ok(out);
}

/* Sdl.convertAudioSamplesRaw : IO ByteArray -- C: SDL_ConvertAudioSamples
 * (copy dst_data into a ByteArray then SDL_free it). */
LEAN_EXPORT lean_obj_res lean_sdl_convert_audio_samples(
        uint32_t src_format, int32_t src_channels, int32_t src_freq,
        b_lean_obj_arg src,
        uint32_t dst_format, int32_t dst_channels, int32_t dst_freq,
        lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_AudioSpec ss = { (SDL_AudioFormat)src_format, (int)src_channels, (int)src_freq };
    SDL_AudioSpec ds = { (SDL_AudioFormat)dst_format, (int)dst_channels, (int)dst_freq };
    Uint8 *out = NULL;
    int out_len = 0;
    if (!SDL_ConvertAudioSamples(&ss, lean_sarray_cptr((lean_object *)src),
                                 (int)lean_sarray_size(src), &ds, &out, &out_len))
        return lean_sdl_throw();
    lean_object *arr = lean_alloc_sarray(1, (size_t)out_len, (size_t)out_len);
    if (out_len > 0) SDL_memcpy(lean_sarray_cptr(arr), out, (size_t)out_len);
    SDL_free(out);
    return lean_io_result_mk_ok(arr);
}

/* ==================== Format helpers ==================== */

/* Sdl.getAudioFormatNameRaw (format : UInt32) : IO String
 * -- C: SDL_GetAudioFormatName (never NULL). */
LEAN_EXPORT lean_obj_res lean_sdl_get_audio_format_name(uint32_t format, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(lean_sdl_mk_string(SDL_GetAudioFormatName((SDL_AudioFormat)format)));
}

/* Sdl.getSilenceValueForFormatRaw (format : UInt32) : IO UInt8
 * -- C: SDL_GetSilenceValueForFormat (int result is a byte value). */
LEAN_EXPORT lean_obj_res lean_sdl_get_silence_value_for_format(uint32_t format, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    int v = SDL_GetSilenceValueForFormat((SDL_AudioFormat)format);
    return lean_io_result_mk_ok(lean_box((uint8_t)v));
}

/* ==================== Stream (un)binding ==================== */

/* Build a temp SDL_AudioStream*[] from an `@& Array AudioStream`, throwing (via
 * `return` in the caller) if any element was destroyed. On success returns a
 * SDL_malloc'd array (caller SDL_free's) and sets *count; on a destroyed
 * element returns NULL after having freed nothing (nothing allocated yet is
 * impossible, so it frees the partial array). */
static SDL_AudioStream **lean_sdl_stream_array(b_lean_obj_arg streams, int *count, bool *bad) {
    size_t n = lean_array_size(streams);
    *count = (int)n;
    *bad = false;
    SDL_AudioStream **arr = (SDL_AudioStream **)SDL_malloc(n ? n * sizeof(SDL_AudioStream *) : 1);
    for (size_t i = 0; i < n; i++) {
        sdl_holder *h = lean_sdl_holder_of(lean_array_get_core(streams, i));
        if (!h->ptr) { SDL_free(arr); *bad = true; return NULL; }
        arr[i] = (SDL_AudioStream *)h->ptr;
    }
    return arr;
}

/* Sdl.unbindAudioStreams (streams : Array AudioStream) : IO Unit
 * -- C: SDL_UnbindAudioStreams (void; NULLed element -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_unbind_audio_streams(b_lean_obj_arg streams, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    int count = 0;
    bool bad = false;
    SDL_AudioStream **arr = lean_sdl_stream_array(streams, &count, &bad);
    if (bad) return lean_sdl_throw_msg("SDL: handle used after destroy/release");
    SDL_UnbindAudioStreams(arr, count);
    SDL_free(arr);
    return lean_sdl_unit_ok();
}

/* ==================== AudioDeviceID methods ==================== */

/* Sdl.AudioDeviceID.nameRaw (devid : UInt32) : IO String
 * -- C: SDL_GetAudioDeviceName (NULL -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_get_audio_device_name(uint32_t devid, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    const char *n = SDL_GetAudioDeviceName((SDL_AudioDeviceID)devid);
    if (!n) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_mk_string(n));
}

/* Sdl.AudioDeviceID.getFormatRaw (devid : UInt32) : IO (AudioSpec x Int32)
 * -- C: SDL_GetAudioDeviceFormat (snd = buffer size in sample frames). */
LEAN_EXPORT lean_obj_res lean_sdl_get_audio_device_format(uint32_t devid, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_AudioSpec spec;
    int frames = 0;
    if (!SDL_GetAudioDeviceFormat((SDL_AudioDeviceID)devid, &spec, &frames))
        return lean_sdl_throw();
    return lean_io_result_mk_ok(
        lean_sdl_pair(lean_sdl_audio_spec_obj(&spec), lean_box_uint32((uint32_t)frames)));
}

/* Sdl.AudioDeviceID.getChannelMapRaw (devid : UInt32) : IO (Option (Array Int32))
 * -- C: SDL_GetAudioDeviceChannelMap (NULL -> none = default order). */
LEAN_EXPORT lean_obj_res lean_sdl_get_audio_device_channel_map(uint32_t devid, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    int count = 0;
    int *map = SDL_GetAudioDeviceChannelMap((SDL_AudioDeviceID)devid, &count);
    return lean_io_result_mk_ok(lean_sdl_int_array_option(map, count));
}

/* Sdl.AudioDeviceID.isPhysicalRaw (devid : UInt32) : IO Bool
 * -- C: SDL_IsAudioDevicePhysical (infallible). */
LEAN_EXPORT lean_obj_res lean_sdl_is_audio_device_physical(uint32_t devid, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(lean_box(SDL_IsAudioDevicePhysical((SDL_AudioDeviceID)devid)));
}

/* Sdl.AudioDeviceID.isPlaybackRaw (devid : UInt32) : IO Bool
 * -- C: SDL_IsAudioDevicePlayback (infallible). */
LEAN_EXPORT lean_obj_res lean_sdl_is_audio_device_playback(uint32_t devid, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(lean_box(SDL_IsAudioDevicePlayback((SDL_AudioDeviceID)devid)));
}

/* Sdl.AudioDeviceID.pauseRaw (devid : UInt32) : IO Unit -- C: SDL_PauseAudioDevice. */
LEAN_EXPORT lean_obj_res lean_sdl_pause_audio_device(uint32_t devid, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_BOOL_TO_IO(SDL_PauseAudioDevice((SDL_AudioDeviceID)devid));
}

/* Sdl.AudioDeviceID.resumeRaw (devid : UInt32) : IO Unit -- C: SDL_ResumeAudioDevice. */
LEAN_EXPORT lean_obj_res lean_sdl_resume_audio_device(uint32_t devid, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_BOOL_TO_IO(SDL_ResumeAudioDevice((SDL_AudioDeviceID)devid));
}

/* Sdl.AudioDeviceID.pausedRaw (devid : UInt32) : IO Bool
 * -- C: SDL_AudioDevicePaused (infallible: false for invalid/physical ids). */
LEAN_EXPORT lean_obj_res lean_sdl_audio_device_paused(uint32_t devid, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(lean_box(SDL_AudioDevicePaused((SDL_AudioDeviceID)devid)));
}

/* Sdl.AudioDeviceID.getGainRaw (devid : UInt32) : IO Float32
 * -- C: SDL_GetAudioDeviceGain (-1.0 -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_get_audio_device_gain(uint32_t devid, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    float g = SDL_GetAudioDeviceGain((SDL_AudioDeviceID)devid);
    if (g < 0.0f) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_box_float32(g));
}

/* Sdl.AudioDeviceID.setGainRaw (devid : UInt32) (gain : Float32) : IO Unit
 * -- C: SDL_SetAudioDeviceGain. */
LEAN_EXPORT lean_obj_res lean_sdl_set_audio_device_gain(
        uint32_t devid, float gain, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_BOOL_TO_IO(SDL_SetAudioDeviceGain((SDL_AudioDeviceID)devid, gain));
}

/* Sdl.AudioDeviceID.closeRaw (devid : UInt32) : IO Unit
 * -- C: SDL_CloseAudioDevice (void; only close ids you opened). Closing
 * unhooks any postmix callback, so its registry entry is released here (a
 * trampoline mid-flight already holds its own closure ref). */
LEAN_EXPORT lean_obj_res lean_sdl_close_audio_device(uint32_t devid, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_CloseAudioDevice((SDL_AudioDeviceID)devid);
    lean_sdl_audio_drop_postmix(devid);
    return lean_sdl_unit_ok();
}

/* Sdl.AudioDeviceID.bindStreamRaw (devid : UInt32) (stream : AudioStream)
 * : IO Unit -- C: SDL_BindAudioStream. */
LEAN_EXPORT lean_obj_res lean_sdl_bind_audio_stream(
        uint32_t devid, b_lean_obj_arg stream, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_AudioStream, s, stream);
    SDL_BOOL_TO_IO(SDL_BindAudioStream((SDL_AudioDeviceID)devid, s));
}

/* Sdl.AudioDeviceID.bindStreamsRaw (devid : UInt32) (streams : Array AudioStream)
 * : IO Unit -- C: SDL_BindAudioStreams (NULLed element -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_bind_audio_streams(
        uint32_t devid, b_lean_obj_arg streams, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    int count = 0;
    bool bad = false;
    SDL_AudioStream **arr = lean_sdl_stream_array(streams, &count, &bad);
    if (bad) return lean_sdl_throw_msg("SDL: handle used after destroy/release");
    bool ok = SDL_BindAudioStreams((SDL_AudioDeviceID)devid, arr, count);
    SDL_free(arr);
    if (!ok) return lean_sdl_throw();
    return lean_sdl_unit_ok();
}

/* ==================== AudioStream methods ==================== */

/* Sdl.AudioStream.destroy : IO Unit -- C: SDL_DestroyAudioStream (manual
 * destroy; NULL the ptr). Do NOT clear the slots here: destroy already unhooked
 * SDL-side, and the finalizer releases the closures. Destroying a stream from
 * openAudioDeviceStream also closes its device (SDL semantics). */
LEAN_EXPORT lean_obj_res lean_sdl_destroy_audio_stream(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    sdl_holder *h = lean_sdl_holder_of(self);
    if (!h->ptr) return lean_sdl_throw_msg("SDL: handle used after destroy/release");
    SDL_DestroyAudioStream((SDL_AudioStream *)h->ptr);
    h->ptr = NULL;
    return lean_sdl_unit_ok();
}

/* Sdl.AudioStream.getProperties : IO Properties -- C: SDL_GetAudioStreamProperties.
 * Borrowed Properties whose lifetime is tied to the stream (owner = inc'd
 * stream external). */
LEAN_EXPORT lean_obj_res lean_sdl_get_audio_stream_properties(
        b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_AudioStream, s, self);
    SDL_PropertiesID id = SDL_GetAudioStreamProperties(s);
    if (id == 0) return lean_sdl_throw();
    lean_inc(self);
    return lean_io_result_mk_ok(lean_sdl_wrap_properties_borrowed(id, (lean_object *)self));
}

/* Sdl.AudioStream.getFormat : IO (AudioSpec x AudioSpec)
 * -- C: SDL_GetAudioStreamFormat (src x dst). */
LEAN_EXPORT lean_obj_res lean_sdl_get_audio_stream_format(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_AudioStream, s, self);
    SDL_AudioSpec src, dst;
    if (!SDL_GetAudioStreamFormat(s, &src, &dst)) return lean_sdl_throw();
    return lean_io_result_mk_ok(
        lean_sdl_pair(lean_sdl_audio_spec_obj(&src), lean_sdl_audio_spec_obj(&dst)));
}

/* Sdl.AudioStream.setFormatRaw : IO Unit -- C: SDL_SetAudioStreamFormat
 * (a NULL spec leaves that side unchanged). */
LEAN_EXPORT lean_obj_res lean_sdl_set_audio_stream_format(
        b_lean_obj_arg self,
        uint8_t has_src, uint32_t src_format, int32_t src_channels, int32_t src_freq,
        uint8_t has_dst, uint32_t dst_format, int32_t dst_channels, int32_t dst_freq,
        lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_AudioStream, s, self);
    SDL_AudioSpec ss = { (SDL_AudioFormat)src_format, (int)src_channels, (int)src_freq };
    SDL_AudioSpec ds = { (SDL_AudioFormat)dst_format, (int)dst_channels, (int)dst_freq };
    SDL_BOOL_TO_IO(SDL_SetAudioStreamFormat(s, has_src ? &ss : NULL, has_dst ? &ds : NULL));
}

/* Sdl.AudioStream.getFrequencyRatio : IO Float32
 * -- C: SDL_GetAudioStreamFrequencyRatio (0.0 -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_get_audio_stream_frequency_ratio(
        b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_AudioStream, s, self);
    float r = SDL_GetAudioStreamFrequencyRatio(s);
    if (r == 0.0f) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_box_float32(r));
}

/* Sdl.AudioStream.setFrequencyRatio (ratio : Float32) : IO Unit
 * -- C: SDL_SetAudioStreamFrequencyRatio. */
LEAN_EXPORT lean_obj_res lean_sdl_set_audio_stream_frequency_ratio(
        b_lean_obj_arg self, float ratio, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_AudioStream, s, self);
    SDL_BOOL_TO_IO(SDL_SetAudioStreamFrequencyRatio(s, ratio));
}

/* Sdl.AudioStream.getGain : IO Float32 -- C: SDL_GetAudioStreamGain (-1.0 -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_get_audio_stream_gain(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_AudioStream, s, self);
    float g = SDL_GetAudioStreamGain(s);
    if (g < 0.0f) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_box_float32(g));
}

/* Sdl.AudioStream.setGain (gain : Float32) : IO Unit -- C: SDL_SetAudioStreamGain. */
LEAN_EXPORT lean_obj_res lean_sdl_set_audio_stream_gain(
        b_lean_obj_arg self, float gain, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_AudioStream, s, self);
    SDL_BOOL_TO_IO(SDL_SetAudioStreamGain(s, gain));
}

/* Sdl.AudioStream.getInputChannelMap : IO (Option (Array Int32))
 * -- C: SDL_GetAudioStreamInputChannelMap (NULL -> none). */
LEAN_EXPORT lean_obj_res lean_sdl_get_audio_stream_input_channel_map(
        b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_AudioStream, s, self);
    int count = 0;
    int *map = SDL_GetAudioStreamInputChannelMap(s, &count);
    return lean_io_result_mk_ok(lean_sdl_int_array_option(map, count));
}

/* Sdl.AudioStream.getOutputChannelMap : IO (Option (Array Int32))
 * -- C: SDL_GetAudioStreamOutputChannelMap (NULL -> none). */
LEAN_EXPORT lean_obj_res lean_sdl_get_audio_stream_output_channel_map(
        b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_AudioStream, s, self);
    int count = 0;
    int *map = SDL_GetAudioStreamOutputChannelMap(s, &count);
    return lean_io_result_mk_ok(lean_sdl_int_array_option(map, count));
}

/* Sdl.AudioStream.setInputChannelMap (chmap : Option (Array Int32)) : IO Unit
 * -- C: SDL_SetAudioStreamInputChannelMap (SDL copies it). For a `none` reset
 * SDL still requires count == the input channel count (it validates count
 * before honoring a NULL map), so query the stream's format for it. */
LEAN_EXPORT lean_obj_res lean_sdl_set_audio_stream_input_channel_map(
        b_lean_obj_arg self, b_lean_obj_arg chmap, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_AudioStream, s, self);
    int count = 0;
    int *map = NULL;
    if (lean_is_scalar(chmap)) {
        SDL_AudioSpec src, dst;
        if (!SDL_GetAudioStreamFormat(s, &src, &dst)) return lean_sdl_throw();
        count = src.channels;
    } else {
        map = lean_sdl_build_int_map(chmap, &count);
    }
    bool ok = SDL_SetAudioStreamInputChannelMap(s, map, count);
    SDL_free(map);
    if (!ok) return lean_sdl_throw();
    return lean_sdl_unit_ok();
}

/* Sdl.AudioStream.setOutputChannelMap (chmap : Option (Array Int32)) : IO Unit
 * -- C: SDL_SetAudioStreamOutputChannelMap (SDL copies it). A `none` reset needs
 * count == the output channel count, like setInputChannelMap. */
LEAN_EXPORT lean_obj_res lean_sdl_set_audio_stream_output_channel_map(
        b_lean_obj_arg self, b_lean_obj_arg chmap, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_AudioStream, s, self);
    int count = 0;
    int *map = NULL;
    if (lean_is_scalar(chmap)) {
        SDL_AudioSpec src, dst;
        if (!SDL_GetAudioStreamFormat(s, &src, &dst)) return lean_sdl_throw();
        count = dst.channels;
    } else {
        map = lean_sdl_build_int_map(chmap, &count);
    }
    bool ok = SDL_SetAudioStreamOutputChannelMap(s, map, count);
    SDL_free(map);
    if (!ok) return lean_sdl_throw();
    return lean_sdl_unit_ok();
}

/* Sdl.AudioStream.putData (data : ByteArray) : IO Unit -- C: SDL_PutAudioStreamData. */
LEAN_EXPORT lean_obj_res lean_sdl_put_audio_stream_data(
        b_lean_obj_arg self, b_lean_obj_arg data, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_AudioStream, s, self);
    size_t n = lean_sarray_size(data);
    SDL_BOOL_TO_IO(SDL_PutAudioStreamData(s, lean_sarray_cptr((lean_object *)data), (int)n));
}

/* Sdl.AudioStream.putDataF32 (samples : FloatArray) : IO Unit -- convenience over
 * C: SDL_PutAudioStreamData. Narrows each Lean 64-bit float to a 32-bit
 * SDL_AUDIO_F32 sample in a temp buffer; the stream's input format must be
 * f32le. */
LEAN_EXPORT lean_obj_res lean_sdl_put_audio_stream_data_f32(
        b_lean_obj_arg self, b_lean_obj_arg samples, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_AudioStream, s, self);
    size_t n = lean_sarray_size(samples);            /* element count (doubles) */
    const double *src = lean_float_array_cptr(samples);
    float *buf = (float *)SDL_malloc(n ? n * sizeof(float) : 1);
    for (size_t i = 0; i < n; i++) buf[i] = (float)src[i];
    bool ok = SDL_PutAudioStreamData(s, buf, (int)(n * sizeof(float)));
    SDL_free(buf);
    if (!ok) return lean_sdl_throw();
    return lean_sdl_unit_ok();
}

/* Sdl.AudioStream.putPlanarData (channels : Array (Option ByteArray))
 * (numSamples : Int32) : IO Unit -- C: SDL_PutAudioStreamPlanarData. A none
 * channel is a NULL buffer (silence); num_channels = channels.size. */
LEAN_EXPORT lean_obj_res lean_sdl_put_audio_stream_planar_data(
        b_lean_obj_arg self, b_lean_obj_arg channels, int32_t num_samples, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_AudioStream, s, self);
    size_t n = lean_array_size(channels);
    const void **bufs = (const void **)SDL_malloc(n ? n * sizeof(const void *) : 1);
    for (size_t i = 0; i < n; i++) {
        lean_object *opt = lean_array_get_core(channels, i);
        bufs[i] = lean_is_scalar(opt) ? NULL : (const void *)lean_sarray_cptr(lean_ctor_get(opt, 0));
    }
    bool ok = SDL_PutAudioStreamPlanarData(s, bufs, (int)n, (int)num_samples);
    SDL_free(bufs);
    if (!ok) return lean_sdl_throw();
    return lean_sdl_unit_ok();
}

/* Sdl.AudioStream.getData (maxBytes : Int32) : IO ByteArray
 * -- C: SDL_GetAudioStreamData (alloc maxBytes, shrink to result; maxBytes < 0
 * or a negative result -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_get_audio_stream_data(
        b_lean_obj_arg self, int32_t max_bytes, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_AudioStream, s, self);
    if (max_bytes < 0)
        return lean_sdl_throw_msg("SDL: getData maxBytes must be non-negative");
    lean_object *arr = lean_alloc_sarray(1, (size_t)max_bytes, (size_t)max_bytes);
    int n = SDL_GetAudioStreamData(s, lean_sarray_cptr(arr), (int)max_bytes);
    if (n < 0) { lean_dec(arr); return lean_sdl_throw(); }
    lean_sarray_set_size(arr, (size_t)n);
    return lean_io_result_mk_ok(arr);
}

/* Sdl.AudioStream.available : IO Int32
 * -- C: SDL_GetAudioStreamAvailable (-1 -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_get_audio_stream_available(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_AudioStream, s, self);
    int a = SDL_GetAudioStreamAvailable(s);
    if (a < 0) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)a));
}

/* Sdl.AudioStream.queued : IO Int32 -- C: SDL_GetAudioStreamQueued (-1 -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_get_audio_stream_queued(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_AudioStream, s, self);
    int q = SDL_GetAudioStreamQueued(s);
    if (q < 0) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)q));
}

/* Sdl.AudioStream.flush : IO Unit -- C: SDL_FlushAudioStream. */
LEAN_EXPORT lean_obj_res lean_sdl_flush_audio_stream(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_AudioStream, s, self);
    SDL_BOOL_TO_IO(SDL_FlushAudioStream(s));
}

/* Sdl.AudioStream.clear : IO Unit -- C: SDL_ClearAudioStream. */
LEAN_EXPORT lean_obj_res lean_sdl_clear_audio_stream(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_AudioStream, s, self);
    SDL_BOOL_TO_IO(SDL_ClearAudioStream(s));
}

/* Sdl.AudioStream.pauseDevice : IO Unit -- C: SDL_PauseAudioStreamDevice. */
LEAN_EXPORT lean_obj_res lean_sdl_pause_audio_stream_device(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_AudioStream, s, self);
    SDL_BOOL_TO_IO(SDL_PauseAudioStreamDevice(s));
}

/* Sdl.AudioStream.resumeDevice : IO Unit -- C: SDL_ResumeAudioStreamDevice. */
LEAN_EXPORT lean_obj_res lean_sdl_resume_audio_stream_device(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_AudioStream, s, self);
    SDL_BOOL_TO_IO(SDL_ResumeAudioStreamDevice(s));
}

/* Sdl.AudioStream.devicePaused : IO Bool
 * -- C: SDL_AudioStreamDevicePaused (infallible). */
LEAN_EXPORT lean_obj_res lean_sdl_audio_stream_device_paused(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_AudioStream, s, self);
    return lean_io_result_mk_ok(lean_box(SDL_AudioStreamDevicePaused(s)));
}

/* Sdl.AudioStream.lock : IO Unit -- C: SDL_LockAudioStream. */
LEAN_EXPORT lean_obj_res lean_sdl_lock_audio_stream(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_AudioStream, s, self);
    SDL_BOOL_TO_IO(SDL_LockAudioStream(s));
}

/* Sdl.AudioStream.unlock : IO Unit -- C: SDL_UnlockAudioStream. */
LEAN_EXPORT lean_obj_res lean_sdl_unlock_audio_stream(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_AudioStream, s, self);
    SDL_BOOL_TO_IO(SDL_UnlockAudioStream(s));
}

/* Sdl.AudioStream.unbind : IO Unit -- C: SDL_UnbindAudioStream (void). */
LEAN_EXPORT lean_obj_res lean_sdl_unbind_audio_stream(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_AudioStream, s, self);
    SDL_UnbindAudioStream(s);
    return lean_sdl_unit_ok();
}

/* Sdl.AudioStream.getDeviceRaw : IO UInt32
 * -- C: SDL_GetAudioStreamDevice (0 = unbound; Lean maps to none). */
LEAN_EXPORT lean_obj_res lean_sdl_get_audio_stream_device(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_AudioStream, s, self);
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)SDL_GetAudioStreamDevice(s)));
}

/* ==================== Stream get/put callbacks ==================== */
/* Locked slot in the stream's holder (docs/DESIGN.md "Callbacks" #2). The SDL
 * userdata is the holder pointer: it stays valid until the finalizer frees it,
 * and SDL_DestroyAudioStream (manual destroy or finalizer) unhooks both
 * callbacks before the closures are released. */

SDL_DEFINE_BORROWED_CLASS(lean_sdl_audio_stream_borrowed)

/* Acquire the slot's closure and apply it as (stream, additional, total). The
 * stream argument is a fresh borrowed-class wrapper whose ptr is NULLed when
 * the callback returns: a stored handle throws afterwards, never dangles. A
 * Lean exception has nowhere to propagate and is swallowed (SDL then proceeds
 * with whatever data the stream has). */
static void lean_sdl_stream_cb_dispatch(sdl_cb_slot *slot, SDL_AudioStream *stream,
                                        int additional, int total) {
    lean_sdl_ensure_thread();
    lean_object *fn = lean_sdl_slot_acquire(slot);
    if (!fn) return; /* cleared mid-dispatch */
    lean_object *wrapper = lean_sdl_wrap(lean_sdl_audio_stream_borrowed_class, stream, NULL);
    lean_inc(wrapper); /* survive the apply so the ptr can be invalidated */
    lean_sdl_io_ignore(lean_apply_4(fn, wrapper,
        lean_box_uint32((uint32_t)additional), lean_box_uint32((uint32_t)total),
        lean_box(0)));
    lean_sdl_holder_of(wrapper)->ptr = NULL; /* invalidate escaped copies */
    lean_dec(wrapper);
}

static void SDLCALL lean_sdl_stream_get_tramp(void *userdata, SDL_AudioStream *stream,
                                              int additional, int total) {
    sdl_audio_stream_holder *h = (sdl_audio_stream_holder *)userdata;
    lean_sdl_stream_cb_dispatch(&h->get_cb, stream, additional, total);
}

static void SDLCALL lean_sdl_stream_put_tramp(void *userdata, SDL_AudioStream *stream,
                                              int additional, int total) {
    sdl_audio_stream_holder *h = (sdl_audio_stream_holder *)userdata;
    lean_sdl_stream_cb_dispatch(&h->put_cb, stream, additional, total);
}

/* Install/replace/remove one of the two stream callbacks. Install order is
 * slot first, SDL hook second (an early callback finding the new closure is
 * correct); removal is SDL unhook first, slot clear second (a trampoline
 * mid-flight already holds its own closure ref — the log.c pattern). Both SDL
 * set-callback calls take the stream lock, so replacement synchronizes with a
 * running callback. */
static lean_obj_res lean_sdl_set_stream_cb(b_lean_obj_arg strm, lean_obj_arg opt_fn, bool get) {
    sdl_audio_stream_holder *h = (sdl_audio_stream_holder *)lean_get_external_data(strm);
    if (!h->ptr) {
        lean_dec(opt_fn);
        return lean_sdl_throw_msg("SDL: handle used after destroy/release");
    }
    SDL_AudioStream *s = (SDL_AudioStream *)h->ptr;
    sdl_cb_slot *slot = get ? &h->get_cb : &h->put_cb;
    lean_object *fn = lean_sdl_option_take(opt_fn);
    if (fn) {
        lean_sdl_slot_set(slot, fn);
        bool ok = get ? SDL_SetAudioStreamGetCallback(s, lean_sdl_stream_get_tramp, h)
                      : SDL_SetAudioStreamPutCallback(s, lean_sdl_stream_put_tramp, h);
        if (!ok) { lean_sdl_slot_clear(slot); return lean_sdl_throw(); }
    } else {
        bool ok = get ? SDL_SetAudioStreamGetCallback(s, NULL, NULL)
                      : SDL_SetAudioStreamPutCallback(s, NULL, NULL);
        if (!ok) return lean_sdl_throw();
        lean_sdl_slot_clear(slot);
    }
    return lean_sdl_unit_ok();
}

/* Sdl.AudioStream.setGetCallback
 * (cb : Option (AudioStream -> Int32 -> Int32 -> IO Unit)) : IO Unit
 * -- C: SDL_SetAudioStreamGetCallback. */
LEAN_EXPORT lean_obj_res lean_sdl_set_audio_stream_get_callback(
        b_lean_obj_arg strm, lean_obj_arg opt_fn, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_sdl_set_stream_cb(strm, opt_fn, true);
}

/* Sdl.AudioStream.setPutCallback
 * (cb : Option (AudioStream -> Int32 -> Int32 -> IO Unit)) : IO Unit
 * -- C: SDL_SetAudioStreamPutCallback. */
LEAN_EXPORT lean_obj_res lean_sdl_set_audio_stream_put_callback(
        b_lean_obj_arg strm, lean_obj_arg opt_fn, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_sdl_set_stream_cb(strm, opt_fn, false);
}

/* ==================== Device postmix callback ==================== */
/* Gen-key registry (docs/DESIGN.md "Callbacks" #1) with aux = device id, so
 * replacement and AudioDeviceID.close can drop the entry. The SDL userdata is
 * the non-pointer key, never freeable memory. */

static sdl_cb_registry lean_sdl_postmix_registry;

static void lean_sdl_audio_drop_postmix(uint32_t devid) {
    lean_object *fn;
    uint64_t key;
    if (lean_sdl_cb_take_by_aux(&lean_sdl_postmix_registry, (uintptr_t)devid, &fn, &key))
        lean_dec(fn);
}

/* Registered closure: AudioSpec -> FloatArray -> IO FloatArray. Widens the
 * mixed float buffer into a FloatArray, applies, and narrows up to buflen
 * bytes of the result back. On a Lean exception the buffer is left as SDL
 * mixed it. Runs on the device thread. */
static void SDLCALL lean_sdl_postmix_tramp(void *userdata, const SDL_AudioSpec *spec,
                                           float *buffer, int buflen) {
    lean_sdl_ensure_thread();
    lean_object *fn = lean_sdl_cb_acquire(&lean_sdl_postmix_registry,
                                          (uint64_t)(uintptr_t)userdata);
    if (!fn) return; /* removed mid-dispatch */
    size_t n = buflen > 0 ? (size_t)buflen / sizeof(float) : 0;
    lean_object *arr = lean_alloc_sarray(sizeof(double), n, n);
    double *d = lean_float_array_cptr(arr);
    for (size_t i = 0; i < n; i++) d[i] = (double)buffer[i];
    lean_object *res = lean_apply_3(fn, lean_sdl_audio_spec_obj(spec), arr, lean_box(0));
    if (lean_io_result_is_ok(res)) {
        lean_object *out = lean_io_result_get_value(res); /* borrowed from res */
        size_t m = lean_sarray_size(out);
        if (m > n) m = n;
        const double *od = lean_float_array_cptr(out);
        for (size_t i = 0; i < m; i++) buffer[i] = (float)od[i];
    }
    lean_dec(res);
}

/* Sdl.AudioDeviceID.setPostmixCallbackRaw (devid : UInt32)
 * (cb : Option (AudioSpec -> FloatArray -> IO FloatArray)) : IO Unit
 * -- C: SDL_SetAudioPostmixCallback. Replacement drops the previous entry
 * before registering the new one; a postmix firing in that gap finds no entry
 * and no-ops (silence-preserving, matching SDL's own replace semantics). */
LEAN_EXPORT lean_obj_res lean_sdl_set_audio_postmix_callback(
        uint32_t devid, lean_obj_arg opt_fn, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    lean_object *fn = lean_sdl_option_take(opt_fn);
    lean_sdl_audio_drop_postmix(devid);
    if (fn) {
        uint64_t key = lean_sdl_cb_register(&lean_sdl_postmix_registry, fn, (uintptr_t)devid);
        if (!SDL_SetAudioPostmixCallback((SDL_AudioDeviceID)devid, lean_sdl_postmix_tramp,
                                         (void *)(uintptr_t)key)) {
            lean_object *f2;
            uintptr_t aux;
            if (lean_sdl_cb_take(&lean_sdl_postmix_registry, key, &f2, &aux)) lean_dec(f2);
            return lean_sdl_throw();
        }
    } else {
        if (!SDL_SetAudioPostmixCallback((SDL_AudioDeviceID)devid, NULL, NULL))
            return lean_sdl_throw();
    }
    return lean_sdl_unit_ok();
}
