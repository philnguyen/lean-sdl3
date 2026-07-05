/* Shims for Sdl/Init.lean (SDL_init.h, SDL_version.h, SDL_platform.h). */
#include "util.h"

/* Sdl.init (flags : UInt32) : IO Unit -- C: SDL_Init */
LEAN_EXPORT lean_obj_res lean_sdl_init(uint32_t flags, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_BOOL_TO_IO(SDL_Init((SDL_InitFlags)flags));
}

/* Sdl.initSubSystem -- C: SDL_InitSubSystem */
LEAN_EXPORT lean_obj_res lean_sdl_init_sub_system(uint32_t flags, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_BOOL_TO_IO(SDL_InitSubSystem((SDL_InitFlags)flags));
}

/* Sdl.quitSubSystem -- C: SDL_QuitSubSystem */
LEAN_EXPORT lean_obj_res lean_sdl_quit_sub_system(uint32_t flags, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_QuitSubSystem((SDL_InitFlags)flags);
    return lean_sdl_unit_ok();
}

/* Sdl.wasInit -- C: SDL_WasInit */
LEAN_EXPORT lean_obj_res lean_sdl_was_init(uint32_t flags, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)SDL_WasInit((SDL_InitFlags)flags)));
}

/* Sdl.quit : IO Unit -- C: SDL_Quit */
LEAN_EXPORT lean_obj_res lean_sdl_quit(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_Quit();
    return lean_sdl_unit_ok();
}

/* Sdl.isMainThread : IO Bool -- C: SDL_IsMainThread */
LEAN_EXPORT lean_obj_res lean_sdl_is_main_thread(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(lean_box(SDL_IsMainThread()));
}

/* Sdl.setAppMetadata -- C: SDL_SetAppMetadata */
LEAN_EXPORT lean_obj_res lean_sdl_set_app_metadata(
        b_lean_obj_arg name, b_lean_obj_arg version, b_lean_obj_arg identifier,
        lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_BOOL_TO_IO(SDL_SetAppMetadata(lean_string_cstr(name),
                                      lean_string_cstr(version),
                                      lean_string_cstr(identifier)));
}

/* Sdl.setAppMetadataProperty -- C: SDL_SetAppMetadataProperty */
LEAN_EXPORT lean_obj_res lean_sdl_set_app_metadata_property(
        b_lean_obj_arg name, b_lean_obj_arg value, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_BOOL_TO_IO(SDL_SetAppMetadataProperty(lean_string_cstr(name),
                                              lean_string_cstr(value)));
}

/* Sdl.getAppMetadataProperty -- C: SDL_GetAppMetadataProperty */
LEAN_EXPORT lean_obj_res lean_sdl_get_app_metadata_property(
        b_lean_obj_arg name, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(
        lean_sdl_option_string(SDL_GetAppMetadataProperty(lean_string_cstr(name))));
}

/* Sdl.getVersionRaw : IO UInt32 -- C: SDL_GetVersion */
LEAN_EXPORT lean_obj_res lean_sdl_get_version(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)SDL_GetVersion()));
}

/* Sdl.getRevision : IO String -- C: SDL_GetRevision */
LEAN_EXPORT lean_obj_res lean_sdl_get_revision(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(lean_sdl_mk_string(SDL_GetRevision()));
}

/* Sdl.getPlatform : IO String -- C: SDL_GetPlatform */
LEAN_EXPORT lean_obj_res lean_sdl_get_platform(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    return lean_io_result_mk_ok(lean_sdl_mk_string(SDL_GetPlatform()));
}
