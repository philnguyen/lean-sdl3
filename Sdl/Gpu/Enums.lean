module

public import Sdl.Core.Macros
public meta import Sdl.Core.Macros

public section

/-!
# GPU enums and flags (`SDL_gpu.h`)

Every enum typedef and flag typedef from `SDL_gpu.h` (SDL 3.4.10), bound with
the binding-kit macros. Type names drop the C `SDL_GPU` prefix
(`SDL_GPUPrimitiveType` → `Sdl.Gpu.PrimitiveType`); members are lowerCamel of
the C suffix. Every value is pinned against the header in `ffi/consts_check.c`.

Closed enums (`sdl_enum`) exhaustively enumerate the C values. `TextureFormat`
is the only version-open one (`sdl_enum_open`): it is returned from
`SDL_GetGPUSwapchainTextureFormat` and future SDL releases may add formats.
Enums that carry an `SDL_GPU_*_INVALID = 0` member keep it as `invalid` — the
meaningful "unset/default" value in create-info structs. Flag typedefs
(`sdl_flags`) map each `(1u << n)` bit; the `_INVALID`/`_SHADERFORMAT_INVALID`
zero value is the macro-generated empty `none`, not a member.

This module binds enums and flags only — no functions, opaque handles, or
structs (see `Sdl/Gpu.lean` and `Sdl/Gpu/Pipeline.lean`).
-/

namespace Sdl.Gpu

/-- Specifies the primitive topology of a graphics pipeline.
C: `SDL_GPUPrimitiveType`. -/
sdl_enum PrimitiveType : UInt32 where
  | triangleList  => 0  -- C: SDL_GPU_PRIMITIVETYPE_TRIANGLELIST
  | triangleStrip => 1  -- C: SDL_GPU_PRIMITIVETYPE_TRIANGLESTRIP
  | lineList      => 2  -- C: SDL_GPU_PRIMITIVETYPE_LINELIST
  | lineStrip     => 3  -- C: SDL_GPU_PRIMITIVETYPE_LINESTRIP
  | pointList     => 4  -- C: SDL_GPU_PRIMITIVETYPE_POINTLIST

/-- How the contents of a render-pass texture are treated at pass begin.
C: `SDL_GPULoadOp`. -/
sdl_enum LoadOp : UInt32 where
  | load     => 0  -- C: SDL_GPU_LOADOP_LOAD
  | clear    => 1  -- C: SDL_GPU_LOADOP_CLEAR
  | dontCare => 2  -- C: SDL_GPU_LOADOP_DONT_CARE

/-- How the contents of a render-pass texture are treated at pass end.
C: `SDL_GPUStoreOp`. -/
sdl_enum StoreOp : UInt32 where
  | store           => 0  -- C: SDL_GPU_STOREOP_STORE
  | dontCare        => 1  -- C: SDL_GPU_STOREOP_DONT_CARE
  | resolve         => 2  -- C: SDL_GPU_STOREOP_RESOLVE
  | resolveAndStore => 3  -- C: SDL_GPU_STOREOP_RESOLVE_AND_STORE

/-- The size of elements in an index buffer. C: `SDL_GPUIndexElementSize`. -/
sdl_enum IndexElementSize : UInt32 where
  | u16 => 0  -- C: SDL_GPU_INDEXELEMENTSIZE_16BIT
  | u32 => 1  -- C: SDL_GPU_INDEXELEMENTSIZE_32BIT

/-- The pixel format of a GPU texture. Version-open: returned from
`SDL_GetGPUSwapchainTextureFormat` and new formats appear in future SDL
releases. C: `SDL_GPUTextureFormat`. -/
sdl_enum_open TextureFormat : UInt32 where
  | invalid              => 0    -- C: SDL_GPU_TEXTUREFORMAT_INVALID
  | a8Unorm              => 1    -- C: SDL_GPU_TEXTUREFORMAT_A8_UNORM
  | r8Unorm              => 2    -- C: SDL_GPU_TEXTUREFORMAT_R8_UNORM
  | r8g8Unorm            => 3    -- C: SDL_GPU_TEXTUREFORMAT_R8G8_UNORM
  | r8g8b8a8Unorm        => 4    -- C: SDL_GPU_TEXTUREFORMAT_R8G8B8A8_UNORM
  | r16Unorm             => 5    -- C: SDL_GPU_TEXTUREFORMAT_R16_UNORM
  | r16g16Unorm          => 6    -- C: SDL_GPU_TEXTUREFORMAT_R16G16_UNORM
  | r16g16b16a16Unorm    => 7    -- C: SDL_GPU_TEXTUREFORMAT_R16G16B16A16_UNORM
  | r10g10b10a2Unorm     => 8    -- C: SDL_GPU_TEXTUREFORMAT_R10G10B10A2_UNORM
  | b5g6r5Unorm          => 9    -- C: SDL_GPU_TEXTUREFORMAT_B5G6R5_UNORM
  | b5g5r5a1Unorm        => 10   -- C: SDL_GPU_TEXTUREFORMAT_B5G5R5A1_UNORM
  | b4g4r4a4Unorm        => 11   -- C: SDL_GPU_TEXTUREFORMAT_B4G4R4A4_UNORM
  | b8g8r8a8Unorm        => 12   -- C: SDL_GPU_TEXTUREFORMAT_B8G8R8A8_UNORM
  | bc1RgbaUnorm         => 13   -- C: SDL_GPU_TEXTUREFORMAT_BC1_RGBA_UNORM
  | bc2RgbaUnorm         => 14   -- C: SDL_GPU_TEXTUREFORMAT_BC2_RGBA_UNORM
  | bc3RgbaUnorm         => 15   -- C: SDL_GPU_TEXTUREFORMAT_BC3_RGBA_UNORM
  | bc4RUnorm            => 16   -- C: SDL_GPU_TEXTUREFORMAT_BC4_R_UNORM
  | bc5RgUnorm           => 17   -- C: SDL_GPU_TEXTUREFORMAT_BC5_RG_UNORM
  | bc7RgbaUnorm         => 18   -- C: SDL_GPU_TEXTUREFORMAT_BC7_RGBA_UNORM
  | bc6hRgbFloat         => 19   -- C: SDL_GPU_TEXTUREFORMAT_BC6H_RGB_FLOAT
  | bc6hRgbUfloat        => 20   -- C: SDL_GPU_TEXTUREFORMAT_BC6H_RGB_UFLOAT
  | r8Snorm              => 21   -- C: SDL_GPU_TEXTUREFORMAT_R8_SNORM
  | r8g8Snorm            => 22   -- C: SDL_GPU_TEXTUREFORMAT_R8G8_SNORM
  | r8g8b8a8Snorm        => 23   -- C: SDL_GPU_TEXTUREFORMAT_R8G8B8A8_SNORM
  | r16Snorm             => 24   -- C: SDL_GPU_TEXTUREFORMAT_R16_SNORM
  | r16g16Snorm          => 25   -- C: SDL_GPU_TEXTUREFORMAT_R16G16_SNORM
  | r16g16b16a16Snorm    => 26   -- C: SDL_GPU_TEXTUREFORMAT_R16G16B16A16_SNORM
  | r16Float             => 27   -- C: SDL_GPU_TEXTUREFORMAT_R16_FLOAT
  | r16g16Float          => 28   -- C: SDL_GPU_TEXTUREFORMAT_R16G16_FLOAT
  | r16g16b16a16Float    => 29   -- C: SDL_GPU_TEXTUREFORMAT_R16G16B16A16_FLOAT
  | r32Float             => 30   -- C: SDL_GPU_TEXTUREFORMAT_R32_FLOAT
  | r32g32Float          => 31   -- C: SDL_GPU_TEXTUREFORMAT_R32G32_FLOAT
  | r32g32b32a32Float    => 32   -- C: SDL_GPU_TEXTUREFORMAT_R32G32B32A32_FLOAT
  | r11g11b10Ufloat      => 33   -- C: SDL_GPU_TEXTUREFORMAT_R11G11B10_UFLOAT
  | r8Uint               => 34   -- C: SDL_GPU_TEXTUREFORMAT_R8_UINT
  | r8g8Uint             => 35   -- C: SDL_GPU_TEXTUREFORMAT_R8G8_UINT
  | r8g8b8a8Uint         => 36   -- C: SDL_GPU_TEXTUREFORMAT_R8G8B8A8_UINT
  | r16Uint              => 37   -- C: SDL_GPU_TEXTUREFORMAT_R16_UINT
  | r16g16Uint           => 38   -- C: SDL_GPU_TEXTUREFORMAT_R16G16_UINT
  | r16g16b16a16Uint     => 39   -- C: SDL_GPU_TEXTUREFORMAT_R16G16B16A16_UINT
  | r32Uint              => 40   -- C: SDL_GPU_TEXTUREFORMAT_R32_UINT
  | r32g32Uint           => 41   -- C: SDL_GPU_TEXTUREFORMAT_R32G32_UINT
  | r32g32b32a32Uint     => 42   -- C: SDL_GPU_TEXTUREFORMAT_R32G32B32A32_UINT
  | r8Int                => 43   -- C: SDL_GPU_TEXTUREFORMAT_R8_INT
  | r8g8Int              => 44   -- C: SDL_GPU_TEXTUREFORMAT_R8G8_INT
  | r8g8b8a8Int          => 45   -- C: SDL_GPU_TEXTUREFORMAT_R8G8B8A8_INT
  | r16Int               => 46   -- C: SDL_GPU_TEXTUREFORMAT_R16_INT
  | r16g16Int            => 47   -- C: SDL_GPU_TEXTUREFORMAT_R16G16_INT
  | r16g16b16a16Int      => 48   -- C: SDL_GPU_TEXTUREFORMAT_R16G16B16A16_INT
  | r32Int               => 49   -- C: SDL_GPU_TEXTUREFORMAT_R32_INT
  | r32g32Int            => 50   -- C: SDL_GPU_TEXTUREFORMAT_R32G32_INT
  | r32g32b32a32Int      => 51   -- C: SDL_GPU_TEXTUREFORMAT_R32G32B32A32_INT
  | r8g8b8a8UnormSrgb    => 52   -- C: SDL_GPU_TEXTUREFORMAT_R8G8B8A8_UNORM_SRGB
  | b8g8r8a8UnormSrgb    => 53   -- C: SDL_GPU_TEXTUREFORMAT_B8G8R8A8_UNORM_SRGB
  | bc1RgbaUnormSrgb     => 54   -- C: SDL_GPU_TEXTUREFORMAT_BC1_RGBA_UNORM_SRGB
  | bc2RgbaUnormSrgb     => 55   -- C: SDL_GPU_TEXTUREFORMAT_BC2_RGBA_UNORM_SRGB
  | bc3RgbaUnormSrgb     => 56   -- C: SDL_GPU_TEXTUREFORMAT_BC3_RGBA_UNORM_SRGB
  | bc7RgbaUnormSrgb     => 57   -- C: SDL_GPU_TEXTUREFORMAT_BC7_RGBA_UNORM_SRGB
  | d16Unorm             => 58   -- C: SDL_GPU_TEXTUREFORMAT_D16_UNORM
  | d24Unorm             => 59   -- C: SDL_GPU_TEXTUREFORMAT_D24_UNORM
  | d32Float             => 60   -- C: SDL_GPU_TEXTUREFORMAT_D32_FLOAT
  | d24UnormS8Uint       => 61   -- C: SDL_GPU_TEXTUREFORMAT_D24_UNORM_S8_UINT
  | d32FloatS8Uint       => 62   -- C: SDL_GPU_TEXTUREFORMAT_D32_FLOAT_S8_UINT
  | astc4x4Unorm         => 63   -- C: SDL_GPU_TEXTUREFORMAT_ASTC_4x4_UNORM
  | astc5x4Unorm         => 64   -- C: SDL_GPU_TEXTUREFORMAT_ASTC_5x4_UNORM
  | astc5x5Unorm         => 65   -- C: SDL_GPU_TEXTUREFORMAT_ASTC_5x5_UNORM
  | astc6x5Unorm         => 66   -- C: SDL_GPU_TEXTUREFORMAT_ASTC_6x5_UNORM
  | astc6x6Unorm         => 67   -- C: SDL_GPU_TEXTUREFORMAT_ASTC_6x6_UNORM
  | astc8x5Unorm         => 68   -- C: SDL_GPU_TEXTUREFORMAT_ASTC_8x5_UNORM
  | astc8x6Unorm         => 69   -- C: SDL_GPU_TEXTUREFORMAT_ASTC_8x6_UNORM
  | astc8x8Unorm         => 70   -- C: SDL_GPU_TEXTUREFORMAT_ASTC_8x8_UNORM
  | astc10x5Unorm        => 71   -- C: SDL_GPU_TEXTUREFORMAT_ASTC_10x5_UNORM
  | astc10x6Unorm        => 72   -- C: SDL_GPU_TEXTUREFORMAT_ASTC_10x6_UNORM
  | astc10x8Unorm        => 73   -- C: SDL_GPU_TEXTUREFORMAT_ASTC_10x8_UNORM
  | astc10x10Unorm       => 74   -- C: SDL_GPU_TEXTUREFORMAT_ASTC_10x10_UNORM
  | astc12x10Unorm       => 75   -- C: SDL_GPU_TEXTUREFORMAT_ASTC_12x10_UNORM
  | astc12x12Unorm       => 76   -- C: SDL_GPU_TEXTUREFORMAT_ASTC_12x12_UNORM
  | astc4x4UnormSrgb     => 77   -- C: SDL_GPU_TEXTUREFORMAT_ASTC_4x4_UNORM_SRGB
  | astc5x4UnormSrgb     => 78   -- C: SDL_GPU_TEXTUREFORMAT_ASTC_5x4_UNORM_SRGB
  | astc5x5UnormSrgb     => 79   -- C: SDL_GPU_TEXTUREFORMAT_ASTC_5x5_UNORM_SRGB
  | astc6x5UnormSrgb     => 80   -- C: SDL_GPU_TEXTUREFORMAT_ASTC_6x5_UNORM_SRGB
  | astc6x6UnormSrgb     => 81   -- C: SDL_GPU_TEXTUREFORMAT_ASTC_6x6_UNORM_SRGB
  | astc8x5UnormSrgb     => 82   -- C: SDL_GPU_TEXTUREFORMAT_ASTC_8x5_UNORM_SRGB
  | astc8x6UnormSrgb     => 83   -- C: SDL_GPU_TEXTUREFORMAT_ASTC_8x6_UNORM_SRGB
  | astc8x8UnormSrgb     => 84   -- C: SDL_GPU_TEXTUREFORMAT_ASTC_8x8_UNORM_SRGB
  | astc10x5UnormSrgb    => 85   -- C: SDL_GPU_TEXTUREFORMAT_ASTC_10x5_UNORM_SRGB
  | astc10x6UnormSrgb    => 86   -- C: SDL_GPU_TEXTUREFORMAT_ASTC_10x6_UNORM_SRGB
  | astc10x8UnormSrgb    => 87   -- C: SDL_GPU_TEXTUREFORMAT_ASTC_10x8_UNORM_SRGB
  | astc10x10UnormSrgb   => 88   -- C: SDL_GPU_TEXTUREFORMAT_ASTC_10x10_UNORM_SRGB
  | astc12x10UnormSrgb   => 89   -- C: SDL_GPU_TEXTUREFORMAT_ASTC_12x10_UNORM_SRGB
  | astc12x12UnormSrgb   => 90   -- C: SDL_GPU_TEXTUREFORMAT_ASTC_12x12_UNORM_SRGB
  | astc4x4Float         => 91   -- C: SDL_GPU_TEXTUREFORMAT_ASTC_4x4_FLOAT
  | astc5x4Float         => 92   -- C: SDL_GPU_TEXTUREFORMAT_ASTC_5x4_FLOAT
  | astc5x5Float         => 93   -- C: SDL_GPU_TEXTUREFORMAT_ASTC_5x5_FLOAT
  | astc6x5Float         => 94   -- C: SDL_GPU_TEXTUREFORMAT_ASTC_6x5_FLOAT
  | astc6x6Float         => 95   -- C: SDL_GPU_TEXTUREFORMAT_ASTC_6x6_FLOAT
  | astc8x5Float         => 96   -- C: SDL_GPU_TEXTUREFORMAT_ASTC_8x5_FLOAT
  | astc8x6Float         => 97   -- C: SDL_GPU_TEXTUREFORMAT_ASTC_8x6_FLOAT
  | astc8x8Float         => 98   -- C: SDL_GPU_TEXTUREFORMAT_ASTC_8x8_FLOAT
  | astc10x5Float        => 99   -- C: SDL_GPU_TEXTUREFORMAT_ASTC_10x5_FLOAT
  | astc10x6Float        => 100  -- C: SDL_GPU_TEXTUREFORMAT_ASTC_10x6_FLOAT
  | astc10x8Float        => 101  -- C: SDL_GPU_TEXTUREFORMAT_ASTC_10x8_FLOAT
  | astc10x10Float       => 102  -- C: SDL_GPU_TEXTUREFORMAT_ASTC_10x10_FLOAT
  | astc12x10Float       => 103  -- C: SDL_GPU_TEXTUREFORMAT_ASTC_12x10_FLOAT
  | astc12x12Float       => 104  -- C: SDL_GPU_TEXTUREFORMAT_ASTC_12x12_FLOAT

/-- How a texture is intended to be used by the client (bit flags).
C: `SDL_GPUTextureUsageFlags`. -/
sdl_flags TextureUsageFlags : UInt32 where
  | sampler                             := 0x00000001  -- C: SDL_GPU_TEXTUREUSAGE_SAMPLER
  | colorTarget                         := 0x00000002  -- C: SDL_GPU_TEXTUREUSAGE_COLOR_TARGET
  | depthStencilTarget                  := 0x00000004  -- C: SDL_GPU_TEXTUREUSAGE_DEPTH_STENCIL_TARGET
  | graphicsStorageRead                 := 0x00000008  -- C: SDL_GPU_TEXTUREUSAGE_GRAPHICS_STORAGE_READ
  | computeStorageRead                  := 0x00000010  -- C: SDL_GPU_TEXTUREUSAGE_COMPUTE_STORAGE_READ
  | computeStorageWrite                 := 0x00000020  -- C: SDL_GPU_TEXTUREUSAGE_COMPUTE_STORAGE_WRITE
  | computeStorageSimultaneousReadWrite := 0x00000040  -- C: SDL_GPU_TEXTUREUSAGE_COMPUTE_STORAGE_SIMULTANEOUS_READ_WRITE

/-- The type of a texture. C: `SDL_GPUTextureType`. -/
sdl_enum TextureType : UInt32 where
  | d2        => 0  -- C: SDL_GPU_TEXTURETYPE_2D
  | d2Array   => 1  -- C: SDL_GPU_TEXTURETYPE_2D_ARRAY
  | d3        => 2  -- C: SDL_GPU_TEXTURETYPE_3D
  | cube      => 3  -- C: SDL_GPU_TEXTURETYPE_CUBE
  | cubeArray => 4  -- C: SDL_GPU_TEXTURETYPE_CUBE_ARRAY

/-- The sample count of a texture (multisampling). C: `SDL_GPUSampleCount`. -/
sdl_enum SampleCount : UInt32 where
  | x1 => 0  -- C: SDL_GPU_SAMPLECOUNT_1
  | x2 => 1  -- C: SDL_GPU_SAMPLECOUNT_2
  | x4 => 2  -- C: SDL_GPU_SAMPLECOUNT_4
  | x8 => 3  -- C: SDL_GPU_SAMPLECOUNT_8

/-- The face of a cube map. C: `SDL_GPUCubeMapFace`. -/
sdl_enum CubeMapFace : UInt32 where
  | positiveX => 0  -- C: SDL_GPU_CUBEMAPFACE_POSITIVEX
  | negativeX => 1  -- C: SDL_GPU_CUBEMAPFACE_NEGATIVEX
  | positiveY => 2  -- C: SDL_GPU_CUBEMAPFACE_POSITIVEY
  | negativeY => 3  -- C: SDL_GPU_CUBEMAPFACE_NEGATIVEY
  | positiveZ => 4  -- C: SDL_GPU_CUBEMAPFACE_POSITIVEZ
  | negativeZ => 5  -- C: SDL_GPU_CUBEMAPFACE_NEGATIVEZ

/-- How a buffer is intended to be used by the client (bit flags).
C: `SDL_GPUBufferUsageFlags`. -/
sdl_flags BufferUsageFlags : UInt32 where
  | vertex              := 0x00000001  -- C: SDL_GPU_BUFFERUSAGE_VERTEX
  | index               := 0x00000002  -- C: SDL_GPU_BUFFERUSAGE_INDEX
  | indirect            := 0x00000004  -- C: SDL_GPU_BUFFERUSAGE_INDIRECT
  | graphicsStorageRead := 0x00000008  -- C: SDL_GPU_BUFFERUSAGE_GRAPHICS_STORAGE_READ
  | computeStorageRead  := 0x00000010  -- C: SDL_GPU_BUFFERUSAGE_COMPUTE_STORAGE_READ
  | computeStorageWrite := 0x00000020  -- C: SDL_GPU_BUFFERUSAGE_COMPUTE_STORAGE_WRITE

/-- How a transfer buffer is intended to be used. C: `SDL_GPUTransferBufferUsage`. -/
sdl_enum TransferBufferUsage : UInt32 where
  | upload   => 0  -- C: SDL_GPU_TRANSFERBUFFERUSAGE_UPLOAD
  | download => 1  -- C: SDL_GPU_TRANSFERBUFFERUSAGE_DOWNLOAD

/-- Which stage a shader program corresponds to. C: `SDL_GPUShaderStage`. -/
sdl_enum ShaderStage : UInt32 where
  | vertex   => 0  -- C: SDL_GPU_SHADERSTAGE_VERTEX
  | fragment => 1  -- C: SDL_GPU_SHADERSTAGE_FRAGMENT

/-- The format of shader code; each maps to a specific backend (bit flags).
`SDL_GPU_SHADERFORMAT_INVALID` (0) is the empty `none`. C: `SDL_GPUShaderFormat`. -/
sdl_flags ShaderFormat : UInt32 where
  | «private» := 0x00000001  -- C: SDL_GPU_SHADERFORMAT_PRIVATE
  | spirv     := 0x00000002  -- C: SDL_GPU_SHADERFORMAT_SPIRV
  | dxbc      := 0x00000004  -- C: SDL_GPU_SHADERFORMAT_DXBC
  | dxil      := 0x00000008  -- C: SDL_GPU_SHADERFORMAT_DXIL
  | msl       := 0x00000010  -- C: SDL_GPU_SHADERFORMAT_MSL
  | metallib  := 0x00000020  -- C: SDL_GPU_SHADERFORMAT_METALLIB

/-- The format of a vertex attribute. C: `SDL_GPUVertexElementFormat`. -/
sdl_enum VertexElementFormat : UInt32 where
  | invalid    => 0   -- C: SDL_GPU_VERTEXELEMENTFORMAT_INVALID
  | int        => 1   -- C: SDL_GPU_VERTEXELEMENTFORMAT_INT
  | int2       => 2   -- C: SDL_GPU_VERTEXELEMENTFORMAT_INT2
  | int3       => 3   -- C: SDL_GPU_VERTEXELEMENTFORMAT_INT3
  | int4       => 4   -- C: SDL_GPU_VERTEXELEMENTFORMAT_INT4
  | uint       => 5   -- C: SDL_GPU_VERTEXELEMENTFORMAT_UINT
  | uint2      => 6   -- C: SDL_GPU_VERTEXELEMENTFORMAT_UINT2
  | uint3      => 7   -- C: SDL_GPU_VERTEXELEMENTFORMAT_UINT3
  | uint4      => 8   -- C: SDL_GPU_VERTEXELEMENTFORMAT_UINT4
  | float      => 9   -- C: SDL_GPU_VERTEXELEMENTFORMAT_FLOAT
  | float2     => 10  -- C: SDL_GPU_VERTEXELEMENTFORMAT_FLOAT2
  | float3     => 11  -- C: SDL_GPU_VERTEXELEMENTFORMAT_FLOAT3
  | float4     => 12  -- C: SDL_GPU_VERTEXELEMENTFORMAT_FLOAT4
  | byte2      => 13  -- C: SDL_GPU_VERTEXELEMENTFORMAT_BYTE2
  | byte4      => 14  -- C: SDL_GPU_VERTEXELEMENTFORMAT_BYTE4
  | ubyte2     => 15  -- C: SDL_GPU_VERTEXELEMENTFORMAT_UBYTE2
  | ubyte4     => 16  -- C: SDL_GPU_VERTEXELEMENTFORMAT_UBYTE4
  | byte2Norm  => 17  -- C: SDL_GPU_VERTEXELEMENTFORMAT_BYTE2_NORM
  | byte4Norm  => 18  -- C: SDL_GPU_VERTEXELEMENTFORMAT_BYTE4_NORM
  | ubyte2Norm => 19  -- C: SDL_GPU_VERTEXELEMENTFORMAT_UBYTE2_NORM
  | ubyte4Norm => 20  -- C: SDL_GPU_VERTEXELEMENTFORMAT_UBYTE4_NORM
  | short2     => 21  -- C: SDL_GPU_VERTEXELEMENTFORMAT_SHORT2
  | short4     => 22  -- C: SDL_GPU_VERTEXELEMENTFORMAT_SHORT4
  | ushort2    => 23  -- C: SDL_GPU_VERTEXELEMENTFORMAT_USHORT2
  | ushort4    => 24  -- C: SDL_GPU_VERTEXELEMENTFORMAT_USHORT4
  | short2Norm => 25  -- C: SDL_GPU_VERTEXELEMENTFORMAT_SHORT2_NORM
  | short4Norm => 26  -- C: SDL_GPU_VERTEXELEMENTFORMAT_SHORT4_NORM
  | ushort2Norm => 27  -- C: SDL_GPU_VERTEXELEMENTFORMAT_USHORT2_NORM
  | ushort4Norm => 28  -- C: SDL_GPU_VERTEXELEMENTFORMAT_USHORT4_NORM
  | half2      => 29  -- C: SDL_GPU_VERTEXELEMENTFORMAT_HALF2
  | half4      => 30  -- C: SDL_GPU_VERTEXELEMENTFORMAT_HALF4

/-- The rate at which vertex attributes are pulled from buffers.
C: `SDL_GPUVertexInputRate`. -/
sdl_enum VertexInputRate : UInt32 where
  | vertex     => 0  -- C: SDL_GPU_VERTEXINPUTRATE_VERTEX
  | «instance» => 1  -- C: SDL_GPU_VERTEXINPUTRATE_INSTANCE

/-- The fill mode of the graphics pipeline. C: `SDL_GPUFillMode`. -/
sdl_enum FillMode : UInt32 where
  | fill => 0  -- C: SDL_GPU_FILLMODE_FILL
  | line => 1  -- C: SDL_GPU_FILLMODE_LINE

/-- The facing direction in which triangle faces are culled. C: `SDL_GPUCullMode`. -/
sdl_enum CullMode : UInt32 where
  | none  => 0  -- C: SDL_GPU_CULLMODE_NONE
  | front => 1  -- C: SDL_GPU_CULLMODE_FRONT
  | back  => 2  -- C: SDL_GPU_CULLMODE_BACK

/-- The vertex winding that makes a triangle front-facing. C: `SDL_GPUFrontFace`. -/
sdl_enum FrontFace : UInt32 where
  | counterClockwise => 0  -- C: SDL_GPU_FRONTFACE_COUNTER_CLOCKWISE
  | clockwise        => 1  -- C: SDL_GPU_FRONTFACE_CLOCKWISE

/-- A comparison operator for depth, stencil and sampler operations.
C: `SDL_GPUCompareOp`. -/
sdl_enum CompareOp : UInt32 where
  | invalid        => 0  -- C: SDL_GPU_COMPAREOP_INVALID
  | never          => 1  -- C: SDL_GPU_COMPAREOP_NEVER
  | less           => 2  -- C: SDL_GPU_COMPAREOP_LESS
  | equal          => 3  -- C: SDL_GPU_COMPAREOP_EQUAL
  | lessOrEqual    => 4  -- C: SDL_GPU_COMPAREOP_LESS_OR_EQUAL
  | greater        => 5  -- C: SDL_GPU_COMPAREOP_GREATER
  | notEqual       => 6  -- C: SDL_GPU_COMPAREOP_NOT_EQUAL
  | greaterOrEqual => 7  -- C: SDL_GPU_COMPAREOP_GREATER_OR_EQUAL
  | always         => 8  -- C: SDL_GPU_COMPAREOP_ALWAYS

/-- What happens to a stored stencil value on stencil test fail/pass.
C: `SDL_GPUStencilOp`. -/
sdl_enum StencilOp : UInt32 where
  | invalid           => 0  -- C: SDL_GPU_STENCILOP_INVALID
  | keep              => 1  -- C: SDL_GPU_STENCILOP_KEEP
  | zero              => 2  -- C: SDL_GPU_STENCILOP_ZERO
  | replace           => 3  -- C: SDL_GPU_STENCILOP_REPLACE
  | incrementAndClamp => 4  -- C: SDL_GPU_STENCILOP_INCREMENT_AND_CLAMP
  | decrementAndClamp => 5  -- C: SDL_GPU_STENCILOP_DECREMENT_AND_CLAMP
  | invert            => 6  -- C: SDL_GPU_STENCILOP_INVERT
  | incrementAndWrap  => 7  -- C: SDL_GPU_STENCILOP_INCREMENT_AND_WRAP
  | decrementAndWrap  => 8  -- C: SDL_GPU_STENCILOP_DECREMENT_AND_WRAP

/-- The operator used when blending render-target pixels. C: `SDL_GPUBlendOp`. -/
sdl_enum BlendOp : UInt32 where
  | invalid         => 0  -- C: SDL_GPU_BLENDOP_INVALID
  | add             => 1  -- C: SDL_GPU_BLENDOP_ADD
  | subtract        => 2  -- C: SDL_GPU_BLENDOP_SUBTRACT
  | reverseSubtract => 3  -- C: SDL_GPU_BLENDOP_REVERSE_SUBTRACT
  | min             => 4  -- C: SDL_GPU_BLENDOP_MIN
  | max             => 5  -- C: SDL_GPU_BLENDOP_MAX

/-- A blending factor used when blending render-target pixels.
C: `SDL_GPUBlendFactor`. -/
sdl_enum BlendFactor : UInt32 where
  | invalid              => 0   -- C: SDL_GPU_BLENDFACTOR_INVALID
  | zero                 => 1   -- C: SDL_GPU_BLENDFACTOR_ZERO
  | one                  => 2   -- C: SDL_GPU_BLENDFACTOR_ONE
  | srcColor             => 3   -- C: SDL_GPU_BLENDFACTOR_SRC_COLOR
  | oneMinusSrcColor     => 4   -- C: SDL_GPU_BLENDFACTOR_ONE_MINUS_SRC_COLOR
  | dstColor             => 5   -- C: SDL_GPU_BLENDFACTOR_DST_COLOR
  | oneMinusDstColor     => 6   -- C: SDL_GPU_BLENDFACTOR_ONE_MINUS_DST_COLOR
  | srcAlpha             => 7   -- C: SDL_GPU_BLENDFACTOR_SRC_ALPHA
  | oneMinusSrcAlpha     => 8   -- C: SDL_GPU_BLENDFACTOR_ONE_MINUS_SRC_ALPHA
  | dstAlpha             => 9   -- C: SDL_GPU_BLENDFACTOR_DST_ALPHA
  | oneMinusDstAlpha     => 10  -- C: SDL_GPU_BLENDFACTOR_ONE_MINUS_DST_ALPHA
  | constantColor        => 11  -- C: SDL_GPU_BLENDFACTOR_CONSTANT_COLOR
  | oneMinusConstantColor => 12 -- C: SDL_GPU_BLENDFACTOR_ONE_MINUS_CONSTANT_COLOR
  | srcAlphaSaturate     => 13  -- C: SDL_GPU_BLENDFACTOR_SRC_ALPHA_SATURATE

/-- Which color components are written in a graphics pipeline (bit flags).
C: `SDL_GPUColorComponentFlags`. -/
sdl_flags ColorComponentFlags : UInt8 where
  | r := 0x01  -- C: SDL_GPU_COLORCOMPONENT_R
  | g := 0x02  -- C: SDL_GPU_COLORCOMPONENT_G
  | b := 0x04  -- C: SDL_GPU_COLORCOMPONENT_B
  | a := 0x08  -- C: SDL_GPU_COLORCOMPONENT_A

/-- A filter operation used by a sampler. C: `SDL_GPUFilter`. -/
sdl_enum Filter : UInt32 where
  | nearest => 0  -- C: SDL_GPU_FILTER_NEAREST
  | linear  => 1  -- C: SDL_GPU_FILTER_LINEAR

/-- A mipmap mode used by a sampler. C: `SDL_GPUSamplerMipmapMode`. -/
sdl_enum SamplerMipmapMode : UInt32 where
  | nearest => 0  -- C: SDL_GPU_SAMPLERMIPMAPMODE_NEAREST
  | linear  => 1  -- C: SDL_GPU_SAMPLERMIPMAPMODE_LINEAR

/-- Texture sampling behavior when coordinates exceed the 0-1 range.
C: `SDL_GPUSamplerAddressMode`. -/
sdl_enum SamplerAddressMode : UInt32 where
  | «repeat»       => 0  -- C: SDL_GPU_SAMPLERADDRESSMODE_REPEAT
  | mirroredRepeat => 1  -- C: SDL_GPU_SAMPLERADDRESSMODE_MIRRORED_REPEAT
  | clampToEdge    => 2  -- C: SDL_GPU_SAMPLERADDRESSMODE_CLAMP_TO_EDGE

/-- The timing used to present swapchain textures to the OS.
C: `SDL_GPUPresentMode`. -/
sdl_enum PresentMode : UInt32 where
  | vsync     => 0  -- C: SDL_GPU_PRESENTMODE_VSYNC
  | immediate => 1  -- C: SDL_GPU_PRESENTMODE_IMMEDIATE
  | mailbox   => 2  -- C: SDL_GPU_PRESENTMODE_MAILBOX

/-- The texture format and colorspace of swapchain textures.
C: `SDL_GPUSwapchainComposition`. -/
sdl_enum SwapchainComposition : UInt32 where
  | sdr               => 0  -- C: SDL_GPU_SWAPCHAINCOMPOSITION_SDR
  | sdrLinear         => 1  -- C: SDL_GPU_SWAPCHAINCOMPOSITION_SDR_LINEAR
  | hdrExtendedLinear => 2  -- C: SDL_GPU_SWAPCHAINCOMPOSITION_HDR_EXTENDED_LINEAR
  | hdr10St2084       => 3  -- C: SDL_GPU_SWAPCHAINCOMPOSITION_HDR10_ST2084

end Sdl.Gpu

end
