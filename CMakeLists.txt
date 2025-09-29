cmake_minimum_required(VERSION 4.0)
project(MatrixTree
        VERSION 1.0
        DESCRIPTION "Matrix-Tree hierarchical matrix structures in x86-64 assembly"
        LANGUAGES C
)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)

# Compiler flags
if(MSVC)
    # MSVC warning flags
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} /W3")
    set(CMAKE_C_FLAGS_DEBUG "/Zi /Od")
    set(CMAKE_C_FLAGS_RELEASE "/O2 /DNDEBUG")
else()
    # GCC/Clang warning flags
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Wall -Wextra")
    set(CMAKE_C_FLAGS_DEBUG "-g -O0")
    set(CMAKE_C_FLAGS_RELEASE "-O2 -DNDEBUG")
endif()

# Platform-specific assembly configuration
if(MSVC)
    message(STATUS "Configuring for MASM (Microsoft Macro Assembler)")
    enable_language(ASM_MASM)
    set(ASM_SOURCE "matrix_tree.asm")
    set(ASM_OBJECT "matrix_tree.obj")
    set(CMAKE_ASM_MASM_FLAGS "/nologo /Zi /W3")
elseif(UNIX OR MINGW OR CYGWIN)
    message(STATUS "Configuring for GAS (GNU Assembler)")
    enable_language(ASM)
    set(ASM_SOURCE "matrix_tree_linux.asm")
    set(ASM_OBJECT "matrix_tree.o")
    set(CMAKE_ASM_FLAGS "--64")
    if(NOT CMAKE_ASM_COMPILER)
        set(CMAKE_ASM_COMPILER "as")
    endif()
else()
    message(FATAL_ERROR "Unsupported platform/compiler for assembly")
endif()

# Source files
set(HEADER_SOURCE "matrix_tree.h")
set(DEMO_SOURCE "demo.c")
set(CHECK_SOURCE "check_tests.c")

# Check if source files exist
if(NOT EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/${ASM_SOURCE}")
    message(FATAL_ERROR "Assembly source ${ASM_SOURCE} not found!")
endif()

message(STATUS "Using files:")
message(STATUS "  ASM:    ${ASM_SOURCE}")
message(STATUS "  Header: ${HEADER_SOURCE}")
message(STATUS "  Demo:   ${DEMO_SOURCE}")
message(STATUS "  Tests:  ${CHECK_SOURCE}")

# Assembly compilation
if(MSVC)
    # MASM compilation for Visual Studio
    add_custom_command(
            OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/${ASM_OBJECT}
            COMMAND ml64 ${CMAKE_ASM_MASM_FLAGS}
            /Fo${CMAKE_CURRENT_BINARY_DIR}/${ASM_OBJECT}
            /c ${CMAKE_CURRENT_SOURCE_DIR}/${ASM_SOURCE}
            DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/${ASM_SOURCE}
            COMMENT "Assembling ${ASM_SOURCE} with MASM"
            VERBATIM
    )
else()
    # GAS compilation for Unix/MinGW
    add_custom_command(
            OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/${ASM_OBJECT}
            COMMAND ${CMAKE_ASM_COMPILER} ${CMAKE_ASM_FLAGS}
            -o ${CMAKE_CURRENT_BINARY_DIR}/${ASM_OBJECT}
            ${CMAKE_CURRENT_SOURCE_DIR}/${ASM_SOURCE}
            DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/${ASM_SOURCE}
            COMMENT "Assembling ${ASM_SOURCE} with GAS"
            VERBATIM
    )
endif()

# Create a custom target for the assembly object file
add_custom_target(matrix_tree_asm ALL
        DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/${ASM_OBJECT}
)

# Create an OBJECT library from the assembled object file
add_library(matrix_tree_obj OBJECT IMPORTED GLOBAL)
set_target_properties(matrix_tree_obj PROPERTIES
        IMPORTED_OBJECTS ${CMAKE_CURRENT_BINARY_DIR}/${ASM_OBJECT}
)
add_dependencies(matrix_tree_obj matrix_tree_asm)

# Demo executable
add_executable(demo ${DEMO_SOURCE})
target_link_libraries(demo PRIVATE matrix_tree_obj)
if(UNIX)
    target_link_libraries(demo PRIVATE m)
endif()
target_include_directories(demo PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})
add_dependencies(demo matrix_tree_asm)

# Check tests executable
add_executable(check_tests ${CHECK_SOURCE})
target_link_libraries(check_tests PRIVATE matrix_tree_obj)
if(UNIX)
    target_link_libraries(check_tests PRIVATE m)
endif()
target_include_directories(check_tests PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})
add_dependencies(check_tests matrix_tree_asm)

# Installation rules
install(TARGETS demo check_tests
        RUNTIME DESTINATION bin
)

install(FILES ${HEADER_SOURCE}
        DESTINATION include
)

install(FILES ${CMAKE_CURRENT_BINARY_DIR}/${ASM_OBJECT}
        DESTINATION lib
)

# Test target
enable_testing()
add_test(NAME check_tests_run COMMAND check_tests)
add_test(NAME demo_run COMMAND demo)

# Print build information
message(STATUS "")
message(STATUS "Matrix-Tree Build Configuration:")
message(STATUS "  Version:           ${PROJECT_VERSION}")
message(STATUS "  Build Type:        ${CMAKE_BUILD_TYPE}")
message(STATUS "  C Compiler:        ${CMAKE_C_COMPILER}")
if(MSVC)
    message(STATUS "  ASM Compiler:      ml64 (MASM)")
else()
    message(STATUS "  ASM Compiler:      ${CMAKE_ASM_COMPILER} (GAS)")
endif()
message(STATUS "  Platform:          ${CMAKE_SYSTEM_NAME}")
message(STATUS "  ASM Source:        ${ASM_SOURCE}")
message(STATUS "  ASM Object:        ${ASM_OBJECT}")
message(STATUS "  Demo Source:       ${DEMO_SOURCE}")
message(STATUS "")

# Help message
if(MSVC)
    message(STATUS "Build targets (Visual Studio):")
    message(STATUS "  MSBuild MatrixTree.sln     - Build all targets")
    message(STATUS "  MSBuild demo.vcxproj       - Build demo executable")
    message(STATUS "  MSBuild check_tests.vcxproj - Build check_tests executable")
    message(STATUS "  Or use Visual Studio IDE to build")
elseif(MINGW OR CYGWIN)
    message(STATUS "Build targets (MinGW):")
    message(STATUS "  mingw32-make               - Build all targets")
    message(STATUS "  mingw32-make demo          - Build demo executable")
    message(STATUS "  mingw32-make check_tests   - Build check_tests executable")
    message(STATUS "  mingw32-make test          - Run all tests")
else()
    message(STATUS "Build targets (Unix):")
    message(STATUS "  make                       - Build all targets")
    message(STATUS "  make demo                  - Build demo executable")
    message(STATUS "  make check_tests           - Build check_tests executable")
    message(STATUS "  make test                  - Run all tests")
    message(STATUS "  make install               - Install binaries and headers")
endif()
message(STATUS "")