# -*- coding:utf-8 -*-

import skbuild
import setuptools


skbuild.setup(
    name = "pcre2",
    version = "0.0.1",
    description = "Python bindings for the PCRE2 regular expression library",
    license = "BSD 3-Clause License",
    author = "Garrett Tetrault",
    include_package_data=True,
    packages = setuptools.find_packages("src"),
    package_dir = {"": "src"},
    cmake_languages = "C",
)
