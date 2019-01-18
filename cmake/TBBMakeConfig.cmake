# Copyright (c) 2017-2018 Intel Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
#
#
#

#
# Usage:
#   include(TBBMakeConfig.cmake)
#   tbb_make_config(TBB_ROOT <tbb_root> SYSTEM_NAME <system_name> CONFIG_DIR <var_to_store_config_dir> [SAVE_TO] [CONFIG_FOR_SOURCE TBB_RELEASE_DIR <tbb_release_dir> TBB_DEBUG_DIR <tbb_debug_dir> | TBB_BUILD_DIR <base of installed binaries>])
#
# TBB_ROOT                                   <- The source code
# SYSTEM_NAME                                <- The system name for the binaries (i.e. Darwin/Linux/Windows/Android)
# CONFIG_DIR                                 <- (output variable) variable name for where the config dir is located
# SAVE_TO                                    <- Relative path where the cmake TBBConfig.cmake package files go
# CONFIG_FOR_SOURCE                          <- Reference the source from TBBConfig.cmake  (mutually exclusive of TBB_BUILD_DIR)
#      TBB_RELEASE_DIR                               | Source build release binaries directory
#      TBB_DEBUG_DIR                                 | Source build debug binaries directory
# TBB_BUILD_DIR:PATH                         <- Where installed packages are located (mutually exclusive of CONFIG_FOR_SOURCE)

include(CMakeParseArguments)

# Save the location of Intel TBB CMake modules here, as it will not be possible to do inside functions,
# see for details: https://cmake.org/cmake/help/latest/variable/CMAKE_CURRENT_LIST_DIR.html
set(_tbb_cmake_module_path ${CMAKE_CURRENT_LIST_DIR})

function(tbb_make_config)
    set(oneValueArgs TBB_ROOT SYSTEM_NAME CONFIG_DIR SAVE_TO TBB_RELEASE_DIR TBB_DEBUG_DIR TBB_BUILD_DIR)
    set(options CONFIG_FOR_SOURCE)
    cmake_parse_arguments(tbb_MK "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    set(tbb_system_name ${CMAKE_SYSTEM_NAME})
    if (tbb_MK_SYSTEM_NAME)
        set(tbb_system_name ${tbb_MK_SYSTEM_NAME})
    endif()
    include(${CMAKE_CURRENT_LIST_DIR}/TBBPlatformDefaults.cmake)

    set(_tbb_config_dir ${tbb_MK_TBB_ROOT}/cmake)
    if (tbb_MK_SAVE_TO)
        set(_tbb_config_dir ${tbb_MK_SAVE_TO})
    endif()
    if(NOT IS_ABSOLUTE ${_tbb_config_dir})
      set(_tbb_config_dir ${CMAKE_CURRENT_BINARY_DIR}/${_tbb_config_dir})
    endif()
    file(MAKE_DIRECTORY ${_tbb_config_dir})

    set(TBB_DEFAULT_COMPONENTS tbb tbbmalloc tbbmalloc_proxy)

    if (tbb_MK_CONFIG_FOR_SOURCE)
        set(TBB_RELEASE_DIR ${tbb_MK_TBB_RELEASE_DIR})
        set(TBB_DEBUG_DIR ${tbb_MK_TBB_DEBUG_DIR})
        set(TBB_ROOT ${tbb_MK_TBB_ROOT})
        set(TBB_CONFIG_FOR_SOURCE ON)
        if(tbb_MK_TBB_BUILD_DIR)
            message(FATAL_ERROR "TBB_BUILD_DIR and CONFIG_FOR_SOURCE are mutually exclusive.  Only use one. :${CONFIG_FOR_SOURCE}:${TBB_BUILD_DIR}:")
        endif()
        if (tbb_system_name STREQUAL "Linux")
            # Note: multiline variable
            set(TBB_CHOOSE_COMPILER_SUBDIR "
if (CMAKE_CXX_COMPILER_LOADED)
    set(_tbb_compiler_id \${CMAKE_CXX_COMPILER_ID})
    set(_tbb_compiler_ver \${CMAKE_CXX_COMPILER_VERSION})
elseif (CMAKE_C_COMPILER_LOADED)
    set(_tbb_compiler_id \${CMAKE_C_COMPILER_ID})
    set(_tbb_compiler_ver \${CMAKE_C_COMPILER_VERSION})
endif()

# For non-GCC compilers try to find version of system GCC to choose right compiler subdirectory.
if (NOT _tbb_compiler_id STREQUAL \"GNU\")
    execute_process(COMMAND gcc --version OUTPUT_VARIABLE _tbb_gcc_ver_output ERROR_QUIET)
    string(REGEX REPLACE \".*gcc.*([0-9]+\\\\.[0-9]+)\\\\.[0-9]+.*\" \"\\\\1\" _tbb_compiler_ver \"\${_tbb_gcc_ver_output}\")
    if (NOT _tbb_compiler_ver)
        message(FATAL_ERROR \"This Intel TBB package is intended to be used only environment with available 'gcc'\")
    endif()
    unset(_tbb_gcc_ver_output)
endif()

set(_tbb_compiler_subdir gcc4.1)
foreach (_tbb_gcc_version 4.1 4.4 4.7 5.0 5.4 6.0 7.0 7.5 8.0 9.0 ${CMAKE_CXX_COMPILER_VERSION})
    if (NOT _tbb_compiler_ver VERSION_LESS \${_tbb_gcc_version})
        set(_tbb_compiler_subdir gcc\${_tbb_gcc_version})
    endif()
endforeach()

unset(_tbb_compiler_id)
unset(_tbb_compiler_ver)")

        elseif (tbb_system_name STREQUAL "Windows")
            # Note: multiline variable
            set(TBB_CHOOSE_COMPILER_SUBDIR "if (NOT MSVC)
    message(FATAL_ERROR \"This Intel TBB package is intended to be used only in the project with MSVC\")
endif()

# Detect the most relevant MSVC subdirectory
set(_tbb_msvc_1700_subdir vc11)
set(_tbb_msvc_1800_subdir vc12)
set(_tbb_msvc_1900_subdir vc14)
set(_tbb_msvc_ver \${MSVC_VERSION})
if (MSVC_VERSION VERSION_LESS 1700)
    message(FATAL_ERROR \"This Intel TBB package is intended to be used only in the project with MSVC version 1700 (vc11) or higher\")
elseif (MSVC_VERSION VERSION_GREATER 1900)
    set(_tbb_msvc_ver 1900)
endif()
set(_tbb_compiler_subdir \${_tbb_msvc_\${_tbb_msvc_ver}_subdir})
unset(_tbb_msvc_1700_subdir)
unset(_tbb_msvc_1800_subdir)
unset(_tbb_msvc_1900_subdir)

if (WINDOWS_STORE)
    set(_tbb_compiler_subdir \${_tbb_compiler_subdir}_ui)
endif()")

            if (tbb_MK_CONFIG_FOR_SOURCE)
                set(TBB_IMPLIB_RELEASE "\nIMPORTED_IMPLIB_RELEASE \"${tbb_MK_TBB_RELEASE_DIR}/\${_tbb_component}.lib\"")
                set(TBB_IMPLIB_DEBUG "\nIMPORTED_IMPLIB_DEBUG \"${tbb_MK_TBB_DEBUG_DIR}/\${_tbb_component}_debug.lib\"")
            else()
                # Note: multiline variable
                set(TBB_IMPLIB "
                                  IMPORTED_IMPLIB_RELEASE       \"\${_tbb_root}/lib/\${_tbb_arch_subdir}/\${_tbb_compiler_subdir}/\${_tbb_component}.lib\"
                                  IMPORTED_IMPLIB_DEBUG         \"\${_tbb_root}/lib/\${_tbb_arch_subdir}/\${_tbb_compiler_subdir}/\${_tbb_component}_debug.lib\"")
            endif()

            # Note: multiline variable
            # tbb/internal/_tbb_windef.h (included via tbb/tbb_stddef.h) does implicit linkage of some .lib files, use a special define to avoid it
            set(TBB_COMPILE_DEFINITIONS "
                                  INTERFACE_COMPILE_DEFINITIONS \"__TBB_NO_IMPLICIT_LINKAGE=1\"")
        elseif (tbb_system_name STREQUAL "Darwin")
            set(TBB_CHOOSE_COMPILER_SUBDIR "set(_tbb_compiler_subdir .)")
        elseif (tbb_system_name STREQUAL "Android")
            set(TBB_CHOOSE_COMPILER_SUBDIR "set(_tbb_compiler_subdir .)")
        else()
            message(FATAL_ERROR "Unsupported OS name: ${tbb_system_name}")
        endif()
    else()
        set(TBB_CONFIG_FOR_SOURCE OFF)
        file(RELATIVE_PATH TBB_CONFIG_TO_LIB_RELATIVE_PATH  ${_tbb_config_dir} ${tbb_MK_TBB_BUILD_DIR} )
        # message(STATUS "RELATIVE PATH FROM:${_tbb_config_dir}: to:${tbb_MK_TBB_BUILD_DIR}: is :${TBB_CONFIG_TO_LIB_RELATIVE_PATH}:" )
        set(TBB_CHOOSE_COMPILER_SUBDIR "set(_tbb_compiler_subdir .)") ## NOTE _tbb_compiler_subdir is not supported for install dirs
    endif()


    file(READ "${tbb_MK_TBB_ROOT}/include/tbb/tbb_stddef.h" _tbb_stddef)
    string(REGEX REPLACE ".*#define TBB_VERSION_MAJOR ([0-9]+).*" "\\1" _tbb_ver_major "${_tbb_stddef}")
    string(REGEX REPLACE ".*#define TBB_VERSION_MINOR ([0-9]+).*" "\\1" _tbb_ver_minor "${_tbb_stddef}")
    string(REGEX REPLACE ".*#define TBB_INTERFACE_VERSION ([0-9]+).*" "\\1" TBB_INTERFACE_VERSION "${_tbb_stddef}")
    set(TBB_VERSION "${_tbb_ver_major}.${_tbb_ver_minor}")

    configure_file(${_tbb_cmake_module_path}/templates/TBBConfig.cmake.in        ${_tbb_config_dir}/TBBConfig.cmake @ONLY)
    configure_file(${_tbb_cmake_module_path}/templates/TBBConfigVersion.cmake.in ${_tbb_config_dir}/TBBConfigVersion.cmake @ONLY)

    set(${tbb_MK_CONFIG_DIR} ${_tbb_config_dir} PARENT_SCOPE)
endfunction()
