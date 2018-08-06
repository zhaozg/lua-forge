IF(DEFINED ENV{FFI_DIR})
  SET(FFI_DIR $ENV{FFI_DIR})
ELSE()
  SET(FFI_DIR ${CMAKE_CURRENT_LIST_DIR}/../thirdparty/ffi)
ENDIF()
MESSAGE(STATUS "FFI_DIR is ${FFI_DIR}")

SET(FFI_SRC
  ${FFI_DIR}/call.c
  ${FFI_DIR}/ctype.c
  ${FFI_DIR}/ffi.c
  ${FFI_DIR}/parser.c
)

if(WITH_SHARED_LUA)
  if(IOS OR ANDROID)
    SET(LIBTYPE STATIC)
    SET(WITH_SHARED_LUA OFF)
  else()
    SET(LIBTYPE SHARED)
  endif()
else()
  SET(LIBTYPE STATIC)
endif()

add_library(ffi ${LIBTYPE} ${FFI_SRC})
target_link_libraries (ffi lualib)

#set(CMD lua)
#add_custom_command(
#  TARGET ffi
#  PRE_BUILD
#  COMMAND ${CMD} ARGS ${FFI_DIR}/dynasm/dynasm.lua -o call_x86.h -LN ${FFI_DIR}/call_x86.dasc
#  COMMAND ${CMD} ARGS ${FFI_DIR}/dynasm/dynasm.lua -o call_x64.h -D X64 -LN ${FFI_DIR}/call_x86.dasc
#  COMMAND ${CMD} ARGS ${FFI_DIR}/dynasm/dynasm.lua -o call_x64win.h -D X64 -D X64WIN ${FFI_DIR}/call_x86.dasc
#  COMMAND ${CMD} ARGS ${FFI_DIR}/dynasm/dynasm.lua -o call_arm.h -LNE ${FFI_DIR}/call_arm.dasc
#  COMMENT "Generating Header Files"
#  WORKING_DIRECTORY ${CMAKE_CURRENT_DIR}
#)
SET_TARGET_PROPERTIES(ffi PROPERTIES
  PREFIX "lib"
  IMPORT_PREFIX "lib"
  COMPILE_FLAGS "-I${FFI_DIR} -I{CMAKE_CURRENT_BINARY_DIR} -Wunused-function"
  OUTPUT_NAME "ffi"
)
list(APPEND LIB_LIST ffi)

