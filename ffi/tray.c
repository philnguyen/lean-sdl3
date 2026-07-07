/* Shims for Sdl/Tray.lean (SDL_tray.h). Main-thread-only; needs SDL_INIT_VIDEO.
 *
 * Three module-local external classes:
 *   - lean_sdl_tray       : OWNED ROOT. Finalizer (and manual Tray.destroy) run
 *     SDL_DestroyTray, which destroys ALL of the tray's menus and entries.
 *   - lean_sdl_tray_menu  : BORROWED. holder {ptr = SDL_TrayMenu*, owner = the
 *     inc'd root Tray external}. Never destroyed by the finalizer; only decs the
 *     owner (keeping the tray alive while a menu handle exists).
 *   - lean_sdl_tray_entry : BORROWED. holder {ptr = SDL_TrayEntry*, owner = the
 *     inc'd root Tray external}. Same story.
 *
 * A menu/entry obtained FROM another menu/entry handle reuses that handle's
 * root-tray owner (inc'd once per new handle).
 *
 * Callbacks use the gen-key registry (ffi/callbacks.h): one global
 * lean_sdl_tray_cb_reg keyed by a monotone uint64 (the SDL userdata), aux = the
 * SDL_TrayEntry*. The Lean closure takes no arguments (the C `entry` arg is
 * dropped). KNOWN BOUNDED LEAK: closures still registered when the tray is
 * destroyed are never dec'd (SDL never fires them again — memory only). Users
 * should `setCallback none` before destroying if they care; remove/setCallback
 * drop the closure for a given entry. */
#include "util.h"
#include "callbacks.h"

/* Owned root. */
SDL_DEFINE_CLASS(lean_sdl_tray, SDL_DestroyTray((SDL_Tray *)self))
/* Borrowed menu/entry: never destroyed, only decs the owner (root tray). */
SDL_DEFINE_BORROWED_CLASS(lean_sdl_tray_menu)
SDL_DEFINE_BORROWED_CLASS(lean_sdl_tray_entry)

/* Per-entry callback registry (aux = SDL_TrayEntry*). */
static sdl_cb_registry lean_sdl_tray_cb_reg;

/* Register all three classes. Called from Sdl/Tray.lean's `initialize`. */
LEAN_EXPORT lean_obj_res lean_sdl_tray_register_classes(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    lean_sdl_tray_class_init();
    lean_sdl_tray_menu_class_init();
    lean_sdl_tray_entry_class_init();
    return lean_sdl_unit_ok();
}

/* ---------- helpers ---------- */

/* Borrowed `Option String` -> C string or NULL. */
static const char *lean_sdl_tray_option_cstr(b_lean_obj_arg opt) {
    if (lean_is_scalar(opt)) return NULL;
    return lean_string_cstr(lean_ctor_get(opt, 0));
}

/* Borrowed `Option Surface` -> SDL_Surface* or NULL (destroyed handle -> NULL,
 * treated as "no icon"). */
static SDL_Surface *lean_sdl_tray_option_surface(b_lean_obj_arg opt) {
    if (lean_is_scalar(opt)) return NULL;
    return (SDL_Surface *)lean_sdl_holder_of(lean_ctor_get(opt, 0))->ptr;
}

/* The root-tray owner of a menu/entry handle, inc'd for reuse in a new handle. */
static lean_object *lean_sdl_tray_owner_inc(b_lean_obj_arg h) {
    lean_object *owner = lean_sdl_holder_of(h)->owner;
    lean_inc(owner);
    return owner;
}

/* Trampoline: acquire the closure by key and apply it (no args). */
static void SDLCALL lean_sdl_tray_tramp(void *userdata, SDL_TrayEntry *entry) {
    (void)entry;
    uint64_t key = (uint64_t)(uintptr_t)userdata;
    lean_sdl_ensure_thread();
    lean_object *fn = lean_sdl_cb_acquire(&lean_sdl_tray_cb_reg, key);
    if (!fn) return;
    lean_sdl_io_ignore(lean_apply_1(fn, lean_box(0)));
}

/* ---------- Tray ---------- */

/* Sdl.createTray (icon : Option Surface) (tooltip : Option String) : IO Tray
 * -- C: SDL_CreateTray (NULL -> throw). Owned root (owner NULL). */
LEAN_EXPORT lean_obj_res lean_sdl_create_tray(
        b_lean_obj_arg icon, b_lean_obj_arg tooltip, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_Tray *tray = SDL_CreateTray(lean_sdl_tray_option_surface(icon),
                                    lean_sdl_tray_option_cstr(tooltip));
    if (!tray) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_wrap(lean_sdl_tray_class, tray, NULL));
}

/* Sdl.Tray.setIcon (icon : Option Surface) : IO Unit -- C: SDL_SetTrayIcon. */
LEAN_EXPORT lean_obj_res lean_sdl_set_tray_icon(
        b_lean_obj_arg self, b_lean_obj_arg icon, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Tray, tray, self);
    SDL_SetTrayIcon(tray, lean_sdl_tray_option_surface(icon));
    return lean_sdl_unit_ok();
}

/* Sdl.Tray.setTooltip (tooltip : Option String) : IO Unit
 * -- C: SDL_SetTrayTooltip. */
LEAN_EXPORT lean_obj_res lean_sdl_set_tray_tooltip(
        b_lean_obj_arg self, b_lean_obj_arg tooltip, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Tray, tray, self);
    SDL_SetTrayTooltip(tray, lean_sdl_tray_option_cstr(tooltip));
    return lean_sdl_unit_ok();
}

/* Sdl.Tray.createMenu : IO TrayMenu -- C: SDL_CreateTrayMenu (NULL -> throw).
 * Owner = the inc'd tray external. */
LEAN_EXPORT lean_obj_res lean_sdl_create_tray_menu(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Tray, tray, self);
    SDL_TrayMenu *menu = SDL_CreateTrayMenu(tray);
    if (!menu) return lean_sdl_throw();
    lean_inc(self);
    return lean_io_result_mk_ok(
        lean_sdl_wrap(lean_sdl_tray_menu_class, menu, (lean_object *)self));
}

/* Sdl.Tray.getMenu : IO (Option TrayMenu) -- C: SDL_GetTrayMenu (NULL -> none,
 * no menu created yet). Owner = the inc'd tray external. */
LEAN_EXPORT lean_obj_res lean_sdl_get_tray_menu(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_Tray, tray, self);
    SDL_TrayMenu *menu = SDL_GetTrayMenu(tray);
    if (!menu) return lean_io_result_mk_ok(lean_sdl_none());
    lean_inc(self);
    return lean_io_result_mk_ok(lean_sdl_some(
        lean_sdl_wrap(lean_sdl_tray_menu_class, menu, (lean_object *)self)));
}

/* Sdl.Tray.destroy : IO Unit -- C: SDL_DestroyTray. Manual destroy: NULL the
 * ptr so the finalizer skips and later use throws. Destroys all child menus and
 * entries too (their handles become stale; documented UB to use them). */
LEAN_EXPORT lean_obj_res lean_sdl_destroy_tray(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    sdl_holder *h = lean_sdl_holder_of(self);
    if (!h->ptr)
        return lean_sdl_throw_msg("SDL: handle used after destroy/release");
    SDL_DestroyTray((SDL_Tray *)h->ptr);
    h->ptr = NULL;
    return lean_sdl_unit_ok();
}

/* ---------- TrayMenu ---------- */

/* Sdl.TrayMenu.getEntries : IO (Array TrayEntry) -- C: SDL_GetTrayEntries.
 * The returned list is SDL-owned (do NOT free) and invalidated by any
 * insert/remove. Each entry handle reuses the menu's root-tray owner. */
LEAN_EXPORT lean_obj_res lean_sdl_get_tray_entries(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_TrayMenu, menu, self);
    int count = 0;
    const SDL_TrayEntry **entries = SDL_GetTrayEntries(menu, &count);
    size_t n = (entries && count > 0) ? (size_t)count : 0;
    lean_object *arr = lean_alloc_array(n, n);
    for (size_t i = 0; i < n; i++)
        lean_array_set_core(arr, i, lean_sdl_wrap(lean_sdl_tray_entry_class,
            (void *)entries[i], lean_sdl_tray_owner_inc(self)));
    return lean_io_result_mk_ok(arr);
}

/* Sdl.TrayMenu.insertEntryAtRaw (pos : Int32) (label : @& Option String)
 *   (flags : UInt32) : IO TrayEntry
 * -- C: SDL_InsertTrayEntryAt (label NULL = separator; pos -1 = append;
 * NULL -> throw, e.g. pos out of bounds). Owner = the menu's root-tray owner. */
LEAN_EXPORT lean_obj_res lean_sdl_insert_tray_entry_at(
        b_lean_obj_arg self, int32_t pos, b_lean_obj_arg label, uint32_t flags,
        lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_TrayMenu, menu, self);
    SDL_TrayEntry *entry = SDL_InsertTrayEntryAt(menu, (int)pos,
        lean_sdl_tray_option_cstr(label), (SDL_TrayEntryFlags)flags);
    if (!entry) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_wrap(lean_sdl_tray_entry_class, entry,
        lean_sdl_tray_owner_inc(self)));
}

/* Sdl.TrayMenu.getParentEntry : IO (Option TrayEntry)
 * -- C: SDL_GetTrayMenuParentEntry (NULL -> none, this is a tray's root menu). */
LEAN_EXPORT lean_obj_res lean_sdl_get_tray_menu_parent_entry(
        b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_TrayMenu, menu, self);
    SDL_TrayEntry *entry = SDL_GetTrayMenuParentEntry(menu);
    if (!entry) return lean_io_result_mk_ok(lean_sdl_none());
    return lean_io_result_mk_ok(lean_sdl_some(lean_sdl_wrap(
        lean_sdl_tray_entry_class, entry, lean_sdl_tray_owner_inc(self))));
}

/* ---------- TrayEntry ---------- */

/* Sdl.TrayEntry.createSubmenu : IO TrayMenu -- C: SDL_CreateTraySubmenu
 * (NULL -> throw; entry must have .submenu). Owner = the entry's root-tray. */
LEAN_EXPORT lean_obj_res lean_sdl_create_tray_submenu(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_TrayEntry, entry, self);
    SDL_TrayMenu *menu = SDL_CreateTraySubmenu(entry);
    if (!menu) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_wrap(lean_sdl_tray_menu_class, menu,
        lean_sdl_tray_owner_inc(self)));
}

/* Sdl.TrayEntry.getSubmenu : IO (Option TrayMenu)
 * -- C: SDL_GetTraySubmenu (NULL -> none). Owner = the entry's root-tray. */
LEAN_EXPORT lean_obj_res lean_sdl_get_tray_submenu(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_TrayEntry, entry, self);
    SDL_TrayMenu *menu = SDL_GetTraySubmenu(entry);
    if (!menu) return lean_io_result_mk_ok(lean_sdl_none());
    return lean_io_result_mk_ok(lean_sdl_some(lean_sdl_wrap(
        lean_sdl_tray_menu_class, menu, lean_sdl_tray_owner_inc(self))));
}

/* Sdl.TrayEntry.getParent : IO TrayMenu -- C: SDL_GetTrayEntryParent
 * (NULL -> throw). Owner = the entry's root-tray. */
LEAN_EXPORT lean_obj_res lean_sdl_get_tray_entry_parent(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_TrayEntry, entry, self);
    SDL_TrayMenu *menu = SDL_GetTrayEntryParent(entry);
    if (!menu) return lean_sdl_throw();
    return lean_io_result_mk_ok(lean_sdl_wrap(lean_sdl_tray_menu_class, menu,
        lean_sdl_tray_owner_inc(self)));
}

/* Sdl.TrayEntry.remove : IO Unit -- C: SDL_RemoveTrayEntry. Drop any callback
 * for this entry first, then remove it and NULL this handle's ptr. Other
 * handles to the same entry become stale (documented UB to use). */
LEAN_EXPORT lean_obj_res lean_sdl_remove_tray_entry(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    sdl_holder *h = lean_sdl_holder_of(self);
    if (!h->ptr)
        return lean_sdl_throw_msg("SDL: handle used after destroy/release");
    SDL_TrayEntry *entry = (SDL_TrayEntry *)h->ptr;
    lean_object *old = NULL;
    uint64_t oldkey = 0;
    if (lean_sdl_cb_take_by_aux(&lean_sdl_tray_cb_reg, (uintptr_t)entry, &old, &oldkey))
        lean_dec(old);
    SDL_RemoveTrayEntry(entry);
    h->ptr = NULL;
    return lean_sdl_unit_ok();
}

/* Sdl.TrayEntry.setLabel (label : Option String) : IO Unit
 * -- C: SDL_SetTrayEntryLabel. */
LEAN_EXPORT lean_obj_res lean_sdl_set_tray_entry_label(
        b_lean_obj_arg self, b_lean_obj_arg label, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_TrayEntry, entry, self);
    SDL_SetTrayEntryLabel(entry, lean_sdl_tray_option_cstr(label));
    return lean_sdl_unit_ok();
}

/* Sdl.TrayEntry.getLabel : IO (Option String) -- C: SDL_GetTrayEntryLabel
 * (NULL = separator -> none). */
LEAN_EXPORT lean_obj_res lean_sdl_get_tray_entry_label(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_TrayEntry, entry, self);
    return lean_io_result_mk_ok(lean_sdl_option_string(SDL_GetTrayEntryLabel(entry)));
}

/* Sdl.TrayEntry.setChecked (checked : Bool) : IO Unit
 * -- C: SDL_SetTrayEntryChecked. */
LEAN_EXPORT lean_obj_res lean_sdl_set_tray_entry_checked(
        b_lean_obj_arg self, uint8_t checked, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_TrayEntry, entry, self);
    SDL_SetTrayEntryChecked(entry, checked != 0);
    return lean_sdl_unit_ok();
}

/* Sdl.TrayEntry.getChecked : IO Bool -- C: SDL_GetTrayEntryChecked. */
LEAN_EXPORT lean_obj_res lean_sdl_get_tray_entry_checked(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_TrayEntry, entry, self);
    return lean_io_result_mk_ok(lean_box(SDL_GetTrayEntryChecked(entry)));
}

/* Sdl.TrayEntry.setEnabled (enabled : Bool) : IO Unit
 * -- C: SDL_SetTrayEntryEnabled. */
LEAN_EXPORT lean_obj_res lean_sdl_set_tray_entry_enabled(
        b_lean_obj_arg self, uint8_t enabled, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_TrayEntry, entry, self);
    SDL_SetTrayEntryEnabled(entry, enabled != 0);
    return lean_sdl_unit_ok();
}

/* Sdl.TrayEntry.getEnabled : IO Bool -- C: SDL_GetTrayEntryEnabled. */
LEAN_EXPORT lean_obj_res lean_sdl_get_tray_entry_enabled(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_TrayEntry, entry, self);
    return lean_io_result_mk_ok(lean_box(SDL_GetTrayEntryEnabled(entry)));
}

/* Sdl.TrayEntry.setCallback (cb : Option (IO Unit)) : IO Unit
 * -- C: SDL_SetTrayEntryCallback via the gen-key registry. Drop any previous
 * closure for this entry, then register the new one (if `some`) before setting
 * the SDL callback, or clear it (if `none`). `cb` is owned. */
LEAN_EXPORT lean_obj_res lean_sdl_set_tray_entry_callback(
        b_lean_obj_arg self, lean_obj_arg cb, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    sdl_holder *h = lean_sdl_holder_of(self);
    if (!h->ptr) {
        lean_dec(cb);
        return lean_sdl_throw_msg("SDL: handle used after destroy/release");
    }
    SDL_TrayEntry *entry = (SDL_TrayEntry *)h->ptr;
    lean_object *fn = lean_sdl_option_take(cb); /* owned closure or NULL */
    lean_object *old = NULL;
    uint64_t oldkey = 0;
    if (lean_sdl_cb_take_by_aux(&lean_sdl_tray_cb_reg, (uintptr_t)entry, &old, &oldkey))
        lean_dec(old);
    if (fn) {
        uint64_t key = lean_sdl_cb_register(&lean_sdl_tray_cb_reg, fn, (uintptr_t)entry);
        SDL_SetTrayEntryCallback(entry, lean_sdl_tray_tramp, (void *)(uintptr_t)key);
    } else {
        SDL_SetTrayEntryCallback(entry, NULL, NULL);
    }
    return lean_sdl_unit_ok();
}

/* Sdl.TrayEntry.click : IO Unit -- C: SDL_ClickTrayEntry. */
LEAN_EXPORT lean_obj_res lean_sdl_click_tray_entry(b_lean_obj_arg self, lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_GET_OR_THROW(SDL_TrayEntry, entry, self);
    SDL_ClickTrayEntry(entry);
    return lean_sdl_unit_ok();
}

/* Sdl.updateTrays : IO Unit -- C: SDL_UpdateTrays. */
LEAN_EXPORT lean_obj_res lean_sdl_update_trays(lean_obj_arg w) {
    (void)w;
    SDL_SHIM_PROLOGUE();
    SDL_UpdateTrays();
    return lean_sdl_unit_ok();
}
