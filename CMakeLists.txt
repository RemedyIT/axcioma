cmake_minimum_required(VERSION 3.16...3.23)
#
# see https://cmake.org/cmake/help/latest/index.html for introduction
#
# cmake -B ../build -G Ninja -S .
# DESTDIR=../stage cmake --install ../build --prefix /
#
option(CMAKE_EXPORT_COMPILE_COMMANDS "for clang-tidy" ON)

project(
  itaox11
  VERSION 2.2.0
  LANGUAGES CXX
)

# ================================
# add dependencies
# ================================
include(cmake/GlobalSettings.cmake)

include(GenerateTaoIdl)
include(GNUInstallDirs)

add_library(itaox11 INTERFACE)

# FIXME: not useable! see $HOME/Workspace/cpp/axcioma/stage/include
set(TAOX11_INCLUDE_DIRS $ENV{TAOX11_ROOT} $ENV{TAOX11_ROOT}/orbsvcs #
                        $ENV{ACE_ROOT} $ENV{TAO_ROOT} $ENV{TAO_ROOT}/orbsvcs
)
foreach(dir_ ${TAOX11_INCLUDE_DIRS})
  cmake_path(GET dir_ FILENAME filename)
  if("${filename}" STREQUAL "taox11")
    message(STATUS "install dir ${dir_}/tao/x11")
    install(
      DIRECTORY ${dir_}/tao/x11 # Note: without trailing /
      DESTINATION include/tao
      FILES_MATCHING
      PATTERN "*.h"
      PATTERN "*.cpp" # Note: we need tao/x11/logger/logstream_t.cpp
    )
  elseif("${filename}" STREQUAL "orbsvcs")
    message(STATUS "install dir ${dir_}/orbsvcs")
    install(
      DIRECTORY ${dir_}/orbsvcs # Note: without trailing /
      DESTINATION include # or TYPE INCLUDE
      FILES_MATCHING
      PATTERN "*.h"
    )
  else()
    set(INCLUDE_DIR $<LOWER_CASE:${filename}>)
    message(STATUS "install dir ${dir_}/${INCLUDE_DIR}/")
    install(
      DIRECTORY ${dir_}/${INCLUDE_DIR} # Note: without trailing /
      DESTINATION include # or TYPE INCLUDE
      FILES_MATCHING
      PATTERN "*.shobj" EXCLUDE
      # FIXME: FILES_MATCHING REGEX ".*/\.shobj$" EXCLUDE
      PATTERN "*.h"
      PATTERN "*.inl"
      PATTERN "*.pidl"
      PATTERN "*.cpp"
    )
  endif()
endforeach()
list(TRANSFORM TAOX11_INCLUDE_DIRS PREPEND "$<BUILD_INTERFACE:")
list(TRANSFORM TAOX11_INCLUDE_DIRS APPEND ">")
message(TRACE "${TAOX11_INCLUDE_DIRS}")

# original header: target_include_directories(itaox11 SYSTEM INTERFACE ${TAOX11_INCLUDE_DIRS})
target_include_directories(
  itaox11 SYSTEM INTERFACE ${TAOX11_INCLUDE_DIRS} $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
)

# the installed stage/usr/include subdirs:
# include/ace
# include/tao/x11
# include/orbsvcs
# include/MgmtLocalAPI

# see $HOME/Workspace/cpp/axcioma/stage/lib
set(TAOX11_LIBRARIES
    taox11_portable_server
    taox11_cosnaming_stub
    taox11_anytypecode
    TAO_PortableServer
    TAO_AnyTypeCode
    taox11
    TAO
    x11_logger
    ACE
)
target_link_libraries(itaox11 INTERFACE ${TAOX11_LIBRARIES})
# TODO: Prevent use of original libs! CK
#   XXX target_link_options(itaox11 INTERFACE -L$ENV{X11_BASE_ROOT}/stage/lib)
# Note: It must NOT be an absolute path! CK
target_link_directories(
  itaox11 INTERFACE $<BUILD_INTERFACE:$ENV{X11_BASE_ROOT}/stage/lib> $<INSTALL_INTERFACE:${CMAKE_INSTALL_LIBDIR}>
)
target_compile_features(itaox11 INTERFACE cxx_std_17)

message(TRACE "X11_BASE_ROOT=$ENV{X11_BASE_ROOT}")
foreach(lib_ ${TAOX11_LIBRARIES})
  find_library(
    ${lib_}_LIB
    NAMES ${lib_}
    NO_DEFAULT_PATH
    PATHS $ENV{X11_BASE_ROOT}/stage/lib REQUIRED
  )
  message(STATUS "install lib ${${lib_}_LIB}")
  # NOTE: this installs only symlinks witch are not useable! install(FILES ${${lib_}_LIB} TYPE LIB)! CK
endforeach()

# Note: install all libs, more than yet used, but with symlinks to dll's
install(DIRECTORY $ENV{X11_BASE_ROOT}/stage/lib/ TYPE LIB)
# NOTE: with / means contents (*.so *.lib *.a pkgconfig)! CK
install(DIRECTORY $ENV{RIDL_ROOT}/ DESTINATION lib)

# stage/usr/lib
# ├── ridl
# └── x86_64-linux-gnu
#     ├── cmake
#     │   ├── idl2cpp
#     │   └── itaox11
#     ├── idl2cpp
#     └── pkgconfig

install(
  DIRECTORY $ENV{X11_BASE_ROOT}/bin/
  TYPE BIN
  USE_SOURCE_PERMISSIONS
)
install(
  DIRECTORY $ENV{X11_BASE_ROOT}/stage/bin/
  TYPE BIN
  USE_SOURCE_PERMISSIONS
)

# stage/usr/bin
# ├── ace_gperf
# ├── brix11
# ├── brix11.bat
# ├── fuzzers
# ├── ridlc
# ├── ridlc.bat
# ├── tao_catior
# ├── tao_cosnaming
# └── tao_idl

if(APPLE) # "think different", indeed! CK
  # see
  # https://opensource.apple.com/source/clang/clang-703.0.31/src/tools/clang/docs/MSVCCompatibility.rst.auto.html
  target_compile_options(itaox11 INTERFACE -fdelayed-template-parsing)
  target_compile_definitions(itaox11 INTERFACE ACE_HAS_IPV6 ACE_HAS_VERSIONED_NAMESPACE=1 ACE_HAS_CUSTOM_EXPORT_MACROS=0)
  target_compile_definitions(itaox11 INTERFACE __ACE_INLINE__)
elseif(UNIX)
  # see https://clang.llvm.org/docs/ClangCommandLineReference.html
  if(CMAKE_CXX_COMPILER_ID MATCHES "Clang")
    # Parse templated function definitions at the end of the translation unit
    target_compile_options(itaox11 INTERFACE -fdelayed-template-parsing)
    target_compile_definitions(itaox11 INTERFACE ACE_HAS_CUSTOM_EXPORT_MACROS=0)
  else()
    target_compile_definitions(itaox11 INTERFACE ACE_HAS_VERSIONED_NAMESPACE=1)
  endif()
  target_compile_definitions(itaox11 INTERFACE _GNU_SOURCE)
  # Give inline C++ member functions hidden visibility by default
  target_compile_options(itaox11 INTERFACE -fvisibility=hidden -fvisibility-inlines-hidden -fno-strict-aliasing)
  target_compile_definitions(itaox11 INTERFACE __ACE_INLINE__)
elseif(CMAKE_CXX_COMPILER_ID STREQUAL "MSVC")
  target_compile_options(itaox11 INTERFACE /bigobj)
  target_compile_definitions(
    itaox11 INTERFACE _CONSOLE _CRT_NONSTDC_NO_WARNINGS _CRT_SECURE_NO_WARNINGS _CRT_SECURE_NO_DEPRECATE
                      _CRT_NONSTDC_NO_DEPRECATE _WINSOCK_DEPRECATED_NO_WARNINGS #NO! CK ACE_AS_STATIC_LIBS
  )
  target_compile_options(
    itaox11
    INTERFACE /JMC
              /GR
              /GS
              /Gd
              /fp:precise
              /Zc:inline
              /Zc:wchar_t
              /Zc:forScope
              /ZI
              /Gm-
              /nologo
              /Ob1
  )
  target_link_options(itaox11 INTERFACE /FORCE:MULTIPLE)
endif()

CPMAddPackage("gh:TheLartians/PackageProject.cmake@1.9.0")

packageProject(
  NAME itaox11
  VERSION ${PROJECT_VERSION}
  NAMESPACE Axcioma
  BINARY_DIR ${PROJECT_BINARY_DIR}
  INCLUDE_DIR include
  INCLUDE_DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
  INCLUDE_HEADER_PATTERN "*.h"
  COMPATIBILITY SameMajorVersion
  DISABLE_VERSION_SUFFIX YES
)

include(CPack)

