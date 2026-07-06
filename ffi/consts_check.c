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
