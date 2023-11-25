cmake_minimum_required(VERSION 3.5)

set(projects C ASM)
project(lua ${projects})

# use, i.e. don't skip the full RPATH for the build tree
set(CMAKE_SKIP_BUILD_RPATH FALSE CACHE INTERNAL "")
# when building, don't use the install RPATH already (but later on when
# installing)
set(CMAKE_BUILD_WITH_INSTALL_RPATH FALSE CACHE INTERNAL "")
set(CMAKE_INSTALL_RPATH "${CMAKE_INSTALL_PREFIX}/lib" CACHE INTERNAL "")
# add the automatically determined parts of the RPATH which point to directories
# outside the build tree to the install RPATH
set(CMAKE_INSTALL_RPATH_USE_LINK_PATH TRUE CACHE INTERNAL "")
# the RPATH to be used when installing, but only if it's not a system directory
list(FIND CMAKE_PLATFORM_IMPLICIT_LINK_DIRECTORIES "${CMAKE_INSTALL_PREFIX}/lib"
          isSystemDir)
if("${isSystemDir}" STREQUAL "-1")
  set(CMAKE_INSTALL_RPATH "${CMAKE_INSTALL_PREFIX}/lib")
endif()

# convert /MD to /MD when build with MSVC
if(MSVC)
  # Statically build against C runtime (use the right version for Release/Debug)
  set(CompilerFlags
      CMAKE_CXX_FLAGS
      CMAKE_CXX_FLAGS_DEBUG
      CMAKE_CXX_FLAGS_RELEASE
      CMAKE_C_FLAGS
      CMAKE_C_FLAGS_DEBUG
      CMAKE_C_FLAGS_RELEASE
  )
  foreach(CompilerFlag ${CompilerFlags})
    string(REPLACE "/MD" "/MT" ${CompilerFlag} "${${CompilerFlag}}")
  endforeach()
endif()

if(CMAKE_COMPILER_IS_GNUCC)
  set(LUA_TARGET_SHARED ON)
endif()
if(DEFINED ENV{LUA_TARGET_SHARED})
  set(LUA_TARGET_SHARED $ENV{LUA_TARGET_SHARED})
endif()

if(${CMAKE_SYSTEM_NAME} MATCHES "Android")
  message("-- Build for Android")
  set(TARGET_LJARCH "arm") # for luajit
  set(ARCH "arm") # for openssl
endif()

find_package(Threads)

#
# build lua[jit] Build luv as static library insteas as module
set(BUILD_MODULE OFF CACHE STRING "Build lua[jit] as static library")

option(BUILD_MODULE "Build as module" ON)
option(BUILD_SHARED_LIBS "Build shared library" OFF)

if(NOT LUA_ENGINE AND NOT DEFINED ENV{LUA_ENGINE})
  set(LUA_ENGINE "LuaJIT" CACHE STRING "Link to LuaJIT or PUC Lua" FORCE)
  set_property(CACHE LUA_ENGINE PROPERTY STRINGS "Lua;LuaJIT")
elseif(NOT LUA_ENGINE)
  set(LUA_ENGINE $ENV{LUA_ENGINE})
endif()

if(NOT LUA_BUILD_TYPE)
  set(LUA_BUILD_TYPE "Static"
      CACHE STRING
            "Build Lua/LuaJIT as static, dynamic libary, or use system one"
      FORCE)
  set_property(CACHE LUA_BUILD_TYPE PROPERTY STRINGS "Static;Dynamic;System")
endif()

if(LUA_ENGINE STREQUAL Lua)
  add_definitions(-DWITH_PLAIN_LUA)
  if(NOT WIN32)
    add_definitions(-DLUA_USE_DLOPEN)
  endif()
  set(USE_LUAJIT OFF)
else()
  set(USE_LUAJIT ON)
endif()

if(LUA_BUILD_TYPE STREQUAL Static)
  set(WITH_SHARED_LUA OFF)
else()
  set(WITH_SHARED_LUA ON)
endif()
if(USE_LUAJIT)
  if(NOT DEFINED(LUAJIT_ENABLE_LUA52COMPAT))
    set(LUAJIT_ENABLE_LUA52COMPAT ON)
  endif()
  if(NOT DEFINED(LUAJIT_BUILD_ALAMG))
    set(LUAJIT_BUILD_ALAMG ON)
  endif()
  set(LUAJIT_DIR ${CMAKE_CURRENT_LIST_DIR}/LuaJIT)
  include(${CMAKE_CURRENT_LIST_DIR}/cmake/LuaJIT.cmake)
  if(NOT ${CMAKE_CURRENT_BINARY_DIR} STREQUAL ${CMAKE_BINARY_DIR})
    set(LUA_TARGET $<TARGET_FILE:luajit> PARENT_SCOPE)
    set(LUA_LIBRARIES luajit::lib PARENT_SCOPE)
    set(LUA_INCLUDE_DIR luajit::header PARENT_SCOPE)
    get_target_property(TARGET_PATH luajit RUNTIME_OUTPUT_DIRECTORY)
    get_target_property(TARGET_NAME luajit RUNTIME_OUTPUT_NAME)
  endif()
else()
  set(LUA_DIR ${CMAKE_CURRENT_LIST_DIR}/lua)
  include(${CMAKE_CURRENT_LIST_DIR}/cmake/lua.cmake)
  if(NOT ${CMAKE_CURRENT_BINARY_DIR} STREQUAL ${CMAKE_BINARY_DIR})
    set(LUA_TARGET $<TARGET_FILE:lua> PARENT_SCOPE)
    set(LUA_LIBRARIES lua::lib PARENT_SCOPE)
    set(LUA_INCLUDE_DIR lua::header PARENT_SCOPE)
    get_target_property(TARGET_PATH lua RUNTIME_OUTPUT_DIRECTORY)
    get_target_property(TARGET_NAME lua RUNTIME_OUTPUT_NAME)
  endif()
  if (WITH_LIBFFI)
    include(cmake/ffi.cmake)
    if(NOT ${CMAKE_CURRENT_BINARY_DIR} STREQUAL ${CMAKE_BINARY_DIR})
      set(LUA_FFI_LIBS ${LUA_FFI_LIBS} PARENT_SCOPE)
    endif()
  endif()
endif()

if(NOT ${CMAKE_CURRENT_BINARY_DIR} STREQUAL ${CMAKE_BINARY_DIR})
  set(LUA_TARGET_PATH ${TARGET_PATH} PARENT_SCOPE)
  set(LUA_TARGET_NAME ${TARGET_NAME} PARENT_SCOPE)
endif()

if(LUAJIT_ENABLE_LUA52COMPAT)
  add_definitions(-DCOMPAT52_IS_LUAJIT)
endif()

if(WIN32)
  add_definitions(-DWIN32_LEAN_AND_MEAN -D_CRT_SECURE_NO_WARNINGS)
else()
  find_package(Threads)
  add_definitions(-DPTHREADS)
endif()

add_library(lfs SHARED modules/lfs/src/lfs.c)
set_target_properties(lfs PROPERTIES
  SUFFIX ".so"
  PREFIX ""
  COMPILE_FLAGS "-DLUA_LIB")
if(USE_LUAJIT)
  target_link_libraries(lfs luajit::lib luajit::header)
else()
  target_link_libraries(lfs lua::lib lua::header)
endif()

