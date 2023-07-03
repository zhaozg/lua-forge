CMAKE_FLAGS+= -H. -Bbuild

ifndef CMAKE_BUILD_TYPE
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
else
ifdef WITH_LIBFFI
	CMAKE_FLAGS+= -DWITH_LIBFFI=ON
endif
endif
endif

ifdef CMAKE_TOOLCHAIN_FILE
	CMAKE_EXTRA_OPTIONS += -DCMAKE_TOOLCHAIN_FILE=${CMAKE_TOOLCHAIN_FILE}
endif

PLATFORM	?= OS
USE_64BITS      ?= ON
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

.PHONY: build lua luajit Windows

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
	-DCMAKE_SYSTEM_NAME=Android -DANDROID_NATIVE_API_LEVEL=21 \
	-DCMAKE_ANDROID_NDK=${ANDROID_NDK} -DANDROID_ABI=armeabi-v7a
	cmake --build build --config Release

Android64:
	cmake $(CMAKE_FLAGS) $(CMAKE_EXTRA_OPTIONS) -DLUAJIT_BUILD_ALAMG=ON \
	-DCMAKE_TOOLCHAIN_FILE=${ANDROID_NDK}/build/cmake/android.toolchain.cmake \
	-DCMAKE_SYSTEM_NAME=Android -DANDROID_NATIVE_API_LEVEL=21 \
	-DCMAKE_ANDROID_NDK=${ANDROID_NDK} -DANDROID_ABI=arm64-v8a
	cmake --build build --config Release

iOS:
	USE_64BITS=${USE_64BITS} cmake $(CMAKE_FLAGS) $(CMAKE_EXTRA_OPTIONS) \
	-DCMAKE_TOOLCHAIN_FILE=$(shell pwd)/cmake/Utils/ios.toolchain.cmake  \
	-DPLATFORM=${PLATFORM} -DARCHS=$(ARCHS) -DLUAJIT_DISABLE_JIT=1
	USE_64BITS=${USE_64BITS} cmake --build build --config Release

Windows:
	cmake $(CMAKE_FLAGS) $(CMAKE_EXTRA_OPTIONS) \
	-DCMAKE_TOOLCHAIN_FILE=$(shell pwd)/cmake/Utils/Windows.toolchain.cmake
	cmake --build build --config Release

x86_64-linux-gnu:
	cmake $(CMAKE_FLAGS) -DTARGET_SYS=x86_64-linux-gnu $(CMAKE_EXTRA_OPTIONS) \
	-DCMAKE_TOOLCHAIN_FILE=$(shell pwd)/cmake/Utils/zig.toolchain.cmake
	cmake --build build --config Release

aarch64-linux-gnu:
	cmake $(CMAKE_FLAGS) -DTARGET_SYS=aarch64-linux-gnu $(CMAKE_EXTRA_OPTIONS) \
	-DCMAKE_TOOLCHAIN_FILE=$(shell pwd)/cmake/Utils/zig.toolchain.cmake
	cmake --build build --config Release

mips64el-linux-gnuabi64:
	cmake $(CMAKE_FLAGS) -DTARGET_SYS=mips64el-linux-gnuabi64 $(CMAKE_EXTRA_OPTIONS) \
	-DCMAKE_TOOLCHAIN_FILE=$(shell pwd)/cmake/Utils/zig.toolchain.cmake
	cmake --build build --config Release

x86_64-windows-gnu:
	cmake $(CMAKE_FLAGS) -DTARGET_SYS=x86_64-windows-gnu $(CMAKE_EXTRA_OPTIONS) \
	-DCMAKE_TOOLCHAIN_FILE=$(shell pwd)/cmake/Utils/zig.toolchain.cmake
	cmake --build build --config Release

i386-windows-gnu:
	cmake $(CMAKE_FLAGS) -DTARGET_SYS=i386-windows-gnu $(CMAKE_EXTRA_OPTIONS) \
	-DCMAKE_TOOLCHAIN_FILE=$(shell pwd)/cmake/Utils/zig.toolchain.cmake
	cmake --build build --config Release

x86_64-macos-gnu:
	cmake $(CMAKE_FLAGS) -DTARGET_SYS=x86_64-macos-gnu $(CMAKE_EXTRA_OPTIONS) \
	-DCMAKE_TOOLCHAIN_FILE=$(shell pwd)/cmake/Utils/zig.toolchain.cmake
	cmake --build build --config Release

native:
	cmake $(CMAKE_FLAGS) -DTARGET_SYS=native $(CMAKE_EXTRA_OPTIONS) \
	-DCMAKE_TOOLCHAIN_FILE=$(shell pwd)/cmake/Utils/zig.toolchain.cmake
	cmake --build build --config Release

##############################################################################
clean:
	@cmake -E remove_directory build
