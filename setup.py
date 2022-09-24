# -*- coding:utf-8 -*-

import typing
import shutil
import hashlib
import pathlib
import tarfile
import requests
import subprocess

import setuptools
import setuptools.extension
import setuptools.command.build_ext
import Cython.Build

CWD = pathlib.Path(__file__).parent


# ========================= #
#         Utilities         #
# ========================= #

def download_from_url(
        url: str, 
        dest: pathlib.Path,
        sha256: typing.Optional[str]=None,
        overwrite_dest: bool=False, 
        clean_unverified_downloads: bool=True,
        chunk_size: int=128):
    """
    Download data from URL and store in given destination. Optionally validate
    download against a SHA256.
    """
    # Check for explicit option to overwrite destination.
    if dest.exists():
        if overwrite_dest:
            dest.unlink()
        else:
            raise ValueError("Destination path already exists")

    response = requests.get(url, stream=True)
    if response.status_code != 200:
        raise Exception(f"Download unsuccessful with status code: {response.status_code}")

    # Stream download to disc and compute hash.
    download_hasher = hashlib.sha256()
    with dest.open("wb") as f:
        for chunk in response.iter_content(chunk_size=chunk_size):
            f.write(chunk)
            download_hasher.update(chunk)
    download_sha256 = download_hasher.hexdigest()
    print(download_sha256)

    if sha256 and download_sha256 != sha256:
        if clean_unverified_downloads:
            dest.unlink()
        raise Exception("Unverified download, computed SHA256 does not match given hash")
   

# ==================================== #
#         Dependency constants         #
# ==================================== #

# Version and remote download location of PCRE2 to use.
PCRE2_VERSION = "10.40"
PCRE2_REPO_URL = "https://github.com/PCRE2Project/pcre2"
PCRE2_TARBALL_URL = f"{PCRE2_REPO_URL}/releases/download/pcre2-{PCRE2_VERSION}/pcre2-{PCRE2_VERSION}.tar.gz"

# SHA256 hashes of PCRE2 tarballs by version.
PCRE2_TARBALL_HASHTABLE = {
    "10.40": "ded42661cab30ada2e72ebff9e725e745b4b16ce831993635136f2ef86177724"
}
PCRE2_TARBALL_HASH = PCRE2_TARBALL_HASHTABLE[PCRE2_VERSION]


# ================================ #
#         Build extensions         #
# ================================ #

class Pcre2BuildExt(setuptools.command.build_ext.build_ext):
    deps_cwd = CWD.joinpath("deps").resolve()

    # PCRE2 download and extract configuration.
    pcre2_tarball_dest = deps_cwd.joinpath(f"pcre2-{PCRE2_VERSION}.tar.gz")
    pcre2_cwd = deps_cwd.joinpath(f"pcre2-{PCRE2_VERSION}")

    # PCRE2 build configuration.
    pcre2_src = pcre2_cwd.joinpath("src")
    pcre2_static_lib = pcre2_cwd.joinpath(".libs/libpcre2-8.a")
    pcre2_compile_args = ["-DPCRE2_CODE_UNIT_WIDTH=8"]
    pcre2_build_cmds = [
        [
            "./configure",
            "--enable-jit",
            "--enable-never-backslash-C",
            f"--prefix={pcre2_cwd}"
        ],
        ["make"]
    ]

    def run(self):
        # If static library is already created, then use this instead.
        if self.pcre2_static_lib.exists():
            setuptools.command.build_ext.build_ext.run(self)
            return

        # Create dependency directory and ensure it's empty.
        if self.deps_cwd.exists():
            shutil.rmtree(self.deps_cwd)
        self.deps_cwd.mkdir(parents=True, exist_ok=True)

        # Download and extract PCRE2 project tarball.
        download_from_url(
            PCRE2_TARBALL_URL,
            self.pcre2_tarball_dest,
            sha256=PCRE2_TARBALL_HASH,
            overwrite_dest=True)
        tarfile.open(self.pcre2_tarball_dest, "r").extractall(self.deps_cwd)

        # Run commands to build library.
        for cmd in self.pcre2_build_cmds:
            subprocess.check_call(cmd, cwd=self.pcre2_cwd)

        setuptools.command.build_ext.build_ext.run(self)


# ===================== #
#         Setup         #
# ===================== #

# Configure Cython extension.
ext_src = CWD.joinpath("pcre2")
pcre2_extension = setuptools.extension.Extension(
    "pcre2.*",
    sources=[f"{str(ext_src)}/*.pyx"],
    include_dirs=[str(Pcre2BuildExt.pcre2_src)],
    extra_objects=[str(Pcre2BuildExt.pcre2_static_lib)],
    extra_compile_args=Pcre2BuildExt.pcre2_compile_args
)

cython_kwargs = {
    "language_level": "3",
    "annotate": True,
    "compiler_directives": {"profile": True}
}

# See setup.cfg for static metadata.
setuptools.setup(
    ext_modules=Cython.Build.cythonize([pcre2_extension], **cython_kwargs),
    cmdclass={"build_ext": Pcre2BuildExt}
)
