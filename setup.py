# -*- coding:utf-8 -*-

import pathlib
import subprocess
import configparser

import setuptools
import setuptools.extension
import setuptools.command.build_ext
import Cython.Build

PROJ_CWD = pathlib.Path(__file__).parent
LIBPCRE2_CONFIG = PROJ_CWD.joinpath("libpcre2.cfg")

config = configparser.ConfigParser()
config.read(LIBPCRE2_CONFIG.resolve())

PCRE2_CWD = PROJ_CWD.joinpath(config["DEFAULT"]["CWD"])


class Pcre2BuildExt(setuptools.command.build_ext.build_ext):
    # PCRE2 build configuration.
    pcre2_src = PCRE2_CWD.joinpath("src")
    pcre2_static_lib = PCRE2_CWD.joinpath(".libs/libpcre2-8.a")
    pcre2_compile_args = ["-DPCRE2_CODE_UNIT_WIDTH=8"]
    pcre2_build_cmds = [
        [
            "./configure",
            "CFLAGS=-fPIC",
            "--enable-jit",
            "--enable-never-backslash-C",
            f"--prefix={PCRE2_CWD.resolve()}"
        ],
        ["make"]
    ]

    def run(self):
        # Run commands to build library if not already created.
        if not self.pcre2_static_lib.exists():
            for cmd in self.pcre2_build_cmds:
                subprocess.check_call(cmd, cwd=PCRE2_CWD, shell="bash")

        setuptools.command.build_ext.build_ext.run(self)


# Configure Cython extension.
ext_src = PROJ_CWD.joinpath("src/pcre2")
pcre2_extension = setuptools.extension.Extension(
    "pcre2.*",
    sources=[f"{str(ext_src)}/*.pyx"],
    include_dirs=[str(Pcre2BuildExt.pcre2_src)],
    extra_objects=[str(Pcre2BuildExt.pcre2_static_lib)],
    extra_compile_args=Pcre2BuildExt.pcre2_compile_args
)

cython_kwargs = {
    "language_level": "3"
}

# See setup.cfg for static metadata.
setuptools.setup(
    ext_modules=Cython.Build.cythonize([pcre2_extension], **cython_kwargs),
    cmdclass={"build_ext": Pcre2BuildExt}
)
