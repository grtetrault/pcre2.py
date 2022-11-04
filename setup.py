# -*- coding:utf-8 -*-

import pathlib
import platform
import subprocess
import configparser

import setuptools
import setuptools.extension
import setuptools.command.build_ext
import Cython.Build

LIBPCRE2_BUILD_SHELL = "msys2" if platform.system() == "Windows" else "bash"

PROJ_CWD = pathlib.Path(__file__).parent
LIBPCRE2_CONFIG = PROJ_CWD.joinpath("libpcre2.cfg")

config = configparser.ConfigParser()
config.read(LIBPCRE2_CONFIG.resolve())

pcre2_cwd = PROJ_CWD.joinpath(config["DEFAULT"]["CWD"])
pcre2_src = pcre2_cwd.joinpath("src")
pcre2_static_lib = pcre2_cwd.joinpath(".libs/libpcre2-8.a")


# Configure Cython extension.
ext_src = PROJ_CWD.joinpath("src/pcre2")
pcre2_extension = setuptools.extension.Extension(
    "pcre2.*",
    sources=[f"{str(ext_src)}/*.pyx"],
    include_dirs=[str(pcre2_src)],
    extra_objects=[str(pcre2_static_lib)],
    extra_compile_args=["-DPCRE2_CODE_UNIT_WIDTH=8"]
)

cython_kwargs = {
    "language_level": "3"
}

# See setup.cfg for static metadata.
setuptools.setup(
    ext_modules=Cython.Build.cythonize([pcre2_extension], **cython_kwargs)
)
