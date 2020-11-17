CMAKE_FLAGS+= -H. -Bbuild

ifdef CMAKE_BUILD_TYPE
	CMAKE_BUILD_TYPE := Release
endif

ifndef GENERATOR
	GENERATOR :="Unix Makefiles"
endif

ifeq ($(OS),Linux)
ifeq ($(ARCH),aarch64)
	CMAKE_EXTRA_OPTIONS+= -DHOST_COMPILER=gcc -DHOST_LINKER=ld
endif
endif

ifdef GENERATOR
	CMAKE_FLAGS+= -G${GENERATOR}
endif

CMAKE_FLAGS+= -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}


ifdef LUA_ENGINE
	CMAKE_EXTRA_OPTIONS+= -DLUA_ENGINE=${LUA_ENGINE}
ifeq (${LUA_ENGINE}, LuaJIT)
ifdef LUAJIT_BUILD_ALAMG
	CMAKE_FLAGS+= -DLUAJIT_BUILD_ALAMG=ON
else
	CMAKE_FLAGS+= -DLUAJIT_BUILD_ALAMG=OFF
endif
endif
endif

ifdef CMAKE_TOOLCHAIN_FILE
	CMAKE_EXTRA_OPTIONS += CMAKE_TOOLCHAIN_FILE=${CMAKE_TOOLCHAIN_FILE}
endif

PLATFORM	?= OS
ifeq (${PLATFORM},OS)
	ARCHS	?= armv7
	USE_64BITS      =OFF
	JIT := 1
endif
ifeq (${PLATFORM},OS64)
	ARCHS	?= arm64
	USE_64BITS      =ON
	JIT := 1
endif
ifeq (${PLATFORM},SIMULATOR)
	ARCHS	?= i386
	USE_64BITS      =OFF
endif
ifeq (${PLATFORM},SIMULATOR64)
	ARCHS	?= x86_64
	USE_64BITS      =ON
endif

.PHONY: build lua luajit Android Windows

##############################################################################
all: build
	${MAKE} -C build ${MAKE_EXTRA_OPTIONS}

build:
	echo build for $(OS) arch $(ARCH)
	echo cmake $(CMAKE_FLAGS) $(CMAKE_EXTRA_OPTIONS)
	USE_64BITS=${USE_64BITS} cmake $(CMAKE_FLAGS) $(CMAKE_EXTRA_OPTIONS)

lua:
	cmake $(CMAKE_FLAGS) $(CMAKE_EXTRA_OPTIONS) -DLUA_ENGINE=Lua
	${MAKE} -C build ${MAKE_EXTRA_OPTIONS}

luajit:
	cmake $(CMAKE_FLAGS) $(CMAKE_EXTRA_OPTIONS) -DLUA_ENGINE=LuaJIT
	${MAKE} -C build ${MAKE_EXTRA_OPTIONS}

Android:
	cmake $(CMAKE_FLAGS) $(CMAKE_EXTRA_OPTIONS) -DLUAJIT_BUILD_ALAMG=ON \
	-DCMAKE_TOOLCHAIN_FILE=${ANDROID_NDK}/build/cmake/android.toolchain.cmake \
	-DCMAKE_SYSTEM_NAME=Android -DCMAKE_SYSTEM_VERSION=19 \
	-DCMAKE_ANDROID_NDK=${ANDROID_NDK}
	cmake --build build --config Release

iOSWithLua:
	cmake $(CMAKE_FLAGS) $(CMAKE_EXTRA_OPTIONS) -DLUA_ENGINE=Lua \
	-DCMAKE_TOOLCHAIN_FILE=cmake/Utils/ios.toolchain.cmake \
	-DPLATFORM=${PLATFORM} -DARCHS=$(ARCHS)
	cmake --build build --config Release

iOS:
	USE_64BITS=${USE_64BITS} cmake $(CMAKE_FLAGS) $(CMAKE_EXTRA_OPTIONS) -DLUA_ENGINE=LuaJIT \
	-DCMAKE_TOOLCHAIN_FILE=cmake/Utils/ios.toolchain.cmake  \
	-DPLATFORM=${PLATFORM} -DARCHS=$(ARCHS) -DLUAJIT_DISABLE_JIT=1
	USE_64BITS=${USE_64BITS} cmake --build build --config Release

Windows:
	cmake $(CMAKE_FLAGS) $(CMAKE_EXTRA_OPTIONS) \
	-DCMAKE_TOOLCHAIN_FILE=cmake/Utils/Windows.toolchain.cmake
	cmake --build build --config Release

x86_64-linux-gnu:
	cmake $(CMAKE_FLAGS) -DTARGET_SYS=x86_64-linux-gnu $(CMAKE_EXTRA_OPTIONS) \
	-DCMAKE_TOOLCHAIN_FILE=cmake/Utils/zig.toolchain.cmake
	cmake --build build --config Release

aarch64-linux-gnu:
	cmake $(CMAKE_FLAGS) -DTARGET_SYS=aarch64-linux-gnu $(CMAKE_EXTRA_OPTIONS) \
	-DCMAKE_TOOLCHAIN_FILE=cmake/Utils/zig.toolchain.cmake
	cmake --build build --config Release

x86_64-windows-gnu:
	cmake $(CMAKE_FLAGS) -DTARGET_SYS=x86_64-windows-gnu $(CMAKE_EXTRA_OPTIONS) \
	-DCMAKE_TOOLCHAIN_FILE=cmake/Utils/zig.toolchain.cmake
	cmake --build build --config Release


##############################################################################
clean:
	@cmake -E remove_directory build
