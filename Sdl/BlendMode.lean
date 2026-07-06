import Sdl.Core.Macros
import Sdl.Error

/-!
# Blend modes (`SDL_blendmode.h`)

`BlendMode` is an open numeric domain (`sdl_id`): beyond the named constants,
custom values are composed by `composeCustomBlendMode` from a
`BlendFactor`/`BlendOperation` sextuple. Composing a combination that matches
a predefined mode returns that mode's value (SDL normalizes it).
-/

namespace Sdl

/-- How the pixels from a drawing operation mix with the render target.
Custom values exist beyond the named constants (see
`Sdl.composeCustomBlendMode`), hence an open domain rather than an enum.
C: `SDL_BlendMode` (a `Uint32`). -/
sdl_id BlendMode : UInt32 where
  /-- No blending: `dstRGBA = srcRGBA`. -/
  | none := 0x00000000  -- C: SDL_BLENDMODE_NONE
  /-- Alpha blending: `dstRGB = srcRGB*srcA + dstRGB*(1-srcA)`,
  `dstA = srcA + dstA*(1-srcA)`. -/
  | blend := 0x00000001  -- C: SDL_BLENDMODE_BLEND
  /-- Pre-multiplied alpha blending: `dstRGBA = srcRGBA + dstRGBA*(1-srcA)`. -/
  | blendPremultiplied := 0x00000010  -- C: SDL_BLENDMODE_BLEND_PREMULTIPLIED
  /-- Additive blending: `dstRGB = srcRGB*srcA + dstRGB`, `dstA = dstA`. -/
  | add := 0x00000002  -- C: SDL_BLENDMODE_ADD
  /-- Pre-multiplied additive blending: `dstRGB = srcRGB + dstRGB`. -/
  | addPremultiplied := 0x00000020  -- C: SDL_BLENDMODE_ADD_PREMULTIPLIED
  /-- Color modulate: `dstRGB = srcRGB * dstRGB`, `dstA = dstA`. -/
  | mod := 0x00000004  -- C: SDL_BLENDMODE_MOD
  /-- Color multiply: `dstRGB = srcRGB*dstRGB + dstRGB*(1-srcA)`. -/
  | mul := 0x00000008  -- C: SDL_BLENDMODE_MUL
  /-- An invalid blend mode. -/
  | invalid := 0x7FFFFFFF  -- C: SDL_BLENDMODE_INVALID

#guard BlendMode.blend.val == 0x1
#guard BlendMode.invalid.val == 0x7FFFFFFF
#guard BlendMode.none != BlendMode.blend

/-- The operation combining the factor-multiplied source and destination pixel
components in a custom blend mode. C: `SDL_BlendOperation`. -/
sdl_enum BlendOperation : UInt32 where
  | add         => 0x1  -- C: SDL_BLENDOPERATION_ADD (dst + src; all renderers)
  | subtract    => 0x2  -- C: SDL_BLENDOPERATION_SUBTRACT (src - dst)
  | revSubtract => 0x3  -- C: SDL_BLENDOPERATION_REV_SUBTRACT (dst - src)
  | minimum     => 0x4  -- C: SDL_BLENDOPERATION_MINIMUM (min(dst, src))
  | maximum     => 0x5  -- C: SDL_BLENDOPERATION_MAXIMUM (max(dst, src))

/-- The normalized factor multiplied with pixel components ahead of the blend
operation, listed in the component order red, green, blue, alpha.
C: `SDL_BlendFactor`. -/
sdl_enum BlendFactor : UInt32 where
  | zero             => 0x1  -- C: SDL_BLENDFACTOR_ZERO (0, 0, 0, 0)
  | one              => 0x2  -- C: SDL_BLENDFACTOR_ONE (1, 1, 1, 1)
  | srcColor         => 0x3  -- C: SDL_BLENDFACTOR_SRC_COLOR
  | oneMinusSrcColor => 0x4  -- C: SDL_BLENDFACTOR_ONE_MINUS_SRC_COLOR
  | srcAlpha         => 0x5  -- C: SDL_BLENDFACTOR_SRC_ALPHA
  | oneMinusSrcAlpha => 0x6  -- C: SDL_BLENDFACTOR_ONE_MINUS_SRC_ALPHA
  | dstColor         => 0x7  -- C: SDL_BLENDFACTOR_DST_COLOR
  | oneMinusDstColor => 0x8  -- C: SDL_BLENDFACTOR_ONE_MINUS_DST_COLOR
  | dstAlpha         => 0x9  -- C: SDL_BLENDFACTOR_DST_ALPHA
  | oneMinusDstAlpha => 0xA  -- C: SDL_BLENDFACTOR_ONE_MINUS_DST_ALPHA

@[extern "lean_sdl_compose_custom_blend_mode"]
private opaque composeCustomBlendModeRaw
  (srcColorFactor dstColorFactor colorOperation
   srcAlphaFactor dstAlphaFactor alphaOperation : UInt32) : UInt32

/-- Compose a custom blend mode for renderers:
`dstRGB = colorOperation(srcRGB * srcColorFactor, dstRGB * dstColorFactor)`
and `dstA = alphaOperation(srcA * srcAlphaFactor, dstA * dstAlphaFactor)`.
A combination equivalent to a predefined mode returns that mode. Renderer
support varies; `setRenderDrawBlendMode`/`setTextureBlendMode` reject
unsupported modes. C: `SDL_ComposeCustomBlendMode`. -/
def composeCustomBlendMode (srcColorFactor dstColorFactor : BlendFactor)
    (colorOperation : BlendOperation) (srcAlphaFactor dstAlphaFactor : BlendFactor)
    (alphaOperation : BlendOperation) : BlendMode :=
  ⟨composeCustomBlendModeRaw srcColorFactor.val dstColorFactor.val colorOperation.val
    srcAlphaFactor.val dstAlphaFactor.val alphaOperation.val⟩

end Sdl
