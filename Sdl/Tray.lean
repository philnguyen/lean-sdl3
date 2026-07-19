module

public import Sdl.Core.Macros
public meta import Sdl.Core.Macros
public import Sdl.Error
public meta import Sdl.Error
public import Sdl.Surface
public meta import Sdl.Surface

public section

/-!
# System tray (`SDL_tray.h`)

Add an icon to the OS notification area / system tray, with submenus,
checkboxes, and clickable entries that fire a callback.

**Main-thread-only module.** Requires `Sdl.init .video` (tray icons need the
video subsystem), and every function must be called on the thread that created
the tray.

## Ownership

`Tray` is an **owned root**: the finalizer (and the manual `destroy`) run
`SDL_DestroyTray`, which also destroys **all** of the tray's menus and entries.

`TrayMenu` and `TrayEntry` are **borrowed-only** handles: SDL owns and destroys
them together with the tray, so a Lean menu/entry handle carries an owned
reference to the root `Tray`'s external object (keeping the tray alive) but never
destroys anything itself. A menu/entry obtained from another menu/entry handle
reuses that handle's root-tray owner.

**Cross-handle staleness:** removing an entry (`TrayEntry.remove`) or destroying
the tray (`Tray.destroy`) invalidates *other* outstanding handles to the same
entry/menu — using one afterwards is undefined exactly as in the C API. Only
*this* handle's pointer is NULLed defensively (so at least the handle you called
the operation on fails cleanly).

Skipped (documented plan-level omissions):
* `SDL_GetTrayMenuParentTray` — returning it would mint a second *owned* handle
  to the same `SDL_Tray*`, risking a double `SDL_DestroyTray`. Keep your original
  `Tray` value instead.
-/

namespace Sdl

/-- Flags controlling the creation of a tray entry. Exactly one of `button`,
`checkbox`, `submenu` is required; `disabled`/`checked` are optional additions.
C: `SDL_TrayEntryFlags`. -/
sdl_flags TrayEntryFlags : UInt32 where
  /-- A simple clickable button (required kind). C: `SDL_TRAYENTRY_BUTTON`. -/
  | button   := 0x00000001
  /-- A checkbox (required kind). C: `SDL_TRAYENTRY_CHECKBOX`. -/
  | checkbox := 0x00000002
  /-- Prepared to hold a submenu (required kind). C: `SDL_TRAYENTRY_SUBMENU`. -/
  | submenu  := 0x00000004
  /-- Disabled (optional). C: `SDL_TRAYENTRY_DISABLED`. -/
  | disabled := 0x80000000
  /-- Checked; only valid for checkboxes (optional). C: `SDL_TRAYENTRY_CHECKED`. -/
  | checked  := 0x40000000

/-- A toplevel system tray icon. C: `SDL_Tray`. -/
sdl_opaque Tray

/-- A menu or submenu on a tray. Borrowed: destroyed with its tray.
C: `SDL_TrayMenu`. -/
sdl_opaque TrayMenu

/-- An entry (button/checkbox/submenu/separator) in a tray menu. Borrowed:
destroyed with its tray. C: `SDL_TrayEntry`. -/
sdl_opaque TrayEntry

@[extern "lean_sdl_tray_register_classes"]
private opaque registerClasses : IO Unit

initialize registerClasses

/-- Create a tray icon in the OS notification area. Both the `icon` surface and
the `tooltip` (shown on hover; not supported on all platforms) are optional.
Requires the video subsystem and the main thread. Throws if the tray could not
be created. C: `SDL_CreateTray`. -/
@[extern "lean_sdl_create_tray"]
opaque createTray (icon : @& Option Surface := none) (tooltip : @& Option String := none) :
  IO Tray

namespace Tray

/-- Replace the tray icon (or clear it with `none`). C: `SDL_SetTrayIcon`. -/
@[extern "lean_sdl_set_tray_icon"]
opaque setIcon (self : @& Tray) (icon : @& Option Surface) : IO Unit

/-- Replace the tray tooltip (or clear it with `none`). C: `SDL_SetTrayTooltip`. -/
@[extern "lean_sdl_set_tray_tooltip"]
opaque setTooltip (self : @& Tray) (tooltip : @& Option String) : IO Unit

/-- Create the tray's top-level menu (call at most once per tray). Throws on
failure. C: `SDL_CreateTrayMenu`. -/
@[extern "lean_sdl_create_tray_menu"]
opaque createMenu (self : @& Tray) : IO TrayMenu

/-- Fetch the tray's previously created top-level menu, or `none` if
`createMenu` has not been called yet (not an error). C: `SDL_GetTrayMenu`. -/
@[extern "lean_sdl_get_tray_menu"]
opaque getMenu (self : @& Tray) : IO (Option TrayMenu)

/-- Destroy the tray and all of its menus and entries. The handle (and any
outstanding menu/entry handles derived from it) must not be used afterwards.
C: `SDL_DestroyTray`. -/
@[extern "lean_sdl_destroy_tray"]
opaque destroy (self : @& Tray) : IO Unit

end Tray

namespace TrayMenu

/-- The entries in the menu, in order. C: `SDL_GetTrayEntries`. -/
@[extern "lean_sdl_get_tray_entries"]
opaque getEntries (self : @& TrayMenu) : IO (Array TrayEntry)

@[extern "lean_sdl_insert_tray_entry_at"]
private opaque insertEntryAtRaw (self : @& TrayMenu) (pos : Int32)
  (label : @& Option String) (flags : UInt32) : IO TrayEntry

/-- Insert a new entry at `pos` (or append with `pos := -1`). A `label` of
`none` makes a **separator**; otherwise pass exactly one required kind flag
(`.button`/`.checkbox`/`.submenu`) optionally OR'd with `.disabled`/`.checked`.
Throws if `pos` is out of bounds. C: `SDL_InsertTrayEntryAt`. -/
def insertEntryAt (self : @& TrayMenu) (pos : Int32) (label : Option String)
    (flags : TrayEntryFlags) : IO TrayEntry :=
  insertEntryAtRaw self pos label flags.val

/-- The tray entry this menu is a submenu of, or `none` if this is a tray's
top-level (root) menu. C: `SDL_GetTrayMenuParentEntry`. -/
@[extern "lean_sdl_get_tray_menu_parent_entry"]
opaque getParentEntry (self : @& TrayMenu) : IO (Option TrayEntry)

end TrayMenu

namespace TrayEntry

/-- Create a submenu bound to this entry (the entry must have been created with
the `.submenu` flag; call at most once). Throws on failure.
C: `SDL_CreateTraySubmenu`. -/
@[extern "lean_sdl_create_tray_submenu"]
opaque createSubmenu (self : @& TrayEntry) : IO TrayMenu

/-- Fetch this entry's previously created submenu, or `none` if it has none.
C: `SDL_GetTraySubmenu`. -/
@[extern "lean_sdl_get_tray_submenu"]
opaque getSubmenu (self : @& TrayEntry) : IO (Option TrayMenu)

/-- The menu containing this entry. C: `SDL_GetTrayEntryParent`. -/
@[extern "lean_sdl_get_tray_entry_parent"]
opaque getParent (self : @& TrayEntry) : IO TrayMenu

/-- Remove this entry from its menu. Also drops any callback registered on it.
Afterwards this handle (and any other handle to the same entry) is invalid; this
handle's later use throws. C: `SDL_RemoveTrayEntry`. -/
@[extern "lean_sdl_remove_tray_entry"]
opaque remove (self : @& TrayEntry) : IO Unit

/-- Set the entry's label. Cannot convert between a separator (`none`) and an
ordinary entry — SDL silently ignores such a change. C: `SDL_SetTrayEntryLabel`. -/
@[extern "lean_sdl_set_tray_entry_label"]
opaque setLabel (self : @& TrayEntry) (label : @& Option String) : IO Unit

/-- The entry's label, or `none` if it is a separator. Caveat: the macOS
backend reports a separator's label as the empty string, so a separator decodes
as `some ""` there — treat empty-or-`none` as "separator" in portable code.
C: `SDL_GetTrayEntryLabel`. -/
@[extern "lean_sdl_get_tray_entry_label"]
opaque getLabel (self : @& TrayEntry) : IO (Option String)

/-- Set whether a checkbox entry is checked (the entry must be a `.checkbox`).
C: `SDL_SetTrayEntryChecked`. -/
@[extern "lean_sdl_set_tray_entry_checked"]
opaque setChecked (self : @& TrayEntry) (checked : Bool) : IO Unit

/-- Whether a checkbox entry is checked. C: `SDL_GetTrayEntryChecked`. -/
@[extern "lean_sdl_get_tray_entry_checked"]
opaque getChecked (self : @& TrayEntry) : IO Bool

/-- Set whether the entry is enabled. C: `SDL_SetTrayEntryEnabled`. -/
@[extern "lean_sdl_set_tray_entry_enabled"]
opaque setEnabled (self : @& TrayEntry) (enabled : Bool) : IO Unit

/-- Whether the entry is enabled. Caveat: the macOS backend does not read the
state back (observed to always return `false` regardless of `setEnabled`) —
track it yourself if you need it. C: `SDL_GetTrayEntryEnabled`. -/
@[extern "lean_sdl_get_tray_entry_enabled"]
opaque getEnabled (self : @& TrayEntry) : IO Bool

/-- Set (`some f`) or clear (`none`) the callback invoked when the entry is
selected. Unlike the C callback, the Lean callback takes **no arguments** — the
C `entry` argument is dropped; capture whatever you need in the closure. Setting
a new callback replaces (and releases) any previous one.
C: `SDL_SetTrayEntryCallback`. -/
@[extern "lean_sdl_set_tray_entry_callback"]
opaque setCallback (self : @& TrayEntry) (cb : Option (IO Unit)) : IO Unit

/-- Simulate a click on the entry (fires its callback as if the user selected
it). C: `SDL_ClickTrayEntry`. -/
@[extern "lean_sdl_click_tray_entry"]
opaque click (self : @& TrayEntry) : IO Unit

end TrayEntry

/-- Update the trays. Normally done automatically by the event loop; only needed
if you use trays without processing SDL events. C: `SDL_UpdateTrays`. -/
@[extern "lean_sdl_update_trays"]
opaque updateTrays : IO Unit

end Sdl

end
