import Common.Gpu

/-!
# gpu/12-copy-and-readback

Port of `CopyAndReadback.c` from
[SDL_gpu_examples](https://github.com/TheSpydog/SDL_gpu_examples): the
transfer side of the API with no shaders at all. At init one upload
transfer buffer carries both an image and a small `Uint32` array; a copy pass
uploads them, copies texture→texture and buffer→buffer, a blit renders a
half-size version of the image into a third texture, and a second copy pass
downloads the copies into a download transfer buffer. The command buffer is
submitted with a fence, the CPU waits on it, and the downloaded bytes are
compared with the originals (logged as SUCCESS/FAILURE lines).

Exercises `CopyPass.uploadToTexture` / `uploadToBuffer`,
`copyTextureToTexture` / `copyBufferToBuffer`, `downloadFromTexture` /
`downloadFromBuffer`, `CommandBuffer.blitTexture`,
`CommandBuffer.submitAndAcquireFence` + `Device.waitForFences`, and
`TransferBuffer.read`. Each frame blits the original (top left), the copy
(top right) and the half-size blit (bottom center) onto the swapchain.

Shaders: none.
-/

open Sdl Examples.Gpu

structure State where
  originalTexture : Gpu.Texture
  textureCopy : Gpu.Texture
  textureSmall : Gpu.Texture
  originalBuffer : Gpu.Buffer
  bufferCopy : Gpu.Buffer
  textureWidth : UInt32
  textureHeight : UInt32

/-- C: `Uint32 bufferData[8] = { 2, 4, 8, 16, 32, 64, 128 };` — the eighth
element is zero-initialized, so the buffer is 32 bytes. -/
def bufferData : ByteArray :=
  #[2, 4, 8, 16, 32, 64, 128, 0].foldl pushU32 .empty

#guard bufferData.size == 32
#guard readU32 bufferData 0 == 2 && readU32 bufferData 24 == 128 && readU32 bufferData 28 == 0

def demo : Example State where
  name := "CopyAndReadback"
  init ctx := do
    -- Load the image
    let image ← loadImage "ravioli.bmp"
    let imageBytes : UInt32 := image.width * image.height * 4

    -- Create texture resources
    let texInfo : Gpu.TextureCreateInfo := {
      type := .d2, format := .r8g8b8a8Unorm, width := image.width, height := image.height,
      layerCountOrDepth := 1, numLevels := 1, usage := .sampler }
    let originalTexture ← ctx.device.createTexture texInfo
    let textureCopy ← ctx.device.createTexture texInfo
    let textureSmall ← ctx.device.createTexture
      { texInfo with width := image.width / 2, height := image.height / 2,
                     usage := .sampler ||| .colorTarget }

    let bufferSize := bufferData.size.toUInt32
    -- The buffer usage is arbitrary; nothing reads these from a shader.
    let originalBuffer ← ctx.device.createBuffer .graphicsStorageRead bufferSize
    let bufferCopy ← ctx.device.createBuffer .graphicsStorageRead bufferSize

    let downloadTransferBuffer ← ctx.device.createTransferBuffer .download
      (imageBytes + bufferSize)
    let uploadTransferBuffer ← ctx.device.createTransferBuffer .upload
      (imageBytes + bufferSize)
    uploadTransferBuffer.write image.pixels
    uploadTransferBuffer.write bufferData (dstOffset := imageBytes)

    let cmd ← ctx.device.acquireCommandBuffer
    let copyPass ← cmd.beginCopyPass

    -- Upload original texture
    copyPass.uploadToTexture
      { buffer := uploadTransferBuffer, offset := 0 }
      { texture := originalTexture, w := image.width, h := image.height, d := 1 }

    -- Copy original to copy
    copyPass.copyTextureToTexture
      { texture := originalTexture } { texture := textureCopy }
      image.width image.height 1

    -- Upload original buffer
    copyPass.uploadToBuffer
      { buffer := uploadTransferBuffer, offset := imageBytes }
      { buffer := originalBuffer, offset := 0, size := bufferSize }

    -- Copy original to copy
    copyPass.copyBufferToBuffer
      { buffer := originalBuffer } { buffer := bufferCopy } bufferSize

    copyPass.finish

    -- Render the half-size version
    cmd.blitTexture {
      source := { texture := originalTexture, w := image.width, h := image.height }
      destination := { texture := textureSmall, w := image.width / 2, h := image.height / 2 }
      loadOp := .dontCare
      filter := .linear }

    -- Download the original bytes from the copy
    let copyPass ← cmd.beginCopyPass
    copyPass.downloadFromTexture
      { texture := textureCopy, w := image.width, h := image.height, d := 1 }
      { buffer := downloadTransferBuffer, offset := 0 }
    copyPass.downloadFromBuffer
      { buffer := bufferCopy, offset := 0, size := bufferSize }
      { buffer := downloadTransferBuffer, offset := imageBytes }
    copyPass.finish

    let fence ← cmd.submitAndAcquireFence
    ctx.device.waitForFences true #[fence]
    fence.release

    -- Compare the original bytes to the copied bytes
    let downloadedTexture ← downloadTransferBuffer.read 0 (some imageBytes)
    let downloadedBuffer ← downloadTransferBuffer.read imageBytes (some bufferSize)
    if downloadedTexture.data == image.pixels.data then
      IO.println "SUCCESS! Original texture bytes and the downloaded bytes match!"
    else
      IO.println "FAILURE! Original texture bytes do not match downloaded bytes!"
    if downloadedBuffer.data == bufferData.data then
      IO.println "SUCCESS! Original buffer bytes and the downloaded bytes match!"
    else
      IO.println "FAILURE! Original buffer bytes do not match downloaded bytes!"

    -- Cleanup
    downloadTransferBuffer.release
    uploadTransferBuffer.release

    return { originalTexture, textureCopy, textureSmall, originalBuffer, bufferCopy,
             textureWidth := image.width, textureHeight := image.height }
  draw ctx s := withSwapchainFrame ctx fun cmd sc => do
    let clearPass ← cmd.beginRenderPass #[{
      texture := sc.texture, clearColor := ⟨0, 0, 0, 1⟩, loadOp := .clear, storeOp := .store }]
    clearPass.finish
    let w := sc.width
    let h := sc.height
    -- Original: top left
    cmd.blitTexture {
      source := { texture := s.originalTexture, w := s.textureWidth, h := s.textureHeight }
      destination := { texture := sc.texture, w := w / 2, h := h / 2 }
      loadOp := .load
      filter := .nearest }
    -- Copy: top right
    cmd.blitTexture {
      source := { texture := s.textureCopy, w := s.textureWidth, h := s.textureHeight }
      destination := { texture := sc.texture, x := w / 2, w := w / 2, h := h / 2 }
      loadOp := .load
      filter := .nearest }
    -- Half-size blit: bottom center
    cmd.blitTexture {
      source := { texture := s.textureSmall, w := s.textureWidth / 2, h := s.textureHeight / 2 }
      destination := { texture := sc.texture, x := w / 4, y := h / 2, w := w / 2, h := h / 2 }
      loadOp := .load
      filter := .nearest }

def main : IO UInt32 := demo.run
