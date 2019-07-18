# Added LUA_ADD_EXECUTABLE Ryan Phillips <ryan at trolocsis.com>
# This CMakeLists.txt has been first taken from LuaDist
# Copyright (C) 2007-2011 LuaDist.
# Created by Peter Drahoš
# Redistribution and use of this file is allowed according to the terms of the MIT license.
# Debugged and (now seriously) modified by Ronan Collobert, for Torch7

project(LuaJIT C ASM)

IF(DEFINED ENV{LUAJIT_DIR})
  SET(LUAJIT_DIR $ENV{LUAJIT_DIR})
ELSE()
  SET(LUAJIT_DIR ${CMAKE_CURRENT_LIST_DIR}/../luajit)
ENDIF()
MESSAGE(STATUS "LUAJIT_DIR is ${LUAJIT_DIR}")

FILE(GLOB lua_files $${CMAKE_CURRENT_LIST_DIR}/*.lua)
FILE(COPY ${lua_files} DESTINATION ${CMAKE_CURRENT_BINARY_DIR})
FILE(COPY ${CMAKE_CURRENT_LIST_DIR}/lua2c.lua DESTINATION ${CMAKE_CURRENT_BINARY_DIR})
FILE(COPY ${CMAKE_CURRENT_LIST_DIR}/luauser.h DESTINATION ${CMAKE_CURRENT_BINARY_DIR})
FILE(COPY ${LUAJIT_DIR}/src/jit DESTINATION ${CMAKE_CURRENT_BINARY_DIR})

# Various includes
INCLUDE(CheckLibraryExists)
INCLUDE(CheckFunctionExists)
INCLUDE(CheckCSourceCompiles)
INCLUDE(CheckTypeSize)

set(CMAKE_ASM_FLAGS "${CMAKE_ASM_FLAGS} ${CMAKE_C_FLAGS}")

# LuaJIT specific
option(LUAJIT_DISABLE_FFI "Disable FFI." OFF)
option(LUAJIT_ENABLE_LUA52COMPAT "Enable Lua 5.2 compatibility." ON)
option(LUAJIT_DISABLE_JIT "Disable JIT." OFF)
option(LUAJIT_CPU_NOCMOV "Disable NOCMOV." OFF)
option(USE_64BITS "Enable 64 bits." ON)
option(USE_LUA2C "Use lua2c replace luajit dump." OFF)
MARK_AS_ADVANCED(LUAJIT_DISABLE_FFI LUAJIT_ENABLE_LUA52COMPAT LUAJIT_DISABLE_JIT LUAJIT_CPU_SSE2 LUAJIT_CPU_NOCMOV)

if(IOS OR ANDROID)
  SET(LUAJIT_DISABLE_JIT ON)
endif()

OPTION(WITH_AMALG "Build eveything in one shot (needs memory)" ON)

# Check Definitions
set(LUAJIT_DEFINITIONS)
IF(LUAJIT_DISABLE_FFI)
  list(APPEND LUAJIT_DEFINITIONS LUAJIT_DISABLE_FFI)
ENDIF()

IF(LUAJIT_ENABLE_LUA52COMPAT)
  list(APPEND LUAJIT_DEFINITIONS LUAJIT_ENABLE_LUA52COMPAT)
ENDIF()

IF(LUAJIT_DISABLE_JIT)
  list(APPEND LUAJIT_DEFINITIONS LUAJIT_DISABLE_JIT)
ENDIF()

IF(LUAJIT_CPU_NOCMOV)
  list(APPEND LUAJIT_DEFINITIONS LUAJIT_CPU_NOCMOV)
ENDIF()

if(NOT CMAKE_CROSSCOMPILING)
  list(APPEND LUAJIT_DEFINITIONS _FILE_OFFSET_BITS=64)
  list(APPEND LUAJIT_DEFINITIONS _LARGEFILE_SOURCE)
  list(APPEND LUAJIT_DEFINITIONS _FORTIFY_SOURCE)
endif()

# Set LJVM_MODE LJVM
set(LJVM_MODE elfasm)
set(LJ_VM lj_vm.S)
if(ANDROID)
  set(LJVM_MODE elfasm)
elseif(IOS OR APPLE)
  set(LJVM_MODE machasm)
elseif(WIN32 AND NOT CYGWIN)
  set(LJVM_MODE peobj)
  set(LJ_VM lj_vm.obj)
endif()
message("LJ_VM ${LJ_VM} LJVM_MODE ${LJVM_MODE}")

# OS Relatived
IF(WIN32)
  IF(MSVC)
    list(APPEND LUAJIT_DEFINITIONS _CRT_SECURE_NO_WARNINGS)
  ENDIF()
ELSE()
  IF(APPLE)
    ADD_DEFINITIONS(-DLUA_USER_H="luauser.h")
    include_directories(${CMAKE_CURRENT_BINARY_DIR})
  ENDIF()
  IF(NOT IOS)
    FIND_LIBRARY(DL_LIBRARY "dl")
    IF(DL_LIBRARY)
      SET(CMAKE_REQUIRED_LIBRARIES ${DL_LIBRARY})
      LIST(APPEND LIBS ${DL_LIBRARY})
    ENDIF(DL_LIBRARY)

    CHECK_FUNCTION_EXISTS(dlopen LUA_USE_DLOPEN)
    IF(NOT LUA_USE_DLOPEN)
      MESSAGE(FATAL_ERROR "Cannot compile a useful lua.
Function dlopen() seems not to be supported on your platform.
Apparently you are not on a Windows platform as well.
So lua has no way to deal with shared libraries!")
    ENDIF(NOT LUA_USE_DLOPEN)
  ENDIF()
  check_library_exists(m sin "" LUA_USE_LIBM)
  if ( LUA_USE_LIBM )
    list ( APPEND LIBS m )
  endif ()
ENDIF()

check_library_exists(m sin "" LUA_USE_LIBM)
if ( LUA_USE_LIBM )
  list ( APPEND LIBS m )
endif ()

if ( CMAKE_SYSTEM_NAME MATCHES "OpenBSD")
  list ( APPEND LIBS pthread c++abi )
endif ()

## SOURCES
MACRO(LJ_TEST_ARCH_VALUE stuff value)
  CHECK_C_SOURCE_COMPILES("
#undef ${stuff}
#include \"lj_arch.h\"
#if ${stuff} == ${value}
int main() { return 0; }
#else
#error \"not defined\"
#endif
" ${stuff}_${value})
ENDMACRO()

## Detect
set(TARGET_LJARCH)
set(TARGET_ARCH)

## TARGET_LJARCH
set(ARG_TESTARCH)
if(IOS)
  list(APPEND ARG_TESTARCH -arch ${IOS_ARCH} -isysroot ${CMAKE_OSX_SYSROOT})
  set(CMAKE_ASM_FLAGS "${CMAKE_ASM_FLAGS} -arch ${IOS_ARCH}")
endif()
if(ANDROID AND NOT CMAKE_HOST_WIN32)
  list(APPEND ARG_TESTARCH -arch ${ANDROID_SYSROOT_ABI} -isysroot ${CMAKE_SYSROOT})
endif()
foreach(define IN LISTS LUAJIT_DEFINITIONS)
  list(APPEND ARG_TESTARCH -D${define})
endforeach()
execute_process(COMMAND ${CMAKE_C_COMPILER}
  ${ARG_TESTARCH}
  -E
  ${LUAJIT_DIR}/src/lj_arch.h
  -dM
  OUTPUT_VARIABLE TARGET_TESTARCH
)
string(REPLACE ";" " " TIPS "${CMAKE_C_COMPILER} ${ARG_TESTARCH} -E ${LUAJIT_DIR}/src/lj_arch.h -dM")
message(STATUS ${TIPS})

if ("${TARGET_TESTARCH}" MATCHES "LJ_TARGET_X64")
  set(TARGET_LJARCH x64)
elseif ("${TARGET_TESTARCH}" MATCHES "LJ_TARGET_X86")
  set(TARGET_LJARCH x86)
  set(USE_64BITS OFF)
elseif ("${TARGET_TESTARCH}" MATCHES "LJ_TARGET_ARM64")
  set(TARGET_LJARCH arm64)
  if ("${TARGET_TESTARCH}" MATCHES "__AARCH64EB__")
    SET(TARGET_ARCH "-D__AARCH64EB__=1")
  endif()
elseif ("${TARGET_TESTARCH}" MATCHES "LJ_TARGET_ARM")
  set(TARGET_LJARCH arm)
  set(USE_64BITS OFF)
elseif ("${TARGET_TESTARCH}" MATCHES "LJ_TARGET_PPC")
  set(TARGET_LJARCH ppc)
elseif ("${TARGET_TESTARCH}" MATCHES "LJ_TARGET_PPCSPE")
  set(TARGET_LJARCH ppcspe)
elseif ("${TARGET_TESTARCH}" MATCHES "LJ_TARGET_MIPS")
  if ("${TARGET_TESTARCH}" MATCHES "MIPSEL")
    set(TARGET_ARCH "-D__MIPSEL__=1")
  endif ()
  set(TARGET_LJARCH mips)
endif ()
IF(NOT TARGET_LJARCH)
  MESSAGE(FATAL_ERROR "architecture not supported")
ELSE()
  MESSAGE(STATUS "LuaJIT target ${TARGET_LJARCH}")
ENDIF()

SET(DASM_ARCH ${TARGET_LJARCH})
SET(DASM_FLAGS)

LIST(APPEND TARGET_ARCH "LUAJIT_TARGET=LUAJIT_ARCH_${TARGET_LJARCH}")
LIST(APPEND LUAJIT_DEFINITIONS "LUAJIT_TARGET=LUAJIT_ARCH_${TARGET_LJARCH}")
IF ("${TARGET_TESTARCH}" MATCHES "LJ_ARCH_BITS 64")
  SET(DASM_FLAGS ${DASM_FLAGS} -D P64)
ENDIF()
IF ("${TARGET_TESTARCH}" MATCHES "LJ_HASJIT 1")
  SET(DASM_FLAGS ${DASM_FLAGS} -D JIT)
ENDIF()
IF ("${TARGET_TESTARCH}" MATCHES "LJ_HASFFI 1")
  SET(DASM_FLAGS ${DASM_FLAGS} -D FFI)
ENDIF()
IF ("${TARGET_TESTARCH}" MATCHES "LJ_DUALNUM 1")
  SET(DASM_FLAGS ${DASM_FLAGS} -D DUALNUM)
ENDIF()
IF ("${TARGET_TESTARCH}" MATCHES "LJ_ARCH_HASFPU 1")
  SET(DASM_FLAGS ${DASM_FLAGS} -D FPU)
  LIST(APPEND TARGET_ARCH "LJ_ARCH_HASFPU=1")
ELSE()
  LIST(APPEND TARGET_ARCH "LJ_ARCH_HASFPU=0")
ENDIF()
IF ("${TARGET_TESTARCH}" MATCHES "LJ_ABI_SOFTFP 1")
  LIST(APPEND TARGET_ARCH "LJ_ABI_SOFTFP=1")
ELSE()
  SET(DASM_FLAGS ${DASM_FLAGS} -D HFABI)
  LIST(APPEND TARGET_ARCH "LJ_ABI_SOFTFP=0")
ENDIF()
IF ("${TARGET_TESTARCH}" MATCHES "LJ_NO_UNWIND 1")
  SET(DASM_FLAGS ${DASM_FLAGS} -D NO_UNWIND)
  LIST(APPEND TARGET_ARCH "LUAJIT_NO_UNWIND")
ENDIF()

SET(DASM_FLAGS ${DASM_FLAGS} -D VER=)
IF(WIN32)
  SET(DASM_FLAGS ${DASM_FLAGS} -LN -D WIN)
ENDIF()
IF(TARGET_LJARCH STREQUAL "x86")
  LJ_TEST_ARCH_VALUE(__SSE2__ 1)
  IF(__SSE2__1)
    SET(DASM_FLAGS ${DASM_FLAGS} -D SSE)
  ENDIF()
ENDIF()
IF(TARGET_LJARCH STREQUAL "x64")
  SET(DASM_ARCH "x86")
ENDIF()
IF(TARGET_LJARCH STREQUAL "ppc")
  LJ_TEST_ARCH_VALUE(LJ_ARCH_SQRT 1)
  IF(NOT LJ_ARCH_SQRT_1)
    SET(DASM_FLAGS ${DASM_FLAGS} -D SQRT)
  ENDIF()
  LJ_TEST_ARCH_VALUE(LJ_ARCH_PPC64 1)
  IF(NOT LJ_ARCH_PPC64_1)
    SET(DASM_FLAGS ${DASM_FLAGS} -D GPR64)
  ENDIF()
ENDIF()
iF(IOS)
  SET(DASM_FLAGS ${DASM_FLAGS} -D IOS)
ENDIF()

# Check HOST_COMPILER
IF(CMAKE_CROSSCOMPILING)
  IF(NOT HOST_COMPILER)
    set(HOST_COMPILER gcc)
  ENDIF()
  IF(NOT HOST_LINKER)
    set(HOST_LINKER ${HOST_COMPILER})
  ENDIF()
ELSE()
  IF(NOT HOST_COMPILER)
    set(HOST_COMPILER ${CMAKE_C_COMPILER})
  ENDIF()
  IF(NOT HOST_LINKER)
    set(HOST_LINKER ${CMAKE_LINKER})
  ENDIF()
ENDIF()

# Build minilua
set(MINILUA ${CMAKE_CURRENT_BINARY_DIR}/minilua${CMAKE_EXECUTABLE_SUFFIX})
SET(buildvm_arg "")
foreach(define IN LISTS TARGET_ARCH)
  SET(buildvm_arg -D${define} ${buildvm_arg})
endforeach()

if(IOS)
  set(HOST_ARGS ${HOST_ARGS} -DLUAJIT_OS=LUAJIT_OS_OSX)
elseif(ANDROID)
  set(HOST_ARGS ${HOST_ARGS} -DLUAJIT_OS=LUAJIT_OS_LINUX)
else()
  list(FIND LIBS m FOUND)
  if(FOUND)
    set(HOST_ARGS ${HOST_ARGS} -lm)
  endif()
endif()

foreach(define IN LISTS LUAJIT_DEFINITIONS)
  list(APPEND HOST_ARGS -D${define})
endforeach()

string(REPLACE ";" " " ARGS "${HOST_BITS} ${HOST_ARGS} ${buildvm_arg}")
add_custom_command(OUTPUT ${MINILUA}
  MAIN_DEPENDENCY ${LUAJIT_DIR}/src/host/minilua.c
  COMMAND ${HOST_COMPILER} ARGS ${HOST_BITS} ${buildvm_arg} ${LUAJIT_DIR}/src/host/minilua.c ${HOST_ARGS} -o ${MINILUA}
  COMMENT "${HOST_COMPILER} ${ARGS} ${LUAJIT_DIR}/src/host/minilua.c -o ${MINILUA}"
)

# generate buildvm_arch.h
string(REPLACE ";" " " ARGS "${DASM_FLAGS}")
IF(CMAKE_CROSSCOMPILING)
  SET(MINILUA_CMD wine)
  SET(MINILUA_CMD_ARG ${MINILUA})
ELSE()
  SET(MINILUA_CMD ${MINILUA})
ENDIF()
add_custom_command(OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/buildvm_arch.h
  COMMAND ${MINILUA_CMD} ARGS
  ${MINILUA_CMD_ARG}
    ${LUAJIT_DIR}/dynasm/dynasm.lua ${DASM_FLAGS} -o
    ${CMAKE_CURRENT_BINARY_DIR}/buildvm_arch.h
    ${LUAJIT_DIR}/src/vm_${DASM_ARCH}.dasc
  DEPENDS ${MINILUA} ${LUAJIT_DIR}/src/vm_${DASM_ARCH}.dasc
  MAIN_DEPENDENCY ${LUAJIT_DIR}/dynasm/dynasm.lua
  COMMENT "${MINILUA} ${LUAJIT_DIR}/dynasm/dynasm.lua ${ARGS} -o ${CMAKE_CURRENT_BINARY_DIR}/buildvm_arch.h ${LUAJIT_DIR}/src/vm_${DASM_ARCH}.dasc"
)

## Source Lists
SET(SRC_LJLIB
  ${LUAJIT_DIR}/src/lib_base.c
  ${LUAJIT_DIR}/src/lib_math.c
  ${LUAJIT_DIR}/src/lib_bit.c
  ${LUAJIT_DIR}/src/lib_string.c
  ${LUAJIT_DIR}/src/lib_table.c
  ${LUAJIT_DIR}/src/lib_io.c
  ${LUAJIT_DIR}/src/lib_os.c
  ${LUAJIT_DIR}/src/lib_package.c
  ${LUAJIT_DIR}/src/lib_debug.c
  ${LUAJIT_DIR}/src/lib_jit.c
  ${LUAJIT_DIR}/src/lib_ffi.c
)

SET(SRC_LIBAUX
  ${LUAJIT_DIR}/src/lib_aux.c
  ${LUAJIT_DIR}/src/lib_init.c
)
file (GLOB_RECURSE SRC_LJCORE   "${LUAJIT_DIR}/src/lj_*.c")
list (APPEND SRC_LJCORE ${SRC_LJLIB} ${SRC_LIBAUX})
file (GLOB_RECURSE SRC_BUILDVM  "${LUAJIT_DIR}/src/host/buildvm*.c")

# Build buildvm
set(BUILDVM ${CMAKE_CURRENT_BINARY_DIR}/buildvm${CMAKE_EXECUTABLE_SUFFIX})
SET(buildvm_arg "")
foreach(define IN LISTS TARGET_ARCH)
  SET(buildvm_arg -D${define} ${buildvm_arg})
endforeach()
SET(buildvm_src "")
foreach(src IN LISTS SRC_BUILDVM)
  SET(buildvm_src ${src} ${buildvm_src})
endforeach()
SET(buildvm_arg ${buildvm_arg} -I${LUAJIT_DIR}/src -I${CMAKE_CURRENT_BINARY_DIR})

string(REPLACE ";" " " ARGS "${HOST_ARGS} ${buildvm_arg} ${buildvm_src}")
add_custom_command(OUTPUT ${BUILDVM}
  COMMAND ${HOST_COMPILER} ARGS
    ${HOST_BITS}
    ${HOST_ARGS}
    ${buildvm_arg} ${buildvm_src} -o ${BUILDVM}
  DEPENDS ${MINILUA}
  MAIN_DEPENDENCY ${CMAKE_CURRENT_BINARY_DIR}/buildvm_arch.h
  COMMENT "${HOST_COMPILER} ${HOST_BITS} ${ARGS} -o ${BUILDVM}"
)

IF(CMAKE_CROSSCOMPILING AND (WIN32 OR NOT USE_64BITS))
  SET(BUILDVM_CMD wine)
  SET(BUILDVM_CMD_ARG ${BUILDVM})
ELSE()
  SET(BUILDVM_CMD ${BUILDVM})
ENDIF()
macro(add_buildvm_target _target _mode)
  string(REPLACE ";" " " ARGS "${ARGN}")
  add_custom_command(OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/${_target}
    COMMAND ${BUILDVM_CMD} ARGS
    ${BUILDVM_CMD_ARG}
    -m ${_mode} -o ${CMAKE_CURRENT_BINARY_DIR}/${_target} ${ARGN}
    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
    DEPENDS ${BUILDVM}
    MAIN_DEPENDENCY ${ARGN}
    COMMENT "${BUILDVM} -m ${_mode} -o ${CMAKE_CURRENT_BINARY_DIR}/${_target} ${ARGS}"
  )
endmacro(add_buildvm_target)

# Generate arch relatived files
add_buildvm_target (${LJ_VM} ${LJVM_MODE})
set (LJ_VM_SRC ${CMAKE_CURRENT_BINARY_DIR}/${LJ_VM})
add_buildvm_target ( lj_ffdef.h   ffdef   ${SRC_LJLIB} )
add_buildvm_target ( lj_bcdef.h   bcdef   ${SRC_LJLIB} )
add_buildvm_target ( lj_folddef.h folddef ${LUAJIT_DIR}/src/lj_opt_fold.c )
add_buildvm_target ( lj_recdef.h  recdef  ${SRC_LJLIB} )
add_buildvm_target ( lj_libdef.h  libdef  ${SRC_LJLIB} )
add_buildvm_target ( jit/vmdef.lua vmdef  ${SRC_LJLIB} )

SET(DEPS
  ${LJ_VM_SRC}
  ${CMAKE_CURRENT_BINARY_DIR}/lj_ffdef.h
  ${CMAKE_CURRENT_BINARY_DIR}/lj_bcdef.h
  ${CMAKE_CURRENT_BINARY_DIR}/lj_libdef.h
  ${CMAKE_CURRENT_BINARY_DIR}/lj_recdef.h
  ${CMAKE_CURRENT_BINARY_DIR}/lj_folddef.h
  ${CMAKE_CURRENT_BINARY_DIR}/jit/vmdef.lua
)

## compile include
include_directories(
  ${CMAKE_CURRENT_BINARY_DIR}
)

## link liblua
if(WITH_SHARED_LUA)
  if(IOS OR ANDROID)
    SET(LIBTYPE STATIC)
  else()
    SET(LIBTYPE SHARED)
  endif()
else()
  SET(LIBTYPE STATIC)
endif()

IF(WITH_AMALG)
  add_library(luajit-5.1 ${LIBTYPE} ${LUAJIT_DIR}/src/ljamalg.c ${DEPS} )
ELSE()
  string(REPLACE ";" " " SRC_STR "${SRC_LJCORE}")
  add_library(luajit-5.1 ${LIBTYPE} ${SRC_LJCORE} ${DEPS} )
ENDIF()
SET_TARGET_PROPERTIES(luajit-5.1 PROPERTIES
  PREFIX "lib"
  IMPORT_PREFIX "lib"
  COMPILE_DEFINITIONS "${LUAJIT_DEFINITIONS}"
  OUTPUT_NAME "lua51"
)
target_link_libraries (luajit-5.1 ${LIBS} )
list(APPEND LIB_LIST luajit-5.1)

## build luajit
add_executable(luajit ${LUAJIT_DIR}/src/luajit.c)
IF(WIN32)
  target_link_libraries(luajit luajit-5.1)
ELSE()
  target_link_libraries(luajit luajit-5.1 ${LIBS})
  IF(APPLE)
    SET_TARGET_PROPERTIES(luajit PROPERTIES
      COMPILE_DEFINITIONS "${LUAJIT_DEFINITIONS}"
      ENABLE_EXPORTS ON
      LINK_FLAGS "-flat_namespace -undefined suppress"
      RUNTIME_OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}"
    )
  ELSE()
    SET_TARGET_PROPERTIES(luajit PROPERTIES
      COMPILE_DEFINITIONS "${LUAJIT_DEFINITIONS}"
      ENABLE_EXPORTS ON
      RUNTIME_OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}"
    )
  ENDIF()
ENDIF()

IF(USE_LUA2C)
  MACRO(LUA_add_custom_commands luajit_target)
    SET(target_srcs "")
    IF(CMAKE_CROSSCOMPILING)
      if(NOT HOST_LUAJIT)
        set(HOST_LUAJIT wine)
        set(HOST_LUAJIT_ARGS "luajit")
      endif()
      set(CMD ${HOST_LUAJIT} ${HOST_LUAJIT_ARGS})
    else()
      set(CMD luajit)
    endif()
    FOREACH(file ${ARGN})
      IF(${file} MATCHES ".*\\.lua$")
        if(NOT IS_ABSOLUTE ${file})
          set(file "${CMAKE_CURRENT_SOURCE_DIR}/${file}")
        endif()
        set(source_file ${file})
        string(LENGTH ${CMAKE_SOURCE_DIR} _luajit_source_dir_length)
        string(LENGTH ${file} _luajit_file_length)
        math(EXPR _begin "${_luajit_source_dir_length} + 1")
        math(EXPR _stripped_file_length "${_luajit_file_length} - ${_luajit_source_dir_length} - 1")
        string(SUBSTRING ${file} ${_begin} ${_stripped_file_length} stripped_file)

        set(generated_file "${CMAKE_CURRENT_BINARY_DIR}/luacode_tmp/${stripped_file}_${luajit_target}_generated.c")

        add_custom_command(
          OUTPUT ${generated_file}
          MAIN_DEPENDENCY ${source_file}
          DEPENDS luajit
          COMMAND ${CMD} ${CMAKE_CURRENT_BINARY_DIR}/lua2c.lua ${source_file} ${generated_file}
          COMMENT "${CMD} ${CMAKE_CURRENT_BINARY_DIR}/lua2c.lua ${source_file} ${generated_file}"
          WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
        )

        get_filename_component(basedir ${generated_file} PATH)
        file(MAKE_DIRECTORY ${basedir})

        set(target_srcs ${target_srcs} ${generated_file})
        set_source_files_properties(
          ${generated_file}
          properties
          generated true        # to say that "it is OK that the obj-files do not exist before build time"
        )
      ELSE()
        set(target_srcs ${target_srcs} ${file})
      ENDIF(${file} MATCHES ".*\\.lua$")
    ENDFOREACH(file)
  ENDMACRO()

  MACRO(LUA_ADD_CUSTOM luajit_target)
    LUA_add_custom_commands(${luajit_target} ${ARGN})
  ENDMACRO(LUA_ADD_CUSTOM luajit_target)

  MACRO(LUA_ADD_EXECUTABLE luajit_target)
    LUA_add_custom_commands(${luajit_target} ${ARGN})
    add_executable(${luajit_target} ${target_srcs})
  ENDMACRO(LUA_ADD_EXECUTABLE luajit_target)
ELSE()
  MACRO(LUAJIT_add_custom_commands luajit_target)
    SET(target_srcs "")
    IF(CMAKE_CROSSCOMPILING)
      if(NOT HOST_LUAJIT)
        set(HOST_LUAJIT wine)
        set(HOST_LUAJIT_ARGS "luajit")
      endif()
      set(CMD ${HOST_LUAJIT} ${HOST_LUAJIT_ARGS})
    else()
      set(CMD ${CMAKE_CURRENT_BINARY_DIR}/luajit)
    endif()
    IF(ANDROID)
      if(USE_64BITS)
        SET(LJDUMP_OPT -b -a arm64 -o linux)
      else()
        SET(LJDUMP_OPT -b -a arm -o linux)
      endif()
    ELSEIF(IOS)
      if(USE_64BITS)
        SET(LJDUMP_OPT -b -a arm64 -o linux)
      else()
        SET(LJDUMP_OPT -b -a arm -o linux)
      endif()
    ELSEIF(WIN32)
      if(USE_64BITS)
        SET(LJDUMP_OPT -b -a x64 -o windows)
      else()
        SET(LJDUMP_OPT -b -a x86 -o windows)
      endif()
    ELSE()
      SET(LJDUMP_OPT -b)
    ENDIF()
    FOREACH(file ${ARGN})
      IF(${file} MATCHES ".*\\.lua$")
        if(NOT IS_ABSOLUTE ${file})
          set(file "${CMAKE_CURRENT_SOURCE_DIR}/${file}")
        endif()
        set(source_file ${file})
        string(LENGTH ${CMAKE_SOURCE_DIR} _luajit_source_dir_length)
        string(LENGTH ${file} _luajit_file_length)
        math(EXPR _begin "${_luajit_source_dir_length} + 1")
        math(EXPR _stripped_file_length "${_luajit_file_length} - ${_luajit_source_dir_length} - 1")
        string(SUBSTRING ${file} ${_begin} ${_stripped_file_length} stripped_file)

        set(generated_file "${CMAKE_CURRENT_BINARY_DIR}/jitted_tmp/${stripped_file}_${luajit_target}_generated${CMAKE_C_OUTPUT_EXTENSION}")
        string(REPLACE ";" " " LJDUMP_OPT_STR "${LJDUMP_OPT}")

        add_custom_command(
          OUTPUT ${generated_file}
          MAIN_DEPENDENCY ${source_file}
          DEPENDS luajit
          COMMAND ${CMD} ${LJDUMP_OPT} ${source_file} ${generated_file}
          COMMENT "${CMD} ${LJDUMP_OPT_STR} ${source_file} ${generated_file}"
          WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
        )
        get_filename_component(basedir ${generated_file} PATH)
        file(MAKE_DIRECTORY ${basedir})

        set(target_srcs ${target_srcs} ${generated_file})
        set_source_files_properties(
          ${generated_file}
          properties
          external_object true # this is an object file
          generated true        # to say that "it is OK that the obj-files do not exist before build time"
        )
      ELSE()
        set(target_srcs ${target_srcs} ${file})
      ENDIF(${file} MATCHES ".*\\.lua$")
    ENDFOREACH(file)
  ENDMACRO()

  MACRO(LUA_ADD_CUSTOM luajit_target)
    LUAJIT_add_custom_commands(${luajit_target} ${ARGN})
  ENDMACRO(LUA_ADD_CUSTOM luajit_target)

  MACRO(LUA_ADD_EXECUTABLE luajit_target)
    LUAJIT_add_custom_commands(${luajit_target} ${ARGN})
    add_executable(${luajit_target} ${target_srcs})
  ENDMACRO(LUA_ADD_EXECUTABLE luajit_target)
ENDIF()
