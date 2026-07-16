module

public import Sdl.Core.Macros
public meta import Sdl.Core.Macros
public import Sdl.Scancode
public meta import Sdl.Scancode

public section

/-!
# Virtual keycodes and key modifiers (`SDL_keycode.h`)

`Keycode` is the layout-dependent virtual key: either the Unicode code point
the key would produce, or an `SDLK_*` constant (scancode-derived or extended)
for keys that produce no character. It is an **open numeric domain** —
arbitrary Unicode code points plus masked scancode/extended values — so
exhaustive matching is impossible by construction and it is modelled as an
`sdl_id` with named constants rather than an enum. The two bit masks
`SDLK_EXTENDED_MASK` and `SDLK_SCANCODE_MASK` are included as members.

`Keymod` is the set of key modifiers (a bit-flag set).
-/

namespace Sdl

/-- A virtual key: a Unicode code point, or an `SDLK_*` constant for keys that
produce no character. Open numeric domain (named constants only; not
exhaustive). C: `SDL_Keycode`. -/
sdl_id Keycode : UInt32 where
  | unknown              := 0x00000000  -- C: SDLK_UNKNOWN
  | «return»             := 0x0000000d  -- C: SDLK_RETURN
  | escape               := 0x0000001b  -- C: SDLK_ESCAPE
  | backspace            := 0x00000008  -- C: SDLK_BACKSPACE
  | tab                  := 0x00000009  -- C: SDLK_TAB
  | space                := 0x00000020  -- C: SDLK_SPACE
  | exclaim              := 0x00000021  -- C: SDLK_EXCLAIM
  | dblApostrophe        := 0x00000022  -- C: SDLK_DBLAPOSTROPHE
  | hash                 := 0x00000023  -- C: SDLK_HASH
  | dollar               := 0x00000024  -- C: SDLK_DOLLAR
  | percent              := 0x00000025  -- C: SDLK_PERCENT
  | ampersand            := 0x00000026  -- C: SDLK_AMPERSAND
  | apostrophe           := 0x00000027  -- C: SDLK_APOSTROPHE
  | leftParen            := 0x00000028  -- C: SDLK_LEFTPAREN
  | rightParen           := 0x00000029  -- C: SDLK_RIGHTPAREN
  | asterisk             := 0x0000002a  -- C: SDLK_ASTERISK
  | plus                 := 0x0000002b  -- C: SDLK_PLUS
  | comma                := 0x0000002c  -- C: SDLK_COMMA
  | minus                := 0x0000002d  -- C: SDLK_MINUS
  | period               := 0x0000002e  -- C: SDLK_PERIOD
  | slash                := 0x0000002f  -- C: SDLK_SLASH
  | num0                 := 0x00000030  -- C: SDLK_0
  | num1                 := 0x00000031  -- C: SDLK_1
  | num2                 := 0x00000032  -- C: SDLK_2
  | num3                 := 0x00000033  -- C: SDLK_3
  | num4                 := 0x00000034  -- C: SDLK_4
  | num5                 := 0x00000035  -- C: SDLK_5
  | num6                 := 0x00000036  -- C: SDLK_6
  | num7                 := 0x00000037  -- C: SDLK_7
  | num8                 := 0x00000038  -- C: SDLK_8
  | num9                 := 0x00000039  -- C: SDLK_9
  | colon                := 0x0000003a  -- C: SDLK_COLON
  | semicolon            := 0x0000003b  -- C: SDLK_SEMICOLON
  | less                 := 0x0000003c  -- C: SDLK_LESS
  | equals               := 0x0000003d  -- C: SDLK_EQUALS
  | greater              := 0x0000003e  -- C: SDLK_GREATER
  | question             := 0x0000003f  -- C: SDLK_QUESTION
  | «at»                 := 0x00000040  -- C: SDLK_AT
  | leftBracket          := 0x0000005b  -- C: SDLK_LEFTBRACKET
  | backslash            := 0x0000005c  -- C: SDLK_BACKSLASH
  | rightBracket         := 0x0000005d  -- C: SDLK_RIGHTBRACKET
  | caret                := 0x0000005e  -- C: SDLK_CARET
  | underscore           := 0x0000005f  -- C: SDLK_UNDERSCORE
  | grave                := 0x00000060  -- C: SDLK_GRAVE
  | a                    := 0x00000061  -- C: SDLK_A
  | b                    := 0x00000062  -- C: SDLK_B
  | c                    := 0x00000063  -- C: SDLK_C
  | d                    := 0x00000064  -- C: SDLK_D
  | e                    := 0x00000065  -- C: SDLK_E
  | f                    := 0x00000066  -- C: SDLK_F
  | g                    := 0x00000067  -- C: SDLK_G
  | h                    := 0x00000068  -- C: SDLK_H
  | i                    := 0x00000069  -- C: SDLK_I
  | j                    := 0x0000006a  -- C: SDLK_J
  | k                    := 0x0000006b  -- C: SDLK_K
  | l                    := 0x0000006c  -- C: SDLK_L
  | m                    := 0x0000006d  -- C: SDLK_M
  | n                    := 0x0000006e  -- C: SDLK_N
  | o                    := 0x0000006f  -- C: SDLK_O
  | p                    := 0x00000070  -- C: SDLK_P
  | q                    := 0x00000071  -- C: SDLK_Q
  | r                    := 0x00000072  -- C: SDLK_R
  | s                    := 0x00000073  -- C: SDLK_S
  | t                    := 0x00000074  -- C: SDLK_T
  | u                    := 0x00000075  -- C: SDLK_U
  | v                    := 0x00000076  -- C: SDLK_V
  | w                    := 0x00000077  -- C: SDLK_W
  | x                    := 0x00000078  -- C: SDLK_X
  | y                    := 0x00000079  -- C: SDLK_Y
  | z                    := 0x0000007a  -- C: SDLK_Z
  | leftBrace            := 0x0000007b  -- C: SDLK_LEFTBRACE
  | pipe                 := 0x0000007c  -- C: SDLK_PIPE
  | rightBrace           := 0x0000007d  -- C: SDLK_RIGHTBRACE
  | tilde                := 0x0000007e  -- C: SDLK_TILDE
  | delete               := 0x0000007f  -- C: SDLK_DELETE
  | plusMinus            := 0x000000b1  -- C: SDLK_PLUSMINUS
  | capsLock             := 0x40000039  -- C: SDLK_CAPSLOCK
  | f1                   := 0x4000003a  -- C: SDLK_F1
  | f2                   := 0x4000003b  -- C: SDLK_F2
  | f3                   := 0x4000003c  -- C: SDLK_F3
  | f4                   := 0x4000003d  -- C: SDLK_F4
  | f5                   := 0x4000003e  -- C: SDLK_F5
  | f6                   := 0x4000003f  -- C: SDLK_F6
  | f7                   := 0x40000040  -- C: SDLK_F7
  | f8                   := 0x40000041  -- C: SDLK_F8
  | f9                   := 0x40000042  -- C: SDLK_F9
  | f10                  := 0x40000043  -- C: SDLK_F10
  | f11                  := 0x40000044  -- C: SDLK_F11
  | f12                  := 0x40000045  -- C: SDLK_F12
  | printScreen          := 0x40000046  -- C: SDLK_PRINTSCREEN
  | scrollLock           := 0x40000047  -- C: SDLK_SCROLLLOCK
  | pause                := 0x40000048  -- C: SDLK_PAUSE
  | insert               := 0x40000049  -- C: SDLK_INSERT
  | home                 := 0x4000004a  -- C: SDLK_HOME
  | pageUp               := 0x4000004b  -- C: SDLK_PAGEUP
  | «end»                := 0x4000004d  -- C: SDLK_END
  | pageDown             := 0x4000004e  -- C: SDLK_PAGEDOWN
  | right                := 0x4000004f  -- C: SDLK_RIGHT
  | left                 := 0x40000050  -- C: SDLK_LEFT
  | down                 := 0x40000051  -- C: SDLK_DOWN
  | up                   := 0x40000052  -- C: SDLK_UP
  | numLockClear         := 0x40000053  -- C: SDLK_NUMLOCKCLEAR
  | kpDivide             := 0x40000054  -- C: SDLK_KP_DIVIDE
  | kpMultiply           := 0x40000055  -- C: SDLK_KP_MULTIPLY
  | kpMinus              := 0x40000056  -- C: SDLK_KP_MINUS
  | kpPlus               := 0x40000057  -- C: SDLK_KP_PLUS
  | kpEnter              := 0x40000058  -- C: SDLK_KP_ENTER
  | kp1                  := 0x40000059  -- C: SDLK_KP_1
  | kp2                  := 0x4000005a  -- C: SDLK_KP_2
  | kp3                  := 0x4000005b  -- C: SDLK_KP_3
  | kp4                  := 0x4000005c  -- C: SDLK_KP_4
  | kp5                  := 0x4000005d  -- C: SDLK_KP_5
  | kp6                  := 0x4000005e  -- C: SDLK_KP_6
  | kp7                  := 0x4000005f  -- C: SDLK_KP_7
  | kp8                  := 0x40000060  -- C: SDLK_KP_8
  | kp9                  := 0x40000061  -- C: SDLK_KP_9
  | kp0                  := 0x40000062  -- C: SDLK_KP_0
  | kpPeriod             := 0x40000063  -- C: SDLK_KP_PERIOD
  | application          := 0x40000065  -- C: SDLK_APPLICATION
  | power                := 0x40000066  -- C: SDLK_POWER
  | kpEquals             := 0x40000067  -- C: SDLK_KP_EQUALS
  | f13                  := 0x40000068  -- C: SDLK_F13
  | f14                  := 0x40000069  -- C: SDLK_F14
  | f15                  := 0x4000006a  -- C: SDLK_F15
  | f16                  := 0x4000006b  -- C: SDLK_F16
  | f17                  := 0x4000006c  -- C: SDLK_F17
  | f18                  := 0x4000006d  -- C: SDLK_F18
  | f19                  := 0x4000006e  -- C: SDLK_F19
  | f20                  := 0x4000006f  -- C: SDLK_F20
  | f21                  := 0x40000070  -- C: SDLK_F21
  | f22                  := 0x40000071  -- C: SDLK_F22
  | f23                  := 0x40000072  -- C: SDLK_F23
  | f24                  := 0x40000073  -- C: SDLK_F24
  | execute              := 0x40000074  -- C: SDLK_EXECUTE
  | help                 := 0x40000075  -- C: SDLK_HELP
  | menu                 := 0x40000076  -- C: SDLK_MENU
  | select               := 0x40000077  -- C: SDLK_SELECT
  | stop                 := 0x40000078  -- C: SDLK_STOP
  | again                := 0x40000079  -- C: SDLK_AGAIN
  | undo                 := 0x4000007a  -- C: SDLK_UNDO
  | cut                  := 0x4000007b  -- C: SDLK_CUT
  | copy                 := 0x4000007c  -- C: SDLK_COPY
  | paste                := 0x4000007d  -- C: SDLK_PASTE
  | find                 := 0x4000007e  -- C: SDLK_FIND
  | mute                 := 0x4000007f  -- C: SDLK_MUTE
  | volumeUp             := 0x40000080  -- C: SDLK_VOLUMEUP
  | volumeDown           := 0x40000081  -- C: SDLK_VOLUMEDOWN
  | kpComma              := 0x40000085  -- C: SDLK_KP_COMMA
  | kpEqualsAs400        := 0x40000086  -- C: SDLK_KP_EQUALSAS400
  | altErase             := 0x40000099  -- C: SDLK_ALTERASE
  | sysReq               := 0x4000009a  -- C: SDLK_SYSREQ
  | cancel               := 0x4000009b  -- C: SDLK_CANCEL
  | clear                := 0x4000009c  -- C: SDLK_CLEAR
  | prior                := 0x4000009d  -- C: SDLK_PRIOR
  | return2              := 0x4000009e  -- C: SDLK_RETURN2
  | separator            := 0x4000009f  -- C: SDLK_SEPARATOR
  | out                  := 0x400000a0  -- C: SDLK_OUT
  | oper                 := 0x400000a1  -- C: SDLK_OPER
  | clearAgain           := 0x400000a2  -- C: SDLK_CLEARAGAIN
  | crSel                := 0x400000a3  -- C: SDLK_CRSEL
  | exSel                := 0x400000a4  -- C: SDLK_EXSEL
  | kp00                 := 0x400000b0  -- C: SDLK_KP_00
  | kp000                := 0x400000b1  -- C: SDLK_KP_000
  | thousandsSeparator   := 0x400000b2  -- C: SDLK_THOUSANDSSEPARATOR
  | decimalSeparator     := 0x400000b3  -- C: SDLK_DECIMALSEPARATOR
  | currencyUnit         := 0x400000b4  -- C: SDLK_CURRENCYUNIT
  | currencySubunit      := 0x400000b5  -- C: SDLK_CURRENCYSUBUNIT
  | kpLeftParen          := 0x400000b6  -- C: SDLK_KP_LEFTPAREN
  | kpRightParen         := 0x400000b7  -- C: SDLK_KP_RIGHTPAREN
  | kpLeftBrace          := 0x400000b8  -- C: SDLK_KP_LEFTBRACE
  | kpRightBrace         := 0x400000b9  -- C: SDLK_KP_RIGHTBRACE
  | kpTab                := 0x400000ba  -- C: SDLK_KP_TAB
  | kpBackspace          := 0x400000bb  -- C: SDLK_KP_BACKSPACE
  | kpA                  := 0x400000bc  -- C: SDLK_KP_A
  | kpB                  := 0x400000bd  -- C: SDLK_KP_B
  | kpC                  := 0x400000be  -- C: SDLK_KP_C
  | kpD                  := 0x400000bf  -- C: SDLK_KP_D
  | kpE                  := 0x400000c0  -- C: SDLK_KP_E
  | kpF                  := 0x400000c1  -- C: SDLK_KP_F
  | kpXor                := 0x400000c2  -- C: SDLK_KP_XOR
  | kpPower              := 0x400000c3  -- C: SDLK_KP_POWER
  | kpPercent            := 0x400000c4  -- C: SDLK_KP_PERCENT
  | kpLess               := 0x400000c5  -- C: SDLK_KP_LESS
  | kpGreater            := 0x400000c6  -- C: SDLK_KP_GREATER
  | kpAmpersand          := 0x400000c7  -- C: SDLK_KP_AMPERSAND
  | kpDblAmpersand       := 0x400000c8  -- C: SDLK_KP_DBLAMPERSAND
  | kpVerticalBar        := 0x400000c9  -- C: SDLK_KP_VERTICALBAR
  | kpDblVerticalBar     := 0x400000ca  -- C: SDLK_KP_DBLVERTICALBAR
  | kpColon              := 0x400000cb  -- C: SDLK_KP_COLON
  | kpHash               := 0x400000cc  -- C: SDLK_KP_HASH
  | kpSpace              := 0x400000cd  -- C: SDLK_KP_SPACE
  | kpAt                 := 0x400000ce  -- C: SDLK_KP_AT
  | kpExclam             := 0x400000cf  -- C: SDLK_KP_EXCLAM
  | kpMemStore           := 0x400000d0  -- C: SDLK_KP_MEMSTORE
  | kpMemRecall          := 0x400000d1  -- C: SDLK_KP_MEMRECALL
  | kpMemClear           := 0x400000d2  -- C: SDLK_KP_MEMCLEAR
  | kpMemAdd             := 0x400000d3  -- C: SDLK_KP_MEMADD
  | kpMemSubtract        := 0x400000d4  -- C: SDLK_KP_MEMSUBTRACT
  | kpMemMultiply        := 0x400000d5  -- C: SDLK_KP_MEMMULTIPLY
  | kpMemDivide          := 0x400000d6  -- C: SDLK_KP_MEMDIVIDE
  | kpPlusMinus          := 0x400000d7  -- C: SDLK_KP_PLUSMINUS
  | kpClear              := 0x400000d8  -- C: SDLK_KP_CLEAR
  | kpClearEntry         := 0x400000d9  -- C: SDLK_KP_CLEARENTRY
  | kpBinary             := 0x400000da  -- C: SDLK_KP_BINARY
  | kpOctal              := 0x400000db  -- C: SDLK_KP_OCTAL
  | kpDecimal            := 0x400000dc  -- C: SDLK_KP_DECIMAL
  | kpHexadecimal        := 0x400000dd  -- C: SDLK_KP_HEXADECIMAL
  | lCtrl                := 0x400000e0  -- C: SDLK_LCTRL
  | lShift               := 0x400000e1  -- C: SDLK_LSHIFT
  | lAlt                 := 0x400000e2  -- C: SDLK_LALT
  | lGui                 := 0x400000e3  -- C: SDLK_LGUI
  | rCtrl                := 0x400000e4  -- C: SDLK_RCTRL
  | rShift               := 0x400000e5  -- C: SDLK_RSHIFT
  | rAlt                 := 0x400000e6  -- C: SDLK_RALT
  | rGui                 := 0x400000e7  -- C: SDLK_RGUI
  | mode                 := 0x40000101  -- C: SDLK_MODE
  | sleep                := 0x40000102  -- C: SDLK_SLEEP
  | wake                 := 0x40000103  -- C: SDLK_WAKE
  | channelIncrement     := 0x40000104  -- C: SDLK_CHANNEL_INCREMENT
  | channelDecrement     := 0x40000105  -- C: SDLK_CHANNEL_DECREMENT
  | mediaPlay            := 0x40000106  -- C: SDLK_MEDIA_PLAY
  | mediaPause           := 0x40000107  -- C: SDLK_MEDIA_PAUSE
  | mediaRecord          := 0x40000108  -- C: SDLK_MEDIA_RECORD
  | mediaFastForward     := 0x40000109  -- C: SDLK_MEDIA_FAST_FORWARD
  | mediaRewind          := 0x4000010a  -- C: SDLK_MEDIA_REWIND
  | mediaNextTrack       := 0x4000010b  -- C: SDLK_MEDIA_NEXT_TRACK
  | mediaPreviousTrack   := 0x4000010c  -- C: SDLK_MEDIA_PREVIOUS_TRACK
  | mediaStop            := 0x4000010d  -- C: SDLK_MEDIA_STOP
  | mediaEject           := 0x4000010e  -- C: SDLK_MEDIA_EJECT
  | mediaPlayPause       := 0x4000010f  -- C: SDLK_MEDIA_PLAY_PAUSE
  | mediaSelect          := 0x40000110  -- C: SDLK_MEDIA_SELECT
  | acNew                := 0x40000111  -- C: SDLK_AC_NEW
  | acOpen               := 0x40000112  -- C: SDLK_AC_OPEN
  | acClose              := 0x40000113  -- C: SDLK_AC_CLOSE
  | acExit               := 0x40000114  -- C: SDLK_AC_EXIT
  | acSave               := 0x40000115  -- C: SDLK_AC_SAVE
  | acPrint              := 0x40000116  -- C: SDLK_AC_PRINT
  | acProperties         := 0x40000117  -- C: SDLK_AC_PROPERTIES
  | acSearch             := 0x40000118  -- C: SDLK_AC_SEARCH
  | acHome               := 0x40000119  -- C: SDLK_AC_HOME
  | acBack               := 0x4000011a  -- C: SDLK_AC_BACK
  | acForward            := 0x4000011b  -- C: SDLK_AC_FORWARD
  | acStop               := 0x4000011c  -- C: SDLK_AC_STOP
  | acRefresh            := 0x4000011d  -- C: SDLK_AC_REFRESH
  | acBookmarks          := 0x4000011e  -- C: SDLK_AC_BOOKMARKS
  | softLeft             := 0x4000011f  -- C: SDLK_SOFTLEFT
  | softRight            := 0x40000120  -- C: SDLK_SOFTRIGHT
  | call                 := 0x40000121  -- C: SDLK_CALL
  | endCall              := 0x40000122  -- C: SDLK_ENDCALL
  | leftTab              := 0x20000001  -- C: SDLK_LEFT_TAB
  | level5Shift          := 0x20000002  -- C: SDLK_LEVEL5_SHIFT
  | multiKeyCompose      := 0x20000003  -- C: SDLK_MULTI_KEY_COMPOSE
  | lMeta                := 0x20000004  -- C: SDLK_LMETA
  | rMeta                := 0x20000005  -- C: SDLK_RMETA
  | lHyper               := 0x20000006  -- C: SDLK_LHYPER
  | rHyper               := 0x20000007  -- C: SDLK_RHYPER
  | extendedMask         := 0x20000000  -- C: SDLK_EXTENDED_MASK
  | scancodeMask         := 0x40000000  -- C: SDLK_SCANCODE_MASK

/-- The keycode at the given scancode's position with `scancodeMask` set.
C: `SDL_SCANCODE_TO_KEYCODE`. -/
def Keycode.ofScancode (s : Scancode) : Keycode := ⟨s.val ||| 0x40000000⟩

#guard Keycode.ofScancode .f1 == .f1
#guard Keycode.ofScancode .capsLock == .capsLock

/-- Key modifiers, OR'd together in a keyboard event's `mod` field. The empty
set is the generated `Keymod.none` (`SDL_KMOD_NONE`); `ctrl`/`shift`/`alt`/
`gui` are the left|right convenience unions. C: `SDL_Keymod`. -/
sdl_flags Keymod : UInt16 where
  | lShift   := 0x0001  -- C: SDL_KMOD_LSHIFT
  | rShift   := 0x0002  -- C: SDL_KMOD_RSHIFT
  | level5   := 0x0004  -- C: SDL_KMOD_LEVEL5
  | lCtrl    := 0x0040  -- C: SDL_KMOD_LCTRL
  | rCtrl    := 0x0080  -- C: SDL_KMOD_RCTRL
  | lAlt     := 0x0100  -- C: SDL_KMOD_LALT
  | rAlt     := 0x0200  -- C: SDL_KMOD_RALT
  | lGui     := 0x0400  -- C: SDL_KMOD_LGUI
  | rGui     := 0x0800  -- C: SDL_KMOD_RGUI
  | num      := 0x1000  -- C: SDL_KMOD_NUM
  | caps     := 0x2000  -- C: SDL_KMOD_CAPS
  | mode     := 0x4000  -- C: SDL_KMOD_MODE
  | scroll   := 0x8000  -- C: SDL_KMOD_SCROLL
  | ctrl     := 0x00c0  -- C: SDL_KMOD_CTRL
  | shift    := 0x0003  -- C: SDL_KMOD_SHIFT
  | alt      := 0x0300  -- C: SDL_KMOD_ALT
  | gui      := 0x0c00  -- C: SDL_KMOD_GUI

#guard Keymod.none.val == 0
#guard (Keymod.lCtrl ||| Keymod.rCtrl) == Keymod.ctrl
#guard (Keymod.lShift ||| Keymod.rShift) == Keymod.shift
#guard (Keymod.lAlt ||| Keymod.rAlt) == Keymod.alt
#guard (Keymod.lGui ||| Keymod.rGui) == Keymod.gui

end Sdl

end
