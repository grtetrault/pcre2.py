find_package(Cython MODULE REQUIRED)
find_package(PythonExtensions MODULE REQUIRED)

include_directories(${CMAKE_CURRENT_SOURCE_DIR})

# Build Cython with annotations.
set(CYTHON_ANNOTATE TRUE)

# Macro to add Cython files as modules, configured to build with PCRE2.
macro(add_pyx_file filename)
    add_cython_target(${filename} C PY3)
    add_library(${filename} MODULE ${filename})
    python_extension_module(${filename})

    target_link_libraries(${filename} pcre2-8-static)
    target_include_directories(${filename} PRIVATE ${PCRE2_INCLUDE_DIR})
    target_compile_options(${filename} PRIVATE ${CYTHON_EXTRA_COMPILE_ARGS})
    
    install(TARGETS ${filename} LIBRARY DESTINATION src/pcre2)
endmacro()

# GLOB pattern is recommended against,
# https://cmake.org/cmake/help/v3.14/command/file.html?highlight=file#filesystem
add_pyx_file(consts)
add_pyx_file(exceptions)
add_pyx_file(match)
add_pyx_file(methods)
add_pyx_file(pattern)
add_pyx_file(scanner)
add_pyx_file(utils)


# Include .pyx and .pxd files in distribution for use by Cython API.
install(
    FILES
        consts.pxd
        consts.pyx
        exceptions.pxd
        exceptions.pyx
        libpcre2.pxd
        match.pxd
        match.pyx
        methods.pxd
        methods.pyx
        pattern.pxd
        pattern.pyx
        scanner.pxd
        scanner.pyx
        utils.pxd
        utils.pyx
    DESTINATION
        src/pcre2
)