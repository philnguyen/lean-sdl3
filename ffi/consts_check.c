/* Compile-time cross-checks: every value in a Lean `sdl_enum`/`sdl_flags`
 * block is pinned against the real SDL headers here. A wrong Lean literal
 * shows up as a build failure. Grouped by Lean module. */
#include <SDL3/SDL.h>

/* ---- ABI assumptions ---- */
_Static_assert(sizeof(SDL_Event) == 128, "SDL_Event ABI size");
_Static_assert(sizeof(bool) == 1, "bool size");

/* ---- Sdl/Init.lean: InitFlags ---- */
_Static_assert(SDL_INIT_AUDIO    == 0x00000010u, "InitFlags.audio");
_Static_assert(SDL_INIT_VIDEO    == 0x00000020u, "InitFlags.video");
_Static_assert(SDL_INIT_JOYSTICK == 0x00000200u, "InitFlags.joystick");
_Static_assert(SDL_INIT_HAPTIC   == 0x00001000u, "InitFlags.haptic");
_Static_assert(SDL_INIT_GAMEPAD  == 0x00002000u, "InitFlags.gamepad");
_Static_assert(SDL_INIT_EVENTS   == 0x00004000u, "InitFlags.events");
_Static_assert(SDL_INIT_SENSOR   == 0x00008000u, "InitFlags.sensor");
_Static_assert(SDL_INIT_CAMERA   == 0x00010000u, "InitFlags.camera");

/* ---- Sdl/Init.lean: AppResult ---- */
_Static_assert((int)SDL_APP_CONTINUE == 0, "AppResult.continue");
_Static_assert((int)SDL_APP_SUCCESS  == 1, "AppResult.success");
_Static_assert((int)SDL_APP_FAILURE  == 2, "AppResult.failure");

/* ---- Sdl/Properties.lean: PropertyType ---- */
_Static_assert((int)SDL_PROPERTY_TYPE_INVALID == 0, "PropertyType.invalid");
_Static_assert((int)SDL_PROPERTY_TYPE_POINTER == 1, "PropertyType.pointer");
_Static_assert((int)SDL_PROPERTY_TYPE_STRING  == 2, "PropertyType.string");
_Static_assert((int)SDL_PROPERTY_TYPE_NUMBER  == 3, "PropertyType.number");
_Static_assert((int)SDL_PROPERTY_TYPE_FLOAT   == 4, "PropertyType.float");
_Static_assert((int)SDL_PROPERTY_TYPE_BOOLEAN == 5, "PropertyType.boolean");

/* ---- Sdl/Hints.lean: HintPriority ---- */
_Static_assert((int)SDL_HINT_DEFAULT  == 0, "HintPriority.default");
_Static_assert((int)SDL_HINT_NORMAL   == 1, "HintPriority.normal");
_Static_assert((int)SDL_HINT_OVERRIDE == 2, "HintPriority.override");

/* ---- Sdl/Log.lean: LogCategory (named constants) ---- */
_Static_assert((int)SDL_LOG_CATEGORY_APPLICATION == 0,  "LogCategory.application");
_Static_assert((int)SDL_LOG_CATEGORY_ERROR       == 1,  "LogCategory.error");
_Static_assert((int)SDL_LOG_CATEGORY_ASSERT      == 2,  "LogCategory.assert");
_Static_assert((int)SDL_LOG_CATEGORY_SYSTEM      == 3,  "LogCategory.system");
_Static_assert((int)SDL_LOG_CATEGORY_AUDIO       == 4,  "LogCategory.audio");
_Static_assert((int)SDL_LOG_CATEGORY_VIDEO       == 5,  "LogCategory.video");
_Static_assert((int)SDL_LOG_CATEGORY_RENDER      == 6,  "LogCategory.render");
_Static_assert((int)SDL_LOG_CATEGORY_INPUT       == 7,  "LogCategory.input");
_Static_assert((int)SDL_LOG_CATEGORY_TEST        == 8,  "LogCategory.test");
_Static_assert((int)SDL_LOG_CATEGORY_GPU         == 9,  "LogCategory.gpu");
_Static_assert((int)SDL_LOG_CATEGORY_CUSTOM      == 19, "LogCategory.custom");

/* ---- Sdl/Log.lean: LogPriority ---- */
_Static_assert((int)SDL_LOG_PRIORITY_INVALID  == 0, "LogPriority.invalid");
_Static_assert((int)SDL_LOG_PRIORITY_TRACE    == 1, "LogPriority.trace");
_Static_assert((int)SDL_LOG_PRIORITY_VERBOSE  == 2, "LogPriority.verbose");
_Static_assert((int)SDL_LOG_PRIORITY_DEBUG    == 3, "LogPriority.debug");
_Static_assert((int)SDL_LOG_PRIORITY_INFO     == 4, "LogPriority.info");
_Static_assert((int)SDL_LOG_PRIORITY_WARN     == 5, "LogPriority.warn");
_Static_assert((int)SDL_LOG_PRIORITY_ERROR    == 6, "LogPriority.error");
_Static_assert((int)SDL_LOG_PRIORITY_CRITICAL == 7, "LogPriority.critical");

/* ---- Sdl/Timer.lean: time-unit constants ---- */
_Static_assert(SDL_NS_PER_SECOND == 1000000000LL, "Timer.nsPerSecond");
_Static_assert(SDL_NS_PER_MS     == 1000000,      "Timer.nsPerMs");
_Static_assert(SDL_NS_PER_US     == 1000,         "Timer.nsPerUs");

/* ---- Sdl/Time.lean: DateFormat ---- */
_Static_assert((int)SDL_DATE_FORMAT_YYYYMMDD == 0, "DateFormat.yyyymmdd");
_Static_assert((int)SDL_DATE_FORMAT_DDMMYYYY == 1, "DateFormat.ddmmyyyy");
_Static_assert((int)SDL_DATE_FORMAT_MMDDYYYY == 2, "DateFormat.mmddyyyy");

/* ---- Sdl/Time.lean: TimeFormat ---- */
_Static_assert((int)SDL_TIME_FORMAT_24HR == 0, "TimeFormat.24hr");
_Static_assert((int)SDL_TIME_FORMAT_12HR == 1, "TimeFormat.12hr");

/* ---- Sdl/Filesystem.lean: Folder ---- */
_Static_assert((int)SDL_FOLDER_HOME        == 0,  "Folder.home");
_Static_assert((int)SDL_FOLDER_DESKTOP     == 1,  "Folder.desktop");
_Static_assert((int)SDL_FOLDER_DOCUMENTS   == 2,  "Folder.documents");
_Static_assert((int)SDL_FOLDER_DOWNLOADS   == 3,  "Folder.downloads");
_Static_assert((int)SDL_FOLDER_MUSIC       == 4,  "Folder.music");
_Static_assert((int)SDL_FOLDER_PICTURES    == 5,  "Folder.pictures");
_Static_assert((int)SDL_FOLDER_PUBLICSHARE == 6,  "Folder.publicshare");
_Static_assert((int)SDL_FOLDER_SAVEDGAMES  == 7,  "Folder.savedgames");
_Static_assert((int)SDL_FOLDER_SCREENSHOTS == 8,  "Folder.screenshots");
_Static_assert((int)SDL_FOLDER_TEMPLATES   == 9,  "Folder.templates");
_Static_assert((int)SDL_FOLDER_VIDEOS      == 10, "Folder.videos");

/* ---- Sdl/Filesystem.lean: PathType ---- */
_Static_assert((int)SDL_PATHTYPE_NONE      == 0, "PathType.none");
_Static_assert((int)SDL_PATHTYPE_FILE      == 1, "PathType.file");
_Static_assert((int)SDL_PATHTYPE_DIRECTORY == 2, "PathType.directory");
_Static_assert((int)SDL_PATHTYPE_OTHER     == 3, "PathType.other");

/* ---- Sdl/Filesystem.lean: GlobFlags ---- */
_Static_assert(SDL_GLOB_CASEINSENSITIVE == 0x1u, "GlobFlags.caseInsensitive");

/* ---- Sdl/Power.lean: PowerState (ERROR is the IO-error sentinel) ---- */
_Static_assert((int)SDL_POWERSTATE_ERROR      == -1, "PowerState.error sentinel");
_Static_assert((int)SDL_POWERSTATE_UNKNOWN    == 0,  "PowerState.unknown");
_Static_assert((int)SDL_POWERSTATE_ON_BATTERY == 1,  "PowerState.onBattery");
_Static_assert((int)SDL_POWERSTATE_NO_BATTERY == 2,  "PowerState.noBattery");
_Static_assert((int)SDL_POWERSTATE_CHARGING   == 3,  "PowerState.charging");
_Static_assert((int)SDL_POWERSTATE_CHARGED    == 4,  "PowerState.charged");

/* ---- Sdl/BlendMode.lean: BlendMode ---- */
_Static_assert(SDL_BLENDMODE_NONE                == 0x00000000u, "BlendMode.none");
_Static_assert(SDL_BLENDMODE_BLEND               == 0x00000001u, "BlendMode.blend");
_Static_assert(SDL_BLENDMODE_BLEND_PREMULTIPLIED == 0x00000010u, "BlendMode.blendPremultiplied");
_Static_assert(SDL_BLENDMODE_ADD                 == 0x00000002u, "BlendMode.add");
_Static_assert(SDL_BLENDMODE_ADD_PREMULTIPLIED   == 0x00000020u, "BlendMode.addPremultiplied");
_Static_assert(SDL_BLENDMODE_MOD                 == 0x00000004u, "BlendMode.mod");
_Static_assert(SDL_BLENDMODE_MUL                 == 0x00000008u, "BlendMode.mul");
_Static_assert(SDL_BLENDMODE_INVALID             == 0x7FFFFFFFu, "BlendMode.invalid");

/* ---- Sdl/BlendMode.lean: BlendOperation ---- */
_Static_assert((int)SDL_BLENDOPERATION_ADD          == 0x1, "BlendOperation.add");
_Static_assert((int)SDL_BLENDOPERATION_SUBTRACT     == 0x2, "BlendOperation.subtract");
_Static_assert((int)SDL_BLENDOPERATION_REV_SUBTRACT == 0x3, "BlendOperation.revSubtract");
_Static_assert((int)SDL_BLENDOPERATION_MINIMUM      == 0x4, "BlendOperation.minimum");
_Static_assert((int)SDL_BLENDOPERATION_MAXIMUM      == 0x5, "BlendOperation.maximum");

/* ---- Sdl/BlendMode.lean: BlendFactor ---- */
_Static_assert((int)SDL_BLENDFACTOR_ZERO                == 0x1, "BlendFactor.zero");
_Static_assert((int)SDL_BLENDFACTOR_ONE                 == 0x2, "BlendFactor.one");
_Static_assert((int)SDL_BLENDFACTOR_SRC_COLOR           == 0x3, "BlendFactor.srcColor");
_Static_assert((int)SDL_BLENDFACTOR_ONE_MINUS_SRC_COLOR == 0x4, "BlendFactor.oneMinusSrcColor");
_Static_assert((int)SDL_BLENDFACTOR_SRC_ALPHA           == 0x5, "BlendFactor.srcAlpha");
_Static_assert((int)SDL_BLENDFACTOR_ONE_MINUS_SRC_ALPHA == 0x6, "BlendFactor.oneMinusSrcAlpha");
_Static_assert((int)SDL_BLENDFACTOR_DST_COLOR           == 0x7, "BlendFactor.dstColor");
_Static_assert((int)SDL_BLENDFACTOR_ONE_MINUS_DST_COLOR == 0x8, "BlendFactor.oneMinusDstColor");
_Static_assert((int)SDL_BLENDFACTOR_DST_ALPHA           == 0x9, "BlendFactor.dstAlpha");
_Static_assert((int)SDL_BLENDFACTOR_ONE_MINUS_DST_ALPHA == 0xA, "BlendFactor.oneMinusDstAlpha");

/* ---- Sdl/Pixels.lean: PixelFormat (every member) ---- */
_Static_assert((unsigned)SDL_PIXELFORMAT_UNKNOWN       == 0x00000000u, "PixelFormat.unknown");
_Static_assert((unsigned)SDL_PIXELFORMAT_INDEX1LSB     == 0x11100100u, "PixelFormat.index1lsb");
_Static_assert((unsigned)SDL_PIXELFORMAT_INDEX1MSB     == 0x11200100u, "PixelFormat.index1msb");
_Static_assert((unsigned)SDL_PIXELFORMAT_INDEX2LSB     == 0x1c100200u, "PixelFormat.index2lsb");
_Static_assert((unsigned)SDL_PIXELFORMAT_INDEX2MSB     == 0x1c200200u, "PixelFormat.index2msb");
_Static_assert((unsigned)SDL_PIXELFORMAT_INDEX4LSB     == 0x12100400u, "PixelFormat.index4lsb");
_Static_assert((unsigned)SDL_PIXELFORMAT_INDEX4MSB     == 0x12200400u, "PixelFormat.index4msb");
_Static_assert((unsigned)SDL_PIXELFORMAT_INDEX8        == 0x13000801u, "PixelFormat.index8");
_Static_assert((unsigned)SDL_PIXELFORMAT_RGB332        == 0x14110801u, "PixelFormat.rgb332");
_Static_assert((unsigned)SDL_PIXELFORMAT_XRGB4444      == 0x15120c02u, "PixelFormat.xrgb4444");
_Static_assert((unsigned)SDL_PIXELFORMAT_XBGR4444      == 0x15520c02u, "PixelFormat.xbgr4444");
_Static_assert((unsigned)SDL_PIXELFORMAT_XRGB1555      == 0x15130f02u, "PixelFormat.xrgb1555");
_Static_assert((unsigned)SDL_PIXELFORMAT_XBGR1555      == 0x15530f02u, "PixelFormat.xbgr1555");
_Static_assert((unsigned)SDL_PIXELFORMAT_ARGB4444      == 0x15321002u, "PixelFormat.argb4444");
_Static_assert((unsigned)SDL_PIXELFORMAT_RGBA4444      == 0x15421002u, "PixelFormat.rgba4444");
_Static_assert((unsigned)SDL_PIXELFORMAT_ABGR4444      == 0x15721002u, "PixelFormat.abgr4444");
_Static_assert((unsigned)SDL_PIXELFORMAT_BGRA4444      == 0x15821002u, "PixelFormat.bgra4444");
_Static_assert((unsigned)SDL_PIXELFORMAT_ARGB1555      == 0x15331002u, "PixelFormat.argb1555");
_Static_assert((unsigned)SDL_PIXELFORMAT_RGBA5551      == 0x15441002u, "PixelFormat.rgba5551");
_Static_assert((unsigned)SDL_PIXELFORMAT_ABGR1555      == 0x15731002u, "PixelFormat.abgr1555");
_Static_assert((unsigned)SDL_PIXELFORMAT_BGRA5551      == 0x15841002u, "PixelFormat.bgra5551");
_Static_assert((unsigned)SDL_PIXELFORMAT_RGB565        == 0x15151002u, "PixelFormat.rgb565");
_Static_assert((unsigned)SDL_PIXELFORMAT_BGR565        == 0x15551002u, "PixelFormat.bgr565");
_Static_assert((unsigned)SDL_PIXELFORMAT_RGB24         == 0x17101803u, "PixelFormat.rgb24");
_Static_assert((unsigned)SDL_PIXELFORMAT_BGR24         == 0x17401803u, "PixelFormat.bgr24");
_Static_assert((unsigned)SDL_PIXELFORMAT_XRGB8888      == 0x16161804u, "PixelFormat.xrgb8888");
_Static_assert((unsigned)SDL_PIXELFORMAT_RGBX8888      == 0x16261804u, "PixelFormat.rgbx8888");
_Static_assert((unsigned)SDL_PIXELFORMAT_XBGR8888      == 0x16561804u, "PixelFormat.xbgr8888");
_Static_assert((unsigned)SDL_PIXELFORMAT_BGRX8888      == 0x16661804u, "PixelFormat.bgrx8888");
_Static_assert((unsigned)SDL_PIXELFORMAT_ARGB8888      == 0x16362004u, "PixelFormat.argb8888");
_Static_assert((unsigned)SDL_PIXELFORMAT_RGBA8888      == 0x16462004u, "PixelFormat.rgba8888");
_Static_assert((unsigned)SDL_PIXELFORMAT_ABGR8888      == 0x16762004u, "PixelFormat.abgr8888");
_Static_assert((unsigned)SDL_PIXELFORMAT_BGRA8888      == 0x16862004u, "PixelFormat.bgra8888");
_Static_assert((unsigned)SDL_PIXELFORMAT_XRGB2101010   == 0x16172004u, "PixelFormat.xrgb2101010");
_Static_assert((unsigned)SDL_PIXELFORMAT_XBGR2101010   == 0x16572004u, "PixelFormat.xbgr2101010");
_Static_assert((unsigned)SDL_PIXELFORMAT_ARGB2101010   == 0x16372004u, "PixelFormat.argb2101010");
_Static_assert((unsigned)SDL_PIXELFORMAT_ABGR2101010   == 0x16772004u, "PixelFormat.abgr2101010");
_Static_assert((unsigned)SDL_PIXELFORMAT_RGB48         == 0x18103006u, "PixelFormat.rgb48");
_Static_assert((unsigned)SDL_PIXELFORMAT_BGR48         == 0x18403006u, "PixelFormat.bgr48");
_Static_assert((unsigned)SDL_PIXELFORMAT_RGBA64        == 0x18204008u, "PixelFormat.rgba64");
_Static_assert((unsigned)SDL_PIXELFORMAT_ARGB64        == 0x18304008u, "PixelFormat.argb64");
_Static_assert((unsigned)SDL_PIXELFORMAT_BGRA64        == 0x18504008u, "PixelFormat.bgra64");
_Static_assert((unsigned)SDL_PIXELFORMAT_ABGR64        == 0x18604008u, "PixelFormat.abgr64");
_Static_assert((unsigned)SDL_PIXELFORMAT_RGB48_FLOAT   == 0x1a103006u, "PixelFormat.rgb48Float");
_Static_assert((unsigned)SDL_PIXELFORMAT_BGR48_FLOAT   == 0x1a403006u, "PixelFormat.bgr48Float");
_Static_assert((unsigned)SDL_PIXELFORMAT_RGBA64_FLOAT  == 0x1a204008u, "PixelFormat.rgba64Float");
_Static_assert((unsigned)SDL_PIXELFORMAT_ARGB64_FLOAT  == 0x1a304008u, "PixelFormat.argb64Float");
_Static_assert((unsigned)SDL_PIXELFORMAT_BGRA64_FLOAT  == 0x1a504008u, "PixelFormat.bgra64Float");
_Static_assert((unsigned)SDL_PIXELFORMAT_ABGR64_FLOAT  == 0x1a604008u, "PixelFormat.abgr64Float");
_Static_assert((unsigned)SDL_PIXELFORMAT_RGB96_FLOAT   == 0x1b10600cu, "PixelFormat.rgb96Float");
_Static_assert((unsigned)SDL_PIXELFORMAT_BGR96_FLOAT   == 0x1b40600cu, "PixelFormat.bgr96Float");
_Static_assert((unsigned)SDL_PIXELFORMAT_RGBA128_FLOAT == 0x1b208010u, "PixelFormat.rgba128Float");
_Static_assert((unsigned)SDL_PIXELFORMAT_ARGB128_FLOAT == 0x1b308010u, "PixelFormat.argb128Float");
_Static_assert((unsigned)SDL_PIXELFORMAT_BGRA128_FLOAT == 0x1b508010u, "PixelFormat.bgra128Float");
_Static_assert((unsigned)SDL_PIXELFORMAT_ABGR128_FLOAT == 0x1b608010u, "PixelFormat.abgr128Float");
_Static_assert((unsigned)SDL_PIXELFORMAT_YV12          == 0x32315659u, "PixelFormat.yv12");
_Static_assert((unsigned)SDL_PIXELFORMAT_IYUV          == 0x56555949u, "PixelFormat.iyuv");
_Static_assert((unsigned)SDL_PIXELFORMAT_YUY2          == 0x32595559u, "PixelFormat.yuy2");
_Static_assert((unsigned)SDL_PIXELFORMAT_UYVY          == 0x59565955u, "PixelFormat.uyvy");
_Static_assert((unsigned)SDL_PIXELFORMAT_YVYU          == 0x55595659u, "PixelFormat.yvyu");
_Static_assert((unsigned)SDL_PIXELFORMAT_NV12          == 0x3231564eu, "PixelFormat.nv12");
_Static_assert((unsigned)SDL_PIXELFORMAT_NV21          == 0x3132564eu, "PixelFormat.nv21");
_Static_assert((unsigned)SDL_PIXELFORMAT_P010          == 0x30313050u, "PixelFormat.p010");
_Static_assert((unsigned)SDL_PIXELFORMAT_EXTERNAL_OES  == 0x2053454fu, "PixelFormat.externalOes");
_Static_assert((unsigned)SDL_PIXELFORMAT_MJPG          == 0x47504a4du, "PixelFormat.mjpg");

/* ---- Sdl/Pixels.lean: PixelFormat byte-order aliases (little-endian) ---- */
_Static_assert(SDL_PIXELFORMAT_RGBA32 == SDL_PIXELFORMAT_ABGR8888, "PixelFormat.rgba32");
_Static_assert(SDL_PIXELFORMAT_ARGB32 == SDL_PIXELFORMAT_BGRA8888, "PixelFormat.argb32");
_Static_assert(SDL_PIXELFORMAT_BGRA32 == SDL_PIXELFORMAT_ARGB8888, "PixelFormat.bgra32");
_Static_assert(SDL_PIXELFORMAT_ABGR32 == SDL_PIXELFORMAT_RGBA8888, "PixelFormat.abgr32");
_Static_assert(SDL_PIXELFORMAT_RGBX32 == SDL_PIXELFORMAT_XBGR8888, "PixelFormat.rgbx32");
_Static_assert(SDL_PIXELFORMAT_XRGB32 == SDL_PIXELFORMAT_BGRX8888, "PixelFormat.xrgb32");
_Static_assert(SDL_PIXELFORMAT_BGRX32 == SDL_PIXELFORMAT_XRGB8888, "PixelFormat.bgrx32");
_Static_assert(SDL_PIXELFORMAT_XBGR32 == SDL_PIXELFORMAT_RGBX8888, "PixelFormat.xbgr32");

/* ---- Sdl/Pixels.lean: Colorspace ---- */
_Static_assert((unsigned)SDL_COLORSPACE_UNKNOWN        == 0x00000000u, "Colorspace.unknown");
_Static_assert((unsigned)SDL_COLORSPACE_SRGB           == 0x120005a0u, "Colorspace.srgb");
_Static_assert((unsigned)SDL_COLORSPACE_SRGB_LINEAR    == 0x12000500u, "Colorspace.srgbLinear");
_Static_assert((unsigned)SDL_COLORSPACE_HDR10          == 0x12002600u, "Colorspace.hdr10");
_Static_assert((unsigned)SDL_COLORSPACE_JPEG           == 0x220004c6u, "Colorspace.jpeg");
_Static_assert((unsigned)SDL_COLORSPACE_BT601_LIMITED  == 0x211018c6u, "Colorspace.bt601Limited");
_Static_assert((unsigned)SDL_COLORSPACE_BT601_FULL     == 0x221018c6u, "Colorspace.bt601Full");
_Static_assert((unsigned)SDL_COLORSPACE_BT709_LIMITED  == 0x21100421u, "Colorspace.bt709Limited");
_Static_assert((unsigned)SDL_COLORSPACE_BT709_FULL     == 0x22100421u, "Colorspace.bt709Full");
_Static_assert((unsigned)SDL_COLORSPACE_BT2020_LIMITED == 0x21102609u, "Colorspace.bt2020Limited");
_Static_assert((unsigned)SDL_COLORSPACE_BT2020_FULL    == 0x22102609u, "Colorspace.bt2020Full");
_Static_assert(SDL_COLORSPACE_RGB_DEFAULT == SDL_COLORSPACE_SRGB, "Colorspace.rgbDefault");
_Static_assert(SDL_COLORSPACE_YUV_DEFAULT == SDL_COLORSPACE_BT601_LIMITED, "Colorspace.yuvDefault");

/* ---- Sdl/Pixels.lean: Color ABI (Palette.setColors packs r,g,b,a bytes) ---- */
_Static_assert(sizeof(SDL_Color) == 4, "SDL_Color size");

/* ---- Sdl/IOStream.lean: IOStatus ---- */
_Static_assert((int)SDL_IO_STATUS_READY     == 0, "IOStatus.ready");
_Static_assert((int)SDL_IO_STATUS_ERROR     == 1, "IOStatus.error");
_Static_assert((int)SDL_IO_STATUS_EOF       == 2, "IOStatus.eof");
_Static_assert((int)SDL_IO_STATUS_NOT_READY == 3, "IOStatus.notReady");
_Static_assert((int)SDL_IO_STATUS_READONLY  == 4, "IOStatus.readonly");
_Static_assert((int)SDL_IO_STATUS_WRITEONLY == 5, "IOStatus.writeonly");

/* ---- Sdl/IOStream.lean: IOWhence ---- */
_Static_assert((int)SDL_IO_SEEK_SET == 0, "IOWhence.seekSet");
_Static_assert((int)SDL_IO_SEEK_CUR == 1, "IOWhence.seekCur");
_Static_assert((int)SDL_IO_SEEK_END == 2, "IOWhence.seekEnd");

/* ---- Sdl/Surface.lean: SurfaceFlags ---- */
_Static_assert(SDL_SURFACE_PREALLOCATED == 0x00000001u, "SurfaceFlags.preallocated");
_Static_assert(SDL_SURFACE_LOCK_NEEDED  == 0x00000002u, "SurfaceFlags.lockNeeded");
_Static_assert(SDL_SURFACE_LOCKED       == 0x00000004u, "SurfaceFlags.locked");
_Static_assert(SDL_SURFACE_SIMD_ALIGNED == 0x00000008u, "SurfaceFlags.simdAligned");

/* ---- Sdl/Surface.lean: ScaleMode (INVALID is the -1 error sentinel) ---- */
_Static_assert((int)SDL_SCALEMODE_INVALID == -1, "ScaleMode.invalid sentinel");
_Static_assert((int)SDL_SCALEMODE_NEAREST ==  0, "ScaleMode.nearest");
_Static_assert((int)SDL_SCALEMODE_LINEAR  ==  1, "ScaleMode.linear");
_Static_assert((int)SDL_SCALEMODE_PIXELART == 2, "ScaleMode.pixelart");

/* ---- Sdl/Surface.lean: FlipMode ---- */
_Static_assert((int)SDL_FLIP_NONE                     == 0, "FlipMode.none");
_Static_assert((int)SDL_FLIP_HORIZONTAL               == 1, "FlipMode.horizontal");
_Static_assert((int)SDL_FLIP_VERTICAL                 == 2, "FlipMode.vertical");
_Static_assert((int)SDL_FLIP_HORIZONTAL_AND_VERTICAL  == 3, "FlipMode.horizontalAndVertical");

/* ---- Sdl/Surface.lean: SDL_Rect ABI (flattened rect args rebuilt in C) ---- */
_Static_assert(sizeof(SDL_Rect) == 16, "SDL_Rect size");

/* ---- Sdl/Video.lean: SystemTheme ---- */
_Static_assert((int)SDL_SYSTEM_THEME_UNKNOWN == 0, "SystemTheme.unknown");
_Static_assert((int)SDL_SYSTEM_THEME_LIGHT   == 1, "SystemTheme.light");
_Static_assert((int)SDL_SYSTEM_THEME_DARK    == 2, "SystemTheme.dark");

/* ---- Sdl/Video.lean: DisplayOrientation ---- */
_Static_assert((int)SDL_ORIENTATION_UNKNOWN           == 0, "DisplayOrientation.unknown");
_Static_assert((int)SDL_ORIENTATION_LANDSCAPE         == 1, "DisplayOrientation.landscape");
_Static_assert((int)SDL_ORIENTATION_LANDSCAPE_FLIPPED == 2, "DisplayOrientation.landscapeFlipped");
_Static_assert((int)SDL_ORIENTATION_PORTRAIT          == 3, "DisplayOrientation.portrait");
_Static_assert((int)SDL_ORIENTATION_PORTRAIT_FLIPPED  == 4, "DisplayOrientation.portraitFlipped");

/* ---- Sdl/Video.lean: WindowFlags ---- */
_Static_assert(SDL_WINDOW_FULLSCREEN          == 0x0000000000000001ULL, "WindowFlags.fullscreen");
_Static_assert(SDL_WINDOW_OPENGL              == 0x0000000000000002ULL, "WindowFlags.opengl");
_Static_assert(SDL_WINDOW_OCCLUDED            == 0x0000000000000004ULL, "WindowFlags.occluded");
_Static_assert(SDL_WINDOW_HIDDEN              == 0x0000000000000008ULL, "WindowFlags.hidden");
_Static_assert(SDL_WINDOW_BORDERLESS          == 0x0000000000000010ULL, "WindowFlags.borderless");
_Static_assert(SDL_WINDOW_RESIZABLE           == 0x0000000000000020ULL, "WindowFlags.resizable");
_Static_assert(SDL_WINDOW_MINIMIZED           == 0x0000000000000040ULL, "WindowFlags.minimized");
_Static_assert(SDL_WINDOW_MAXIMIZED           == 0x0000000000000080ULL, "WindowFlags.maximized");
_Static_assert(SDL_WINDOW_MOUSE_GRABBED       == 0x0000000000000100ULL, "WindowFlags.mouseGrabbed");
_Static_assert(SDL_WINDOW_INPUT_FOCUS         == 0x0000000000000200ULL, "WindowFlags.inputFocus");
_Static_assert(SDL_WINDOW_MOUSE_FOCUS         == 0x0000000000000400ULL, "WindowFlags.mouseFocus");
_Static_assert(SDL_WINDOW_EXTERNAL            == 0x0000000000000800ULL, "WindowFlags.external");
_Static_assert(SDL_WINDOW_MODAL               == 0x0000000000001000ULL, "WindowFlags.modal");
_Static_assert(SDL_WINDOW_HIGH_PIXEL_DENSITY  == 0x0000000000002000ULL, "WindowFlags.highPixelDensity");
_Static_assert(SDL_WINDOW_MOUSE_CAPTURE       == 0x0000000000004000ULL, "WindowFlags.mouseCapture");
_Static_assert(SDL_WINDOW_MOUSE_RELATIVE_MODE == 0x0000000000008000ULL, "WindowFlags.mouseRelativeMode");
_Static_assert(SDL_WINDOW_ALWAYS_ON_TOP       == 0x0000000000010000ULL, "WindowFlags.alwaysOnTop");
_Static_assert(SDL_WINDOW_UTILITY             == 0x0000000000020000ULL, "WindowFlags.utility");
_Static_assert(SDL_WINDOW_TOOLTIP             == 0x0000000000040000ULL, "WindowFlags.tooltip");
_Static_assert(SDL_WINDOW_POPUP_MENU          == 0x0000000000080000ULL, "WindowFlags.popupMenu");
_Static_assert(SDL_WINDOW_KEYBOARD_GRABBED    == 0x0000000000100000ULL, "WindowFlags.keyboardGrabbed");
_Static_assert(SDL_WINDOW_FILL_DOCUMENT       == 0x0000000000200000ULL, "WindowFlags.fillDocument");
_Static_assert(SDL_WINDOW_VULKAN              == 0x0000000010000000ULL, "WindowFlags.vulkan");
_Static_assert(SDL_WINDOW_METAL               == 0x0000000020000000ULL, "WindowFlags.metal");
_Static_assert(SDL_WINDOW_TRANSPARENT         == 0x0000000040000000ULL, "WindowFlags.transparent");
_Static_assert(SDL_WINDOW_NOT_FOCUSABLE       == 0x0000000080000000ULL, "WindowFlags.notFocusable");

/* ---- Sdl/Video.lean: FlashOperation ---- */
_Static_assert((int)SDL_FLASH_CANCEL        == 0, "FlashOperation.cancel");
_Static_assert((int)SDL_FLASH_BRIEFLY       == 1, "FlashOperation.briefly");
_Static_assert((int)SDL_FLASH_UNTIL_FOCUSED == 2, "FlashOperation.untilFocused");

/* ---- Sdl/Video.lean: ProgressState (INVALID is the -1 error sentinel) ---- */
_Static_assert((int)SDL_PROGRESS_STATE_INVALID       == -1, "ProgressState.invalid sentinel");
_Static_assert((int)SDL_PROGRESS_STATE_NONE          == 0,  "ProgressState.none");
_Static_assert((int)SDL_PROGRESS_STATE_INDETERMINATE == 1,  "ProgressState.indeterminate");
_Static_assert((int)SDL_PROGRESS_STATE_NORMAL        == 2,  "ProgressState.normal");
_Static_assert((int)SDL_PROGRESS_STATE_PAUSED        == 3,  "ProgressState.paused");
_Static_assert((int)SDL_PROGRESS_STATE_ERROR         == 4,  "ProgressState.error");

/* ---- Sdl/Video.lean: GLAttr ---- */
_Static_assert((int)SDL_GL_RED_SIZE                   == 0,  "GLAttr.redSize");
_Static_assert((int)SDL_GL_GREEN_SIZE                 == 1,  "GLAttr.greenSize");
_Static_assert((int)SDL_GL_BLUE_SIZE                  == 2,  "GLAttr.blueSize");
_Static_assert((int)SDL_GL_ALPHA_SIZE                 == 3,  "GLAttr.alphaSize");
_Static_assert((int)SDL_GL_BUFFER_SIZE                == 4,  "GLAttr.bufferSize");
_Static_assert((int)SDL_GL_DOUBLEBUFFER               == 5,  "GLAttr.doublebuffer");
_Static_assert((int)SDL_GL_DEPTH_SIZE                 == 6,  "GLAttr.depthSize");
_Static_assert((int)SDL_GL_STENCIL_SIZE               == 7,  "GLAttr.stencilSize");
_Static_assert((int)SDL_GL_ACCUM_RED_SIZE             == 8,  "GLAttr.accumRedSize");
_Static_assert((int)SDL_GL_ACCUM_GREEN_SIZE           == 9,  "GLAttr.accumGreenSize");
_Static_assert((int)SDL_GL_ACCUM_BLUE_SIZE            == 10, "GLAttr.accumBlueSize");
_Static_assert((int)SDL_GL_ACCUM_ALPHA_SIZE           == 11, "GLAttr.accumAlphaSize");
_Static_assert((int)SDL_GL_STEREO                     == 12, "GLAttr.stereo");
_Static_assert((int)SDL_GL_MULTISAMPLEBUFFERS         == 13, "GLAttr.multisamplebuffers");
_Static_assert((int)SDL_GL_MULTISAMPLESAMPLES         == 14, "GLAttr.multisamplesamples");
_Static_assert((int)SDL_GL_ACCELERATED_VISUAL         == 15, "GLAttr.acceleratedVisual");
_Static_assert((int)SDL_GL_RETAINED_BACKING           == 16, "GLAttr.retainedBacking");
_Static_assert((int)SDL_GL_CONTEXT_MAJOR_VERSION      == 17, "GLAttr.contextMajorVersion");
_Static_assert((int)SDL_GL_CONTEXT_MINOR_VERSION      == 18, "GLAttr.contextMinorVersion");
_Static_assert((int)SDL_GL_CONTEXT_FLAGS              == 19, "GLAttr.contextFlags");
_Static_assert((int)SDL_GL_CONTEXT_PROFILE_MASK       == 20, "GLAttr.contextProfileMask");
_Static_assert((int)SDL_GL_SHARE_WITH_CURRENT_CONTEXT == 21, "GLAttr.shareWithCurrentContext");
_Static_assert((int)SDL_GL_FRAMEBUFFER_SRGB_CAPABLE   == 22, "GLAttr.framebufferSrgbCapable");
_Static_assert((int)SDL_GL_CONTEXT_RELEASE_BEHAVIOR   == 23, "GLAttr.contextReleaseBehavior");
_Static_assert((int)SDL_GL_CONTEXT_RESET_NOTIFICATION == 24, "GLAttr.contextResetNotification");
_Static_assert((int)SDL_GL_CONTEXT_NO_ERROR           == 25, "GLAttr.contextNoError");
_Static_assert((int)SDL_GL_FLOATBUFFERS               == 26, "GLAttr.floatbuffers");
_Static_assert((int)SDL_GL_EGL_PLATFORM               == 27, "GLAttr.eglPlatform");

/* ---- Sdl/Video.lean: GLProfile ---- */
_Static_assert(SDL_GL_CONTEXT_PROFILE_CORE          == 0x0001, "GLProfile.core");
_Static_assert(SDL_GL_CONTEXT_PROFILE_COMPATIBILITY == 0x0002, "GLProfile.compatibility");
_Static_assert(SDL_GL_CONTEXT_PROFILE_ES            == 0x0004, "GLProfile.es");

/* ---- Sdl/Video.lean: GLContextFlag ---- */
_Static_assert(SDL_GL_CONTEXT_DEBUG_FLAG              == 0x0001, "GLContextFlag.debug");
_Static_assert(SDL_GL_CONTEXT_FORWARD_COMPATIBLE_FLAG == 0x0002, "GLContextFlag.forwardCompatible");
_Static_assert(SDL_GL_CONTEXT_ROBUST_ACCESS_FLAG     == 0x0004, "GLContextFlag.robustAccess");
_Static_assert(SDL_GL_CONTEXT_RESET_ISOLATION_FLAG   == 0x0008, "GLContextFlag.resetIsolation");

/* ---- Sdl/Video.lean: GLContextReleaseBehavior ---- */
_Static_assert(SDL_GL_CONTEXT_RELEASE_BEHAVIOR_NONE  == 0, "GLContextReleaseBehavior.none");
_Static_assert(SDL_GL_CONTEXT_RELEASE_BEHAVIOR_FLUSH == 1, "GLContextReleaseBehavior.flush");

/* ---- Sdl/Video.lean: GLContextResetNotification ---- */
_Static_assert(SDL_GL_CONTEXT_RESET_NO_NOTIFICATION == 0, "GLContextResetNotification.noNotification");
_Static_assert(SDL_GL_CONTEXT_RESET_LOSE_CONTEXT    == 1, "GLContextResetNotification.loseContext");

/* ---- Sdl/Video.lean: window surface vsync constants ---- */
_Static_assert(SDL_WINDOW_SURFACE_VSYNC_DISABLED == 0,  "Window.surfaceVSyncDisabled");
_Static_assert(SDL_WINDOW_SURFACE_VSYNC_ADAPTIVE == -1, "Window.surfaceVSyncAdaptive");

/* ---- Sdl/MessageBox.lean: MessageBoxFlags ---- */
_Static_assert(SDL_MESSAGEBOX_ERROR                 == 0x00000010u, "MessageBoxFlags.error");
_Static_assert(SDL_MESSAGEBOX_WARNING               == 0x00000020u, "MessageBoxFlags.warning");
_Static_assert(SDL_MESSAGEBOX_INFORMATION           == 0x00000040u, "MessageBoxFlags.information");
_Static_assert(SDL_MESSAGEBOX_BUTTONS_LEFT_TO_RIGHT == 0x00000080u, "MessageBoxFlags.buttonsLeftToRight");
_Static_assert(SDL_MESSAGEBOX_BUTTONS_RIGHT_TO_LEFT == 0x00000100u, "MessageBoxFlags.buttonsRightToLeft");

/* ---- Sdl/MessageBox.lean: MessageBoxButtonFlags ---- */
_Static_assert(SDL_MESSAGEBOX_BUTTON_RETURNKEY_DEFAULT == 0x00000001u, "MessageBoxButtonFlags.returnkeyDefault");
_Static_assert(SDL_MESSAGEBOX_BUTTON_ESCAPEKEY_DEFAULT == 0x00000002u, "MessageBoxButtonFlags.escapekeyDefault");

/* ---- Sdl/MessageBox.lean: SDL_MessageBoxColorType indices, pinned to the
 * MessageBoxColorScheme field ORDER (background, text, buttonBorder,
 * buttonBackground, buttonSelected) so the packed 15-byte scheme lines up. ---- */
_Static_assert((int)SDL_MESSAGEBOX_COLOR_BACKGROUND        == 0, "MessageBoxColorScheme.background index");
_Static_assert((int)SDL_MESSAGEBOX_COLOR_TEXT             == 1, "MessageBoxColorScheme.text index");
_Static_assert((int)SDL_MESSAGEBOX_COLOR_BUTTON_BORDER     == 2, "MessageBoxColorScheme.buttonBorder index");
_Static_assert((int)SDL_MESSAGEBOX_COLOR_BUTTON_BACKGROUND == 3, "MessageBoxColorScheme.buttonBackground index");
_Static_assert((int)SDL_MESSAGEBOX_COLOR_BUTTON_SELECTED   == 4, "MessageBoxColorScheme.buttonSelected index");
_Static_assert((int)SDL_MESSAGEBOX_COLOR_COUNT             == 5, "MessageBoxColorScheme field count");

/* ---- Sdl/MessageBox.lean: SDL_MessageBoxColor ABI (scheme packs r,g,b bytes) ---- */
_Static_assert(sizeof(SDL_MessageBoxColor) == 3, "SDL_MessageBoxColor size");

/* == Sdl/Scancode.lean: Scancode (every member; RESERVED/COUNT excluded) == */
_Static_assert(SDL_SCANCODE_UNKNOWN == 0, "Scancode.unknown");
_Static_assert(SDL_SCANCODE_A == 4, "Scancode.a");
_Static_assert(SDL_SCANCODE_B == 5, "Scancode.b");
_Static_assert(SDL_SCANCODE_C == 6, "Scancode.c");
_Static_assert(SDL_SCANCODE_D == 7, "Scancode.d");
_Static_assert(SDL_SCANCODE_E == 8, "Scancode.e");
_Static_assert(SDL_SCANCODE_F == 9, "Scancode.f");
_Static_assert(SDL_SCANCODE_G == 10, "Scancode.g");
_Static_assert(SDL_SCANCODE_H == 11, "Scancode.h");
_Static_assert(SDL_SCANCODE_I == 12, "Scancode.i");
_Static_assert(SDL_SCANCODE_J == 13, "Scancode.j");
_Static_assert(SDL_SCANCODE_K == 14, "Scancode.k");
_Static_assert(SDL_SCANCODE_L == 15, "Scancode.l");
_Static_assert(SDL_SCANCODE_M == 16, "Scancode.m");
_Static_assert(SDL_SCANCODE_N == 17, "Scancode.n");
_Static_assert(SDL_SCANCODE_O == 18, "Scancode.o");
_Static_assert(SDL_SCANCODE_P == 19, "Scancode.p");
_Static_assert(SDL_SCANCODE_Q == 20, "Scancode.q");
_Static_assert(SDL_SCANCODE_R == 21, "Scancode.r");
_Static_assert(SDL_SCANCODE_S == 22, "Scancode.s");
_Static_assert(SDL_SCANCODE_T == 23, "Scancode.t");
_Static_assert(SDL_SCANCODE_U == 24, "Scancode.u");
_Static_assert(SDL_SCANCODE_V == 25, "Scancode.v");
_Static_assert(SDL_SCANCODE_W == 26, "Scancode.w");
_Static_assert(SDL_SCANCODE_X == 27, "Scancode.x");
_Static_assert(SDL_SCANCODE_Y == 28, "Scancode.y");
_Static_assert(SDL_SCANCODE_Z == 29, "Scancode.z");
_Static_assert(SDL_SCANCODE_1 == 30, "Scancode.num1");
_Static_assert(SDL_SCANCODE_2 == 31, "Scancode.num2");
_Static_assert(SDL_SCANCODE_3 == 32, "Scancode.num3");
_Static_assert(SDL_SCANCODE_4 == 33, "Scancode.num4");
_Static_assert(SDL_SCANCODE_5 == 34, "Scancode.num5");
_Static_assert(SDL_SCANCODE_6 == 35, "Scancode.num6");
_Static_assert(SDL_SCANCODE_7 == 36, "Scancode.num7");
_Static_assert(SDL_SCANCODE_8 == 37, "Scancode.num8");
_Static_assert(SDL_SCANCODE_9 == 38, "Scancode.num9");
_Static_assert(SDL_SCANCODE_0 == 39, "Scancode.num0");
_Static_assert(SDL_SCANCODE_RETURN == 40, "Scancode.return");
_Static_assert(SDL_SCANCODE_ESCAPE == 41, "Scancode.escape");
_Static_assert(SDL_SCANCODE_BACKSPACE == 42, "Scancode.backspace");
_Static_assert(SDL_SCANCODE_TAB == 43, "Scancode.tab");
_Static_assert(SDL_SCANCODE_SPACE == 44, "Scancode.space");
_Static_assert(SDL_SCANCODE_MINUS == 45, "Scancode.minus");
_Static_assert(SDL_SCANCODE_EQUALS == 46, "Scancode.equals");
_Static_assert(SDL_SCANCODE_LEFTBRACKET == 47, "Scancode.leftBracket");
_Static_assert(SDL_SCANCODE_RIGHTBRACKET == 48, "Scancode.rightBracket");
_Static_assert(SDL_SCANCODE_BACKSLASH == 49, "Scancode.backslash");
_Static_assert(SDL_SCANCODE_NONUSHASH == 50, "Scancode.nonUsHash");
_Static_assert(SDL_SCANCODE_SEMICOLON == 51, "Scancode.semicolon");
_Static_assert(SDL_SCANCODE_APOSTROPHE == 52, "Scancode.apostrophe");
_Static_assert(SDL_SCANCODE_GRAVE == 53, "Scancode.grave");
_Static_assert(SDL_SCANCODE_COMMA == 54, "Scancode.comma");
_Static_assert(SDL_SCANCODE_PERIOD == 55, "Scancode.period");
_Static_assert(SDL_SCANCODE_SLASH == 56, "Scancode.slash");
_Static_assert(SDL_SCANCODE_CAPSLOCK == 57, "Scancode.capsLock");
_Static_assert(SDL_SCANCODE_F1 == 58, "Scancode.f1");
_Static_assert(SDL_SCANCODE_F2 == 59, "Scancode.f2");
_Static_assert(SDL_SCANCODE_F3 == 60, "Scancode.f3");
_Static_assert(SDL_SCANCODE_F4 == 61, "Scancode.f4");
_Static_assert(SDL_SCANCODE_F5 == 62, "Scancode.f5");
_Static_assert(SDL_SCANCODE_F6 == 63, "Scancode.f6");
_Static_assert(SDL_SCANCODE_F7 == 64, "Scancode.f7");
_Static_assert(SDL_SCANCODE_F8 == 65, "Scancode.f8");
_Static_assert(SDL_SCANCODE_F9 == 66, "Scancode.f9");
_Static_assert(SDL_SCANCODE_F10 == 67, "Scancode.f10");
_Static_assert(SDL_SCANCODE_F11 == 68, "Scancode.f11");
_Static_assert(SDL_SCANCODE_F12 == 69, "Scancode.f12");
_Static_assert(SDL_SCANCODE_PRINTSCREEN == 70, "Scancode.printScreen");
_Static_assert(SDL_SCANCODE_SCROLLLOCK == 71, "Scancode.scrollLock");
_Static_assert(SDL_SCANCODE_PAUSE == 72, "Scancode.pause");
_Static_assert(SDL_SCANCODE_INSERT == 73, "Scancode.insert");
_Static_assert(SDL_SCANCODE_HOME == 74, "Scancode.home");
_Static_assert(SDL_SCANCODE_PAGEUP == 75, "Scancode.pageUp");
_Static_assert(SDL_SCANCODE_DELETE == 76, "Scancode.delete");
_Static_assert(SDL_SCANCODE_END == 77, "Scancode.end");
_Static_assert(SDL_SCANCODE_PAGEDOWN == 78, "Scancode.pageDown");
_Static_assert(SDL_SCANCODE_RIGHT == 79, "Scancode.right");
_Static_assert(SDL_SCANCODE_LEFT == 80, "Scancode.left");
_Static_assert(SDL_SCANCODE_DOWN == 81, "Scancode.down");
_Static_assert(SDL_SCANCODE_UP == 82, "Scancode.up");
_Static_assert(SDL_SCANCODE_NUMLOCKCLEAR == 83, "Scancode.numLockClear");
_Static_assert(SDL_SCANCODE_KP_DIVIDE == 84, "Scancode.kpDivide");
_Static_assert(SDL_SCANCODE_KP_MULTIPLY == 85, "Scancode.kpMultiply");
_Static_assert(SDL_SCANCODE_KP_MINUS == 86, "Scancode.kpMinus");
_Static_assert(SDL_SCANCODE_KP_PLUS == 87, "Scancode.kpPlus");
_Static_assert(SDL_SCANCODE_KP_ENTER == 88, "Scancode.kpEnter");
_Static_assert(SDL_SCANCODE_KP_1 == 89, "Scancode.kp1");
_Static_assert(SDL_SCANCODE_KP_2 == 90, "Scancode.kp2");
_Static_assert(SDL_SCANCODE_KP_3 == 91, "Scancode.kp3");
_Static_assert(SDL_SCANCODE_KP_4 == 92, "Scancode.kp4");
_Static_assert(SDL_SCANCODE_KP_5 == 93, "Scancode.kp5");
_Static_assert(SDL_SCANCODE_KP_6 == 94, "Scancode.kp6");
_Static_assert(SDL_SCANCODE_KP_7 == 95, "Scancode.kp7");
_Static_assert(SDL_SCANCODE_KP_8 == 96, "Scancode.kp8");
_Static_assert(SDL_SCANCODE_KP_9 == 97, "Scancode.kp9");
_Static_assert(SDL_SCANCODE_KP_0 == 98, "Scancode.kp0");
_Static_assert(SDL_SCANCODE_KP_PERIOD == 99, "Scancode.kpPeriod");
_Static_assert(SDL_SCANCODE_NONUSBACKSLASH == 100, "Scancode.nonUsBackslash");
_Static_assert(SDL_SCANCODE_APPLICATION == 101, "Scancode.application");
_Static_assert(SDL_SCANCODE_POWER == 102, "Scancode.power");
_Static_assert(SDL_SCANCODE_KP_EQUALS == 103, "Scancode.kpEquals");
_Static_assert(SDL_SCANCODE_F13 == 104, "Scancode.f13");
_Static_assert(SDL_SCANCODE_F14 == 105, "Scancode.f14");
_Static_assert(SDL_SCANCODE_F15 == 106, "Scancode.f15");
_Static_assert(SDL_SCANCODE_F16 == 107, "Scancode.f16");
_Static_assert(SDL_SCANCODE_F17 == 108, "Scancode.f17");
_Static_assert(SDL_SCANCODE_F18 == 109, "Scancode.f18");
_Static_assert(SDL_SCANCODE_F19 == 110, "Scancode.f19");
_Static_assert(SDL_SCANCODE_F20 == 111, "Scancode.f20");
_Static_assert(SDL_SCANCODE_F21 == 112, "Scancode.f21");
_Static_assert(SDL_SCANCODE_F22 == 113, "Scancode.f22");
_Static_assert(SDL_SCANCODE_F23 == 114, "Scancode.f23");
_Static_assert(SDL_SCANCODE_F24 == 115, "Scancode.f24");
_Static_assert(SDL_SCANCODE_EXECUTE == 116, "Scancode.execute");
_Static_assert(SDL_SCANCODE_HELP == 117, "Scancode.help");
_Static_assert(SDL_SCANCODE_MENU == 118, "Scancode.menu");
_Static_assert(SDL_SCANCODE_SELECT == 119, "Scancode.select");
_Static_assert(SDL_SCANCODE_STOP == 120, "Scancode.stop");
_Static_assert(SDL_SCANCODE_AGAIN == 121, "Scancode.again");
_Static_assert(SDL_SCANCODE_UNDO == 122, "Scancode.undo");
_Static_assert(SDL_SCANCODE_CUT == 123, "Scancode.cut");
_Static_assert(SDL_SCANCODE_COPY == 124, "Scancode.copy");
_Static_assert(SDL_SCANCODE_PASTE == 125, "Scancode.paste");
_Static_assert(SDL_SCANCODE_FIND == 126, "Scancode.find");
_Static_assert(SDL_SCANCODE_MUTE == 127, "Scancode.mute");
_Static_assert(SDL_SCANCODE_VOLUMEUP == 128, "Scancode.volumeUp");
_Static_assert(SDL_SCANCODE_VOLUMEDOWN == 129, "Scancode.volumeDown");
_Static_assert(SDL_SCANCODE_KP_COMMA == 133, "Scancode.kpComma");
_Static_assert(SDL_SCANCODE_KP_EQUALSAS400 == 134, "Scancode.kpEqualsAs400");
_Static_assert(SDL_SCANCODE_INTERNATIONAL1 == 135, "Scancode.international1");
_Static_assert(SDL_SCANCODE_INTERNATIONAL2 == 136, "Scancode.international2");
_Static_assert(SDL_SCANCODE_INTERNATIONAL3 == 137, "Scancode.international3");
_Static_assert(SDL_SCANCODE_INTERNATIONAL4 == 138, "Scancode.international4");
_Static_assert(SDL_SCANCODE_INTERNATIONAL5 == 139, "Scancode.international5");
_Static_assert(SDL_SCANCODE_INTERNATIONAL6 == 140, "Scancode.international6");
_Static_assert(SDL_SCANCODE_INTERNATIONAL7 == 141, "Scancode.international7");
_Static_assert(SDL_SCANCODE_INTERNATIONAL8 == 142, "Scancode.international8");
_Static_assert(SDL_SCANCODE_INTERNATIONAL9 == 143, "Scancode.international9");
_Static_assert(SDL_SCANCODE_LANG1 == 144, "Scancode.lang1");
_Static_assert(SDL_SCANCODE_LANG2 == 145, "Scancode.lang2");
_Static_assert(SDL_SCANCODE_LANG3 == 146, "Scancode.lang3");
_Static_assert(SDL_SCANCODE_LANG4 == 147, "Scancode.lang4");
_Static_assert(SDL_SCANCODE_LANG5 == 148, "Scancode.lang5");
_Static_assert(SDL_SCANCODE_LANG6 == 149, "Scancode.lang6");
_Static_assert(SDL_SCANCODE_LANG7 == 150, "Scancode.lang7");
_Static_assert(SDL_SCANCODE_LANG8 == 151, "Scancode.lang8");
_Static_assert(SDL_SCANCODE_LANG9 == 152, "Scancode.lang9");
_Static_assert(SDL_SCANCODE_ALTERASE == 153, "Scancode.altErase");
_Static_assert(SDL_SCANCODE_SYSREQ == 154, "Scancode.sysReq");
_Static_assert(SDL_SCANCODE_CANCEL == 155, "Scancode.cancel");
_Static_assert(SDL_SCANCODE_CLEAR == 156, "Scancode.clear");
_Static_assert(SDL_SCANCODE_PRIOR == 157, "Scancode.prior");
_Static_assert(SDL_SCANCODE_RETURN2 == 158, "Scancode.return2");
_Static_assert(SDL_SCANCODE_SEPARATOR == 159, "Scancode.separator");
_Static_assert(SDL_SCANCODE_OUT == 160, "Scancode.out");
_Static_assert(SDL_SCANCODE_OPER == 161, "Scancode.oper");
_Static_assert(SDL_SCANCODE_CLEARAGAIN == 162, "Scancode.clearAgain");
_Static_assert(SDL_SCANCODE_CRSEL == 163, "Scancode.crSel");
_Static_assert(SDL_SCANCODE_EXSEL == 164, "Scancode.exSel");
_Static_assert(SDL_SCANCODE_KP_00 == 176, "Scancode.kp00");
_Static_assert(SDL_SCANCODE_KP_000 == 177, "Scancode.kp000");
_Static_assert(SDL_SCANCODE_THOUSANDSSEPARATOR == 178, "Scancode.thousandsSeparator");
_Static_assert(SDL_SCANCODE_DECIMALSEPARATOR == 179, "Scancode.decimalSeparator");
_Static_assert(SDL_SCANCODE_CURRENCYUNIT == 180, "Scancode.currencyUnit");
_Static_assert(SDL_SCANCODE_CURRENCYSUBUNIT == 181, "Scancode.currencySubunit");
_Static_assert(SDL_SCANCODE_KP_LEFTPAREN == 182, "Scancode.kpLeftParen");
_Static_assert(SDL_SCANCODE_KP_RIGHTPAREN == 183, "Scancode.kpRightParen");
_Static_assert(SDL_SCANCODE_KP_LEFTBRACE == 184, "Scancode.kpLeftBrace");
_Static_assert(SDL_SCANCODE_KP_RIGHTBRACE == 185, "Scancode.kpRightBrace");
_Static_assert(SDL_SCANCODE_KP_TAB == 186, "Scancode.kpTab");
_Static_assert(SDL_SCANCODE_KP_BACKSPACE == 187, "Scancode.kpBackspace");
_Static_assert(SDL_SCANCODE_KP_A == 188, "Scancode.kpA");
_Static_assert(SDL_SCANCODE_KP_B == 189, "Scancode.kpB");
_Static_assert(SDL_SCANCODE_KP_C == 190, "Scancode.kpC");
_Static_assert(SDL_SCANCODE_KP_D == 191, "Scancode.kpD");
_Static_assert(SDL_SCANCODE_KP_E == 192, "Scancode.kpE");
_Static_assert(SDL_SCANCODE_KP_F == 193, "Scancode.kpF");
_Static_assert(SDL_SCANCODE_KP_XOR == 194, "Scancode.kpXor");
_Static_assert(SDL_SCANCODE_KP_POWER == 195, "Scancode.kpPower");
_Static_assert(SDL_SCANCODE_KP_PERCENT == 196, "Scancode.kpPercent");
_Static_assert(SDL_SCANCODE_KP_LESS == 197, "Scancode.kpLess");
_Static_assert(SDL_SCANCODE_KP_GREATER == 198, "Scancode.kpGreater");
_Static_assert(SDL_SCANCODE_KP_AMPERSAND == 199, "Scancode.kpAmpersand");
_Static_assert(SDL_SCANCODE_KP_DBLAMPERSAND == 200, "Scancode.kpDblAmpersand");
_Static_assert(SDL_SCANCODE_KP_VERTICALBAR == 201, "Scancode.kpVerticalBar");
_Static_assert(SDL_SCANCODE_KP_DBLVERTICALBAR == 202, "Scancode.kpDblVerticalBar");
_Static_assert(SDL_SCANCODE_KP_COLON == 203, "Scancode.kpColon");
_Static_assert(SDL_SCANCODE_KP_HASH == 204, "Scancode.kpHash");
_Static_assert(SDL_SCANCODE_KP_SPACE == 205, "Scancode.kpSpace");
_Static_assert(SDL_SCANCODE_KP_AT == 206, "Scancode.kpAt");
_Static_assert(SDL_SCANCODE_KP_EXCLAM == 207, "Scancode.kpExclam");
_Static_assert(SDL_SCANCODE_KP_MEMSTORE == 208, "Scancode.kpMemStore");
_Static_assert(SDL_SCANCODE_KP_MEMRECALL == 209, "Scancode.kpMemRecall");
_Static_assert(SDL_SCANCODE_KP_MEMCLEAR == 210, "Scancode.kpMemClear");
_Static_assert(SDL_SCANCODE_KP_MEMADD == 211, "Scancode.kpMemAdd");
_Static_assert(SDL_SCANCODE_KP_MEMSUBTRACT == 212, "Scancode.kpMemSubtract");
_Static_assert(SDL_SCANCODE_KP_MEMMULTIPLY == 213, "Scancode.kpMemMultiply");
_Static_assert(SDL_SCANCODE_KP_MEMDIVIDE == 214, "Scancode.kpMemDivide");
_Static_assert(SDL_SCANCODE_KP_PLUSMINUS == 215, "Scancode.kpPlusMinus");
_Static_assert(SDL_SCANCODE_KP_CLEAR == 216, "Scancode.kpClear");
_Static_assert(SDL_SCANCODE_KP_CLEARENTRY == 217, "Scancode.kpClearEntry");
_Static_assert(SDL_SCANCODE_KP_BINARY == 218, "Scancode.kpBinary");
_Static_assert(SDL_SCANCODE_KP_OCTAL == 219, "Scancode.kpOctal");
_Static_assert(SDL_SCANCODE_KP_DECIMAL == 220, "Scancode.kpDecimal");
_Static_assert(SDL_SCANCODE_KP_HEXADECIMAL == 221, "Scancode.kpHexadecimal");
_Static_assert(SDL_SCANCODE_LCTRL == 224, "Scancode.lCtrl");
_Static_assert(SDL_SCANCODE_LSHIFT == 225, "Scancode.lShift");
_Static_assert(SDL_SCANCODE_LALT == 226, "Scancode.lAlt");
_Static_assert(SDL_SCANCODE_LGUI == 227, "Scancode.lGui");
_Static_assert(SDL_SCANCODE_RCTRL == 228, "Scancode.rCtrl");
_Static_assert(SDL_SCANCODE_RSHIFT == 229, "Scancode.rShift");
_Static_assert(SDL_SCANCODE_RALT == 230, "Scancode.rAlt");
_Static_assert(SDL_SCANCODE_RGUI == 231, "Scancode.rGui");
_Static_assert(SDL_SCANCODE_MODE == 257, "Scancode.mode");
_Static_assert(SDL_SCANCODE_SLEEP == 258, "Scancode.sleep");
_Static_assert(SDL_SCANCODE_WAKE == 259, "Scancode.wake");
_Static_assert(SDL_SCANCODE_CHANNEL_INCREMENT == 260, "Scancode.channelIncrement");
_Static_assert(SDL_SCANCODE_CHANNEL_DECREMENT == 261, "Scancode.channelDecrement");
_Static_assert(SDL_SCANCODE_MEDIA_PLAY == 262, "Scancode.mediaPlay");
_Static_assert(SDL_SCANCODE_MEDIA_PAUSE == 263, "Scancode.mediaPause");
_Static_assert(SDL_SCANCODE_MEDIA_RECORD == 264, "Scancode.mediaRecord");
_Static_assert(SDL_SCANCODE_MEDIA_FAST_FORWARD == 265, "Scancode.mediaFastForward");
_Static_assert(SDL_SCANCODE_MEDIA_REWIND == 266, "Scancode.mediaRewind");
_Static_assert(SDL_SCANCODE_MEDIA_NEXT_TRACK == 267, "Scancode.mediaNextTrack");
_Static_assert(SDL_SCANCODE_MEDIA_PREVIOUS_TRACK == 268, "Scancode.mediaPreviousTrack");
_Static_assert(SDL_SCANCODE_MEDIA_STOP == 269, "Scancode.mediaStop");
_Static_assert(SDL_SCANCODE_MEDIA_EJECT == 270, "Scancode.mediaEject");
_Static_assert(SDL_SCANCODE_MEDIA_PLAY_PAUSE == 271, "Scancode.mediaPlayPause");
_Static_assert(SDL_SCANCODE_MEDIA_SELECT == 272, "Scancode.mediaSelect");
_Static_assert(SDL_SCANCODE_AC_NEW == 273, "Scancode.acNew");
_Static_assert(SDL_SCANCODE_AC_OPEN == 274, "Scancode.acOpen");
_Static_assert(SDL_SCANCODE_AC_CLOSE == 275, "Scancode.acClose");
_Static_assert(SDL_SCANCODE_AC_EXIT == 276, "Scancode.acExit");
_Static_assert(SDL_SCANCODE_AC_SAVE == 277, "Scancode.acSave");
_Static_assert(SDL_SCANCODE_AC_PRINT == 278, "Scancode.acPrint");
_Static_assert(SDL_SCANCODE_AC_PROPERTIES == 279, "Scancode.acProperties");
_Static_assert(SDL_SCANCODE_AC_SEARCH == 280, "Scancode.acSearch");
_Static_assert(SDL_SCANCODE_AC_HOME == 281, "Scancode.acHome");
_Static_assert(SDL_SCANCODE_AC_BACK == 282, "Scancode.acBack");
_Static_assert(SDL_SCANCODE_AC_FORWARD == 283, "Scancode.acForward");
_Static_assert(SDL_SCANCODE_AC_STOP == 284, "Scancode.acStop");
_Static_assert(SDL_SCANCODE_AC_REFRESH == 285, "Scancode.acRefresh");
_Static_assert(SDL_SCANCODE_AC_BOOKMARKS == 286, "Scancode.acBookmarks");
_Static_assert(SDL_SCANCODE_SOFTLEFT == 287, "Scancode.softLeft");
_Static_assert(SDL_SCANCODE_SOFTRIGHT == 288, "Scancode.softRight");
_Static_assert(SDL_SCANCODE_CALL == 289, "Scancode.call");
_Static_assert(SDL_SCANCODE_ENDCALL == 290, "Scancode.endCall");
_Static_assert(SDL_SCANCODE_COUNT == 512, "Scancode.maxScancodes");

/* == Sdl/Keycode.lean: Keycode (every member incl. masks), Keymod == */
_Static_assert(SDLK_UNKNOWN == 0x00000000u, "Keycode.unknown");
_Static_assert(SDLK_RETURN == 0x0000000du, "Keycode.return");
_Static_assert(SDLK_ESCAPE == 0x0000001bu, "Keycode.escape");
_Static_assert(SDLK_BACKSPACE == 0x00000008u, "Keycode.backspace");
_Static_assert(SDLK_TAB == 0x00000009u, "Keycode.tab");
_Static_assert(SDLK_SPACE == 0x00000020u, "Keycode.space");
_Static_assert(SDLK_EXCLAIM == 0x00000021u, "Keycode.exclaim");
_Static_assert(SDLK_DBLAPOSTROPHE == 0x00000022u, "Keycode.dblApostrophe");
_Static_assert(SDLK_HASH == 0x00000023u, "Keycode.hash");
_Static_assert(SDLK_DOLLAR == 0x00000024u, "Keycode.dollar");
_Static_assert(SDLK_PERCENT == 0x00000025u, "Keycode.percent");
_Static_assert(SDLK_AMPERSAND == 0x00000026u, "Keycode.ampersand");
_Static_assert(SDLK_APOSTROPHE == 0x00000027u, "Keycode.apostrophe");
_Static_assert(SDLK_LEFTPAREN == 0x00000028u, "Keycode.leftParen");
_Static_assert(SDLK_RIGHTPAREN == 0x00000029u, "Keycode.rightParen");
_Static_assert(SDLK_ASTERISK == 0x0000002au, "Keycode.asterisk");
_Static_assert(SDLK_PLUS == 0x0000002bu, "Keycode.plus");
_Static_assert(SDLK_COMMA == 0x0000002cu, "Keycode.comma");
_Static_assert(SDLK_MINUS == 0x0000002du, "Keycode.minus");
_Static_assert(SDLK_PERIOD == 0x0000002eu, "Keycode.period");
_Static_assert(SDLK_SLASH == 0x0000002fu, "Keycode.slash");
_Static_assert(SDLK_0 == 0x00000030u, "Keycode.num0");
_Static_assert(SDLK_1 == 0x00000031u, "Keycode.num1");
_Static_assert(SDLK_2 == 0x00000032u, "Keycode.num2");
_Static_assert(SDLK_3 == 0x00000033u, "Keycode.num3");
_Static_assert(SDLK_4 == 0x00000034u, "Keycode.num4");
_Static_assert(SDLK_5 == 0x00000035u, "Keycode.num5");
_Static_assert(SDLK_6 == 0x00000036u, "Keycode.num6");
_Static_assert(SDLK_7 == 0x00000037u, "Keycode.num7");
_Static_assert(SDLK_8 == 0x00000038u, "Keycode.num8");
_Static_assert(SDLK_9 == 0x00000039u, "Keycode.num9");
_Static_assert(SDLK_COLON == 0x0000003au, "Keycode.colon");
_Static_assert(SDLK_SEMICOLON == 0x0000003bu, "Keycode.semicolon");
_Static_assert(SDLK_LESS == 0x0000003cu, "Keycode.less");
_Static_assert(SDLK_EQUALS == 0x0000003du, "Keycode.equals");
_Static_assert(SDLK_GREATER == 0x0000003eu, "Keycode.greater");
_Static_assert(SDLK_QUESTION == 0x0000003fu, "Keycode.question");
_Static_assert(SDLK_AT == 0x00000040u, "Keycode.at");
_Static_assert(SDLK_LEFTBRACKET == 0x0000005bu, "Keycode.leftBracket");
_Static_assert(SDLK_BACKSLASH == 0x0000005cu, "Keycode.backslash");
_Static_assert(SDLK_RIGHTBRACKET == 0x0000005du, "Keycode.rightBracket");
_Static_assert(SDLK_CARET == 0x0000005eu, "Keycode.caret");
_Static_assert(SDLK_UNDERSCORE == 0x0000005fu, "Keycode.underscore");
_Static_assert(SDLK_GRAVE == 0x00000060u, "Keycode.grave");
_Static_assert(SDLK_A == 0x00000061u, "Keycode.a");
_Static_assert(SDLK_B == 0x00000062u, "Keycode.b");
_Static_assert(SDLK_C == 0x00000063u, "Keycode.c");
_Static_assert(SDLK_D == 0x00000064u, "Keycode.d");
_Static_assert(SDLK_E == 0x00000065u, "Keycode.e");
_Static_assert(SDLK_F == 0x00000066u, "Keycode.f");
_Static_assert(SDLK_G == 0x00000067u, "Keycode.g");
_Static_assert(SDLK_H == 0x00000068u, "Keycode.h");
_Static_assert(SDLK_I == 0x00000069u, "Keycode.i");
_Static_assert(SDLK_J == 0x0000006au, "Keycode.j");
_Static_assert(SDLK_K == 0x0000006bu, "Keycode.k");
_Static_assert(SDLK_L == 0x0000006cu, "Keycode.l");
_Static_assert(SDLK_M == 0x0000006du, "Keycode.m");
_Static_assert(SDLK_N == 0x0000006eu, "Keycode.n");
_Static_assert(SDLK_O == 0x0000006fu, "Keycode.o");
_Static_assert(SDLK_P == 0x00000070u, "Keycode.p");
_Static_assert(SDLK_Q == 0x00000071u, "Keycode.q");
_Static_assert(SDLK_R == 0x00000072u, "Keycode.r");
_Static_assert(SDLK_S == 0x00000073u, "Keycode.s");
_Static_assert(SDLK_T == 0x00000074u, "Keycode.t");
_Static_assert(SDLK_U == 0x00000075u, "Keycode.u");
_Static_assert(SDLK_V == 0x00000076u, "Keycode.v");
_Static_assert(SDLK_W == 0x00000077u, "Keycode.w");
_Static_assert(SDLK_X == 0x00000078u, "Keycode.x");
_Static_assert(SDLK_Y == 0x00000079u, "Keycode.y");
_Static_assert(SDLK_Z == 0x0000007au, "Keycode.z");
_Static_assert(SDLK_LEFTBRACE == 0x0000007bu, "Keycode.leftBrace");
_Static_assert(SDLK_PIPE == 0x0000007cu, "Keycode.pipe");
_Static_assert(SDLK_RIGHTBRACE == 0x0000007du, "Keycode.rightBrace");
_Static_assert(SDLK_TILDE == 0x0000007eu, "Keycode.tilde");
_Static_assert(SDLK_DELETE == 0x0000007fu, "Keycode.delete");
_Static_assert(SDLK_PLUSMINUS == 0x000000b1u, "Keycode.plusMinus");
_Static_assert(SDLK_CAPSLOCK == 0x40000039u, "Keycode.capsLock");
_Static_assert(SDLK_F1 == 0x4000003au, "Keycode.f1");
_Static_assert(SDLK_F2 == 0x4000003bu, "Keycode.f2");
_Static_assert(SDLK_F3 == 0x4000003cu, "Keycode.f3");
_Static_assert(SDLK_F4 == 0x4000003du, "Keycode.f4");
_Static_assert(SDLK_F5 == 0x4000003eu, "Keycode.f5");
_Static_assert(SDLK_F6 == 0x4000003fu, "Keycode.f6");
_Static_assert(SDLK_F7 == 0x40000040u, "Keycode.f7");
_Static_assert(SDLK_F8 == 0x40000041u, "Keycode.f8");
_Static_assert(SDLK_F9 == 0x40000042u, "Keycode.f9");
_Static_assert(SDLK_F10 == 0x40000043u, "Keycode.f10");
_Static_assert(SDLK_F11 == 0x40000044u, "Keycode.f11");
_Static_assert(SDLK_F12 == 0x40000045u, "Keycode.f12");
_Static_assert(SDLK_PRINTSCREEN == 0x40000046u, "Keycode.printScreen");
_Static_assert(SDLK_SCROLLLOCK == 0x40000047u, "Keycode.scrollLock");
_Static_assert(SDLK_PAUSE == 0x40000048u, "Keycode.pause");
_Static_assert(SDLK_INSERT == 0x40000049u, "Keycode.insert");
_Static_assert(SDLK_HOME == 0x4000004au, "Keycode.home");
_Static_assert(SDLK_PAGEUP == 0x4000004bu, "Keycode.pageUp");
_Static_assert(SDLK_END == 0x4000004du, "Keycode.end");
_Static_assert(SDLK_PAGEDOWN == 0x4000004eu, "Keycode.pageDown");
_Static_assert(SDLK_RIGHT == 0x4000004fu, "Keycode.right");
_Static_assert(SDLK_LEFT == 0x40000050u, "Keycode.left");
_Static_assert(SDLK_DOWN == 0x40000051u, "Keycode.down");
_Static_assert(SDLK_UP == 0x40000052u, "Keycode.up");
_Static_assert(SDLK_NUMLOCKCLEAR == 0x40000053u, "Keycode.numLockClear");
_Static_assert(SDLK_KP_DIVIDE == 0x40000054u, "Keycode.kpDivide");
_Static_assert(SDLK_KP_MULTIPLY == 0x40000055u, "Keycode.kpMultiply");
_Static_assert(SDLK_KP_MINUS == 0x40000056u, "Keycode.kpMinus");
_Static_assert(SDLK_KP_PLUS == 0x40000057u, "Keycode.kpPlus");
_Static_assert(SDLK_KP_ENTER == 0x40000058u, "Keycode.kpEnter");
_Static_assert(SDLK_KP_1 == 0x40000059u, "Keycode.kp1");
_Static_assert(SDLK_KP_2 == 0x4000005au, "Keycode.kp2");
_Static_assert(SDLK_KP_3 == 0x4000005bu, "Keycode.kp3");
_Static_assert(SDLK_KP_4 == 0x4000005cu, "Keycode.kp4");
_Static_assert(SDLK_KP_5 == 0x4000005du, "Keycode.kp5");
_Static_assert(SDLK_KP_6 == 0x4000005eu, "Keycode.kp6");
_Static_assert(SDLK_KP_7 == 0x4000005fu, "Keycode.kp7");
_Static_assert(SDLK_KP_8 == 0x40000060u, "Keycode.kp8");
_Static_assert(SDLK_KP_9 == 0x40000061u, "Keycode.kp9");
_Static_assert(SDLK_KP_0 == 0x40000062u, "Keycode.kp0");
_Static_assert(SDLK_KP_PERIOD == 0x40000063u, "Keycode.kpPeriod");
_Static_assert(SDLK_APPLICATION == 0x40000065u, "Keycode.application");
_Static_assert(SDLK_POWER == 0x40000066u, "Keycode.power");
_Static_assert(SDLK_KP_EQUALS == 0x40000067u, "Keycode.kpEquals");
_Static_assert(SDLK_F13 == 0x40000068u, "Keycode.f13");
_Static_assert(SDLK_F14 == 0x40000069u, "Keycode.f14");
_Static_assert(SDLK_F15 == 0x4000006au, "Keycode.f15");
_Static_assert(SDLK_F16 == 0x4000006bu, "Keycode.f16");
_Static_assert(SDLK_F17 == 0x4000006cu, "Keycode.f17");
_Static_assert(SDLK_F18 == 0x4000006du, "Keycode.f18");
_Static_assert(SDLK_F19 == 0x4000006eu, "Keycode.f19");
_Static_assert(SDLK_F20 == 0x4000006fu, "Keycode.f20");
_Static_assert(SDLK_F21 == 0x40000070u, "Keycode.f21");
_Static_assert(SDLK_F22 == 0x40000071u, "Keycode.f22");
_Static_assert(SDLK_F23 == 0x40000072u, "Keycode.f23");
_Static_assert(SDLK_F24 == 0x40000073u, "Keycode.f24");
_Static_assert(SDLK_EXECUTE == 0x40000074u, "Keycode.execute");
_Static_assert(SDLK_HELP == 0x40000075u, "Keycode.help");
_Static_assert(SDLK_MENU == 0x40000076u, "Keycode.menu");
_Static_assert(SDLK_SELECT == 0x40000077u, "Keycode.select");
_Static_assert(SDLK_STOP == 0x40000078u, "Keycode.stop");
_Static_assert(SDLK_AGAIN == 0x40000079u, "Keycode.again");
_Static_assert(SDLK_UNDO == 0x4000007au, "Keycode.undo");
_Static_assert(SDLK_CUT == 0x4000007bu, "Keycode.cut");
_Static_assert(SDLK_COPY == 0x4000007cu, "Keycode.copy");
_Static_assert(SDLK_PASTE == 0x4000007du, "Keycode.paste");
_Static_assert(SDLK_FIND == 0x4000007eu, "Keycode.find");
_Static_assert(SDLK_MUTE == 0x4000007fu, "Keycode.mute");
_Static_assert(SDLK_VOLUMEUP == 0x40000080u, "Keycode.volumeUp");
_Static_assert(SDLK_VOLUMEDOWN == 0x40000081u, "Keycode.volumeDown");
_Static_assert(SDLK_KP_COMMA == 0x40000085u, "Keycode.kpComma");
_Static_assert(SDLK_KP_EQUALSAS400 == 0x40000086u, "Keycode.kpEqualsAs400");
_Static_assert(SDLK_ALTERASE == 0x40000099u, "Keycode.altErase");
_Static_assert(SDLK_SYSREQ == 0x4000009au, "Keycode.sysReq");
_Static_assert(SDLK_CANCEL == 0x4000009bu, "Keycode.cancel");
_Static_assert(SDLK_CLEAR == 0x4000009cu, "Keycode.clear");
_Static_assert(SDLK_PRIOR == 0x4000009du, "Keycode.prior");
_Static_assert(SDLK_RETURN2 == 0x4000009eu, "Keycode.return2");
_Static_assert(SDLK_SEPARATOR == 0x4000009fu, "Keycode.separator");
_Static_assert(SDLK_OUT == 0x400000a0u, "Keycode.out");
_Static_assert(SDLK_OPER == 0x400000a1u, "Keycode.oper");
_Static_assert(SDLK_CLEARAGAIN == 0x400000a2u, "Keycode.clearAgain");
_Static_assert(SDLK_CRSEL == 0x400000a3u, "Keycode.crSel");
_Static_assert(SDLK_EXSEL == 0x400000a4u, "Keycode.exSel");
_Static_assert(SDLK_KP_00 == 0x400000b0u, "Keycode.kp00");
_Static_assert(SDLK_KP_000 == 0x400000b1u, "Keycode.kp000");
_Static_assert(SDLK_THOUSANDSSEPARATOR == 0x400000b2u, "Keycode.thousandsSeparator");
_Static_assert(SDLK_DECIMALSEPARATOR == 0x400000b3u, "Keycode.decimalSeparator");
_Static_assert(SDLK_CURRENCYUNIT == 0x400000b4u, "Keycode.currencyUnit");
_Static_assert(SDLK_CURRENCYSUBUNIT == 0x400000b5u, "Keycode.currencySubunit");
_Static_assert(SDLK_KP_LEFTPAREN == 0x400000b6u, "Keycode.kpLeftParen");
_Static_assert(SDLK_KP_RIGHTPAREN == 0x400000b7u, "Keycode.kpRightParen");
_Static_assert(SDLK_KP_LEFTBRACE == 0x400000b8u, "Keycode.kpLeftBrace");
_Static_assert(SDLK_KP_RIGHTBRACE == 0x400000b9u, "Keycode.kpRightBrace");
_Static_assert(SDLK_KP_TAB == 0x400000bau, "Keycode.kpTab");
_Static_assert(SDLK_KP_BACKSPACE == 0x400000bbu, "Keycode.kpBackspace");
_Static_assert(SDLK_KP_A == 0x400000bcu, "Keycode.kpA");
_Static_assert(SDLK_KP_B == 0x400000bdu, "Keycode.kpB");
_Static_assert(SDLK_KP_C == 0x400000beu, "Keycode.kpC");
_Static_assert(SDLK_KP_D == 0x400000bfu, "Keycode.kpD");
_Static_assert(SDLK_KP_E == 0x400000c0u, "Keycode.kpE");
_Static_assert(SDLK_KP_F == 0x400000c1u, "Keycode.kpF");
_Static_assert(SDLK_KP_XOR == 0x400000c2u, "Keycode.kpXor");
_Static_assert(SDLK_KP_POWER == 0x400000c3u, "Keycode.kpPower");
_Static_assert(SDLK_KP_PERCENT == 0x400000c4u, "Keycode.kpPercent");
_Static_assert(SDLK_KP_LESS == 0x400000c5u, "Keycode.kpLess");
_Static_assert(SDLK_KP_GREATER == 0x400000c6u, "Keycode.kpGreater");
_Static_assert(SDLK_KP_AMPERSAND == 0x400000c7u, "Keycode.kpAmpersand");
_Static_assert(SDLK_KP_DBLAMPERSAND == 0x400000c8u, "Keycode.kpDblAmpersand");
_Static_assert(SDLK_KP_VERTICALBAR == 0x400000c9u, "Keycode.kpVerticalBar");
_Static_assert(SDLK_KP_DBLVERTICALBAR == 0x400000cau, "Keycode.kpDblVerticalBar");
_Static_assert(SDLK_KP_COLON == 0x400000cbu, "Keycode.kpColon");
_Static_assert(SDLK_KP_HASH == 0x400000ccu, "Keycode.kpHash");
_Static_assert(SDLK_KP_SPACE == 0x400000cdu, "Keycode.kpSpace");
_Static_assert(SDLK_KP_AT == 0x400000ceu, "Keycode.kpAt");
_Static_assert(SDLK_KP_EXCLAM == 0x400000cfu, "Keycode.kpExclam");
_Static_assert(SDLK_KP_MEMSTORE == 0x400000d0u, "Keycode.kpMemStore");
_Static_assert(SDLK_KP_MEMRECALL == 0x400000d1u, "Keycode.kpMemRecall");
_Static_assert(SDLK_KP_MEMCLEAR == 0x400000d2u, "Keycode.kpMemClear");
_Static_assert(SDLK_KP_MEMADD == 0x400000d3u, "Keycode.kpMemAdd");
_Static_assert(SDLK_KP_MEMSUBTRACT == 0x400000d4u, "Keycode.kpMemSubtract");
_Static_assert(SDLK_KP_MEMMULTIPLY == 0x400000d5u, "Keycode.kpMemMultiply");
_Static_assert(SDLK_KP_MEMDIVIDE == 0x400000d6u, "Keycode.kpMemDivide");
_Static_assert(SDLK_KP_PLUSMINUS == 0x400000d7u, "Keycode.kpPlusMinus");
_Static_assert(SDLK_KP_CLEAR == 0x400000d8u, "Keycode.kpClear");
_Static_assert(SDLK_KP_CLEARENTRY == 0x400000d9u, "Keycode.kpClearEntry");
_Static_assert(SDLK_KP_BINARY == 0x400000dau, "Keycode.kpBinary");
_Static_assert(SDLK_KP_OCTAL == 0x400000dbu, "Keycode.kpOctal");
_Static_assert(SDLK_KP_DECIMAL == 0x400000dcu, "Keycode.kpDecimal");
_Static_assert(SDLK_KP_HEXADECIMAL == 0x400000ddu, "Keycode.kpHexadecimal");
_Static_assert(SDLK_LCTRL == 0x400000e0u, "Keycode.lCtrl");
_Static_assert(SDLK_LSHIFT == 0x400000e1u, "Keycode.lShift");
_Static_assert(SDLK_LALT == 0x400000e2u, "Keycode.lAlt");
_Static_assert(SDLK_LGUI == 0x400000e3u, "Keycode.lGui");
_Static_assert(SDLK_RCTRL == 0x400000e4u, "Keycode.rCtrl");
_Static_assert(SDLK_RSHIFT == 0x400000e5u, "Keycode.rShift");
_Static_assert(SDLK_RALT == 0x400000e6u, "Keycode.rAlt");
_Static_assert(SDLK_RGUI == 0x400000e7u, "Keycode.rGui");
_Static_assert(SDLK_MODE == 0x40000101u, "Keycode.mode");
_Static_assert(SDLK_SLEEP == 0x40000102u, "Keycode.sleep");
_Static_assert(SDLK_WAKE == 0x40000103u, "Keycode.wake");
_Static_assert(SDLK_CHANNEL_INCREMENT == 0x40000104u, "Keycode.channelIncrement");
_Static_assert(SDLK_CHANNEL_DECREMENT == 0x40000105u, "Keycode.channelDecrement");
_Static_assert(SDLK_MEDIA_PLAY == 0x40000106u, "Keycode.mediaPlay");
_Static_assert(SDLK_MEDIA_PAUSE == 0x40000107u, "Keycode.mediaPause");
_Static_assert(SDLK_MEDIA_RECORD == 0x40000108u, "Keycode.mediaRecord");
_Static_assert(SDLK_MEDIA_FAST_FORWARD == 0x40000109u, "Keycode.mediaFastForward");
_Static_assert(SDLK_MEDIA_REWIND == 0x4000010au, "Keycode.mediaRewind");
_Static_assert(SDLK_MEDIA_NEXT_TRACK == 0x4000010bu, "Keycode.mediaNextTrack");
_Static_assert(SDLK_MEDIA_PREVIOUS_TRACK == 0x4000010cu, "Keycode.mediaPreviousTrack");
_Static_assert(SDLK_MEDIA_STOP == 0x4000010du, "Keycode.mediaStop");
_Static_assert(SDLK_MEDIA_EJECT == 0x4000010eu, "Keycode.mediaEject");
_Static_assert(SDLK_MEDIA_PLAY_PAUSE == 0x4000010fu, "Keycode.mediaPlayPause");
_Static_assert(SDLK_MEDIA_SELECT == 0x40000110u, "Keycode.mediaSelect");
_Static_assert(SDLK_AC_NEW == 0x40000111u, "Keycode.acNew");
_Static_assert(SDLK_AC_OPEN == 0x40000112u, "Keycode.acOpen");
_Static_assert(SDLK_AC_CLOSE == 0x40000113u, "Keycode.acClose");
_Static_assert(SDLK_AC_EXIT == 0x40000114u, "Keycode.acExit");
_Static_assert(SDLK_AC_SAVE == 0x40000115u, "Keycode.acSave");
_Static_assert(SDLK_AC_PRINT == 0x40000116u, "Keycode.acPrint");
_Static_assert(SDLK_AC_PROPERTIES == 0x40000117u, "Keycode.acProperties");
_Static_assert(SDLK_AC_SEARCH == 0x40000118u, "Keycode.acSearch");
_Static_assert(SDLK_AC_HOME == 0x40000119u, "Keycode.acHome");
_Static_assert(SDLK_AC_BACK == 0x4000011au, "Keycode.acBack");
_Static_assert(SDLK_AC_FORWARD == 0x4000011bu, "Keycode.acForward");
_Static_assert(SDLK_AC_STOP == 0x4000011cu, "Keycode.acStop");
_Static_assert(SDLK_AC_REFRESH == 0x4000011du, "Keycode.acRefresh");
_Static_assert(SDLK_AC_BOOKMARKS == 0x4000011eu, "Keycode.acBookmarks");
_Static_assert(SDLK_SOFTLEFT == 0x4000011fu, "Keycode.softLeft");
_Static_assert(SDLK_SOFTRIGHT == 0x40000120u, "Keycode.softRight");
_Static_assert(SDLK_CALL == 0x40000121u, "Keycode.call");
_Static_assert(SDLK_ENDCALL == 0x40000122u, "Keycode.endCall");
_Static_assert(SDLK_LEFT_TAB == 0x20000001u, "Keycode.leftTab");
_Static_assert(SDLK_LEVEL5_SHIFT == 0x20000002u, "Keycode.level5Shift");
_Static_assert(SDLK_MULTI_KEY_COMPOSE == 0x20000003u, "Keycode.multiKeyCompose");
_Static_assert(SDLK_LMETA == 0x20000004u, "Keycode.lMeta");
_Static_assert(SDLK_RMETA == 0x20000005u, "Keycode.rMeta");
_Static_assert(SDLK_LHYPER == 0x20000006u, "Keycode.lHyper");
_Static_assert(SDLK_RHYPER == 0x20000007u, "Keycode.rHyper");
_Static_assert(SDLK_EXTENDED_MASK == 0x20000000u, "Keycode.extendedMask");
_Static_assert(SDLK_SCANCODE_MASK == 0x40000000u, "Keycode.scancodeMask");

/* ---- Sdl/Keycode.lean: Keymod ---- */
_Static_assert(SDL_KMOD_NONE == 0x0000u, "Keymod.none");
_Static_assert(SDL_KMOD_LSHIFT == 0x0001u, "Keymod.lShift");
_Static_assert(SDL_KMOD_RSHIFT == 0x0002u, "Keymod.rShift");
_Static_assert(SDL_KMOD_LEVEL5 == 0x0004u, "Keymod.level5");
_Static_assert(SDL_KMOD_LCTRL == 0x0040u, "Keymod.lCtrl");
_Static_assert(SDL_KMOD_RCTRL == 0x0080u, "Keymod.rCtrl");
_Static_assert(SDL_KMOD_LALT == 0x0100u, "Keymod.lAlt");
_Static_assert(SDL_KMOD_RALT == 0x0200u, "Keymod.rAlt");
_Static_assert(SDL_KMOD_LGUI == 0x0400u, "Keymod.lGui");
_Static_assert(SDL_KMOD_RGUI == 0x0800u, "Keymod.rGui");
_Static_assert(SDL_KMOD_NUM == 0x1000u, "Keymod.num");
_Static_assert(SDL_KMOD_CAPS == 0x2000u, "Keymod.caps");
_Static_assert(SDL_KMOD_MODE == 0x4000u, "Keymod.mode");
_Static_assert(SDL_KMOD_SCROLL == 0x8000u, "Keymod.scroll");
_Static_assert(SDL_KMOD_CTRL == 0x00c0u, "Keymod.ctrl");
_Static_assert(SDL_KMOD_SHIFT == 0x0003u, "Keymod.shift");
_Static_assert(SDL_KMOD_ALT == 0x0300u, "Keymod.alt");
_Static_assert(SDL_KMOD_GUI == 0x0c00u, "Keymod.gui");

/* ---- Sdl/Keyboard.lean: no new enum/flag constants (Scancode/Keycode/Keymod
 * are pinned above; KeyboardId is an open id domain). ---- */

/* ---- Sdl/Mouse.lean: MouseButton (SDL_BUTTON_*) ---- */
_Static_assert(SDL_BUTTON_LEFT   == 1, "MouseButton.left");
_Static_assert(SDL_BUTTON_MIDDLE == 2, "MouseButton.middle");
_Static_assert(SDL_BUTTON_RIGHT  == 3, "MouseButton.right");
_Static_assert(SDL_BUTTON_X1     == 4, "MouseButton.x1");
_Static_assert(SDL_BUTTON_X2     == 5, "MouseButton.x2");

/* ---- Sdl/Mouse.lean: MouseButtonFlags (SDL_BUTTON_*MASK) ---- */
_Static_assert(SDL_BUTTON_LMASK  == 0x1u,  "MouseButtonFlags.left");
_Static_assert(SDL_BUTTON_MMASK  == 0x2u,  "MouseButtonFlags.middle");
_Static_assert(SDL_BUTTON_RMASK  == 0x4u,  "MouseButtonFlags.right");
_Static_assert(SDL_BUTTON_X1MASK == 0x8u,  "MouseButtonFlags.x1");
_Static_assert(SDL_BUTTON_X2MASK == 0x10u, "MouseButtonFlags.x2");

/* ---- Sdl/Mouse.lean: MouseWheelDirection ---- */
_Static_assert((int)SDL_MOUSEWHEEL_NORMAL  == 0, "MouseWheelDirection.normal");
_Static_assert((int)SDL_MOUSEWHEEL_FLIPPED == 1, "MouseWheelDirection.flipped");

/* ---- Sdl/Mouse.lean: SystemCursor (COUNT excluded) ---- */
_Static_assert((int)SDL_SYSTEM_CURSOR_DEFAULT     == 0,  "SystemCursor.default");
_Static_assert((int)SDL_SYSTEM_CURSOR_TEXT        == 1,  "SystemCursor.text");
_Static_assert((int)SDL_SYSTEM_CURSOR_WAIT        == 2,  "SystemCursor.wait");
_Static_assert((int)SDL_SYSTEM_CURSOR_CROSSHAIR   == 3,  "SystemCursor.crosshair");
_Static_assert((int)SDL_SYSTEM_CURSOR_PROGRESS    == 4,  "SystemCursor.progress");
_Static_assert((int)SDL_SYSTEM_CURSOR_NWSE_RESIZE == 5,  "SystemCursor.nwseResize");
_Static_assert((int)SDL_SYSTEM_CURSOR_NESW_RESIZE == 6,  "SystemCursor.neswResize");
_Static_assert((int)SDL_SYSTEM_CURSOR_EW_RESIZE   == 7,  "SystemCursor.ewResize");
_Static_assert((int)SDL_SYSTEM_CURSOR_NS_RESIZE   == 8,  "SystemCursor.nsResize");
_Static_assert((int)SDL_SYSTEM_CURSOR_MOVE        == 9,  "SystemCursor.move");
_Static_assert((int)SDL_SYSTEM_CURSOR_NOT_ALLOWED == 10, "SystemCursor.notAllowed");
_Static_assert((int)SDL_SYSTEM_CURSOR_POINTER     == 11, "SystemCursor.pointer");
_Static_assert((int)SDL_SYSTEM_CURSOR_NW_RESIZE   == 12, "SystemCursor.nwResize");
_Static_assert((int)SDL_SYSTEM_CURSOR_N_RESIZE    == 13, "SystemCursor.nResize");
_Static_assert((int)SDL_SYSTEM_CURSOR_NE_RESIZE   == 14, "SystemCursor.neResize");
_Static_assert((int)SDL_SYSTEM_CURSOR_E_RESIZE    == 15, "SystemCursor.eResize");
_Static_assert((int)SDL_SYSTEM_CURSOR_SE_RESIZE   == 16, "SystemCursor.seResize");
_Static_assert((int)SDL_SYSTEM_CURSOR_S_RESIZE    == 17, "SystemCursor.sResize");
_Static_assert((int)SDL_SYSTEM_CURSOR_SW_RESIZE   == 18, "SystemCursor.swResize");
_Static_assert((int)SDL_SYSTEM_CURSOR_W_RESIZE    == 19, "SystemCursor.wResize");
_Static_assert((int)SDL_SYSTEM_CURSOR_COUNT       == 20, "SystemCursor count");

/* ---- Sdl/Mouse.lean: MouseId virtual-mouse named constants ---- */
_Static_assert((Uint32)SDL_TOUCH_MOUSEID == 0xFFFFFFFFu, "MouseId.touch");
_Static_assert((Uint32)SDL_PEN_MOUSEID   == 0xFFFFFFFEu, "MouseId.pen");

/* ---- Sdl/Touch.lean: TouchDeviceType (INVALID is the -1 error sentinel) ---- */
_Static_assert((int)SDL_TOUCH_DEVICE_INVALID          == -1, "TouchDeviceType.invalid sentinel");
_Static_assert((int)SDL_TOUCH_DEVICE_DIRECT           == 0,  "TouchDeviceType.direct");
_Static_assert((int)SDL_TOUCH_DEVICE_INDIRECT_ABSOLUTE == 1, "TouchDeviceType.indirectAbsolute");
_Static_assert((int)SDL_TOUCH_DEVICE_INDIRECT_RELATIVE == 2, "TouchDeviceType.indirectRelative");

/* ---- Sdl/Touch.lean: TouchId virtual-touch named constants ---- */
_Static_assert((Uint64)SDL_MOUSE_TOUCHID == 0xFFFFFFFFFFFFFFFFull, "TouchId.mouse");
_Static_assert((Uint64)SDL_PEN_TOUCHID   == 0xFFFFFFFFFFFFFFFEull, "TouchId.pen");

/* ---- Sdl/Pen.lean: PenInputFlags ---- */
_Static_assert(SDL_PEN_INPUT_DOWN         == 0x1u,        "PenInputFlags.down");
_Static_assert(SDL_PEN_INPUT_BUTTON_1     == 0x2u,        "PenInputFlags.button1");
_Static_assert(SDL_PEN_INPUT_BUTTON_2     == 0x4u,        "PenInputFlags.button2");
_Static_assert(SDL_PEN_INPUT_BUTTON_3     == 0x8u,        "PenInputFlags.button3");
_Static_assert(SDL_PEN_INPUT_BUTTON_4     == 0x10u,       "PenInputFlags.button4");
_Static_assert(SDL_PEN_INPUT_BUTTON_5     == 0x20u,       "PenInputFlags.button5");
_Static_assert(SDL_PEN_INPUT_ERASER_TIP   == 0x40000000u, "PenInputFlags.eraserTip");
_Static_assert(SDL_PEN_INPUT_IN_PROXIMITY == 0x80000000u, "PenInputFlags.inProximity");

/* ---- Sdl/Pen.lean: PenAxis (version-open; COUNT excluded) ---- */
_Static_assert((int)SDL_PEN_AXIS_PRESSURE            == 0, "PenAxis.pressure");
_Static_assert((int)SDL_PEN_AXIS_XTILT               == 1, "PenAxis.xTilt");
_Static_assert((int)SDL_PEN_AXIS_YTILT               == 2, "PenAxis.yTilt");
_Static_assert((int)SDL_PEN_AXIS_DISTANCE            == 3, "PenAxis.distance");
_Static_assert((int)SDL_PEN_AXIS_ROTATION            == 4, "PenAxis.rotation");
_Static_assert((int)SDL_PEN_AXIS_SLIDER              == 5, "PenAxis.slider");
_Static_assert((int)SDL_PEN_AXIS_TANGENTIAL_PRESSURE == 6, "PenAxis.tangentialPressure");
_Static_assert((int)SDL_PEN_AXIS_COUNT               == 7, "PenAxis count");

/* ---- Sdl/Pen.lean: PenDeviceType (INVALID is the -1 error sentinel) ---- */
_Static_assert((int)SDL_PEN_DEVICE_TYPE_INVALID  == -1, "PenDeviceType.invalid sentinel");
_Static_assert((int)SDL_PEN_DEVICE_TYPE_UNKNOWN  == 0,  "PenDeviceType.unknown");
_Static_assert((int)SDL_PEN_DEVICE_TYPE_DIRECT   == 1,  "PenDeviceType.direct");
_Static_assert((int)SDL_PEN_DEVICE_TYPE_INDIRECT == 2,  "PenDeviceType.indirect");

/* ---- Sdl/Events.lean: EventType (open numeric domain; PRIVATE0..3,
 *      ENUM_PADDING, and the DISPLAY/WINDOW range aliases are excluded from the
 *      Lean side but the aliases are pinned below because the C decode switch
 *      routes the display/window families by range). ---- */
_Static_assert(sizeof(SDL_Event) == 128, "SDL_Event ABI size (events)");
_Static_assert((Uint32)SDL_EVENT_FIRST                      == 0x0,    "EventType.first");
_Static_assert((Uint32)SDL_EVENT_QUIT                       == 0x100,  "EventType.quit");
_Static_assert((Uint32)SDL_EVENT_TERMINATING                == 0x101,  "EventType.terminating");
_Static_assert((Uint32)SDL_EVENT_LOW_MEMORY                 == 0x102,  "EventType.lowMemory");
_Static_assert((Uint32)SDL_EVENT_WILL_ENTER_BACKGROUND      == 0x103,  "EventType.willEnterBackground");
_Static_assert((Uint32)SDL_EVENT_DID_ENTER_BACKGROUND       == 0x104,  "EventType.didEnterBackground");
_Static_assert((Uint32)SDL_EVENT_WILL_ENTER_FOREGROUND      == 0x105,  "EventType.willEnterForeground");
_Static_assert((Uint32)SDL_EVENT_DID_ENTER_FOREGROUND       == 0x106,  "EventType.didEnterForeground");
_Static_assert((Uint32)SDL_EVENT_LOCALE_CHANGED             == 0x107,  "EventType.localeChanged");
_Static_assert((Uint32)SDL_EVENT_SYSTEM_THEME_CHANGED       == 0x108,  "EventType.systemThemeChanged");
_Static_assert((Uint32)SDL_EVENT_DISPLAY_ORIENTATION        == 0x151,  "EventType.displayOrientation");
_Static_assert((Uint32)SDL_EVENT_DISPLAY_ADDED              == 0x152,  "EventType.displayAdded");
_Static_assert((Uint32)SDL_EVENT_DISPLAY_REMOVED            == 0x153,  "EventType.displayRemoved");
_Static_assert((Uint32)SDL_EVENT_DISPLAY_MOVED              == 0x154,  "EventType.displayMoved");
_Static_assert((Uint32)SDL_EVENT_DISPLAY_DESKTOP_MODE_CHANGED  == 0x155, "EventType.displayDesktopModeChanged");
_Static_assert((Uint32)SDL_EVENT_DISPLAY_CURRENT_MODE_CHANGED  == 0x156, "EventType.displayCurrentModeChanged");
_Static_assert((Uint32)SDL_EVENT_DISPLAY_CONTENT_SCALE_CHANGED == 0x157, "EventType.displayContentScaleChanged");
_Static_assert((Uint32)SDL_EVENT_DISPLAY_USABLE_BOUNDS_CHANGED == 0x158, "EventType.displayUsableBoundsChanged");
_Static_assert((Uint32)SDL_EVENT_DISPLAY_FIRST             == 0x151,  "EventType DISPLAY_FIRST alias");
_Static_assert((Uint32)SDL_EVENT_DISPLAY_LAST              == 0x158,  "EventType DISPLAY_LAST alias");
_Static_assert((Uint32)SDL_EVENT_WINDOW_SHOWN              == 0x202,  "EventType.windowShown");
_Static_assert((Uint32)SDL_EVENT_WINDOW_HIDDEN            == 0x203,  "EventType.windowHidden");
_Static_assert((Uint32)SDL_EVENT_WINDOW_EXPOSED          == 0x204,  "EventType.windowExposed");
_Static_assert((Uint32)SDL_EVENT_WINDOW_MOVED            == 0x205,  "EventType.windowMoved");
_Static_assert((Uint32)SDL_EVENT_WINDOW_RESIZED          == 0x206,  "EventType.windowResized");
_Static_assert((Uint32)SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED == 0x207, "EventType.windowPixelSizeChanged");
_Static_assert((Uint32)SDL_EVENT_WINDOW_METAL_VIEW_RESIZED == 0x208, "EventType.windowMetalViewResized");
_Static_assert((Uint32)SDL_EVENT_WINDOW_MINIMIZED        == 0x209,  "EventType.windowMinimized");
_Static_assert((Uint32)SDL_EVENT_WINDOW_MAXIMIZED        == 0x20A,  "EventType.windowMaximized");
_Static_assert((Uint32)SDL_EVENT_WINDOW_RESTORED         == 0x20B,  "EventType.windowRestored");
_Static_assert((Uint32)SDL_EVENT_WINDOW_MOUSE_ENTER      == 0x20C,  "EventType.windowMouseEnter");
_Static_assert((Uint32)SDL_EVENT_WINDOW_MOUSE_LEAVE      == 0x20D,  "EventType.windowMouseLeave");
_Static_assert((Uint32)SDL_EVENT_WINDOW_FOCUS_GAINED     == 0x20E,  "EventType.windowFocusGained");
_Static_assert((Uint32)SDL_EVENT_WINDOW_FOCUS_LOST       == 0x20F,  "EventType.windowFocusLost");
_Static_assert((Uint32)SDL_EVENT_WINDOW_CLOSE_REQUESTED  == 0x210,  "EventType.windowCloseRequested");
_Static_assert((Uint32)SDL_EVENT_WINDOW_HIT_TEST         == 0x211,  "EventType.windowHitTest");
_Static_assert((Uint32)SDL_EVENT_WINDOW_ICCPROF_CHANGED  == 0x212,  "EventType.windowIccprofChanged");
_Static_assert((Uint32)SDL_EVENT_WINDOW_DISPLAY_CHANGED  == 0x213,  "EventType.windowDisplayChanged");
_Static_assert((Uint32)SDL_EVENT_WINDOW_DISPLAY_SCALE_CHANGED == 0x214, "EventType.windowDisplayScaleChanged");
_Static_assert((Uint32)SDL_EVENT_WINDOW_SAFE_AREA_CHANGED == 0x215, "EventType.windowSafeAreaChanged");
_Static_assert((Uint32)SDL_EVENT_WINDOW_OCCLUDED         == 0x216,  "EventType.windowOccluded");
_Static_assert((Uint32)SDL_EVENT_WINDOW_ENTER_FULLSCREEN == 0x217,  "EventType.windowEnterFullscreen");
_Static_assert((Uint32)SDL_EVENT_WINDOW_LEAVE_FULLSCREEN == 0x218,  "EventType.windowLeaveFullscreen");
_Static_assert((Uint32)SDL_EVENT_WINDOW_DESTROYED        == 0x219,  "EventType.windowDestroyed");
_Static_assert((Uint32)SDL_EVENT_WINDOW_HDR_STATE_CHANGED == 0x21A, "EventType.windowHdrStateChanged");
_Static_assert((Uint32)SDL_EVENT_WINDOW_FIRST             == 0x202,  "EventType WINDOW_FIRST alias");
_Static_assert((Uint32)SDL_EVENT_WINDOW_LAST              == 0x21A,  "EventType WINDOW_LAST alias");
_Static_assert((Uint32)SDL_EVENT_KEY_DOWN                == 0x300,  "EventType.keyDown");
_Static_assert((Uint32)SDL_EVENT_KEY_UP                  == 0x301,  "EventType.keyUp");
_Static_assert((Uint32)SDL_EVENT_TEXT_EDITING            == 0x302,  "EventType.textEditing");
_Static_assert((Uint32)SDL_EVENT_TEXT_INPUT              == 0x303,  "EventType.textInput");
_Static_assert((Uint32)SDL_EVENT_KEYMAP_CHANGED          == 0x304,  "EventType.keymapChanged");
_Static_assert((Uint32)SDL_EVENT_KEYBOARD_ADDED          == 0x305,  "EventType.keyboardAdded");
_Static_assert((Uint32)SDL_EVENT_KEYBOARD_REMOVED        == 0x306,  "EventType.keyboardRemoved");
_Static_assert((Uint32)SDL_EVENT_TEXT_EDITING_CANDIDATES == 0x307,  "EventType.textEditingCandidates");
_Static_assert((Uint32)SDL_EVENT_SCREEN_KEYBOARD_SHOWN   == 0x308,  "EventType.screenKeyboardShown");
_Static_assert((Uint32)SDL_EVENT_SCREEN_KEYBOARD_HIDDEN  == 0x309,  "EventType.screenKeyboardHidden");
_Static_assert((Uint32)SDL_EVENT_MOUSE_MOTION            == 0x400,  "EventType.mouseMotion");
_Static_assert((Uint32)SDL_EVENT_MOUSE_BUTTON_DOWN       == 0x401,  "EventType.mouseButtonDown");
_Static_assert((Uint32)SDL_EVENT_MOUSE_BUTTON_UP         == 0x402,  "EventType.mouseButtonUp");
_Static_assert((Uint32)SDL_EVENT_MOUSE_WHEEL             == 0x403,  "EventType.mouseWheel");
_Static_assert((Uint32)SDL_EVENT_MOUSE_ADDED             == 0x404,  "EventType.mouseAdded");
_Static_assert((Uint32)SDL_EVENT_MOUSE_REMOVED           == 0x405,  "EventType.mouseRemoved");
_Static_assert((Uint32)SDL_EVENT_JOYSTICK_AXIS_MOTION    == 0x600,  "EventType.joystickAxisMotion");
_Static_assert((Uint32)SDL_EVENT_JOYSTICK_BALL_MOTION    == 0x601,  "EventType.joystickBallMotion");
_Static_assert((Uint32)SDL_EVENT_JOYSTICK_HAT_MOTION     == 0x602,  "EventType.joystickHatMotion");
_Static_assert((Uint32)SDL_EVENT_JOYSTICK_BUTTON_DOWN    == 0x603,  "EventType.joystickButtonDown");
_Static_assert((Uint32)SDL_EVENT_JOYSTICK_BUTTON_UP      == 0x604,  "EventType.joystickButtonUp");
_Static_assert((Uint32)SDL_EVENT_JOYSTICK_ADDED          == 0x605,  "EventType.joystickAdded");
_Static_assert((Uint32)SDL_EVENT_JOYSTICK_REMOVED        == 0x606,  "EventType.joystickRemoved");
_Static_assert((Uint32)SDL_EVENT_JOYSTICK_BATTERY_UPDATED == 0x607, "EventType.joystickBatteryUpdated");
_Static_assert((Uint32)SDL_EVENT_JOYSTICK_UPDATE_COMPLETE == 0x608, "EventType.joystickUpdateComplete");
_Static_assert((Uint32)SDL_EVENT_GAMEPAD_AXIS_MOTION     == 0x650,  "EventType.gamepadAxisMotion");
_Static_assert((Uint32)SDL_EVENT_GAMEPAD_BUTTON_DOWN     == 0x651,  "EventType.gamepadButtonDown");
_Static_assert((Uint32)SDL_EVENT_GAMEPAD_BUTTON_UP       == 0x652,  "EventType.gamepadButtonUp");
_Static_assert((Uint32)SDL_EVENT_GAMEPAD_ADDED           == 0x653,  "EventType.gamepadAdded");
_Static_assert((Uint32)SDL_EVENT_GAMEPAD_REMOVED         == 0x654,  "EventType.gamepadRemoved");
_Static_assert((Uint32)SDL_EVENT_GAMEPAD_REMAPPED        == 0x655,  "EventType.gamepadRemapped");
_Static_assert((Uint32)SDL_EVENT_GAMEPAD_TOUCHPAD_DOWN   == 0x656,  "EventType.gamepadTouchpadDown");
_Static_assert((Uint32)SDL_EVENT_GAMEPAD_TOUCHPAD_MOTION == 0x657,  "EventType.gamepadTouchpadMotion");
_Static_assert((Uint32)SDL_EVENT_GAMEPAD_TOUCHPAD_UP     == 0x658,  "EventType.gamepadTouchpadUp");
_Static_assert((Uint32)SDL_EVENT_GAMEPAD_SENSOR_UPDATE   == 0x659,  "EventType.gamepadSensorUpdate");
_Static_assert((Uint32)SDL_EVENT_GAMEPAD_UPDATE_COMPLETE == 0x65A,  "EventType.gamepadUpdateComplete");
_Static_assert((Uint32)SDL_EVENT_GAMEPAD_STEAM_HANDLE_UPDATED == 0x65B, "EventType.gamepadSteamHandleUpdated");
_Static_assert((Uint32)SDL_EVENT_FINGER_DOWN             == 0x700,  "EventType.fingerDown");
_Static_assert((Uint32)SDL_EVENT_FINGER_UP               == 0x701,  "EventType.fingerUp");
_Static_assert((Uint32)SDL_EVENT_FINGER_MOTION           == 0x702,  "EventType.fingerMotion");
_Static_assert((Uint32)SDL_EVENT_FINGER_CANCELED         == 0x703,  "EventType.fingerCanceled");
_Static_assert((Uint32)SDL_EVENT_PINCH_BEGIN             == 0x710,  "EventType.pinchBegin");
_Static_assert((Uint32)SDL_EVENT_PINCH_UPDATE            == 0x711,  "EventType.pinchUpdate");
_Static_assert((Uint32)SDL_EVENT_PINCH_END               == 0x712,  "EventType.pinchEnd");
_Static_assert((Uint32)SDL_EVENT_CLIPBOARD_UPDATE        == 0x900,  "EventType.clipboardUpdate");
_Static_assert((Uint32)SDL_EVENT_DROP_FILE               == 0x1000, "EventType.dropFile");
_Static_assert((Uint32)SDL_EVENT_DROP_TEXT               == 0x1001, "EventType.dropText");
_Static_assert((Uint32)SDL_EVENT_DROP_BEGIN              == 0x1002, "EventType.dropBegin");
_Static_assert((Uint32)SDL_EVENT_DROP_COMPLETE           == 0x1003, "EventType.dropComplete");
_Static_assert((Uint32)SDL_EVENT_DROP_POSITION           == 0x1004, "EventType.dropPosition");
_Static_assert((Uint32)SDL_EVENT_AUDIO_DEVICE_ADDED      == 0x1100, "EventType.audioDeviceAdded");
_Static_assert((Uint32)SDL_EVENT_AUDIO_DEVICE_REMOVED    == 0x1101, "EventType.audioDeviceRemoved");
_Static_assert((Uint32)SDL_EVENT_AUDIO_DEVICE_FORMAT_CHANGED == 0x1102, "EventType.audioDeviceFormatChanged");
_Static_assert((Uint32)SDL_EVENT_SENSOR_UPDATE           == 0x1200, "EventType.sensorUpdate");
_Static_assert((Uint32)SDL_EVENT_PEN_PROXIMITY_IN        == 0x1300, "EventType.penProximityIn");
_Static_assert((Uint32)SDL_EVENT_PEN_PROXIMITY_OUT       == 0x1301, "EventType.penProximityOut");
_Static_assert((Uint32)SDL_EVENT_PEN_DOWN                == 0x1302, "EventType.penDown");
_Static_assert((Uint32)SDL_EVENT_PEN_UP                  == 0x1303, "EventType.penUp");
_Static_assert((Uint32)SDL_EVENT_PEN_BUTTON_DOWN         == 0x1304, "EventType.penButtonDown");
_Static_assert((Uint32)SDL_EVENT_PEN_BUTTON_UP           == 0x1305, "EventType.penButtonUp");
_Static_assert((Uint32)SDL_EVENT_PEN_MOTION              == 0x1306, "EventType.penMotion");
_Static_assert((Uint32)SDL_EVENT_PEN_AXIS                == 0x1307, "EventType.penAxis");
_Static_assert((Uint32)SDL_EVENT_CAMERA_DEVICE_ADDED     == 0x1400, "EventType.cameraDeviceAdded");
_Static_assert((Uint32)SDL_EVENT_CAMERA_DEVICE_REMOVED   == 0x1401, "EventType.cameraDeviceRemoved");
_Static_assert((Uint32)SDL_EVENT_CAMERA_DEVICE_APPROVED  == 0x1402, "EventType.cameraDeviceApproved");
_Static_assert((Uint32)SDL_EVENT_CAMERA_DEVICE_DENIED    == 0x1403, "EventType.cameraDeviceDenied");
_Static_assert((Uint32)SDL_EVENT_RENDER_TARGETS_RESET    == 0x2000, "EventType.renderTargetsReset");
_Static_assert((Uint32)SDL_EVENT_RENDER_DEVICE_RESET     == 0x2001, "EventType.renderDeviceReset");
_Static_assert((Uint32)SDL_EVENT_RENDER_DEVICE_LOST      == 0x2002, "EventType.renderDeviceLost");
_Static_assert((Uint32)SDL_EVENT_POLL_SENTINEL           == 0x7F00, "EventType.pollSentinel");
_Static_assert((Uint32)SDL_EVENT_USER                    == 0x8000, "EventType.user");
_Static_assert((Uint32)SDL_EVENT_LAST                    == 0xFFFF, "EventType.last");

/* ==== Sdl/Filesystem.lean : EnumerationResult ==== */
_Static_assert((Uint32)SDL_ENUM_CONTINUE == 0, "EnumerationResult.continue");
_Static_assert((Uint32)SDL_ENUM_SUCCESS  == 1, "EnumerationResult.success");
_Static_assert((Uint32)SDL_ENUM_FAILURE  == 2, "EnumerationResult.failure");

/* ==== Sdl/Dialog.lean : FileDialogType ==== */
_Static_assert((Uint32)SDL_FILEDIALOG_OPENFILE   == 0, "FileDialogType.openFile");
_Static_assert((Uint32)SDL_FILEDIALOG_SAVEFILE   == 1, "FileDialogType.saveFile");
_Static_assert((Uint32)SDL_FILEDIALOG_OPENFOLDER == 2, "FileDialogType.openFolder");

/* ==== Sdl/Video.lean : HitTestResult ==== */
_Static_assert((Uint32)SDL_HITTEST_NORMAL             == 0, "HitTestResult.normal");
_Static_assert((Uint32)SDL_HITTEST_DRAGGABLE          == 1, "HitTestResult.draggable");
_Static_assert((Uint32)SDL_HITTEST_RESIZE_TOPLEFT     == 2, "HitTestResult.resizeTopLeft");
_Static_assert((Uint32)SDL_HITTEST_RESIZE_TOP         == 3, "HitTestResult.resizeTop");
_Static_assert((Uint32)SDL_HITTEST_RESIZE_TOPRIGHT    == 4, "HitTestResult.resizeTopRight");
_Static_assert((Uint32)SDL_HITTEST_RESIZE_RIGHT       == 5, "HitTestResult.resizeRight");
_Static_assert((Uint32)SDL_HITTEST_RESIZE_BOTTOMRIGHT == 6, "HitTestResult.resizeBottomRight");
_Static_assert((Uint32)SDL_HITTEST_RESIZE_BOTTOM      == 7, "HitTestResult.resizeBottom");
_Static_assert((Uint32)SDL_HITTEST_RESIZE_BOTTOMLEFT  == 8, "HitTestResult.resizeBottomLeft");
_Static_assert((Uint32)SDL_HITTEST_RESIZE_LEFT        == 9, "HitTestResult.resizeLeft");
