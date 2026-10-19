import importlib
from pathlib import Path
import shutil
import subprocess
import sys

import pcre2
import pytest


@pytest.fixture(scope="session")
def matcher_api(tmp_path_factory):
    """Compile a C consumer against the installed package and its header."""
    directory = tmp_path_factory.mktemp("matcher_api")
    shutil.copyfile(
        Path(__file__).with_name("_matcher_api_consumer.c"),
        directory / "_matcher_api_consumer.c",
    )
    header_directory = str(Path(pcre2.__file__).parent)
    assert (Path(header_directory) / "matcher_api.h").is_file()
    (directory / "setup.py").write_text(
        "from setuptools import Extension, setup\n"
        "setup(name='_matcher_api_consumer', ext_modules=[Extension(\n"
        "    '_matcher_api_consumer', ['_matcher_api_consumer.c'],\n"
        f"    include_dirs=[{header_directory!r}])])\n"
    )
    result = subprocess.run(
        [sys.executable, "setup.py", "build_ext", "--inplace"],
        cwd=directory,
        capture_output=True,
        text=True,
    )
    assert result.returncode == 0, result.stdout + result.stderr
    sys.path.insert(0, str(directory))
    try:
        yield importlib.import_module("_matcher_api_consumer")
    finally:
        sys.path.remove(str(directory))
