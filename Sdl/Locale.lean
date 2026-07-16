module

public import Sdl.Core.Macros
public meta import Sdl.Core.Macros
public import Sdl.Error
public meta import Sdl.Error

public section

/-!
# Locale preferences (`SDL_locale.h`)

A single query, `getPreferredLocales`, returning the user's preferred locales
in order of preference.
-/

namespace Sdl

/-- A user locale: a spoken language plus an optional country. C: `SDL_Locale`.

`language` is an ISO-639 code (e.g. `"en"`); `country`, when present, is an
ISO-3166 code (e.g. `"US"`). Some codes are longer than two characters. -/
structure Locale where
  /-- ISO-639 language code, e.g. `"en"`. Never empty. -/
  language : String
  /-- ISO-3166 country code, e.g. `"US"`, or `none` if unspecified. -/
  country : Option String
deriving BEq, Repr, Inhabited

/-- Maker called from C to hand a `Locale` back to Lean. C builds the `country`
option and passes owned string objects. -/
@[export lean_sdl_mk_locale]
private def mkLocale (language : String) (country : Option String) : Locale :=
  { language, country }

/-- The user's preferred locales, most-preferred first. Throws on failure,
including when the platform supplies no locale information.
C: `SDL_GetPreferredLocales`. -/
@[extern "lean_sdl_get_preferred_locales"]
opaque getPreferredLocales : IO (Array Locale)

end Sdl

end
