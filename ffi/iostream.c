/* Shims for Sdl/IOStream.lean (SDL_iostream.h).
 *
 * One external class over the Lean `IOStream` type:
 *   - lean_sdl_iostream : owned (SDL_IOFromFile/ConstMem/DynamicMem) -> finalizer
 *     runs SDL_CloseIO(ptr) (ignoring the bool result). `IOStream.close` is a
 *     manual close (files need a prompt flush); it NULLs the holder ptr EVEN on
 *     failure, because SDL frees the stream regardless (see SDL_CloseIO docs),
 *     so the finalizer then skips.
 *
 * ioFromConstMem stores the source ByteArray object as the holder's `owner` so
 * the buffer (ptr = lean_sarray_cptr) outlives the read-only stream; the
 * finalizer closes the stream then decs the ByteArray. Read-only aliasing of a
 * possibly-shared ByteArray is sound (Lean copy-on-write).
 *
 * All *_IO calls pass closeio=false: Lean owns the stream lifetime. */
#include "util.h"
#include "classes.h"

/* Owned: SDL_CloseIO on finalize (bool result ignored). */
SDL_DEFINE_CLASS(lean_sdl_iostream, SDL_CloseIO((SDL_IOStream *)self))
/* Borrowed (e.g. a process's stdin/stdout): never closed, only decs the owner.
 * Used by ffi/process.c via lean_sdl_wrap_iostream_borrowed (classes.h). */
SDL_DEFINE_BORROWED_CLASS(lean_sdl_iostream_borrowed)

/* Register both classes. Called from Sdl/IOStream.lean's `initialize`. */
LEAN_EXPORT lean_obj_res lean_sdl_iostream_register_classes(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    lean_sdl_iostream_class_init();
    lean_sdl_iostream_borrowed_class_init();
    return lean_sdl_unit_ok();
}

/* ---------- Constructors ---------- */

/* Sdl.ioFromFile (file mode : String) : IO IOStream -- C: SDL_IOFromFile */
LEAN_EXPORT lean_obj_res lean_sdl_io_from_file(
        b_lean_obj_arg file, b_lean_obj_arg mode, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_IOStream *s = SDL_IOFromFile(lean_string_cstr(file), lean_string_cstr(mode));
    if (!s) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_wrap(lean_sdl_iostream_class, s, NULL));
}

/* Sdl.ioFromConstMem (data : ByteArray) : IO IOStream -- C: SDL_IOFromConstMem.
 * `data` is OWNED: we keep it as the holder's owner so the buffer outlives the
 * stream. On failure we must dec it ourselves. */
LEAN_EXPORT lean_obj_res lean_sdl_io_from_const_mem(lean_obj_arg data, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    size_t size = lean_sarray_size(data);
    const void *mem = lean_sarray_cptr(data);
    SDL_IOStream *s = SDL_IOFromConstMem(mem, size);
    if (!s) {
        lean_dec(data);
        return lean_sdl_throw();
    }
    return lean_io_result_mk_ok(lean_sdl_wrap(lean_sdl_iostream_class, s, data));
}

/* Sdl.ioFromDynamicMem : IO IOStream -- C: SDL_IOFromDynamicMem */
LEAN_EXPORT lean_obj_res lean_sdl_io_from_dynamic_mem(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_IOStream *s = SDL_IOFromDynamicMem();
    if (!s) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_wrap(lean_sdl_iostream_class, s, NULL));
}

/* ---------- Methods ---------- */

/* Sdl.IOStream.close : IO Unit -- C: SDL_CloseIO. Manual close: throws on a
 * flush failure but NULLs the ptr either way (SDL frees the stream regardless),
 * so the finalizer skips and later use is an IO error. */
LEAN_EXPORT lean_obj_res lean_sdl_close_io(b_lean_obj_arg io, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    if (lean_get_external_class((lean_object *)io) == lean_sdl_iostream_borrowed_class)
        return lean_sdl_throw_msg("SDL: cannot close a borrowed stream");
    sdl_holder *h = lean_sdl_holder_of(io);
    if (!h->ptr)
        return lean_sdl_throw_msg("SDL: handle used after destroy/release");
    bool ok = SDL_CloseIO((SDL_IOStream *)h->ptr);
    h->ptr = NULL;
    if (!ok) return lean_sdl_throw();
    return lean_sdl_unit_ok();
}

/* Sdl.IOStream.getProperties : IO Properties -- C: SDL_GetIOProperties.
 * Borrowed Properties whose lifetime is tied to the stream (owner = inc'd
 * stream external). */
LEAN_EXPORT lean_obj_res lean_sdl_get_io_properties(b_lean_obj_arg io, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_IOStream, s, io);
    SDL_PropertiesID id = SDL_GetIOProperties(s);
    if (id == 0) return lean_sdl_throw();
    lean_inc(io);
    return lean_io_result_mk_ok(lean_sdl_wrap_properties_borrowed(id, io));
}

/* Sdl.IOStream.getIOStatusRaw : IO UInt32 -- C: SDL_GetIOStatus (infallible). */
LEAN_EXPORT lean_obj_res lean_sdl_get_io_status(b_lean_obj_arg io, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_IOStream, s, io);
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)SDL_GetIOStatus(s)));
}

/* Sdl.IOStream.size : IO Int64 -- C: SDL_GetIOSize (negative -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_get_io_size(b_lean_obj_arg io, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_IOStream, s, io);
    Sint64 sz = SDL_GetIOSize(s);
    if (sz < 0) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_box_uint64((uint64_t)sz));
}

/* Sdl.IOStream.seekRaw (offset : Int64) (whence : UInt32) : IO Int64
 * -- C: SDL_SeekIO (-1 -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_seek_io(
        b_lean_obj_arg io, int64_t offset, uint32_t whence, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_IOStream, s, io);
    Sint64 r = SDL_SeekIO(s, (Sint64)offset, (SDL_IOWhence)whence);
    if (r < 0) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_box_uint64((uint64_t)r));
}

/* Sdl.IOStream.tell : IO Int64 -- C: SDL_TellIO (-1 -> throw). */
LEAN_EXPORT lean_obj_res lean_sdl_tell_io(b_lean_obj_arg io, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_IOStream, s, io);
    Sint64 r = SDL_TellIO(s);
    if (r < 0) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_box_uint64((uint64_t)r));
}

/* Sdl.IOStream.read (maxBytes : USize) : IO ByteArray -- C: SDL_ReadIO.
 * Allocate `max_bytes`, read, then set the sarray size to the actual count; a
 * short read of 0 is EOF/empty unless the status is ERROR (then throw). */
LEAN_EXPORT lean_obj_res lean_sdl_read_io(
        b_lean_obj_arg io, size_t max_bytes, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_IOStream, s, io);
    lean_object *arr = lean_alloc_sarray(1, max_bytes, max_bytes);
    size_t n = SDL_ReadIO(s, lean_sarray_cptr(arr), max_bytes);
    if (n == 0 && SDL_GetIOStatus(s) == SDL_IO_STATUS_ERROR) {
        lean_dec(arr);
        return lean_sdl_throw();
    }
    lean_sarray_set_size(arr, n);
    return lean_io_result_mk_ok(arr);
}

/* Sdl.IOStream.write (data : @& ByteArray) : IO Unit -- C: SDL_WriteIO
 * (throw if fewer than `size` bytes were written). */
LEAN_EXPORT lean_obj_res lean_sdl_write_io(
        b_lean_obj_arg io, b_lean_obj_arg data, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_IOStream, s, io);
    size_t size = lean_sarray_size(data);
    size_t n = SDL_WriteIO(s, lean_sarray_cptr((lean_object *)data), size);
    if (n < size) return lean_sdl_throw();
    return lean_sdl_unit_ok();
}

/* Sdl.IOStream.flush : IO Unit -- C: SDL_FlushIO. */
LEAN_EXPORT lean_obj_res lean_sdl_flush_io(b_lean_obj_arg io, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_IOStream, s, io);
    SDL_BOOL_TO_IO(SDL_FlushIO(s));
}

/* Sdl.IOStream.loadFile : IO ByteArray -- C: SDL_LoadFile_IO (closeio=false).
 * The SDL-owned buffer is copied into a fresh sarray then freed. */
LEAN_EXPORT lean_obj_res lean_sdl_load_file_io(b_lean_obj_arg io, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_IOStream, s, io);
    size_t datasize = 0;
    void *data = SDL_LoadFile_IO(s, &datasize, false);
    if (!data) return lean_sdl_throw();
    lean_object *arr = lean_alloc_sarray(1, datasize, datasize);
    if (datasize) SDL_memcpy(lean_sarray_cptr(arr), data, datasize);
    SDL_free(data);
    return lean_io_result_mk_ok(arr);
}

/* Sdl.IOStream.saveFile (data : @& ByteArray) : IO Unit
 * -- C: SDL_SaveFile_IO (closeio=false). */
LEAN_EXPORT lean_obj_res lean_sdl_save_file_io(
        b_lean_obj_arg io, b_lean_obj_arg data, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_IOStream, s, io);
    size_t size = lean_sarray_size(data);
    SDL_BOOL_TO_IO(SDL_SaveFile_IO(s, lean_sarray_cptr((lean_object *)data), size, false));
}

/* ---------- Endian read/write helpers ----------
 * Each read returns false at EOF too; we surface that as an IO error (the Lean
 * doc comments note EOF is included). Boxing follows the scalar width. */

#define IO_READ(name, sdlfn, ctype, boxexpr)                                   \
    LEAN_EXPORT lean_obj_res name(b_lean_obj_arg io, lean_obj_arg w) {          \
        (void)w;                                                               \
        SDL_SHIM_PROLOGUE();                                                   \
        SDL_GET_OR_THROW(SDL_IOStream, s, io);                                 \
        ctype v = 0;                                                           \
        if (!sdlfn(s, &v)) return lean_sdl_throw();                            \
        return lean_io_result_mk_ok(boxexpr);                                  \
    }

#define IO_WRITE(name, sdlfn, ptype, sdltype)                                  \
    LEAN_EXPORT lean_obj_res name(                                             \
            b_lean_obj_arg io, ptype value, lean_obj_arg w) {                  \
        (void)w;                                                               \
        SDL_SHIM_PROLOGUE();                                                   \
        SDL_GET_OR_THROW(SDL_IOStream, s, io);                                 \
        SDL_BOOL_TO_IO(sdlfn(s, (sdltype)value));                             \
    }

/* Sdl.IOStream.readU8/readS8/... -- C: SDL_ReadU8/SDL_ReadS8/... */
IO_READ(lean_sdl_read_u8,    SDL_ReadU8,    Uint8,  lean_box(v))
IO_READ(lean_sdl_read_s8,    SDL_ReadS8,    Sint8,  lean_box((uint8_t)v))
IO_READ(lean_sdl_read_u16le, SDL_ReadU16LE, Uint16, lean_box(v))
IO_READ(lean_sdl_read_s16le, SDL_ReadS16LE, Sint16, lean_box((uint16_t)v))
IO_READ(lean_sdl_read_u16be, SDL_ReadU16BE, Uint16, lean_box(v))
IO_READ(lean_sdl_read_s16be, SDL_ReadS16BE, Sint16, lean_box((uint16_t)v))
IO_READ(lean_sdl_read_u32le, SDL_ReadU32LE, Uint32, lean_box_uint32(v))
IO_READ(lean_sdl_read_s32le, SDL_ReadS32LE, Sint32, lean_box_uint32((uint32_t)v))
IO_READ(lean_sdl_read_u32be, SDL_ReadU32BE, Uint32, lean_box_uint32(v))
IO_READ(lean_sdl_read_s32be, SDL_ReadS32BE, Sint32, lean_box_uint32((uint32_t)v))
IO_READ(lean_sdl_read_u64le, SDL_ReadU64LE, Uint64, lean_box_uint64(v))
IO_READ(lean_sdl_read_s64le, SDL_ReadS64LE, Sint64, lean_box_uint64((uint64_t)v))
IO_READ(lean_sdl_read_u64be, SDL_ReadU64BE, Uint64, lean_box_uint64(v))
IO_READ(lean_sdl_read_s64be, SDL_ReadS64BE, Sint64, lean_box_uint64((uint64_t)v))

/* Sdl.IOStream.writeU8/writeS8/... -- C: SDL_WriteU8/SDL_WriteS8/... */
IO_WRITE(lean_sdl_write_u8,    SDL_WriteU8,    uint8_t,  Uint8)
IO_WRITE(lean_sdl_write_s8,    SDL_WriteS8,    int8_t,   Sint8)
IO_WRITE(lean_sdl_write_u16le, SDL_WriteU16LE, uint16_t, Uint16)
IO_WRITE(lean_sdl_write_s16le, SDL_WriteS16LE, int16_t,  Sint16)
IO_WRITE(lean_sdl_write_u16be, SDL_WriteU16BE, uint16_t, Uint16)
IO_WRITE(lean_sdl_write_s16be, SDL_WriteS16BE, int16_t,  Sint16)
IO_WRITE(lean_sdl_write_u32le, SDL_WriteU32LE, uint32_t, Uint32)
IO_WRITE(lean_sdl_write_s32le, SDL_WriteS32LE, int32_t,  Sint32)
IO_WRITE(lean_sdl_write_u32be, SDL_WriteU32BE, uint32_t, Uint32)
IO_WRITE(lean_sdl_write_s32be, SDL_WriteS32BE, int32_t,  Sint32)
IO_WRITE(lean_sdl_write_u64le, SDL_WriteU64LE, uint64_t, Uint64)
IO_WRITE(lean_sdl_write_s64le, SDL_WriteS64LE, int64_t,  Sint64)
IO_WRITE(lean_sdl_write_u64be, SDL_WriteU64BE, uint64_t, Uint64)
IO_WRITE(lean_sdl_write_s64be, SDL_WriteS64BE, int64_t,  Sint64)

/* ---------- Top-level file helpers ---------- */

/* Sdl.loadFile (path : String) : IO ByteArray -- C: SDL_LoadFile. */
LEAN_EXPORT lean_obj_res lean_sdl_load_file(b_lean_obj_arg file, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    size_t datasize = 0;
    void *data = SDL_LoadFile(lean_string_cstr(file), &datasize);
    if (!data) return lean_sdl_throw();
    lean_object *arr = lean_alloc_sarray(1, datasize, datasize);
    if (datasize) SDL_memcpy(lean_sarray_cptr(arr), data, datasize);
    SDL_free(data);
    return lean_io_result_mk_ok(arr);
}

/* Sdl.saveFile (path : String) (data : @& ByteArray) : IO Unit
 * -- C: SDL_SaveFile. */
LEAN_EXPORT lean_obj_res lean_sdl_save_file(
        b_lean_obj_arg file, b_lean_obj_arg data, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    size_t size = lean_sarray_size(data);
    SDL_BOOL_TO_IO(SDL_SaveFile(lean_string_cstr(file),
                                lean_sarray_cptr((lean_object *)data), size));
}
