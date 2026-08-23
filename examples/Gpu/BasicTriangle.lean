import Common.Gpu

/-!
# gpu/02-basic-triangle

Port of `BasicTriangle.c` from
[SDL_gpu_examples](https://github.com/TheSpydog/SDL_gpu_examples): the first
real draw. Two graphics pipelines (solid fill and wireframe) share a vertex
shader that synthesizes a triangle from `SV_VertexID` — no vertex buffer at
all — and a flat-color fragment shader. The viewport and scissor rectangle
can be toggled to show how they clip the draw.

Controls: **Left** toggles wireframe, **Down** toggles a small viewport,
**Right** toggles a scissor rectangle.

Shaders: `RawTriangle.vert`, `SolidColor.frag` (sources under
`examples/assets/gpu/shaders/Source/`).
-/

open Sdl Examples.Gpu

structure State where
  fillPipeline : Gpu.GraphicsPipeline
  linePipeline : Gpu.GraphicsPipeline
  useWireframeMode : IO.Ref Bool
  useSmallViewport : IO.Ref Bool
  useScissorRect : IO.Ref Bool

def smallViewport : Gpu.Viewport := { x := 160, y := 120, w := 320, h := 240, minDepth := 0.1 }
def scissorRect : Rect := ⟨320, 240, 320, 240⟩

def demo : Example State where
  name := "BasicTriangle"
  init ctx := do
    let vertexShader ← loadShader ctx.device "RawTriangle.vert"
    let fragmentShader ← loadShader ctx.device "SolidColor.frag"
    let info : Gpu.GraphicsPipelineCreateInfo := {
      vertexShader, fragmentShader
      primitiveType := .triangleList
      targetInfo := { colorTargetDescriptions := #[{ format := ← ctx.swapchainFormat }] }
    }
    let fillPipeline ← ctx.device.createGraphicsPipeline
      { info with rasterizerState := { fillMode := .fill } }
    let linePipeline ← ctx.device.createGraphicsPipeline
      { info with rasterizerState := { fillMode := .line } }
    -- The pipelines keep their own references to the compiled programs.
    vertexShader.release
    fragmentShader.release
    IO.println "Press Left to toggle wireframe mode"
    IO.println "Press Down to toggle small viewport"
    IO.println "Press Right to toggle scissor rect"
    return { fillPipeline, linePipeline,
             useWireframeMode := ← IO.mkRef false,
             useSmallViewport := ← IO.mkRef false,
             useScissorRect := ← IO.mkRef false }
  update ctx s := do
    if ← ctx.leftPressed then s.useWireframeMode.modify not
    if ← ctx.downPressed then s.useSmallViewport.modify not
    if ← ctx.rightPressed then s.useScissorRect.modify not
  draw ctx s := withSwapchainFrame ctx fun cmd sc => do
    let rp ← cmd.beginRenderPass #[{
      texture := sc.texture, clearColor := ⟨0, 0, 0, 1⟩, loadOp := .clear, storeOp := .store }]
    rp.bindPipeline (if ← s.useWireframeMode.get then s.linePipeline else s.fillPipeline)
    if ← s.useSmallViewport.get then rp.setViewport smallViewport
    if ← s.useScissorRect.get then rp.setScissor scissorRect
    rp.drawPrimitives 3
    rp.finish

def main : IO UInt32 := demo.run
