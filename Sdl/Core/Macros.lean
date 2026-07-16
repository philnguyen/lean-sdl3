module

meta import Lean
public meta import Std.Data.HashMap.Basic
public meta import Std.Data.HashSet.Basic

/-!
# Binding-kit macros

Command macros generating the repetitive Lean-side boilerplate for SDL
bindings (see `docs/DESIGN.md` §"Binding-kit macros"):

* `sdl_opaque X` — opaque handle type for a C pointer.
* `sdl_id X : UIntN where …` — 1-field wrapper for IDs / open numeric domains.
* `sdl_enum X : UIntN where | a => 0 …` — closed C enum as a Lean `inductive`.
* `sdl_enum_open X : UIntN where …` — version-open enum (extra `other (raw)`).
* `sdl_flags X : UIntN where | f := 0x1 …` — bit flags as a 1-field structure.

Every macro requires a leading doc comment citing the exact C name. Members
carry a `-- C: SDL_NAME` comment for greppability. The FFI boundary always
converts through the generated `val`/`ofVal?`/`ofVal`; a Lean inductive's tag
is never assumed to equal the C value.
-/

public meta section

namespace Sdl.Core.Macros
open Lean

/-- Derive `FooPointed` from `Foo`. -/
private def pointedName (id : Ident) : Ident :=
  mkIdentFrom id (id.getId.modifyBase (·.appendAfter "Pointed"))

/-- Qualify a member name: `(Flags, audio) ↦ Flags.audio`. -/
private def memberName (ty : Ident) (mem : Ident) : Ident :=
  mkIdentFrom mem (ty.getId ++ mem.getId)

/-- Opaque handle type for a C pointer.

`sdl_opaque Window` generates the `NonemptyType` boilerplate:
`private opaque WindowPointed : NonemptyType`, `def Window`, and the
`Nonempty Window` instance required by `@[extern]` signatures. -/
syntax (name := sdlOpaque) docComment "sdl_opaque " ident : command

macro_rules
  | `($doc:docComment sdl_opaque $id:ident) => do
    let ptd := pointedName id
    `(private opaque $ptd:ident : NonemptyType
      $doc:docComment
      def $id:ident : Type := NonemptyType.type $ptd
      instance : Nonempty $id:ident := Subtype.property $ptd)

/-- The syntax kind of doc comments. -/
private abbrev DocComment := TSyntax `Lean.Parser.Command.docComment

/-- Member with an assigned raw value: `| name := 0x10`. The doc comment is
grouped atomically with `|` so a doc comment of the *following* command isn't
consumed as a member prefix. -/
syntax sdlMemberAssign := atomic((docComment)? "| ") ident " := " num
/-- Member with a mapped raw value: `| name => 3`. -/
syntax sdlMemberArrow := atomic((docComment)? "| ") ident " => " num

/-- Destructure a parsed `sdlMemberAssign`. -/
private def getAssign : TSyntax ``sdlMemberAssign →
    MacroM (Option DocComment × Ident × TSyntax `num)
  | `(sdlMemberAssign| $[$doc?:docComment]? | $n:ident := $v:num) => return (doc?, n, v)
  | _ => Macro.throwUnsupported

/-- Destructure a parsed `sdlMemberArrow`. -/
private def getArrow : TSyntax ``sdlMemberArrow →
    MacroM (Option DocComment × Ident × TSyntax `num)
  | `(sdlMemberArrow| $[$doc?:docComment]? | $n:ident => $v:num) => return (doc?, n, v)
  | _ => Macro.throwUnsupported

/-- `def Ty.name : Ty := ⟨val⟩`, with optional doc comment, plus a `#guard`. -/
private def mkConstMember (id : Ident) (doc? : Option DocComment)
    (n : Ident) (v : TSyntax `num) : MacroM (Array (TSyntax `command)) := do
  let member := memberName id n
  let d ← match doc? with
    | some d => `($d:docComment @[expose] def $member:ident : $id := ⟨$v⟩)
    | none   => `(@[expose] def $member:ident : $id := ⟨$v⟩)
  let g ← `(#guard ($member:ident).val == $v)
  return #[d, g]

/-- 1-field wrapper structure for IDs and open numeric domains, with optional
named constants. Example:
```
/-- C: `SDL_Keycode`. -/
sdl_id Keycode : UInt32 where
  | unknown := 0x0  -- C: SDLK_UNKNOWN
```
-/
syntax (name := sdlId) docComment "sdl_id " ident " : " ident
  (" where" sdlMemberAssign+)? : command

macro_rules
  | `($doc:docComment sdl_id $id:ident : $ty:ident $[where $mems?:sdlMemberAssign*]?) => do
    let mut cmds : Array (TSyntax `command) := #[]
    cmds := cmds.push <| ←
      `($doc:docComment
        structure $id:ident where
          val : $ty
          deriving BEq, Hashable, Repr, Inhabited, DecidableEq)
    for m in mems?.getD #[] do
      let (doc?, n, v) ← getAssign m
      cmds := cmds ++ (← mkConstMember id doc? n v)
    return mkNullNode (cmds.map (·.raw))

/-- Shared expansion for `sdl_enum` / `sdl_enum_open`. -/
private def mkEnum (doc : DocComment) (id ty : Ident)
    (mems : Array (TSyntax ``sdlMemberArrow)) (isOpen : Bool) :
    MacroM Syntax := do
  let parsed ← mems.mapM getArrow
  let names := parsed.map (fun (_, n, _) => n)
  let pats  := names.map (memberName id)
  let vals  := parsed.map (fun (_, _, v) => v)
  let valId   := memberName id (mkIdent `val)
  let otherBare : Ident := mkIdent `other
  let otherId := memberName id otherBare
  let mut cmds : Array (TSyntax `command) := #[]
  -- the inductive (`$otherBare` keeps the ctor name unhygienic)
  cmds := cmds.push <| ← if isOpen then
      `($doc:docComment
        inductive $id:ident where
          $[| $names:ident]*
          | $otherBare:ident (raw : $ty)
          deriving BEq, Hashable, Repr, Inhabited, DecidableEq)
    else
      `($doc:docComment
        inductive $id:ident where
          $[| $names:ident]*
          deriving BEq, Hashable, Repr, Inhabited, DecidableEq)
  -- val : X → UIntN
  cmds := cmds.push <| ← if isOpen then
      `(/-- Raw C value. -/
        def $valId:ident : $id → $ty
          $[| $pats:ident => $vals:num]*
          | $otherId:ident raw => raw)
    else
      `(/-- Raw C value. -/
        def $valId:ident : $id → $ty
          $[| $pats:ident => $vals:num]*)
  -- decode: ofVal? (closed) / total ofVal (open); dedup aliased values (first wins)
  let mut seen : Std.HashSet Nat := {}
  let mut dPats : Array Ident := #[]
  let mut dVals : Array (TSyntax `num) := #[]
  for h : i in [0:vals.size] do
    let v := vals[i]
    if !seen.contains v.getNat then
      seen := seen.insert v.getNat
      dPats := dPats.push pats[i]!
      dVals := dVals.push v
  if isOpen then
    let ofValId := memberName id (mkIdent `ofVal)
    cmds := cmds.push <| ←
      `(/-- Decode a raw C value (total; unmapped values become `other`). -/
        def $ofValId:ident : $ty → $id
          $[| $dVals:num => $dPats:ident]*
          | raw => $otherId:ident raw)
    for i in [0:dVals.size] do
      cmds := cmds.push <| ← `(#guard $ofValId:ident $(dVals[i]!) == $(dPats[i]!):ident)
    cmds := cmds.push <| ← `(#guard $ofValId:ident 0xffffff == $otherId:ident 0xffffff)
  else
    let ofValId := memberName id (mkIdent `ofVal?)
    cmds := cmds.push <| ←
      `(/-- Decode a raw C value. -/
        def $ofValId:ident : $ty → Option $id
          $[| $dVals:num => some $dPats:ident]*
          | _ => none)
    for i in [0:dVals.size] do
      cmds := cmds.push <| ← `(#guard $ofValId:ident $(dVals[i]!) == some $(dPats[i]!):ident)
  -- val round-trip guards (all members, including aliases)
  for i in [0:pats.size] do
    cmds := cmds.push <| ← `(#guard $valId:ident $(pats[i]!) == $(vals[i]!))
  return mkNullNode (cmds.map (·.raw))

/-- Closed C enum as a genuine Lean `inductive` (exhaustive `match`), with
`val`, `ofVal?`, and generated `#guard`s. Example:
```
/-- C: `SDL_AppResult`. -/
sdl_enum AppResult : UInt32 where
  | «continue» => 0  -- C: SDL_APP_CONTINUE
  | success    => 1  -- C: SDL_APP_SUCCESS
  | failure    => 2  -- C: SDL_APP_FAILURE
```
-/
syntax (name := sdlEnum) docComment "sdl_enum " ident " : " ident
  " where" sdlMemberArrow+ : command

/-- Version-open C enum: like `sdl_enum` but with a final `other (raw : UIntN)`
constructor and a **total** `ofVal`, for enums that may grow in future SDL
releases and appear in C→Lean return positions. -/
syntax (name := sdlEnumOpen) docComment "sdl_enum_open " ident " : " ident
  " where" sdlMemberArrow+ : command

macro_rules
  | `($doc:docComment sdl_enum $id:ident : $ty:ident where $mems:sdlMemberArrow*) =>
    mkEnum doc id ty mems false
  | `($doc:docComment sdl_enum_open $id:ident : $ty:ident where $mems:sdlMemberArrow*) =>
    mkEnum doc id ty mems true

/-- Bit flags as a 1-field structure with bitwise instances, `none`, `has`,
named members, and generated `#guard`s. Example:
```
/-- C: `SDL_InitFlags`. -/
sdl_flags InitFlags : UInt32 where
  | audio := 0x00000010  -- C: SDL_INIT_AUDIO
```
-/
syntax (name := sdlFlags) docComment "sdl_flags " ident " : " ident
  " where" sdlMemberAssign+ : command

macro_rules
  | `($doc:docComment sdl_flags $id:ident : $ty:ident where $mems:sdlMemberAssign*) => do
    let noneId := memberName id (mkIdent `none)
    let hasId  := memberName id (mkIdent `has)
    let mut cmds : Array (TSyntax `command) := #[]
    cmds := cmds.push <| ←
      `($doc:docComment
        structure $id:ident where
          val : $ty
          deriving BEq, Hashable, Repr, Inhabited, DecidableEq)
    cmds := cmds.push <| ←
      `(instance : _root_.OrOp $id := ⟨fun a b => ⟨a.val ||| b.val⟩⟩
        instance : _root_.AndOp $id := ⟨fun a b => ⟨a.val &&& b.val⟩⟩
        instance : _root_.XorOp $id := ⟨fun a b => ⟨a.val ^^^ b.val⟩⟩
        instance : _root_.Complement $id := ⟨fun a => ⟨~~~ a.val⟩⟩
        /-- The empty flag set. -/
        def $noneId:ident : $id := ⟨0⟩
        /-- `a.has b`: every bit of `b` is set in `a`. -/
        def $hasId:ident (a b : $id) : Bool := a.val &&& b.val == b.val)
    for m in mems do
      let (doc?, n, v) ← getAssign m
      cmds := cmds ++ (← mkConstMember id doc? n v)
    return mkNullNode (cmds.map (·.raw))

end Sdl.Core.Macros

end

/-! ## Self-tests (compile-time; no SDL linkage required) -/

namespace Sdl.Core.Macros.SelfTest

/-- C: (self-test only). -/
sdl_opaque TestHandle

/-- C: (self-test only). -/
sdl_id TestId : UInt32 where
  /-- C: (self-test only). -/
  | invalid := 0
  | first := 1

/-- C: (self-test only). -/
sdl_enum TestEnum : UInt32 where
  | alpha => 0
  | beta  => 5
  | «continue» => 7
  | betaAlias  => 5

/-- C: (self-test only). -/
sdl_enum_open TestOpen : UInt16 where
  | first  => 1
  | second => 2

/-- C: (self-test only). -/
sdl_flags TestFlags : UInt64 where
  | one := 0x1
  | two := 0x2
  | big := 0x8000000000000000

#guard TestEnum.ofVal? 5 == some .beta
#guard TestEnum.ofVal? 4 == none
#guard TestEnum.betaAlias.val == 5
#guard TestEnum.«continue».val == 7
#guard TestOpen.ofVal 2 == .second
#guard TestOpen.ofVal 99 == .other 99
#guard (TestOpen.ofVal 99).val == 99
#guard (TestFlags.one ||| TestFlags.two).val == 3
#guard (TestFlags.one ||| TestFlags.two).has .two
#guard !(TestFlags.one.has .two)
#guard (~~~TestFlags.none).has .big
#guard TestId.invalid.val == 0
#guard TestId.first != TestId.invalid
example : Nonempty TestHandle := inferInstance

end Sdl.Core.Macros.SelfTest
