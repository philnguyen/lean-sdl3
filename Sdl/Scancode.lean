module

public import Sdl.Core.Macros
public meta import Sdl.Core.Macros

public section

/-!
# Keyboard scancodes (`SDL_scancode.h`)

Physical key positions, independent of keyboard layout: a scancode names
*where* a key sits on the keyboard (USB usage-page based), not what character
it produces.

`Scancode` is an **open numeric domain**, modelled as an `sdl_id` (a 1-field
`UInt32` wrapper with named constants) rather than a Lean `inductive`. SDL
reserves the range 400–500 for dynamically-added scancodes and may add named
members in future releases; a wrapper represents *every* raw value (named
constants for the known keys, bare `⟨raw⟩` for reserved/dynamic/future codes),
so decoding from C is total and lossless.

Model note: `SDL_Scancode` is a C `enum`, so `sdl_enum_open` would be the
natural fit, but a Lean `inductive` with one constructor per member exceeds the
runtime's constructor-tag limit (≤ 243 named members) at this size, so the
open-numeric-domain `sdl_id` form is used here — the same treatment as
`Keycode`. The two non-key markers `SDL_SCANCODE_RESERVED` (400) and
`SDL_SCANCODE_COUNT` (512) are not given named constants; the array bound is
exposed separately as `Scancode.maxScancodes`.
-/

namespace Sdl

/-- A keyboard scancode: the physical position of a key, independent of the
current layout. Open numeric domain (named constants only; a bare `⟨raw⟩` holds
reserved/dynamic/future codes). C: `SDL_Scancode`. -/
sdl_id Scancode : UInt32 where
  | unknown              := 0    -- C: SDL_SCANCODE_UNKNOWN
  | a                    := 4    -- C: SDL_SCANCODE_A
  | b                    := 5    -- C: SDL_SCANCODE_B
  | c                    := 6    -- C: SDL_SCANCODE_C
  | d                    := 7    -- C: SDL_SCANCODE_D
  | e                    := 8    -- C: SDL_SCANCODE_E
  | f                    := 9    -- C: SDL_SCANCODE_F
  | g                    := 10   -- C: SDL_SCANCODE_G
  | h                    := 11   -- C: SDL_SCANCODE_H
  | i                    := 12   -- C: SDL_SCANCODE_I
  | j                    := 13   -- C: SDL_SCANCODE_J
  | k                    := 14   -- C: SDL_SCANCODE_K
  | l                    := 15   -- C: SDL_SCANCODE_L
  | m                    := 16   -- C: SDL_SCANCODE_M
  | n                    := 17   -- C: SDL_SCANCODE_N
  | o                    := 18   -- C: SDL_SCANCODE_O
  | p                    := 19   -- C: SDL_SCANCODE_P
  | q                    := 20   -- C: SDL_SCANCODE_Q
  | r                    := 21   -- C: SDL_SCANCODE_R
  | s                    := 22   -- C: SDL_SCANCODE_S
  | t                    := 23   -- C: SDL_SCANCODE_T
  | u                    := 24   -- C: SDL_SCANCODE_U
  | v                    := 25   -- C: SDL_SCANCODE_V
  | w                    := 26   -- C: SDL_SCANCODE_W
  | x                    := 27   -- C: SDL_SCANCODE_X
  | y                    := 28   -- C: SDL_SCANCODE_Y
  | z                    := 29   -- C: SDL_SCANCODE_Z
  | num1                 := 30   -- C: SDL_SCANCODE_1
  | num2                 := 31   -- C: SDL_SCANCODE_2
  | num3                 := 32   -- C: SDL_SCANCODE_3
  | num4                 := 33   -- C: SDL_SCANCODE_4
  | num5                 := 34   -- C: SDL_SCANCODE_5
  | num6                 := 35   -- C: SDL_SCANCODE_6
  | num7                 := 36   -- C: SDL_SCANCODE_7
  | num8                 := 37   -- C: SDL_SCANCODE_8
  | num9                 := 38   -- C: SDL_SCANCODE_9
  | num0                 := 39   -- C: SDL_SCANCODE_0
  | «return»             := 40   -- C: SDL_SCANCODE_RETURN
  | escape               := 41   -- C: SDL_SCANCODE_ESCAPE
  | backspace            := 42   -- C: SDL_SCANCODE_BACKSPACE
  | tab                  := 43   -- C: SDL_SCANCODE_TAB
  | space                := 44   -- C: SDL_SCANCODE_SPACE
  | minus                := 45   -- C: SDL_SCANCODE_MINUS
  | equals               := 46   -- C: SDL_SCANCODE_EQUALS
  | leftBracket          := 47   -- C: SDL_SCANCODE_LEFTBRACKET
  | rightBracket         := 48   -- C: SDL_SCANCODE_RIGHTBRACKET
  | backslash            := 49   -- C: SDL_SCANCODE_BACKSLASH
  | nonUsHash            := 50   -- C: SDL_SCANCODE_NONUSHASH
  | semicolon            := 51   -- C: SDL_SCANCODE_SEMICOLON
  | apostrophe           := 52   -- C: SDL_SCANCODE_APOSTROPHE
  | grave                := 53   -- C: SDL_SCANCODE_GRAVE
  | comma                := 54   -- C: SDL_SCANCODE_COMMA
  | period               := 55   -- C: SDL_SCANCODE_PERIOD
  | slash                := 56   -- C: SDL_SCANCODE_SLASH
  | capsLock             := 57   -- C: SDL_SCANCODE_CAPSLOCK
  | f1                   := 58   -- C: SDL_SCANCODE_F1
  | f2                   := 59   -- C: SDL_SCANCODE_F2
  | f3                   := 60   -- C: SDL_SCANCODE_F3
  | f4                   := 61   -- C: SDL_SCANCODE_F4
  | f5                   := 62   -- C: SDL_SCANCODE_F5
  | f6                   := 63   -- C: SDL_SCANCODE_F6
  | f7                   := 64   -- C: SDL_SCANCODE_F7
  | f8                   := 65   -- C: SDL_SCANCODE_F8
  | f9                   := 66   -- C: SDL_SCANCODE_F9
  | f10                  := 67   -- C: SDL_SCANCODE_F10
  | f11                  := 68   -- C: SDL_SCANCODE_F11
  | f12                  := 69   -- C: SDL_SCANCODE_F12
  | printScreen          := 70   -- C: SDL_SCANCODE_PRINTSCREEN
  | scrollLock           := 71   -- C: SDL_SCANCODE_SCROLLLOCK
  | pause                := 72   -- C: SDL_SCANCODE_PAUSE
  | insert               := 73   -- C: SDL_SCANCODE_INSERT
  | home                 := 74   -- C: SDL_SCANCODE_HOME
  | pageUp               := 75   -- C: SDL_SCANCODE_PAGEUP
  | delete               := 76   -- C: SDL_SCANCODE_DELETE
  | «end»                := 77   -- C: SDL_SCANCODE_END
  | pageDown             := 78   -- C: SDL_SCANCODE_PAGEDOWN
  | right                := 79   -- C: SDL_SCANCODE_RIGHT
  | left                 := 80   -- C: SDL_SCANCODE_LEFT
  | down                 := 81   -- C: SDL_SCANCODE_DOWN
  | up                   := 82   -- C: SDL_SCANCODE_UP
  | numLockClear         := 83   -- C: SDL_SCANCODE_NUMLOCKCLEAR
  | kpDivide             := 84   -- C: SDL_SCANCODE_KP_DIVIDE
  | kpMultiply           := 85   -- C: SDL_SCANCODE_KP_MULTIPLY
  | kpMinus              := 86   -- C: SDL_SCANCODE_KP_MINUS
  | kpPlus               := 87   -- C: SDL_SCANCODE_KP_PLUS
  | kpEnter              := 88   -- C: SDL_SCANCODE_KP_ENTER
  | kp1                  := 89   -- C: SDL_SCANCODE_KP_1
  | kp2                  := 90   -- C: SDL_SCANCODE_KP_2
  | kp3                  := 91   -- C: SDL_SCANCODE_KP_3
  | kp4                  := 92   -- C: SDL_SCANCODE_KP_4
  | kp5                  := 93   -- C: SDL_SCANCODE_KP_5
  | kp6                  := 94   -- C: SDL_SCANCODE_KP_6
  | kp7                  := 95   -- C: SDL_SCANCODE_KP_7
  | kp8                  := 96   -- C: SDL_SCANCODE_KP_8
  | kp9                  := 97   -- C: SDL_SCANCODE_KP_9
  | kp0                  := 98   -- C: SDL_SCANCODE_KP_0
  | kpPeriod             := 99   -- C: SDL_SCANCODE_KP_PERIOD
  | nonUsBackslash       := 100  -- C: SDL_SCANCODE_NONUSBACKSLASH
  | application          := 101  -- C: SDL_SCANCODE_APPLICATION
  | power                := 102  -- C: SDL_SCANCODE_POWER
  | kpEquals             := 103  -- C: SDL_SCANCODE_KP_EQUALS
  | f13                  := 104  -- C: SDL_SCANCODE_F13
  | f14                  := 105  -- C: SDL_SCANCODE_F14
  | f15                  := 106  -- C: SDL_SCANCODE_F15
  | f16                  := 107  -- C: SDL_SCANCODE_F16
  | f17                  := 108  -- C: SDL_SCANCODE_F17
  | f18                  := 109  -- C: SDL_SCANCODE_F18
  | f19                  := 110  -- C: SDL_SCANCODE_F19
  | f20                  := 111  -- C: SDL_SCANCODE_F20
  | f21                  := 112  -- C: SDL_SCANCODE_F21
  | f22                  := 113  -- C: SDL_SCANCODE_F22
  | f23                  := 114  -- C: SDL_SCANCODE_F23
  | f24                  := 115  -- C: SDL_SCANCODE_F24
  | execute              := 116  -- C: SDL_SCANCODE_EXECUTE
  | help                 := 117  -- C: SDL_SCANCODE_HELP
  | menu                 := 118  -- C: SDL_SCANCODE_MENU
  | select               := 119  -- C: SDL_SCANCODE_SELECT
  | stop                 := 120  -- C: SDL_SCANCODE_STOP
  | again                := 121  -- C: SDL_SCANCODE_AGAIN
  | undo                 := 122  -- C: SDL_SCANCODE_UNDO
  | cut                  := 123  -- C: SDL_SCANCODE_CUT
  | copy                 := 124  -- C: SDL_SCANCODE_COPY
  | paste                := 125  -- C: SDL_SCANCODE_PASTE
  | find                 := 126  -- C: SDL_SCANCODE_FIND
  | mute                 := 127  -- C: SDL_SCANCODE_MUTE
  | volumeUp             := 128  -- C: SDL_SCANCODE_VOLUMEUP
  | volumeDown           := 129  -- C: SDL_SCANCODE_VOLUMEDOWN
  | kpComma              := 133  -- C: SDL_SCANCODE_KP_COMMA
  | kpEqualsAs400        := 134  -- C: SDL_SCANCODE_KP_EQUALSAS400
  | international1       := 135  -- C: SDL_SCANCODE_INTERNATIONAL1
  | international2       := 136  -- C: SDL_SCANCODE_INTERNATIONAL2
  | international3       := 137  -- C: SDL_SCANCODE_INTERNATIONAL3
  | international4       := 138  -- C: SDL_SCANCODE_INTERNATIONAL4
  | international5       := 139  -- C: SDL_SCANCODE_INTERNATIONAL5
  | international6       := 140  -- C: SDL_SCANCODE_INTERNATIONAL6
  | international7       := 141  -- C: SDL_SCANCODE_INTERNATIONAL7
  | international8       := 142  -- C: SDL_SCANCODE_INTERNATIONAL8
  | international9       := 143  -- C: SDL_SCANCODE_INTERNATIONAL9
  | lang1                := 144  -- C: SDL_SCANCODE_LANG1
  | lang2                := 145  -- C: SDL_SCANCODE_LANG2
  | lang3                := 146  -- C: SDL_SCANCODE_LANG3
  | lang4                := 147  -- C: SDL_SCANCODE_LANG4
  | lang5                := 148  -- C: SDL_SCANCODE_LANG5
  | lang6                := 149  -- C: SDL_SCANCODE_LANG6
  | lang7                := 150  -- C: SDL_SCANCODE_LANG7
  | lang8                := 151  -- C: SDL_SCANCODE_LANG8
  | lang9                := 152  -- C: SDL_SCANCODE_LANG9
  | altErase             := 153  -- C: SDL_SCANCODE_ALTERASE
  | sysReq               := 154  -- C: SDL_SCANCODE_SYSREQ
  | cancel               := 155  -- C: SDL_SCANCODE_CANCEL
  | clear                := 156  -- C: SDL_SCANCODE_CLEAR
  | prior                := 157  -- C: SDL_SCANCODE_PRIOR
  | return2              := 158  -- C: SDL_SCANCODE_RETURN2
  | separator            := 159  -- C: SDL_SCANCODE_SEPARATOR
  | out                  := 160  -- C: SDL_SCANCODE_OUT
  | oper                 := 161  -- C: SDL_SCANCODE_OPER
  | clearAgain           := 162  -- C: SDL_SCANCODE_CLEARAGAIN
  | crSel                := 163  -- C: SDL_SCANCODE_CRSEL
  | exSel                := 164  -- C: SDL_SCANCODE_EXSEL
  | kp00                 := 176  -- C: SDL_SCANCODE_KP_00
  | kp000                := 177  -- C: SDL_SCANCODE_KP_000
  | thousandsSeparator   := 178  -- C: SDL_SCANCODE_THOUSANDSSEPARATOR
  | decimalSeparator     := 179  -- C: SDL_SCANCODE_DECIMALSEPARATOR
  | currencyUnit         := 180  -- C: SDL_SCANCODE_CURRENCYUNIT
  | currencySubunit      := 181  -- C: SDL_SCANCODE_CURRENCYSUBUNIT
  | kpLeftParen          := 182  -- C: SDL_SCANCODE_KP_LEFTPAREN
  | kpRightParen         := 183  -- C: SDL_SCANCODE_KP_RIGHTPAREN
  | kpLeftBrace          := 184  -- C: SDL_SCANCODE_KP_LEFTBRACE
  | kpRightBrace         := 185  -- C: SDL_SCANCODE_KP_RIGHTBRACE
  | kpTab                := 186  -- C: SDL_SCANCODE_KP_TAB
  | kpBackspace          := 187  -- C: SDL_SCANCODE_KP_BACKSPACE
  | kpA                  := 188  -- C: SDL_SCANCODE_KP_A
  | kpB                  := 189  -- C: SDL_SCANCODE_KP_B
  | kpC                  := 190  -- C: SDL_SCANCODE_KP_C
  | kpD                  := 191  -- C: SDL_SCANCODE_KP_D
  | kpE                  := 192  -- C: SDL_SCANCODE_KP_E
  | kpF                  := 193  -- C: SDL_SCANCODE_KP_F
  | kpXor                := 194  -- C: SDL_SCANCODE_KP_XOR
  | kpPower              := 195  -- C: SDL_SCANCODE_KP_POWER
  | kpPercent            := 196  -- C: SDL_SCANCODE_KP_PERCENT
  | kpLess               := 197  -- C: SDL_SCANCODE_KP_LESS
  | kpGreater            := 198  -- C: SDL_SCANCODE_KP_GREATER
  | kpAmpersand          := 199  -- C: SDL_SCANCODE_KP_AMPERSAND
  | kpDblAmpersand       := 200  -- C: SDL_SCANCODE_KP_DBLAMPERSAND
  | kpVerticalBar        := 201  -- C: SDL_SCANCODE_KP_VERTICALBAR
  | kpDblVerticalBar     := 202  -- C: SDL_SCANCODE_KP_DBLVERTICALBAR
  | kpColon              := 203  -- C: SDL_SCANCODE_KP_COLON
  | kpHash               := 204  -- C: SDL_SCANCODE_KP_HASH
  | kpSpace              := 205  -- C: SDL_SCANCODE_KP_SPACE
  | kpAt                 := 206  -- C: SDL_SCANCODE_KP_AT
  | kpExclam             := 207  -- C: SDL_SCANCODE_KP_EXCLAM
  | kpMemStore           := 208  -- C: SDL_SCANCODE_KP_MEMSTORE
  | kpMemRecall          := 209  -- C: SDL_SCANCODE_KP_MEMRECALL
  | kpMemClear           := 210  -- C: SDL_SCANCODE_KP_MEMCLEAR
  | kpMemAdd             := 211  -- C: SDL_SCANCODE_KP_MEMADD
  | kpMemSubtract        := 212  -- C: SDL_SCANCODE_KP_MEMSUBTRACT
  | kpMemMultiply        := 213  -- C: SDL_SCANCODE_KP_MEMMULTIPLY
  | kpMemDivide          := 214  -- C: SDL_SCANCODE_KP_MEMDIVIDE
  | kpPlusMinus          := 215  -- C: SDL_SCANCODE_KP_PLUSMINUS
  | kpClear              := 216  -- C: SDL_SCANCODE_KP_CLEAR
  | kpClearEntry         := 217  -- C: SDL_SCANCODE_KP_CLEARENTRY
  | kpBinary             := 218  -- C: SDL_SCANCODE_KP_BINARY
  | kpOctal              := 219  -- C: SDL_SCANCODE_KP_OCTAL
  | kpDecimal            := 220  -- C: SDL_SCANCODE_KP_DECIMAL
  | kpHexadecimal        := 221  -- C: SDL_SCANCODE_KP_HEXADECIMAL
  | lCtrl                := 224  -- C: SDL_SCANCODE_LCTRL
  | lShift               := 225  -- C: SDL_SCANCODE_LSHIFT
  | lAlt                 := 226  -- C: SDL_SCANCODE_LALT
  | lGui                 := 227  -- C: SDL_SCANCODE_LGUI
  | rCtrl                := 228  -- C: SDL_SCANCODE_RCTRL
  | rShift               := 229  -- C: SDL_SCANCODE_RSHIFT
  | rAlt                 := 230  -- C: SDL_SCANCODE_RALT
  | rGui                 := 231  -- C: SDL_SCANCODE_RGUI
  | mode                 := 257  -- C: SDL_SCANCODE_MODE
  | sleep                := 258  -- C: SDL_SCANCODE_SLEEP
  | wake                 := 259  -- C: SDL_SCANCODE_WAKE
  | channelIncrement     := 260  -- C: SDL_SCANCODE_CHANNEL_INCREMENT
  | channelDecrement     := 261  -- C: SDL_SCANCODE_CHANNEL_DECREMENT
  | mediaPlay            := 262  -- C: SDL_SCANCODE_MEDIA_PLAY
  | mediaPause           := 263  -- C: SDL_SCANCODE_MEDIA_PAUSE
  | mediaRecord          := 264  -- C: SDL_SCANCODE_MEDIA_RECORD
  | mediaFastForward     := 265  -- C: SDL_SCANCODE_MEDIA_FAST_FORWARD
  | mediaRewind          := 266  -- C: SDL_SCANCODE_MEDIA_REWIND
  | mediaNextTrack       := 267  -- C: SDL_SCANCODE_MEDIA_NEXT_TRACK
  | mediaPreviousTrack   := 268  -- C: SDL_SCANCODE_MEDIA_PREVIOUS_TRACK
  | mediaStop            := 269  -- C: SDL_SCANCODE_MEDIA_STOP
  | mediaEject           := 270  -- C: SDL_SCANCODE_MEDIA_EJECT
  | mediaPlayPause       := 271  -- C: SDL_SCANCODE_MEDIA_PLAY_PAUSE
  | mediaSelect          := 272  -- C: SDL_SCANCODE_MEDIA_SELECT
  | acNew                := 273  -- C: SDL_SCANCODE_AC_NEW
  | acOpen               := 274  -- C: SDL_SCANCODE_AC_OPEN
  | acClose              := 275  -- C: SDL_SCANCODE_AC_CLOSE
  | acExit               := 276  -- C: SDL_SCANCODE_AC_EXIT
  | acSave               := 277  -- C: SDL_SCANCODE_AC_SAVE
  | acPrint              := 278  -- C: SDL_SCANCODE_AC_PRINT
  | acProperties         := 279  -- C: SDL_SCANCODE_AC_PROPERTIES
  | acSearch             := 280  -- C: SDL_SCANCODE_AC_SEARCH
  | acHome               := 281  -- C: SDL_SCANCODE_AC_HOME
  | acBack               := 282  -- C: SDL_SCANCODE_AC_BACK
  | acForward            := 283  -- C: SDL_SCANCODE_AC_FORWARD
  | acStop               := 284  -- C: SDL_SCANCODE_AC_STOP
  | acRefresh            := 285  -- C: SDL_SCANCODE_AC_REFRESH
  | acBookmarks          := 286  -- C: SDL_SCANCODE_AC_BOOKMARKS
  | softLeft             := 287  -- C: SDL_SCANCODE_SOFTLEFT
  | softRight            := 288  -- C: SDL_SCANCODE_SOFTRIGHT
  | call                 := 289  -- C: SDL_SCANCODE_CALL
  | endCall              := 290  -- C: SDL_SCANCODE_ENDCALL

/-- Array bound for scancode-indexed tables (not a key).
C: `SDL_SCANCODE_COUNT`. -/
def Scancode.maxScancodes : Nat := 512

#guard (⟨4⟩ : Scancode) == .a
#guard (⟨400⟩ : Scancode).val == 400  -- reserved-range raw is representable
#guard Scancode.«return».val == 40
#guard Scancode.«end».val == 77

end Sdl

end
