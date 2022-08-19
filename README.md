# :construction: PCRE2.py: fast regular expressions, no ease-of-use sacrificed :construction:

:warning: **This project is currently under active development and still in planning stages.**

This project contains Python bindings for [PCRE2](https://github.com/PCRE2Project/pcre2)
with the goal of providing fast regular expression functionality.
The API design is inspired by Python's built-in [re module](https://docs.python.org/3/library/re.html) to minimize porting overhead.

## Perl compatible regular expressions

PCRE2 is the revised API for the Perl-compatible regular expressions, or PCRE, library created by Philip Hazel.
The library supports strings of 8-bit, 16-bit, or 32-bit code units, configured during compilation.
In the bindings provided here, however, **strings and bytes-like objects are interpreted as UTF-8 encoded Unicode**.
If your project requires 16-bit or 32-bit code unit support, the PCRE2 library will have to be built from source with the appropriate compilation options.
For more information, see the [PCRE2 build documentation](http://www.pcre.org/current/doc/html/pcre2build.html).

For source code, see the [official PCRE2 repository](https://github.com/PCRE2Project/pcre2).
The [PCRE2 license](https://github.com/PCRE2Project/pcre2/blob/master/LICENCE) is reproduced in the license provided by this project.

## Installation

If a wheel is not available for your platform, the source for PCRE2 is downloaded over HTTP from the [PCRE2 releases](https://github.com/PCRE2Project/pcre2/releases/) and built. Building requires:

* `autoconf`
* C compiler toolchain, such as `gcc` and `make`
* `libtool`
* Python headers

## Usage

