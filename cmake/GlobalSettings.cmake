include_guard(GLOBAL)

# require a C++ standard
if(NOT DEFINED CMAKE_CXX_STANDARD)
  set(CMAKE_CXX_STANDARD 17)
  option(CMAKE_CXX_EXTENSIONS "" NO)
  option(CMAKE_CXX_STANDARD_REQUIRED "" YES)
endif()

# NOTE: only for MSVC build shared libs (DLL)
include(CMakeDependentOption)
cmake_dependent_option(BUILD_SHARED_LIBS "Build shared instead of static library" YES "MSVC" NO)

option(BUILD_SHARED_LIBS "Build shared Libraries" NO)
option(USE_POSTFIX "Use postfix for debug" YES)
if(USE_POSTFIX)
  set(CMAKE_DEBUG_POSTFIX d)
endif()

list(APPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_LIST_DIR})

# set this variable to specify a common place where CMake should put all
# libraries and executables (instead of CMAKE_CURRENT_BINARY_DIR)
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${PROJECT_BINARY_DIR}/lib)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${PROJECT_BINARY_DIR}/bin)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${PROJECT_BINARY_DIR}/bin)

# ================================
# add dependencies
# ================================
include(CPM)

CPMUsePackageLock(package-lock.cmake)
