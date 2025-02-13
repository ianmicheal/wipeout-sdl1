CC ?= gcc
EMCC ?= emcc
#UNAME_S := AmigaOS-gcc4
UNAME_S := Msys
UNAME_O := $(shell uname -o)
#RENDERER = SOFTWARE
RENDERER = GL_LEGACY
USE_GLX ?= false
DEBUG ?= true
USER_CFLAGS ?= -D__MORPHOS__

L_FLAGS ?= -lm
C_FLAGS ?= -std=gnu99 -Wall -Wno-unused-variable -Isrc $(USER_CFLAGS)

ifeq ($(DEBUG), true)
	C_FLAGS := $(C_FLAGS) -g
else
	C_FLAGS := $(C_FLAGS) -O3
endif


# Rendeder ---------------------------------------------------------------------

ifeq ($(RENDERER), GL)
	RENDERER_SRC = src/render_gl.c
	C_FLAGS := $(C_FLAGS) -DRENDERER_GL
else ifeq ($(RENDERER), GL_LEGACY)
	RENDERER_SRC = src/render_gl_legacy.c
	C_FLAGS := $(C_FLAGS) -DRENDERER_GL_LEGACY
else ifeq ($(RENDERER), SOFTWARE)
	RENDERER_SRC = src/render_software.c
	C_FLAGS := $(C_FLAGS) -DRENDERER_SOFTWARE
else
$(error Unknown RENDERER)
endif

ifeq ($(GL_VERSION), GLES2)
	C_FLAGS := $(C_FLAGS) -DUSE_GLES2
endif


# MorphOS ------------------------------------------------------------------------

ifeq ($(UNAME_S), MorphOS)
	C_FLAGS := $(C_FLAGS)  -noixemul
	C_FLAGS := $(C_FLAGS) -I/usr/local/include
	L_FLAGS := $(L_FLAGS) -L/usr/local/lib
	L_FLAGS_SDL = -noixemul -lSDL -lGL  -lm -lc
	CC = ppc-morphos-gcc-9
# MorphOS ------------------------------------------------------------------------

else ifeq ($(UNAME_S), AmigaOS)
	C_FLAGS := $(C_FLAGS)  -noixemul  -O3 -m68040 -mhard-float
	C_FLAGS += $(C_FLAGS) -I/mnt/d/amiga-gcc/include -Isrc -Isrc/wipeout/ -Isrc/libs
	L_FLAGS_SDL =  -L/mnt/d/amiga-gcc2/lib/ -lSDL-gl -lGL  -lm  -noixemul 
	CC = m68k-amigaos-gcc
# AmigaOS ------------------------------------------------------------------------
else ifeq ($(UNAME_S), AmigaOS-gcc4)
	#PATH=/dev/msys64/usr/local/amiga
	C_FLAGS := $(C_FLAGS)  -O3 -m68040 -mhard-float
	C_FLAGS += $(C_FLAGS) -I/dev/msys64/usr/local/amiga/m68k-amigaos/include/ -Isrc -Isrc/wipeout/ -Isrc/libs
	ifeq ($(RENDERER), GL_LEGACY)
		C_FLAGS += -DRENDERER_GL
		L_FLAGS_SDL = -L/dev/msys64/usr/local/amiga/m68k-amigaos/lib -lSDL.ix -lGL  -lm -ldebug
		TARGET_NATIVE = wipegame-gcc4-gl
	else
		L_FLAGS_SDL = -L/dev/msys64/usr/local/amiga/m68k-amigaos/lib -lSDL -lm040 -ldebug -noixemul
		TARGET_NATIVE = wipegame-gcc4
	endif	
	CC = /e/usr/local/amiga/bin/m68k-amigaos-gcc-4.exe --sysroot=e:/usr/local/amiga/bin
# AmigaOS ------------------------------------------------------------------------

else ifeq ($(UNAME_S), AmigaOS-wsl-gcc4)
	#PATH=/dev/msys64/usr/local/amiga
	C_FLAGS := $(C_FLAGS)  -O3 -m68040 
	C_FLAGS += $(C_FLAGS) -I/dev/msys64/usr/local/amiga/m68k-amigaos/include/ -Isrc -Isrc/wipeout/ -Isrc/libs
	ifeq ($(RENDERER), GL_LEGACY)
		C_FLAGS += -DRENDERER_GL
		L_FLAGS_SDL = -L/dev/msys64/usr/local/amiga/m68k-amigaos/lib -lSDL_gl -lGL  -lm -ldebug
		TARGET_NATIVE = wipegame-gcc4-gl
	else
		L_FLAGS_SDL = -L/dev/msys64/usr/local/amiga/m68k-amigaos/lib -lSDL -lm040 -ldebug -noixemul
		TARGET_NATIVE = wipegame-gcc4
	endif	
	CC = /mnt/e/usr/local/amiga/bin/m68k-amigaos-gcc-4.exe --sysroot=e:/usr/local/amiga/bin
# AmigaOS ------------------------------------------------------------------------

else ifeq ($(UNAME_S), Darwin)
	C_FLAGS := $(C_FLAGS) -x objective-c -I/opt/homebrew/include -D_THREAD_SAFE -w
	L_FLAGS := $(L_FLAGS) -L/opt/homebrew/lib -framework Foundation

	ifeq ($(RENDERER), GL)
		L_FLAGS := $(L_FLAGS) -lGLEW -GLU -framework OpenGL
	endif

	L_FLAGS_SDL = -lSDL2
	L_FLAGS_SOKOL = -framework Cocoa -framework QuartzCore -framework AudioToolbox


# Linux ------------------------------------------------------------------------

else ifeq ($(UNAME_S), Linux)
	ifeq ($(RENDERER), GL)
		L_FLAGS := $(L_FLAGS) -lGLEW

		# Prefer modern GLVND instead of legacy X11-only GLX
		ifeq ($(USE_GLX), true)
			L_FLAGS := $(L_FLAGS) -lGL
		else
			L_FLAGS := $(L_FLAGS) -lOpenGL
		endif
	endif

	L_FLAGS_SDL = -lSDL2 -lGL
	L_FLAGS_SOKOL = -lX11 -lXcursor -pthread -lXi -ldl -lasound


# Windows MSYS ------------------------------------------------------------------
else ifeq ($(UNAME_O), Msys)
	ifeq ($(GL_LEGACY), RENDERER)
		L_FLAGS := $(L_FLAGS) -lopengl32
	endif
#-lglew32 
	C_FLAGS := $(C_FLAGS) -DSDL_MAIN_HANDLED -D__MSYS__ -Isrc -Isrc/wipeout/ -Isrc/libs
	L_FLAGS_SDL = -lSDL -lopengl32
	L_FLAGS_SOKOL = --pthread -ldl -lasound
	CC = /d/dev/msys64/mingw64/bin/gcc

# Windows NON-MSYS ---------------------------------------------------------------
else ifeq ($(OS), Windows_NT)
	$(error TODO: FLAGS for windows have not been set up. Please modify this makefile and send a PR!)

else
$(error Unknown environment)
endif



# Source files -----------------------------------------------------------------

TARGET_NATIVE ?= wipegame
BUILD_DIR = build/obj/native
BUILD_DIR_WASM = build/obj/wasm

WASM_RELEASE_DIR ?= build/wasm
TARGET_WASM ?= $(WASM_RELEASE_DIR)/wipeout.js
TARGET_WASM_MINIMAL ?= $(WASM_RELEASE_DIR)/wipeout-minimal.js

COMMON_SRC = \
	src/wipeout/race.c \
	src/wipeout/camera.c \
	src/wipeout/object.c \
	src/wipeout/droid.c \
	src/wipeout/ui.c \
	src/wipeout/hud.c \
	src/wipeout/image.c \
	src/wipeout/game.c \
	src/wipeout/menu.c \
	src/wipeout/main_menu.c \
	src/wipeout/ingame_menus.c \
	src/wipeout/title.c \
	src/wipeout/intro.c \
	src/wipeout/scene.c \
	src/wipeout/ship.c \
	src/wipeout/ship_ai.c \
	src/wipeout/ship_player.c \
	src/wipeout/track.c \
	src/wipeout/weapon.c \
	src/wipeout/particle.c \
	src/wipeout/sfx.c \
	src/utils.c \
	src/types.c \
	src/system.c \
	src/mem.c \
	src/input.c \
	$(RENDERER_SRC)


# Targets native ---------------------------------------------------------------

COMMON_OBJ = $(patsubst %.c, $(BUILD_DIR)/%.o, $(COMMON_SRC))
COMMON_DEPS = $(patsubst %.c, $(BUILD_DIR)/%.d, $(COMMON_SRC))

sdl: $(BUILD_DIR)/src/platform_sdl.o
sdl: $(COMMON_OBJ)
	$(CC) $^ -o $(TARGET_NATIVE) $(L_FLAGS) $(L_FLAGS_SDL)

sokol: $(BUILD_DIR)/src/platform_sokol.o
sokol: $(COMMON_OBJ)
	$(CC) $^ -o $(TARGET_NATIVE) $(L_FLAGS) $(L_FLAGS_SOKOL)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(BUILD_DIR)/%.o: %.c
	mkdir -p $(dir $@)
	$(CC) $(C_FLAGS) -MMD -MP -c $< -o $@

-include $(COMMON_DEPS)


# Targets wasm -----------------------------------------------------------------

COMMON_OBJ_WASM = $(patsubst %.c, $(BUILD_DIR_WASM)/%.o, $(COMMON_SRC))
COMMON_DEPS_WASM = $(patsubst %.c, $(BUILD_DIR_WASM)/%.d, $(COMMON_SRC))

wasm: wasm_full wasm_minimal
	cp src/wasm-index.html $(WASM_RELEASE_DIR)/game.html


wasm_full: $(BUILD_DIR_WASM)/src/platform_sokol.o
wasm_full: $(COMMON_OBJ_WASM)
	mkdir -p $(WASM_RELEASE_DIR)
	$(EMCC) $^ -o $(TARGET_WASM) -lGLEW -lGL \
		-s ALLOW_MEMORY_GROWTH=1 \
		-s ENVIRONMENT=web \
		--preload-file wipeout

wasm_minimal: $(BUILD_DIR_WASM)/src/platform_sokol.o
wasm_minimal: $(COMMON_OBJ_WASM)
	mkdir -p $(WASM_RELEASE_DIR)
	$(EMCC) $^ -o $(TARGET_WASM_MINIMAL) -lGLEW -lGL \
		-s ALLOW_MEMORY_GROWTH=1 \
		-s ENVIRONMENT=web \
		--preload-file wipeout \
		--exclude-file wipeout/music \
		--exclude-file wipeout/intro.mpeg

$(BUILD_DIR_WASM):
	mkdir -p $(BUILD_DIR_WASM)

$(BUILD_DIR_WASM)/%.o: %.c
	mkdir -p $(dir $@)
	$(EMCC) $(C_FLAGS) -MMD -MP -c $< -o $@

-include $(COMMON_DEPS_WASM)




.PHONY: clean
clean:
	$(RM) -rf $(BUILD_DIR) $(BUILD_DIR_WASM) $(WASM_RELEASE_DIR)
