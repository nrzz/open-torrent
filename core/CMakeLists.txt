cmake_minimum_required(VERSION 3.20)
project(opentorrent_core VERSION 0.3.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

if(WIN32)
  add_compile_definitions(_WIN32_WINNT=0x0A00)
endif()

option(OPENTORRENT_USE_LIBTORRENT "Build against libtorrent-rasterbar" ON)
option(OPENTORRENT_BUILD_TESTS "Build core unit tests" ON)
option(OPENTORRENT_BUILD_SHARED "Build shared library (required for Flutter FFI)" ON)

set(_ot_lib_type STATIC)
if(OPENTORRENT_BUILD_SHARED)
  set(_ot_lib_type SHARED)
endif()

add_library(opentorrent_core ${_ot_lib_type}
  src/session.cpp
  src/c_api.cpp
  src/utils.cpp
)

# --- Security hardening flags ---
if(MSVC)
  target_compile_options(opentorrent_core PRIVATE /W4 /GS /sdl /guard:cf)
  target_link_options(opentorrent_core PRIVATE /DYNAMICBASE /NXCOMPAT /guard:cf)
else()
  target_compile_options(opentorrent_core PRIVATE
    -fstack-protector-strong
    -D_FORTIFY_SOURCE=2
    -Wall -Wextra
  )
  if(UNIX AND NOT APPLE)
    target_link_options(opentorrent_core PRIVATE
      -Wl,-z,relro
      -Wl,-z,now
      -Wl,-z,noexecstack
    )
  endif()
endif()

if(OPENTORRENT_BUILD_SHARED)
  set_target_properties(opentorrent_core PROPERTIES WINDOWS_EXPORT_ALL_SYMBOLS ON)
else()
  target_compile_definitions(opentorrent_core PUBLIC OPENTORRENT_STATIC)
endif()

target_include_directories(opentorrent_core
  PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:include>
  PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/src
)

target_compile_definitions(opentorrent_core PRIVATE OPENTORRENT_BUILD)

if(OPENTORRENT_USE_LIBTORRENT)
  find_package(LibtorrentRasterbar CONFIG QUIET)
  if(NOT LibtorrentRasterbar_FOUND)
    find_package(PkgConfig QUIET)
    if(PkgConfig_FOUND)
      pkg_check_modules(LIBTORRENT IMPORTED_TARGET libtorrent-rasterbar)
    endif()
  endif()

  if(TARGET LibtorrentRasterbar::torrent-rasterbar)
    target_link_libraries(opentorrent_core PUBLIC LibtorrentRasterbar::torrent-rasterbar)
    target_compile_definitions(opentorrent_core PUBLIC OPENTORRENT_HAS_LIBTORRENT=1)
  elseif(TARGET PkgConfig::LIBTORRENT)
    target_link_libraries(opentorrent_core PUBLIC PkgConfig::LIBTORRENT)
    target_compile_definitions(opentorrent_core PUBLIC OPENTORRENT_HAS_LIBTORRENT=1)
  else()
    message(WARNING "libtorrent not found — building stub engine (OPENTORRENT_HAS_LIBTORRENT=0)")
    target_compile_definitions(opentorrent_core PUBLIC OPENTORRENT_HAS_LIBTORRENT=0)
  endif()
else()
  target_compile_definitions(opentorrent_core PUBLIC OPENTORRENT_HAS_LIBTORRENT=0)
endif()

if(WIN32)
  target_link_libraries(opentorrent_core PUBLIC ws2_32)
endif()

if(ANDROID)
  find_library(ANDROID_LOG_LIB log)
  if(ANDROID_LOG_LIB)
    target_link_libraries(opentorrent_core PUBLIC ${ANDROID_LOG_LIB})
  endif()
  set_target_properties(opentorrent_core PROPERTIES
    OUTPUT_NAME opentorrent_core
    ANDROID_ARM_MODE arm
  )
endif()

install(TARGETS opentorrent_core
  RUNTIME DESTINATION bin
  LIBRARY DESTINATION lib
  ARCHIVE DESTINATION lib
)
install(FILES include/opentorrent.h DESTINATION include)

if(OPENTORRENT_BUILD_TESTS)
  enable_testing()
  add_executable(opentorrent_core_tests tests/test_session.cpp)
  target_link_libraries(opentorrent_core_tests PRIVATE opentorrent_core)
  add_test(NAME opentorrent_core_tests COMMAND opentorrent_core_tests)
endif()
