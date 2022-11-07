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
    version = "0.0.1",
    description = "Python bindings for the PCRE2 regular expression library",
    long_description = get_long_desciption(),
    long_description_content_type = 'text/markdown',
    license = "BSD 3-Clause License",
    author = "Garrett Tetrault",
    include_package_data=True,
    packages = setuptools.find_packages("src"),
    package_dir = {"": "src"},
    cmake_languages = "C",
)
