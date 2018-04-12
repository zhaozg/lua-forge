# Added LUA_ADD_EXECUTABLE Ryan Phillips <ryan at trolocsis.com>
# This CMakeLists.txt has been first taken from LuaDist
# Copyright (C) 2007-2011 LuaDist.
# Created by Peter Drahoš
# Redistribution and use of this file is allowed according to the terms of the MIT license.
# Debugged and (now seriously) modified by Ronan Collobert, for Torch7

#project(LuaJIT C ASM)

IF(DEFINED ENV{LUAJIT_DIR})
  SET(LUAJIT_DIR $ENV{LUAJIT_DIR})
ELSE()
  SET(LUAJIT_DIR ${CMAKE_CURRENT_LIST_DIR}/../luajit)
ENDIF()
MESSAGE(STATUS "LUAJIT_DIR is ${LUAJIT_DIR}")

# Various includes
INCLUDE(CheckLibraryExists)
INCLUDE(CheckFunctionExists)
INCLUDE(CheckCSourceCompiles)
INCLUDE(CheckTypeSize)

# disable warning
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Wno-unused-function")

set(CMAKE_ASM_FLAGS "${CMAKE_ASM_FLAGS} ${CMAKE_C_FLAGS}")

# LuaJIT specific
option(LUAJIT_DISABLE_FFI "Disable FFI." OFF)
option(LUAJIT_ENABLE_LUA52COMPAT "Enable Lua 5.2 compatibility." ON)
option(LUAJIT_DISABLE_JIT "Disable JIT." OFF)
if (NOT IOS)
option(LUAJIT_CPU_SSE2 "Use SSE2 instead of x87 instructions." ON)
endif ()
option(LUAJIT_CPU_NOCMOV "Disable NOCMOV." OFF)
MARK_AS_ADVANCED(LUAJIT_DISABLE_FFI LUAJIT_ENABLE_LUA52COMPAT LUAJIT_DISABLE_JIT LUAJIT_CPU_SSE2 LUAJIT_CPU_NOCMOV)

OPTION(WITH_AMALG "Build eveything in one shot (needs memory)" ON)

## Source Lists
file (GLOB_RECURSE SRC_LJLIB    "${LUAJIT_DIR}/src/lib_*.c")
file (GLOB_RECURSE SRC_LJCORE   "${LUAJIT_DIR}/src/lj_*.c")
file (GLOB_RECURSE SRC_BUILDVM  "${LUAJIT_DIR}/src/host/buildvm*.c")

FILE(MAKE_DIRECTORY ${CMAKE_BINARY_DIR}/jit)
FILE(GLOB jit_files ${LUAJIT_DIR}/src/jit/*.lua)
FILE(COPY ${jit_files} DESTINATION ${CMAKE_BINARY_DIR}/jit)

SET(CMAKE_REQUIRED_INCLUDES
  ${LUAJIT_DIR}
  ${LUAJIT_DIR}/src
  ${CMAKE_CURRENT_BINARY_DIR}
)

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

IF(LUAJIT_CPU_SSE2)
  list(APPEND LUAJIT_DEFINITIONS LUAJIT_CPU_SSE2)
ENDIF()

IF(LUAJIT_CPU_NOCMOV)
  list(APPEND LUAJIT_DEFINITIONS LUAJIT_CPU_NOCMOV)
ENDIF()

list(APPEND LUAJIT_DEFINITIONS _FILE_OFFSET_BITS=64)
list(APPEND LUAJIT_DEFINITIONS _LARGEFILE_SOURCE)

# Set LJVM_MODE LJVM
set(LJVM_MODE)
set(LJ_VM lj_vm.S)
if ( WIN32 AND NOT CYGWIN )
  set ( LJVM_MODE peobj )
  set ( LJ_VM lj_vm.obj )
elseif ( APPLE )
  if (NOT IOS)
    set ( CMAKE_EXE_LINKER_FLAGS "-pagezero_size 10000 -image_base 100000000 ${CMAKE_EXE_LINKER_FLAGS}" )
  endif ()
  set ( LJVM_MODE machasm )
else ()
  set ( LJVM_MODE elfasm )
endif ()

# OS Relatived
IF(WIN32)
  IF(MSVC)
    list(APPEND LUAJIT_DEFINITIONS _CRT_SECURE_NO_WARNINGS)
  ENDIF()
ELSE()
  if(NOT IOS)
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
  endif()
  check_library_exists(m sin "" LUA_USE_LIBM)
  if ( LUA_USE_LIBM )
    list ( APPEND LIBS m )
  endif ()
ENDIF()

## Detect
MACRO(LJ_TEST_ARCH stuff)
  CHECK_C_SOURCE_COMPILES("
#undef ${stuff}
#include \"lj_arch.h\"
#if ${stuff}
int main() { return 0; }
#else
#error \"not defined\"
#endif
" ${stuff})
ENDMACRO()

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

## TARGET_LJARCH
FOREACH(arch X64 X86 ARM ARM64 PPC PPCSPE MIPS)
  LJ_TEST_ARCH(LJ_TARGET_${arch})
  if(LJ_TARGET_${arch})
    STRING(TOLOWER ${arch} TARGET_LJARCH)
    MESSAGE(STATUS "LuaJIT Target: ${TARGET_LJARCH}")
    BREAK()
  ENDIF()
ENDFOREACH()

IF(NOT TARGET_LJARCH)
  MESSAGE(FATAL_ERROR "architecture not supported")
ELSE()
  MESSAGE(STATUS "LuaJIT target ${TARGET_LJARCH}")
ENDIF()


SET(DASM_ARCH ${TARGET_LJARCH})
SET(DASM_FLAGS)
SET(TARGET_ARCH)

LIST(APPEND TARGET_ARCH "LUAJIT_TARGET=LUAJIT_ARCH_${TARGET_LJARCH}")
LJ_TEST_ARCH_VALUE(LJ_ARCH_BITS 64)
IF(LJ_ARCH_BITS_64)
  SET(DASM_FLAGS ${DASM_FLAGS} -D P64)
ENDIF()
LJ_TEST_ARCH_VALUE(LJ_HASJIT 1)
IF(LJ_HASJIT_1)
  SET(DASM_FLAGS ${DASM_FLAGS} -D JIT)
ENDIF()
LJ_TEST_ARCH_VALUE(LJ_HASFFI 1)
IF(LJ_HASFFI_1)
  SET(DASM_FLAGS ${DASM_FLAGS} -D FFI)
ENDIF()
LJ_TEST_ARCH_VALUE(LJ_DUALNUM 1)
IF(LJ_DUALNUM_1)
  SET(DASM_FLAGS ${DASM_FLAGS} -D DUALNUM)
ENDIF()
LJ_TEST_ARCH_VALUE(LJ_ARCH_HASFPU 1)
IF(LJ_ARCH_HASFPU_1)
  SET(DASM_FLAGS ${DASM_FLAGS} -D FPU)
  LIST(APPEND TARGET_ARCH "LJ_ARCH_HASFPU=1")
ELSE()
  LIST(APPEND TARGET_ARCH "LJ_ARCH_HASFPU=0")
ENDIF()
LJ_TEST_ARCH_VALUE(LJ_ABI_SOFTFP 1)
IF(NOT LJ_ABI_SOFTFP_1)
  SET(DASM_FLAGS ${DASM_FLAGS} -D HFABI)
  LIST(APPEND TARGET_ARCH "LJ_ABI_SOFTFP=0")
ELSE()
  LIST(APPEND TARGET_ARCH "LJ_ABI_SOFTFP=1")
ENDIF()
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
LIST(APPEND LUAJIT_DEFINITIONS ${TARGET_ARCH})

# Check HOST_COMPILER
IF(CMAKE_CROSSCOMPILING)
  IF(NOT HOST_COMPILER)
    set(HOST_COMPILER gcc)
  ENDIF()
  IF(NOT HOST_LINKER)
    set(HOST_LINKER ${HOST_COMPILER})
  ENDIF()
ELSE()
  set(HOST_COMPILER ${CMAKE_C_COMPILER})
  set(HOST_LINKER ${CMAKE_LINKER})
ENDIF()

# Build minilua
set(MINILUA ${CMAKE_CURRENT_BINARY_DIR}/minilua${CMAKE_EXECUTABLE_SUFFIX})
SET(buildvm_arg "")
foreach(define IN LISTS TARGET_ARCH)
  SET(buildvm_arg -D${define} ${buildvm_arg})
endforeach()
foreach(define IN LISTS LUAJIT_DEFINITIONS)
  SET(buildvm_arg -D${define} ${buildvm_arg})
endforeach()

if(IOS)
  set(HOST_ARGS ${HOST_ARGS} -arch i386 -DLUAJIT_OS=LUAJIT_OS_OSX)
endif()
add_custom_command(OUTPUT ${MINILUA}
  COMMAND ${HOST_COMPILER} ARGS ${HOST_ARGS} ${buildvm_arg} ${LUAJIT_DIR}/src/host/minilua.c -o ${MINILUA}
)

# generate buildvm_arch.h
add_custom_command(OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/buildvm_arch.h
  COMMAND ${MINILUA} ARGS
    ${LUAJIT_DIR}/dynasm/dynasm.lua ${DASM_FLAGS} -o
    ${CMAKE_CURRENT_BINARY_DIR}/buildvm_arch.h
    ${LUAJIT_DIR}/src/vm_${DASM_ARCH}.dasc
  DEPENDS ${MINILUA}
  MAIN_DEPENDENCY ${LUAJIT_DIR}/dynasm/dynasm.lua
)

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

add_custom_command(OUTPUT ${BUILDVM}
  COMMAND ${HOST_COMPILER} ARGS
    ${HOST_ARGS}
    ${buildvm_arg} ${buildvm_src} -o ${BUILDVM}
  DEPENDS ${MINILUA}
  MAIN_DEPENDENCY ${CMAKE_CURRENT_BINARY_DIR}/buildvm_arch.h
)

macro(add_buildvm_target _target _mode)
  add_custom_command(OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/${_target}
    COMMAND ${BUILDVM} ARGS -m ${_mode} -o ${CMAKE_CURRENT_BINARY_DIR}/${_target} ${ARGN}
    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
    DEPENDS ${BUILDVM}
    MAIN_DEPENDENCY ${ARGN}
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
add_buildvm_target ( vmdef.lua    vmdef   ${SRC_LJLIB} )

SET(DEPS
  ${LJ_VM_SRC}
  ${CMAKE_CURRENT_BINARY_DIR}/lj_ffdef.h
  ${CMAKE_CURRENT_BINARY_DIR}/lj_bcdef.h
  ${CMAKE_CURRENT_BINARY_DIR}/lj_libdef.h
  ${CMAKE_CURRENT_BINARY_DIR}/lj_recdef.h
  ${CMAKE_CURRENT_BINARY_DIR}/lj_folddef.h
  ${CMAKE_CURRENT_BINARY_DIR}/vmdef.lua
)

## compile include
include_directories(
  ${LUAJIT_DIR}/src
  ${CMAKE_CURRENT_BINARY_DIR}
)
set(LJ_COMPILE_FLAGS "-I${LUAJIT_DIR}/dynasm")

## link liblua
set_source_files_properties(${LJ_VM_SRC}
  properties
  COMPILE_FLAGS ${CMAKE_C_FLAGS}
)
IF(IOS)
  SET(LIBTYPE STATIC)
ELSE()
  SET(LIBTYPE SHARED)
ENDIF()
IF(WITH_AMALG)
  add_library(luajit-5.1 ${LIBTYPE} ${LUAJIT_DIR}/src/ljamalg.c ${DEPS} )
ELSE()
  add_library(luajit-5.1 ${LIBTYPE} ${SRC_LJCORE} ${DEPS} )
ENDIF()
SET_TARGET_PROPERTIES(luajit-5.1 PROPERTIES
  PREFIX "lib"
  IMPORT_PREFIX "lib"
  COMPILE_FLAGS ${LJ_COMPILE_FLAGS}
  COMPILE_DEFINITIONS "${LUAJIT_DEFINITIONS}"
  OUTPUT_NAME "lua51"
)
target_link_libraries (luajit-5.1 ${LIBS} )
list(APPEND LIB_LIST luajit-5.1)

## build luajit
IF(WIN32)
  add_executable(luajit ${LUAJIT_DIR}/src/luajit.c)
  target_link_libraries(luajit luajit-5.1)
ELSE()
  IF(WITH_AMALG)
    add_executable(luajit ${LUAJIT_DIR}/src/luajit.c ${LUAJIT_DIR}/src/ljamalg.c ${DEPS})
  ELSE()
    add_executable(luajit ${LUAJIT_DIR}/src/luajit.c ${SRC_LJCORE} ${DEPS})
  ENDIF()
  target_link_libraries(luajit ${LIBS})
  SET_TARGET_PROPERTIES(luajit PROPERTIES
    COMPILE_FLAGS ${LJ_COMPILE_FLAGS}
    COMPILE_DEFINITIONS "${LUAJIT_DEFINITIONS}"
    ENABLE_EXPORTS ON
  )
ENDIF()

MACRO(LUAJIT_add_custom_commands luajit_target)
  SET(target_srcs "")
  IF(ANDROID)
    SET(LJDUMP_OPT "-b -a arm -o linux")
  ELSEIF(IOS)
    SET(LJDUMP_OPT "-b -a arm -o osx")
  ELSE()
    SET(LJDUMP_OPT "-b")
  ENDIF()
  FOREACH(file ${ARGN})
    IF(${file} MATCHES ".*\\.lua$")
      set(file "${CMAKE_CURRENT_SOURCE_DIR}/${file}")
      set(source_file ${file})
      string(LENGTH ${CMAKE_SOURCE_DIR} _luajit_source_dir_length)
      string(LENGTH ${file} _luajit_file_length)
      math(EXPR _begin "${_luajit_source_dir_length} + 1")
      math(EXPR _stripped_file_length "${_luajit_file_length} - ${_luajit_source_dir_length} - 1")
      string(SUBSTRING ${file} ${_begin} ${_stripped_file_length} stripped_file)

      set(generated_file "${CMAKE_BINARY_DIR}/jitted_tmp/${stripped_file}_${luajit_target}_generated${CMAKE_C_OUTPUT_EXTENSION}")
      IF(IOS)
        set(CMD /usr/local/bin/luajit)
      else()
        set(CMD luajit)
      endif()
      add_custom_command(
        OUTPUT ${generated_file}
        MAIN_DEPENDENCY ${source_file}
        DEPENDS luajit
        COMMAND "${CMD} ${LJDUMP_OPT} ${source_file} ${generated_file}"
        COMMENT "luajit ${LJDUMP_OPT} ${source_file} ${generated_file}"
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

MACRO(LUA_ADD_EXECUTABLE luajit_target)
  LUAJIT_add_custom_commands(${luajit_target} ${ARGN})
  add_executable(${luajit_target} ${target_srcs})
ENDMACRO(LUA_ADD_EXECUTABLE luajit_target)
