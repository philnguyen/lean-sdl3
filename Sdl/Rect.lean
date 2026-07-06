import Sdl.Core.Macros

/-!
# Rectangles and points (`SDL_rect.h`)

Pure Lean reimplementations of every function in `SDL_rect.h`: the
`SDL_FORCE_INLINE` helpers (whose C source lives in the header) replicate that
source exactly, and the ten `SDL_DECLSPEC` functions are reimplemented from
their documented semantics (cross-validated against the linked SDL 3.4.10 at
development time). Nothing here calls into SDL, so everything is
`#guard`-tested at compile time and no runtime test group exists.

Semantics notes (all matching SDL):
* Integer rects treat the far edge as exclusive (a 1×1 rect contains `(0,0)`
  but not `(0,1)`); float rects treat it as inclusive.
* An integer rect is empty iff `w ≤ 0` or `h ≤ 0`; a float rect only iff
  `w < 0` or `h < 0` — a zero-area float rect is *not* empty, so e.g. two
  merely touching float rects do intersect while integer ones do not.
* C's bool-with-out-param results become `Option`; `Rect.union` is total
  (C only fails on NULL args, which cannot happen here).
-/

namespace Sdl

/-- A 2D point (integer). C: `SDL_Point`. -/
structure Point where
  /-- X coordinate. -/
  x : Int32
  /-- Y coordinate. -/
  y : Int32
deriving Repr, BEq, DecidableEq, Inhabited

/-- A 2D point (floating point). C: `SDL_FPoint`. -/
structure FPoint where
  /-- X coordinate. -/
  x : Float32
  /-- Y coordinate. -/
  y : Float32
deriving Repr, BEq, Inhabited

/-- A rectangle with the origin at the upper left (integer). C: `SDL_Rect`. -/
structure Rect where
  /-- X coordinate of the upper-left corner. -/
  x : Int32
  /-- Y coordinate of the upper-left corner. -/
  y : Int32
  /-- Width. -/
  w : Int32
  /-- Height. -/
  h : Int32
deriving Repr, BEq, DecidableEq, Inhabited

/-- A rectangle with the origin at the upper left (floating point).
C: `SDL_FRect`. -/
structure FRect where
  /-- X coordinate of the upper-left corner. -/
  x : Float32
  /-- Y coordinate of the upper-left corner. -/
  y : Float32
  /-- Width. -/
  w : Float32
  /-- Height. -/
  h : Float32
deriving Repr, BEq, Inhabited

/-- Convert to an `FRect`. C: `SDL_RectToFRect`. -/
def Rect.toFRect (r : Rect) : FRect :=
  { x := r.x.toFloat32, y := r.y.toFloat32, w := r.w.toFloat32, h := r.h.toFloat32 }

#guard (Rect.mk 1 2 3 4).toFRect == { x := 1, y := 2, w := 3, h := 4 }
#guard (Rect.mk (-5) 0 10 0).toFRect == { x := -5, y := 0, w := 10, h := 0 }

/-- Whether `p` lies inside `r`: the top/left edges are inside, the far edges
(`x + w`, `y + h`) are outside — a 1×1 rect contains `(0,0)` but not `(0,1)`.
C: `SDL_PointInRect`. -/
def Point.inRect (p : Point) (r : Rect) : Bool :=
  p.x >= r.x && p.x < r.x + r.w && p.y >= r.y && p.y < r.y + r.h

#guard (Point.mk 0 0).inRect ⟨0, 0, 1, 1⟩          -- near corner inside
#guard !(Point.mk 0 1).inRect ⟨0, 0, 1, 1⟩          -- far edge exclusive
#guard !(Point.mk 1 0).inRect ⟨0, 0, 1, 1⟩          -- far edge exclusive
#guard (Point.mk 9 9).inRect ⟨0, 0, 10, 10⟩         -- last interior cell
#guard !(Point.mk 10 9).inRect ⟨0, 0, 10, 10⟩
#guard !(Point.mk (-1) 5).inRect ⟨0, 0, 10, 10⟩
#guard !(Point.mk 0 0).inRect ⟨0, 0, 0, 10⟩         -- empty rect contains nothing

/-- Whether `p` lies inside `r`: unlike the integer version the far edges are
*inclusive* — a 1×1 rect contains both `(0,0)` and `(0,1)` but not `(0,2)`.
C: `SDL_PointInRectFloat`. -/
def FPoint.inRect (p : FPoint) (r : FRect) : Bool :=
  p.x >= r.x && p.x <= r.x + r.w && p.y >= r.y && p.y <= r.y + r.h

#guard (FPoint.mk 0 0).inRect ⟨0, 0, 1, 1⟩
#guard (FPoint.mk 0 1).inRect ⟨0, 0, 1, 1⟩          -- far edge inclusive
#guard !(FPoint.mk 0 2).inRect ⟨0, 0, 1, 1⟩
#guard (FPoint.mk 0 0).inRect ⟨0, 0, 0, 0⟩          -- zero-size still contains its corner
#guard !(FPoint.mk (-0.5) 0).inRect ⟨0, 0, 1, 1⟩

/-- Whether the rectangle has no area: `w ≤ 0` or `h ≤ 0`. C: `SDL_RectEmpty`. -/
def Rect.isEmpty (r : Rect) : Bool :=
  r.w <= 0 || r.h <= 0

#guard (Rect.mk 0 0 0 10).isEmpty
#guard (Rect.mk 0 0 10 (-1)).isEmpty
#guard !(Rect.mk 0 0 1 1).isEmpty

/-- Whether the rectangle takes no space: `w < 0` or `h < 0`. Note that unlike
`Rect.isEmpty` a zero-width/height float rect is *not* empty.
C: `SDL_RectEmptyFloat`. -/
def FRect.isEmpty (r : FRect) : Bool :=
  r.w < 0 || r.h < 0

#guard !(FRect.mk 0 0 0 0).isEmpty                  -- zero size is not float-empty
#guard (FRect.mk 0 0 (-0.1) 10).isEmpty
#guard !(FRect.mk 0 0 1 1).isEmpty

/-- Whether two rectangles are equal (same `x`, `y`, `w`, `h`); identical to
`==`. C: `SDL_RectsEqual`. -/
def Rect.equals (a b : Rect) : Bool :=
  a == b

#guard (Rect.mk 1 2 3 4).equals ⟨1, 2, 3, 4⟩
#guard !(Rect.mk 1 2 3 4).equals ⟨1, 2, 3, 5⟩

/-- Whether `a` and `b` have each of `x`, `y`, `w`, `h` within `epsilon` of
each other. The default `epsilon` is `SDL_FLT_EPSILON`.
C: `SDL_RectsEqualEpsilon`. -/
def FRect.equalsEpsilon (a b : FRect) (epsilon : Float32 := 1.1920928955078125e-7) : Bool :=
  (a.x - b.x).abs <= epsilon && (a.y - b.y).abs <= epsilon &&
  (a.w - b.w).abs <= epsilon && (a.h - b.h).abs <= epsilon

#guard (FRect.mk 1 2 3 4).equalsEpsilon ⟨1, 2, 3, 4⟩
#guard (FRect.mk 1 2 3 4).equalsEpsilon ⟨1.5, 2, 3, 4⟩ (epsilon := 0.5)
#guard !(FRect.mk 1 2 3 4).equalsEpsilon ⟨1.5, 2, 3, 4⟩ (epsilon := 0.25)

/-- Whether `a` and `b` are equal within the default epsilon
(`SDL_FLT_EPSILON`). C: `SDL_RectsEqualFloat`. -/
def FRect.equalsFloat (a b : FRect) : Bool :=
  a.equalsEpsilon b

#guard (FRect.mk 1 2 3 4).equalsFloat ⟨1, 2, 3, 4⟩
-- 1 + FLT_EPSILON is the next Float32 after 1: within default epsilon
#guard (FRect.mk 1 2 3 4).equalsFloat ⟨1 + 1.1920928955078125e-7, 2, 3, 4⟩
#guard !(FRect.mk 1 2 3 4).equalsFloat ⟨1.001, 2, 3, 4⟩

/-- Whether two rectangles intersect; `false` if either rect is empty. Merely
touching rects (zero-area overlap) do not intersect.
C: `SDL_HasRectIntersection`. -/
def Rect.hasIntersection (a b : Rect) : Bool :=
  !a.isEmpty && !b.isEmpty &&
  min (a.x + a.w) (b.x + b.w) > max a.x b.x &&
  min (a.y + a.h) (b.y + b.h) > max a.y b.y

#guard (Rect.mk 0 0 10 10).hasIntersection ⟨5, 5, 10, 10⟩
#guard !(Rect.mk 0 0 5 5).hasIntersection ⟨5, 0, 5, 5⟩   -- touching is not intersecting
#guard !(Rect.mk 0 0 0 10).hasIntersection ⟨0, 0, 10, 10⟩ -- empty never intersects
#guard !(Rect.mk 0 0 5 5).hasIntersection ⟨6, 6, 5, 5⟩

/-- Whether two rectangles intersect; unlike the integer version a zero-area
overlap counts (merely touching float rects *do* intersect).
C: `SDL_HasRectIntersectionFloat`. -/
def FRect.hasIntersection (a b : FRect) : Bool :=
  !a.isEmpty && !b.isEmpty &&
  min (a.x + a.w) (b.x + b.w) >= max a.x b.x &&
  min (a.y + a.h) (b.y + b.h) >= max a.y b.y

#guard (FRect.mk 0 0 10 10).hasIntersection ⟨5, 5, 10, 10⟩
#guard (FRect.mk 0 0 5 5).hasIntersection ⟨5, 0, 5, 5⟩   -- touching intersects (float)
#guard !(FRect.mk 0 0 5 5).hasIntersection ⟨5.5, 0, 5, 5⟩
#guard !(FRect.mk 0 0 (-1) 5).hasIntersection ⟨0, 0, 5, 5⟩

/-- The intersection of two rectangles, or `none` when they do not intersect
(C returns `false`). C: `SDL_GetRectIntersection`. -/
def Rect.intersection (a b : Rect) : Option Rect :=
  if a.isEmpty || b.isEmpty then none
  else
    let x := max a.x b.x
    let y := max a.y b.y
    let w := min (a.x + a.w) (b.x + b.w) - x
    let h := min (a.y + a.h) (b.y + b.h) - y
    if w <= 0 || h <= 0 then none else some { x, y, w, h }

#guard (Rect.mk 0 0 10 10).intersection ⟨5, 5, 10, 10⟩ == some ⟨5, 5, 5, 5⟩
#guard (Rect.mk 0 0 10 10).intersection ⟨2, 3, 4, 5⟩ == some ⟨2, 3, 4, 5⟩  -- contained
#guard (Rect.mk 0 0 5 5).intersection ⟨5, 0, 5, 5⟩ == none  -- touching: empty result
#guard (Rect.mk 0 0 0 10).intersection ⟨0, 0, 10, 10⟩ == none  -- empty input
#guard (Rect.mk 0 0 5 5).intersection ⟨6, 6, 5, 5⟩ == none

/-- The intersection of two rectangles, or `none` when they do not intersect.
A zero-area overlap of non-empty float rects is a valid (zero-size) result.
C: `SDL_GetRectIntersectionFloat`. -/
def FRect.intersection (a b : FRect) : Option FRect :=
  if a.isEmpty || b.isEmpty then none
  else
    let x := max a.x b.x
    let y := max a.y b.y
    let w := min (a.x + a.w) (b.x + b.w) - x
    let h := min (a.y + a.h) (b.y + b.h) - y
    if w < 0 || h < 0 then none else some { x, y, w, h }

#guard (FRect.mk 0 0 10 10).intersection ⟨5, 5, 10, 10⟩ == some ⟨5, 5, 5, 5⟩
#guard (FRect.mk 0 0 5 5).intersection ⟨5, 0, 5, 5⟩ == some ⟨5, 0, 0, 5⟩  -- touching
#guard (FRect.mk 0 0 (-1) 5).intersection ⟨0, 0, 5, 5⟩ == none
#guard (FRect.mk 0 0 5 5).intersection ⟨6, 6, 5, 5⟩ == none

/-- The union (bounding box) of two rectangles. An empty rect is the identity:
union with it returns the other rect, and the union of two empty rects is the
zero rect. Total in Lean — C's `bool` only signals NULL arguments.
C: `SDL_GetRectUnion`. -/
def Rect.union (a b : Rect) : Rect :=
  if a.isEmpty then
    if b.isEmpty then ⟨0, 0, 0, 0⟩ else b
  else if b.isEmpty then a
  else
    let x := min a.x b.x
    let y := min a.y b.y
    let w := max (a.x + a.w) (b.x + b.w) - x
    let h := max (a.y + a.h) (b.y + b.h) - y
    { x, y, w, h }

#guard (Rect.mk 0 0 5 5).union ⟨10 , 10, 5, 5⟩ == ⟨0, 0, 15, 15⟩
#guard (Rect.mk 0 0 5 5).union ⟨3, 3, 0, 0⟩ == ⟨0, 0, 5, 5⟩   -- empty is identity
#guard (Rect.mk 3 3 0 0).union ⟨1, 1, 4, 4⟩ == ⟨1, 1, 4, 4⟩   -- empty is identity
#guard (Rect.mk 0 0 0 0).union ⟨0, 0, (-1), 5⟩ == ⟨0, 0, 0, 0⟩ -- both empty: zero rect
#guard (Rect.mk (-5) (-5) 5 5).union ⟨0, 0, 5, 5⟩ == ⟨(-5), (-5), 10, 10⟩

/-- The union (bounding box) of two rectangles. A float-empty rect
(`w < 0`/`h < 0`) is the identity; both empty gives the zero rect. Note that a
zero-size float rect is *not* empty and its corner extends the union.
C: `SDL_GetRectUnionFloat`. -/
def FRect.union (a b : FRect) : FRect :=
  if a.isEmpty then
    if b.isEmpty then ⟨0, 0, 0, 0⟩ else b
  else if b.isEmpty then a
  else
    let x := min a.x b.x
    let y := min a.y b.y
    let w := max (a.x + a.w) (b.x + b.w) - x
    let h := max (a.y + a.h) (b.y + b.h) - y
    { x, y, w, h }

#guard (FRect.mk 0 0 5 5).union ⟨10, 10, 5, 5⟩ == ⟨0, 0, 15, 15⟩
#guard (FRect.mk 10 10 (-1) 5).union ⟨1, 1, 4, 4⟩ == ⟨1, 1, 4, 4⟩  -- float-empty identity
#guard (FRect.mk 10 10 0 0).union ⟨1, 1, 4, 4⟩ == ⟨1, 1, 9, 9⟩  -- zero-size still counts
#guard (FRect.mk 0 0 (-1) 0).union ⟨0, 0, 0, (-1)⟩ == ⟨0, 0, 0, 0⟩

/-- The minimal rectangle enclosing `points` — only those inside `clip` when
one is given (integer point-in-rect semantics: far edges exclusive). `none` if
the array is empty or no point survives the clip (C returns `false`).
C: `SDL_GetRectEnclosingPoints`. -/
def Rect.enclosingPoints (points : Array Point) (clip : Option Rect := none) :
    Option Rect := Id.run do
  let mut acc : Option (Int32 × Int32 × Int32 × Int32) := none
  for p in points do
    if clip.all p.inRect then
      acc := match acc with
        | none => some (p.x, p.y, p.x, p.y)
        | some (minx, miny, maxx, maxy) =>
          some (min minx p.x, min miny p.y, max maxx p.x, max maxy p.y)
  return acc.map fun (minx, miny, maxx, maxy) =>
    { x := minx, y := miny, w := maxx - minx + 1, h := maxy - miny + 1 }

#guard Rect.enclosingPoints #[⟨1, 2⟩, ⟨5, 9⟩, ⟨3, 4⟩] == some ⟨1, 2, 5, 8⟩
#guard Rect.enclosingPoints #[⟨1, 2⟩, ⟨5, 9⟩, ⟨3, 4⟩] (clip := some ⟨0, 0, 4, 5⟩)
  == some ⟨1, 2, 3, 3⟩
#guard Rect.enclosingPoints #[⟨7, 7⟩] == some ⟨7, 7, 1, 1⟩
#guard Rect.enclosingPoints #[] == none
#guard Rect.enclosingPoints #[⟨9, 9⟩] (clip := some ⟨0, 0, 5, 5⟩) == none
#guard Rect.enclosingPoints #[⟨4, 2⟩] (clip := some ⟨0, 0, 4, 5⟩) == none  -- far edge excl.
#guard Rect.enclosingPoints #[⟨1, 1⟩] (clip := some ⟨0, 0, 0, 0⟩) == none  -- empty clip

/-- The minimal rectangle enclosing `points` — only those inside `clip` when
one is given (float point-in-rect semantics: far edges inclusive). Unlike the
integer version the result's `w`/`h` are exactly `max - min` (no `+ 1`).
`none` if the array is empty or no point survives the clip.
C: `SDL_GetRectEnclosingPointsFloat`. -/
def FRect.enclosingPoints (points : Array FPoint) (clip : Option FRect := none) :
    Option FRect := Id.run do
  let mut acc : Option (Float32 × Float32 × Float32 × Float32) := none
  for p in points do
    if clip.all p.inRect then
      acc := match acc with
        | none => some (p.x, p.y, p.x, p.y)
        | some (minx, miny, maxx, maxy) =>
          some (min minx p.x, min miny p.y, max maxx p.x, max maxy p.y)
  return acc.map fun (minx, miny, maxx, maxy) =>
    { x := minx, y := miny, w := maxx - minx, h := maxy - miny }

#guard FRect.enclosingPoints #[⟨1, 2⟩, ⟨5, 9⟩, ⟨3, 4⟩] == some ⟨1, 2, 4, 7⟩
#guard FRect.enclosingPoints #[⟨1, 2⟩, ⟨5, 9⟩, ⟨3, 4⟩] (clip := some ⟨0, 0, 4, 5⟩)
  == some ⟨1, 2, 2, 2⟩
#guard FRect.enclosingPoints #[⟨4, 2⟩] (clip := some ⟨0, 0, 4, 5⟩)
  == some ⟨4, 2, 0, 0⟩  -- far edge inclusive (float)
#guard FRect.enclosingPoints #[] == none

/-! ## Line clipping (Cohen–Sutherland)

Shared machinery for `Rect.lineIntersection` / `FRect.lineIntersection`. The
integer version computes boundary crossings with exact rational arithmetic
truncated toward zero — identical to SDL's `double` intermediate for any
coordinates whose cross products stay below 2^53 (SDL only differs beyond
that, where its `double` rounds). -/

/-- Outcode for Cohen–Sutherland clipping against the inclusive bounds
`[xmin, xmax] × [ymin, ymax]`: bit 1 = below, 2 = above, 4 = left, 8 = right.
Mirrors the `COMPUTEOUTCODE` helper in SDL's rect implementation. -/
private def lineOutcode (xmin ymin xmax ymax x y : Int) : UInt32 :=
  let c : UInt32 := if y < ymin then 2 else if y > ymax then 1 else 0
  if x < xmin then c ||| 4 else if x > xmax then c ||| 8 else c

/-- Clip endpoint `(x, y)` (outcode `code`) of the segment toward the other
endpoint `(ox, oy)`, testing edges in SDL's order (top, bottom, left, right).
The crossing is `trunc`-rounded toward zero like C's `(int)` cast. -/
private def lineClipOnce (xmin ymin xmax ymax x y ox oy : Int) (code : UInt32) :
    Int × Int :=
  if code &&& 2 != 0 then       -- above: clip to y = ymin
    (Int.tdiv (x * (oy - y) + (ox - x) * (ymin - y)) (oy - y), ymin)
  else if code &&& 1 != 0 then  -- below: clip to y = ymax
    (Int.tdiv (x * (oy - y) + (ox - x) * (ymax - y)) (oy - y), ymax)
  else if code &&& 4 != 0 then  -- left: clip to x = xmin
    (xmin, Int.tdiv (y * (ox - x) + (oy - y) * (xmin - x)) (ox - x))
  else                          -- right: clip to x = xmax
    (xmax, Int.tdiv (y * (ox - x) + (oy - y) * (xmax - x)) (ox - x))

/-- Cohen–Sutherland iteration (fuel-bounded; the algorithm needs at most two
clips per endpoint, so the fuel is never exhausted for sane input). -/
private def lineClipLoop (xmin ymin xmax ymax : Int) :
    Nat → Int → Int → Int → Int → Option (Int × Int × Int × Int)
  | 0, _, _, _, _ => none
  | fuel + 1, x1, y1, x2, y2 =>
    let out1 := lineOutcode xmin ymin xmax ymax x1 y1
    let out2 := lineOutcode xmin ymin xmax ymax x2 y2
    if out1 == 0 && out2 == 0 then some (x1, y1, x2, y2)
    else if out1 &&& out2 != 0 then none
    else if out1 != 0 then
      let (nx, ny) := lineClipOnce xmin ymin xmax ymax x1 y1 x2 y2 out1
      lineClipLoop xmin ymin xmax ymax fuel nx ny x2 y2
    else
      let (nx, ny) := lineClipOnce xmin ymin xmax ymax x2 y2 x1 y1 out2
      lineClipLoop xmin ymin xmax ymax fuel x1 y1 nx ny

/-- Clip the segment `(x1, y1)-(x2, y2)` to `r`. A segment entirely inside
comes back unchanged; one entirely outside gives `none` (C returns `false`);
one crossing the boundary comes back with the exterior part cut at the
boundary (inclusive far edge `x + w - 1` / `y + h - 1`). An empty rect
intersects nothing. C: `SDL_GetRectAndLineIntersection`. -/
def Rect.lineIntersection (r : Rect) (x1 y1 x2 y2 : Int32) :
    Option (Int32 × Int32 × Int32 × Int32) :=
  if r.isEmpty then none else
  let xmin := r.x.toInt
  let ymin := r.y.toInt
  let xmax := r.x.toInt + r.w.toInt - 1
  let ymax := r.y.toInt + r.h.toInt - 1
  let ix1 := x1.toInt
  let iy1 := y1.toInt
  let ix2 := x2.toInt
  let iy2 := y2.toInt
  -- entirely inside: unchanged
  if ix1 >= xmin && ix1 <= xmax && ix2 >= xmin && ix2 <= xmax &&
     iy1 >= ymin && iy1 <= ymax && iy2 >= ymin && iy2 <= ymax then
    some (x1, y1, x2, y2)
  -- entirely on one side: no intersection
  else if (ix1 < xmin && ix2 < xmin) || (ix1 > xmax && ix2 > xmax) ||
          (iy1 < ymin && iy2 < ymin) || (iy1 > ymax && iy2 > ymax) then
    none
  else if iy1 == iy2 then  -- horizontal: clamp the xs
    some ((min (max ix1 xmin) xmax).toInt32, y1, (min (max ix2 xmin) xmax).toInt32, y2)
  else if ix1 == ix2 then  -- vertical: clamp the ys
    some (x1, (min (max iy1 ymin) ymax).toInt32, x2, (min (max iy2 ymin) ymax).toInt32)
  else
    (lineClipLoop xmin ymin xmax ymax 8 ix1 iy1 ix2 iy2).map
      fun (a, b, c, d) => (a.toInt32, b.toInt32, c.toInt32, d.toInt32)

#guard (Rect.mk 0 0 10 10).lineIntersection 2 2 5 5 == some (2, 2, 5, 5)     -- inside
#guard (Rect.mk 0 0 10 10).lineIntersection (-5) 20 (-1) 25 == none          -- outside
#guard (Rect.mk 0 0 10 10).lineIntersection (-5) 5 15 5 == some (0, 5, 9, 5) -- horizontal
#guard (Rect.mk 0 0 10 10).lineIntersection 5 (-5) 5 15 == some (5, 0, 5, 9) -- vertical
#guard (Rect.mk 0 0 10 10).lineIntersection (-5) (-5) 15 15 == some (0, 0, 9, 9)
#guard (Rect.mk 0 0 10 10).lineIntersection (-10) 0 0 (-10) == none          -- corner miss
#guard (Rect.mk 0 0 10 10).lineIntersection (-1) 4 4 (-1) == some (0, 3, 3, 0)
#guard (Rect.mk 0 0 10 10).lineIntersection 5 5 15 25 == some (5, 5, 7, 9)   -- one end in
#guard (Rect.mk 0 0 0 10).lineIntersection 2 2 5 5 == none                   -- empty rect

/-- Float outcode; same bit layout as `lineOutcode` over the inclusive bounds
`[xmin, xmax] × [ymin, ymax]`. -/
private def lineOutcodeF (xmin ymin xmax ymax x y : Float32) : UInt32 :=
  let c : UInt32 := if y < ymin then 2 else if y > ymax then 1 else 0
  if x < xmin then c ||| 4 else if x > xmax then c ||| 8 else c

/-- Float clip step (crossings computed in `Float32`). -/
private def lineClipOnceF (xmin ymin xmax ymax x y ox oy : Float32) (code : UInt32) :
    Float32 × Float32 :=
  if code &&& 2 != 0 then
    (x + (ox - x) * (ymin - y) / (oy - y), ymin)
  else if code &&& 1 != 0 then
    (x + (ox - x) * (ymax - y) / (oy - y), ymax)
  else if code &&& 4 != 0 then
    (xmin, y + (oy - y) * (xmin - x) / (ox - x))
  else
    (xmax, y + (oy - y) * (xmax - x) / (ox - x))

/-- Float Cohen–Sutherland iteration (fuel-bounded like `lineClipLoop`). -/
private def lineClipLoopF (xmin ymin xmax ymax : Float32) :
    Nat → Float32 → Float32 → Float32 → Float32 →
    Option (Float32 × Float32 × Float32 × Float32)
  | 0, _, _, _, _ => none
  | fuel + 1, x1, y1, x2, y2 =>
    let out1 := lineOutcodeF xmin ymin xmax ymax x1 y1
    let out2 := lineOutcodeF xmin ymin xmax ymax x2 y2
    if out1 == 0 && out2 == 0 then some (x1, y1, x2, y2)
    else if out1 &&& out2 != 0 then none
    else if out1 != 0 then
      let (nx, ny) := lineClipOnceF xmin ymin xmax ymax x1 y1 x2 y2 out1
      lineClipLoopF xmin ymin xmax ymax fuel nx ny x2 y2
    else
      let (nx, ny) := lineClipOnceF xmin ymin xmax ymax x2 y2 x1 y1 out2
      lineClipLoopF xmin ymin xmax ymax fuel x1 y1 nx ny

/-- Clip the segment `(x1, y1)-(x2, y2)` to `r`. Like `Rect.lineIntersection`
but with the float rect's inclusive far edge at exactly `x + w` / `y + h`, and
crossings computed in `Float32`. C: `SDL_GetRectAndLineIntersectionFloat`. -/
def FRect.lineIntersection (r : FRect) (x1 y1 x2 y2 : Float32) :
    Option (Float32 × Float32 × Float32 × Float32) :=
  if r.isEmpty then none else
  let xmin := r.x
  let ymin := r.y
  let xmax := r.x + r.w
  let ymax := r.y + r.h
  if x1 >= xmin && x1 <= xmax && x2 >= xmin && x2 <= xmax &&
     y1 >= ymin && y1 <= ymax && y2 >= ymin && y2 <= ymax then
    some (x1, y1, x2, y2)
  else if (x1 < xmin && x2 < xmin) || (x1 > xmax && x2 > xmax) ||
          (y1 < ymin && y2 < ymin) || (y1 > ymax && y2 > ymax) then
    none
  else if y1 == y2 then
    some (min (max x1 xmin) xmax, y1, min (max x2 xmin) xmax, y2)
  else if x1 == x2 then
    some (x1, min (max y1 ymin) ymax, x2, min (max y2 ymin) ymax)
  else
    lineClipLoopF xmin ymin xmax ymax 8 x1 y1 x2 y2

#guard (FRect.mk 0 0 10 10).lineIntersection 2 2 5 5 == some (2, 2, 5, 5)
#guard (FRect.mk 0 0 10 10).lineIntersection (-5) 5 15 5 == some (0, 5, 10, 5)
#guard (FRect.mk 0 0 10 10).lineIntersection (-5) (-5) 15 15 == some (0, 0, 10, 10)
#guard (FRect.mk 0 0 10 10).lineIntersection 5 5 15 25 == some (5, 5, 7.5, 10)
#guard (FRect.mk 0 0 10 10).lineIntersection 11 (-5) 15 15 == none
#guard (FRect.mk 0 0 (-1) 10).lineIntersection 2 2 5 5 == none

end Sdl
