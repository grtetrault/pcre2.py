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
add_pyx_file(_cy)


# Include .pyx and .pxd files in distribution for use by Cython API.
install(
    FILES
        _libpcre2.pxd
        _cy.pyx
    DESTINATION
        src/pcre2
)