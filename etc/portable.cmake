if(MSVC)
  add_definitions( -D_CRT_SECURE_NO_WARNINGS -D_CRT_NONSTDC_NO_WARNINGS )
endif()

if(UNIX)
  add_definitions(-Wall)
endif()
