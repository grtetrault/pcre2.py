# PCRE2.py: Python bindings for the PCRE2 regular expression library

:construction: **This project is currently under active development and still in planning stages.**  :construction:

This project contains Python bindings for [PCRE2](https://github.com/PCRE2Project/pcre2).
PCRE2 is the revised API for the Perl-compatible regular expressions (PCRE) library created by Philip Hazel.
For source code, see the [official PCRE2 repository](https://github.com/PCRE2Project/pcre2).

## Installation

From PyPI:
```
pip install pcre2
```

If a wheel is not available for your platform, the source for PCRE2 is downloaded over HTTP from [PCRE2 releases](https://github.com/PCRE2Project/pcre2/releases/) and built. Building requires:

* `autoconf`
* C compiler toolchain, such as `gcc` and `make`
* `libtool`
* Python headers

## Usage

PCRE2.py provides two primary objects, `Pattern` 

Patterns are compiled with `pcre2.compile()` which accepts both unicode strings and bytes-like objects.
Patterns can be compiled with a number of options (combined with the bitwise-or operator) and can be JIT compiled.

```python
>>> import pcre2
>>> expr = r"(?<head>\w+)\s+(?<tail>\w+)"
>>> patn = pcre2.compile(expr, options=pcre2.I, jit=True)
>>> patn.jit_compile()  # Patterns can also be JIT compiled after initialization.
```

### Pattern object

A `Pattern` object is returned from `pcre2.compile`, which provides several methods for using the compiled pattern:

### Match object

Some example usage below:
```python
>>> patn.name_dict()
{1: 'head', 2: 'tail'}
>> subj = "foo bar bazz buzz"
>>> match = patn.match(subj)
>>> match.substring()
'foo bar'
>>> for match in patn.scan(subj):
...     print(match.start(), match.end())
...
0 7
8 17
>>> patn.substitute("$2 $1", subj, options=pcre2.G)
'bar foo buzz bazz'
```

### Top-level methods

Several top-level methods are provided for ease of use



