import Sdl.Core.Macros
import Sdl.Error

/-!
# Object properties (`SDL_properties.h`)

A `Properties` handle wraps an `SDL_PropertiesID`. Two C external classes back
the one Lean type: an **owned** class (from `Sdl.createProperties`, destroyed on
finalize) and a **borrowed** class (from `Sdl.getGlobalProperties`, never
destroyed). The `SDL_PropertiesID` (a nonzero `Uint32`) lives in the holder's
`ptr` as `(void *)(uintptr_t)id`; a NULL `ptr` means the handle was destroyed.

Skipped:
* `SDL_SetPointerProperty`, `SDL_GetPointerProperty`,
  `SDL_SetPointerPropertyWithCleanup` — raw `void *`; deliberately left
  unbound (unsafe across the FFI boundary). The cleanup mechanism is used
  *internally* by the binding to keep owned Lean closures in SDL properties
  (e.g. a window's hit-test callback).
-/

namespace Sdl

/-- Type of a property value. C: `SDL_PropertyType`. -/
sdl_enum PropertyType : UInt32 where
  | invalid => 0  -- C: SDL_PROPERTY_TYPE_INVALID
  | pointer => 1  -- C: SDL_PROPERTY_TYPE_POINTER
  | string  => 2  -- C: SDL_PROPERTY_TYPE_STRING
  | number  => 3  -- C: SDL_PROPERTY_TYPE_NUMBER
  | float   => 4  -- C: SDL_PROPERTY_TYPE_FLOAT
  | boolean => 5  -- C: SDL_PROPERTY_TYPE_BOOLEAN

/-- A group of properties. C: `SDL_PropertiesID`. -/
sdl_opaque Properties

@[extern "lean_sdl_properties_register_classes"]
private opaque registerClasses : IO Unit

initialize registerClasses

/-- The global property group (shared process-wide). Borrowed: it must not be
destroyed. C: `SDL_GetGlobalProperties`. -/
@[extern "lean_sdl_get_global_properties"]
opaque getGlobalProperties : IO Properties

/-- Create a new, empty owned property group. C: `SDL_CreateProperties`. -/
@[extern "lean_sdl_create_properties"]
opaque createProperties : IO Properties

namespace Properties

/-- Copy all properties from `src` into `dst` (overwriting existing keys of the
same name; callback-cleanup pointer properties are skipped by SDL).
C: `SDL_CopyProperties`. -/
@[extern "lean_sdl_copy_properties"]
opaque copyProperties (src dst : @& Properties) : IO Unit

/-- Lock a property group for exclusive access (rarely needed; SDL locks
internally). Pair with `unlockProperties`. C: `SDL_LockProperties`. -/
@[extern "lean_sdl_lock_properties"]
opaque lockProperties (props : @& Properties) : IO Unit

/-- Unlock a property group locked by `lockProperties`.
C: `SDL_UnlockProperties`. -/
@[extern "lean_sdl_unlock_properties"]
opaque unlockProperties (props : @& Properties) : IO Unit

/-- Set a string property (the value is copied by SDL).
C: `SDL_SetStringProperty`. -/
@[extern "lean_sdl_set_string_property"]
opaque setStringProperty (props : @& Properties) (name value : @& String) : IO Unit

/-- Set an integer property. C: `SDL_SetNumberProperty`. -/
@[extern "lean_sdl_set_number_property"]
opaque setNumberProperty (props : @& Properties) (name : @& String) (value : Int64) : IO Unit

/-- Set a floating-point property. C: `SDL_SetFloatProperty`. -/
@[extern "lean_sdl_set_float_property"]
opaque setFloatProperty (props : @& Properties) (name : @& String) (value : Float32) : IO Unit

/-- Set a boolean property. C: `SDL_SetBooleanProperty`. -/
@[extern "lean_sdl_set_boolean_property"]
opaque setBooleanProperty (props : @& Properties) (name : @& String) (value : Bool) : IO Unit

/-- Whether a property with the given name exists. C: `SDL_HasProperty`. -/
@[extern "lean_sdl_has_property"]
opaque hasProperty (props : @& Properties) (name : @& String) : IO Bool

@[extern "lean_sdl_get_property_type"]
private opaque getPropertyTypeRaw (props : @& Properties) (name : @& String) : IO UInt32

/-- Type of the named property (`.invalid` if it does not exist).
C: `SDL_GetPropertyType`. -/
def getPropertyType (props : @& Properties) (name : @& String) : IO PropertyType := do
  return PropertyType.ofVal? (← getPropertyTypeRaw props name) |>.getD .invalid

/-- String value of the named property, or `defaultValue` if missing/not a
string. C: `SDL_GetStringProperty`. -/
@[extern "lean_sdl_get_string_property"]
opaque getStringProperty (props : @& Properties) (name : @& String)
  (defaultValue : @& String := "") : IO String

/-- Integer value of the named property, or `defaultValue` if missing/not a
number. C: `SDL_GetNumberProperty`. -/
@[extern "lean_sdl_get_number_property"]
opaque getNumberProperty (props : @& Properties) (name : @& String)
  (defaultValue : Int64 := 0) : IO Int64

/-- Float value of the named property, or `defaultValue` if missing/not a
float. C: `SDL_GetFloatProperty`. -/
@[extern "lean_sdl_get_float_property"]
opaque getFloatProperty (props : @& Properties) (name : @& String)
  (defaultValue : Float32 := 0) : IO Float32

/-- Boolean value of the named property, or `defaultValue` if missing/not a
boolean. C: `SDL_GetBooleanProperty`. -/
@[extern "lean_sdl_get_boolean_property"]
opaque getBooleanProperty (props : @& Properties) (name : @& String)
  (defaultValue : Bool := false) : IO Bool

/-- Remove the named property. C: `SDL_ClearProperty`. -/
@[extern "lean_sdl_clear_property"]
opaque clearProperty (props : @& Properties) (name : @& String) : IO Unit

@[extern "lean_sdl_enumerate_properties"]
private opaque enumerateRaw (props : @& Properties) (cb : String → IO Unit) : IO Unit

/-- Call `cb` once per property name, synchronously on this thread. SDL holds
the group's lock during enumeration, so `cb` must not read or modify `props`
itself — collect the names and act afterwards. (The C callback's `props`
argument is dropped; the caller already holds the handle.)
C: `SDL_EnumerateProperties`. -/
def enumerate (props : @& Properties) (cb : String → IO Unit) : IO Unit :=
  enumerateRaw props cb

/-- Destroy an owned property group (do not use the handle afterwards). Throws
if `props` is the borrowed global group. C: `SDL_DestroyProperties`. -/
@[extern "lean_sdl_destroy_properties"]
opaque destroy (props : @& Properties) : IO Unit

end Properties
end Sdl
