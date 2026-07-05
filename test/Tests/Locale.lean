import Sdl
import Tests.Harness

namespace Tests.Locale
open Sdl Tests.Harness

/-- Preferred locales may be unavailable on CI, so treat a throw as acceptable;
on success, every language code must be nonempty (SDL never returns an empty
language). -/
def run : IO Unit := do
  try
    let locales ← Sdl.getPreferredLocales
    for loc in locales do
      check "locale language nonempty" (!loc.language.isEmpty)
    check "getPreferredLocales succeeded" true
  catch _ =>
    check "getPreferredLocales unavailable (ok)" true

end Tests.Locale
