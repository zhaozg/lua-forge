if(MSVC)
  add_definitions( -D_CRT_SECURE_NO_WARNINGS -D_CRT_NONSTDC_NO_WARNINGS )
endif()

if(UNIX)
  add_definitions(-Wall)
endif()

if(APPLE)
  if(NOT IOS)
    set(CMAKE_EXE_LINKER_FLAGS
      "-pagezero_size 10000 -image_base 100000000 ${CMAKE_EXE_LINKER_FLAGS}")
  endif()
endif()
