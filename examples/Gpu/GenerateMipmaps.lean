import Common.Gpu

/-!
# gpu/15-generate-mipmaps

Port of `GenerateMipmaps.c` from
[SDL_gpu_examples](https://github.com/TheSpydog/SDL_gpu_examples): a 32×32
texture is created with three mip levels (32, 16, 8), `cube0.bmp` is uploaded
into level 0, and `CommandBuffer.generateMipmaps` fills the remaining levels.
Every frame the smallest level (8×8, `BlitRegion.mipLevel := 2`) is blitted
up to the full swapchain, so the window shows the downsampled image
magnified with nearest filtering — a coarse, blocky version of the face.

This exercises `SDL_GenerateMipmapsForGPUTexture` (the texture needs both
the `sampler` and `colorTarget` usages) and blitting from a non-zero mip
level. There are no controls.

Shaders: none (blit only).
-/

open Sdl Examples.Gpu

structure State where
  mipmapTexture : Gpu.Texture

/-- The bytes of a 32×32 RGBA8 level 0. C: `byteCount`. -/
def byteCount : UInt32 := 32 * 32 * 4

#guard byteCount == 4096

def demo : Example State where
  name := "GenerateMipmaps"
  init ctx := do
    let mipmapTexture ← ctx.device.createTexture {
      type := .d2, format := .r8g8b8a8Unorm, usage := .sampler ||| .colorTarget,
      width := 32, height := 32, layerCountOrDepth := 1, numLevels := 3 }
    let textureTransferBuffer ← ctx.device.createTransferBuffer .upload byteCount
    let imageData ← loadImage "cube0.bmp"
    -- Like the C's fixed-size memcpy, only the first 32×32×4 bytes go up.
    textureTransferBuffer.write (imageData.pixels.extract 0 byteCount.toNat)
    let cmd ← ctx.device.acquireCommandBuffer
    let copyPass ← cmd.beginCopyPass
    copyPass.uploadToTexture { buffer := textureTransferBuffer }
      { texture := mipmapTexture, w := 32, h := 32, d := 1 }
    copyPass.finish
    cmd.generateMipmaps mipmapTexture
    cmd.submit
    textureTransferBuffer.release
    return { mipmapTexture }
  draw ctx s := withSwapchainFrame ctx fun cmd sc => do
    -- Blit the smallest mip level
    cmd.blitTexture {
      source := { texture := s.mipmapTexture, w := 8, h := 8, mipLevel := 2 }
      destination := { texture := sc.texture, w := sc.width, h := sc.height }
      loadOp := .dontCare }

def main : IO UInt32 := demo.run
