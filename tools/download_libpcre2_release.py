# -*- coding:utf-8 -*-

import typing
import shutil
import hashlib
import pathlib
import tarfile
import requests
import configparser


PROJ_CWD = pathlib.Path(__file__).parents[1]
LIBPCRE2_CONFIG = PROJ_CWD.joinpath("libpcre2.cfg")


def download_from_url(
    url: str, 
    dest: pathlib.Path,
    sha256: typing.Optional[str]=None,
    overwrite_dest: bool=False, 
    clean_unverified_downloads: bool=True,
    chunk_size: int=128
):
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

    if sha256 and download_sha256 != sha256:
        if clean_unverified_downloads:
            dest.unlink()
        raise Exception("Unverified download, computed SHA256 does not match given hash")


if __name__ == "__main__":
    config = configparser.ConfigParser()
    config.read(LIBPCRE2_CONFIG.resolve())

    # Create dependency directory and ensure it's empty.
    dest_dir = pathlib.Path(PROJ_CWD.joinpath(config["DEFAULT"]["DEST"]))
    if dest_dir.exists():
        shutil.rmtree(dest_dir)
    dest_dir.mkdir(parents=True, exist_ok=True)

    # Download and extract PCRE2 project tarball.
    section = config["DEFAULT"]["SECTION"]
    tarball_dest = dest_dir.joinpath(f"{section}.tar.gz")
    download_from_url(
        config[section]["TARBALL_URL"],
        tarball_dest,
        config[section]["TARBALL_HASH"],
        overwrite_dest=True)

    tarfile.open(tarball_dest, "r").extractall(dest_dir)
