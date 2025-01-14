# PCRE2.py: Python bindings for the PCRE2 regular expression library

This project contains Python bindings for [PCRE2](https://github.com/PCRE2Project/pcre2).
PCRE2 is the revised API for the Perl-compatible regular expressions (PCRE) library created by Philip Hazel.
For original source code, see the [official PCRE2 repository](https://github.com/PCRE2Project/pcre2).

## Installation

From PyPI:
```
pip install pcre2
```

If a wheel is not available for your platform, the module will be built from source.
Building requires:

* `cmake`
* C compiler toolchain, such as `gcc` and `make`
* `libtool`
* Python headers

## Usage

This library aims to be compatible with Python's built-in `re` module. In many cases, this means
that `pcre2` can drop-in replace `re` to gain some performance (see benchmarks below).
However, PCRE2 and Python implement different regex specifications, so patterns and behavior will
not always be translatable (e.g., the syntax for group replacement differs).

Regular expressions are compiled with `pcre2.compile()` which accepts both unicode strings and
bytes-like objects.
This returns a `Pattern` object.
Expressions can be compiled with a number of options (combined with the bitwise-or operator) and
can be JIT compiled,

```python
>>> import pcre2
>>> expr = r'(?<head>\w+)\s+(?<tail>\w+)'
>>> patn = pcre2.compile(expr, flags=pcre2.I, jit=True)
>>> # Patterns can also be JIT compiled after initialization.
>>> patn.jit_compile()
```

Inspection of `Pattern` objects is done as follows,

```python
>>> patn.jit
True
>>> patn.groupindex
{'head': 1, 'tail': 2}
>>> patn.flags
<CompileOption.IGNORECASE: 8>
```

Once compiled, `Pattern` objects can be used to match against strings.
Matching return a `Match` object, which has several functions to view results,

```python
>>> subj = 'foo bar buzz bazz'
>>> match = patn.match(subj)
>>> match[0]
'foo bar'
>>> match.span()
(0, 7)
```

Substitution is also supported, both from `Pattern` and `Match` objects,

```python
>>> repl = '$2 $1'
>>> patn.sub(repl, subj) # Global substitutions by default.
'bar foo bazz buzz'
>>> patn.sub(repl, subj, count=1)
'bar foo buzz bazz'
>>> match.expand(repl)
'bar foo'
```

Additionally, `Pattern` objects support scanning over subjects for all non-overlapping matches,

```python
>>> for match in patn.finditer(subj):
...     print(match.group('head'))
...
foo
buzz
```

## Performance

PCRE2 provides a fast regular expression library, particularly with JIT compilation enabled.
Below are the `regex-redux` benchmark results included in this repository,

| Script              | Number of runs | Total time | Real time  | User time   | System time   |
| ------------------- | -------------- | ---------- | ---------- | ----------- | ------------- |
| baseline.py         |             10 |      3.230 |      0.323 |       0.020 |         0.100 |
| re_vanilla.py       |             10 |     51.090 |      5.109 |      11.375 |         0.530 |
| pcre2_vanilla.py    |             10 |     21.980 |      2.198 |       3.154 |         0.483 |
| pcre2_optimized.py  |             10 |     14.860 |      1.486 |       2.520 |         0.548 |
| cffi_optimized.py   |             10 |     14.130 |      1.413 |       3.111 |         0.411 |
 
Script descriptions are as follows,

| Script              | Description                                                          |
| ------------------- | -------------------------------------------------------------------- |
| `baseline.py`       | Reads input file and outputs stored expected output                  |
| `re_vanilla.py`     | Pure Python version                                                  |
| `re_vanilla.py`     | Same as `re_vanilla.py`, with `pcre2` drop-in replacing `re`         |
| `pcre2_module.py`   | More optimized implementation using `pcre2`                          |
| `cffi_optimized.py` | Manually written Python `ctypes` bindings for shared PCRE2 C library |

Tests were performed on an M2 Macbook Air.
Note that to run benchmarks locally, [Git LFS](https://git-lfs.com/) must be installed to download the input dataset.
Additionally, a Python virtual environment must be created, and the package built
with `make init` and `make build` respectively.
For more information on this benchmark, see [The Computer Language Benchmarks Game](https://benchmarksgame-team.pages.debian.net/benchmarksgame/performance/regexredux.html).
See source code of benchmark scripts for details and original sources.
