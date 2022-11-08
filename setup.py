# -*- coding:utf-8 -*-

import os
import skbuild
import setuptools


def get_long_desciption():
    cwd = os.path.abspath(os.path.dirname(__file__))
    filename = os.path.join(cwd, "README.md")
    with open(filename) as f:
        long_description = f.read()

    return long_description


skbuild.setup(
    name = "pcre2",
    version = "0.1.0",
    description = "Python bindings for the PCRE2 regular expression library",
    long_description = get_long_desciption(),
    long_description_content_type = "text/markdown",
    license = "BSD 3-Clause License",
    author = "Garrett Tetrault",
    url = "https://github.com/grtetrault/pcre2.py",
    classifiers = [
        "Development Status :: 3 - Alpha",
        "Intended Audience :: Developers",
        "License :: OSI Approved :: BSD License",
        "Programming Language :: C",
        "Programming Language :: Cython",
        "Programming Language :: Python :: 3.6",
        "Programming Language :: Python :: 3.7",
        "Programming Language :: Python :: 3.8",
        "Programming Language :: Python :: 3.9",
        "Programming Language :: Python :: 3.10",
        "Programming Language :: Python :: 3.11",
        "Operating System :: MacOS :: MacOS X",
        "Operating System :: POSIX :: Linux",
        "Operating System :: Microsoft :: Windows"
    ],
    include_package_data=True,
    packages = setuptools.find_packages("src"),
    package_dir = {"": "src"},
    cmake_languages = "C",
)
