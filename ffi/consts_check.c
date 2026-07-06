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

