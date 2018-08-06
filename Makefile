ifneq ($(TARGET_SYS), )
	OS:=$(TARGET_SYS)
else
	OS:=$(shell uname -s)
endif

CMAKE_FLAGS+= -H. -B${OS}
ifdef BUILDTYPE
	BUILDTYPE := Release
endif
ifndef GENERATOR
	GENERATOR :="Unix Makefiles"
endif
ifndef LUA_ENGINE
	LUA_ENGINE := LuaJIT
endif

ifeq ($(OS),Android)
	CMAKE_EXTRA_OPTIONS+=-DCMAKE_SYSTEM_NAME=Android -DCMAKE_SYSTEM_VERSION=19 \
	  -DCMAKE_ANDROID_ARCH_ABI=armeabi -DCMAKE_ANDROID_NDK=${ANDROID_NDK} \
	  -DCMAKE_MAKE_PROGRAM=${MAKE} \
	  -DHOST_COMPILER=gcc -DHOST_LINKER=ld -DHOST_BITS=-m32
endif

ifeq ($(OS),iOS)
ifeq (${LUA_ENGINE}, Lua)
	CMAKE_EXTRA_OPTIONS+=-DCMAKE_TOOLCHAIN_FILE=etc/ios.toolchain.cmake -DIOS_PLATFORM=OS
else
	CMAKE_EXTRA_OPTIONS+=-DCMAKE_TOOLCHAIN_FILE=etc/ios.toolchain.cmake -DIOS_PLATFORM=OS \
		-DIOS_ARCH="armv7;armv7s" -DASM_FLAGS="-arch armv7 -arch armv7s -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS11.3.sdk"
endif
endif

ifdef GENERATOR
	CMAKE_FLAGS+= -G${GENERATOR}
endif

ifdef BUILDTYPE
	CMAKE_FLAGS+= -DCMAKE_BUILD_TYPE=${BUILDTYPE}
endif

ifdef WITHOUT_AMALG
	CMAKE_FLAGS+= -DWITH_AMALG=OFF
endif

#Disable NPROCS
#~ ifdef NPROCS
	#~ MAKE_EXTRA_OPTIONS+= -j${NPROCS}
#~ endif

ifdef LUA_ENGINE
	CMAKE_EXTRA_OPTIONS+= -DLUA_ENGINE=${LUA_ENGINE}
endif

ifdef LUA_BUILD_TYPE
	CMAKE_EXTRA_OPTIONS+= -DLUA_BUILD_TYPE=${LUA_BUILD_TYPE}
endif

.PHONY: build lua luajit
##############################################################################
all: build
	${MAKE} -C ${OS} ${MAKE_EXTRA_OPTIONS}

build:
	echo build for $(OS) $(CMAKE_EXTRA_OPTIONS)
	cmake $(CMAKE_FLAGS) $(CMAKE_EXTRA_OPTIONS)

lua:
	cmake $(CMAKE_FLAGS) $(CMAKE_EXTRA_OPTIONS) -DLUA_ENGINE=Lua
	${MAKE} -C ${OS} ${MAKE_EXTRA_OPTIONS}

luajit:
	cmake $(CMAKE_FLAGS) $(CMAKE_EXTRA_OPTIONS) -DLUA_ENGINE=LuaJIT
	${MAKE} -C ${OS} ${MAKE_EXTRA_OPTIONS}

##############################################################################
clean:
	rm -rf ${OS}
