CMAKE_FLAGS+= -H. -Bbuild

ifdef CMAKE_BUILD_TYPE
	CMAKE_BUILD_TYPE := Release
endif

ifndef GENERATOR
	GENERATOR :="Unix Makefiles"
endif

ifndef LUA_ENGINE
	LUA_ENGINE := LuaJIT
endif

ifeq ($(OS),Linux)
ifeq ($(ARCH),aarch64)
	CMAKE_EXTRA_OPTIONS+= -DHOST_COMPILER=gcc -DHOST_LINKER=ld
endif
endif


ifeq ($(OS),iOS)
ifeq (${LUA_ENGINE}, Lua)
	CMAKE_EXTRA_OPTIONS+=-DCMAKE_TOOLCHAIN_FILE=etc/ios.toolchain.cmake -DIOS_PLATFORM=OS
else
	CMAKE_EXTRA_OPTIONS+=-DCMAKE_TOOLCHAIN_FILE=etc/ios.toolchain.cmake -DIOS_PLATFORM=OS \
-DIOS_ARCH="armv7" -DLUAJIT_DISABLE_JIT=1 -DASM_FLAGS="-arch armv7 -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk"
endif
endif

ifdef GENERATOR
	CMAKE_FLAGS+= -G${GENERATOR}
endif

CMAKE_FLAGS+= -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}

ifdef LUAJIT_BUILD_ALAMG
	CMAKE_FLAGS+= -DLUAJIT_BUILD_ALAMG=ON
else
	CMAKE_FLAGS+= -DLUAJIT_BUILD_ALAMG=OFF
endif

CMAKE_EXTRA_OPTIONS+= -DLUA_ENGINE=${LUA_ENGINE}

ifdef CMAKE_TOOLCHAIN_FILE
	CMAKE_EXTRA_OPTIONS += CMAKE_TOOLCHAIN_FILE=${CMAKE_TOOLCHAIN_FILE}
endif
IOS_ARCH=armv7

.PHONY: build lua luajit Android Windows

##############################################################################
all: build
	${MAKE} -C build ${MAKE_EXTRA_OPTIONS}

build:
	echo build for $(OS) arch $(ARCH)
	echo cmake $(CMAKE_FLAGS) $(CMAKE_EXTRA_OPTIONS)
	cmake $(CMAKE_FLAGS) $(CMAKE_EXTRA_OPTIONS)

lua:
	cmake $(CMAKE_FLAGS) $(CMAKE_EXTRA_OPTIONS) -DLUA_ENGINE=Lua
	${MAKE} -C ${OS} ${MAKE_EXTRA_OPTIONS}

luajit:
	cmake $(CMAKE_FLAGS) $(CMAKE_EXTRA_OPTIONS) -DLUA_ENGINE=LuaJIT
	${MAKE} -C ${OS} ${MAKE_EXTRA_OPTIONS}

Android:
	cmake $(CMAKE_FLAGS) $(CMAKE_EXTRA_OPTIONS) -DLUAJIT_BUILD_ALAMG=ON \
	-DCMAKE_TOOLCHAIN_FILE=${ANDROID_NDK}/build/cmake/android.toolchain.cmake \
	-DCMAKE_SYSTEM_NAME=Android -DCMAKE_SYSTEM_VERSION=19 \
	-DCMAKE_ANDROID_NDK=${ANDROID_NDK}
	cmake --build build --config Release

iOSWithLua:
	cmake $(CMAKE_FLAGS) $(CMAKE_EXTRA_OPTIONS) -DLUA_ENGINE=Lua \
	-DCMAKE_TOOLCHAIN_FILE=cmake/Utils/ios.toolchain.cmake \
	-DIOS_PLATFORM=OS -DIOS_ARCH=$(IOS_ARCH) \
	-DASM_FLAGS="-arch ${IOS_ARCH} -isysroot ${shell xcrun --sdk iphoneos --show-sdk-path}"
	cmake --build build --config Release

iOS:
	cmake $(CMAKE_FLAGS) $(CMAKE_EXTRA_OPTIONS) -DLUA_ENGINE=LuaJIT \
	-DCMAKE_TOOLCHAIN_FILE=cmake/Utils/ios.toolchain.cmake \
	-DIOS_PLATFORM=OS -DIOS_ARCH=$(IOS_ARCH) -DLUAJIT_DISABLE_JIT=1 \
	-DASM_FLAGS="-arch ${IOS_ARCH} -isysroot ${shell xcrun --sdk iphoneos --show-sdk-path}"
	cmake --build build --config Release

Windows:
	cmake $(CMAKE_FLAGS) $(CMAKE_EXTRA_OPTIONS) -DLUAJIT_BUILD_ALAMG=ON \
	-DCMAKE_TOOLCHAIN_FILE=cmake/Utils/Windows.toolchain.cmake
	cmake --build build --config Release


##############################################################################
clean:
	@cmake -E remove_directory build
