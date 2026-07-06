import Sdl
import Tests.Harness

namespace Tests.BlendMode
open Sdl Tests.Harness

/-- `composeCustomBlendMode` against the linked SDL: a sextuple equivalent to
a predefined mode composes to that mode (SDL normalizes it), while a genuinely
custom sextuple yields a nonzero packed value distinct from every named
constant. -/
def run : IO Unit := do
  -- the standard alpha-blend combination composes to the predefined .blend
  let blend := Sdl.composeCustomBlendMode .srcAlpha .oneMinusSrcAlpha .add
    .one .oneMinusSrcAlpha .add
  check "standard combo composes to .blend" (blend == .blend)
  -- a genuinely custom combination: nonzero and distinct from all constants
  let custom := Sdl.composeCustomBlendMode .one .one .maximum .one .one .maximum
  check "custom mode nonzero" (custom.val != 0)
  let named : List Sdl.BlendMode := [.none, .blend, .blendPremultiplied, .add,
    .addPremultiplied, .mod, .mul, .invalid]
  check "custom mode differs from every named constant" (named.all (custom != ·))
  -- composing is deterministic
  let custom2 := Sdl.composeCustomBlendMode .one .one .maximum .one .one .maximum
  check "compose deterministic" (custom == custom2)

end Tests.BlendMode
