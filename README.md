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

Regular expressions are compiled with `pcre2.compile()` which accepts both unicode strings and bytes-like objects.
This returns a `Pattern` object.
Expressions can be compiled with a number of options (combined with the bitwise-or operator) and can be JIT compiled,

```python
>>> import pcre2
>>> expr = r'(?<head>\w+)\s+(?<tail>\w+)'
>>> patn = pcre2.compile(expr, options=pcre2.I, jit=True)
>>> # Patterns can also be JIT compiled after initialization.
>>> patn.jit_compile()
```

Inspection of `Pattern` objects is done as follows,

```python
>>> patn.jit_size
980
>>> patn.name_dict()
{1: 'head', 2: 'tail'}
>>> patn.options
524296
>>> # Deeper inspection into options is available.
>>> pcre2.CompileOption.decompose(patn.options)
[<CompileOption.CASELESS: 0x8>, <CompileOption.UTF: 0x80000>]
```

Once compiled, `Pattern` objects can be used to match against strings.
Matching return a `Match` object, which has several functions to view results,

```python
>>> subj = 'foo bar buzz bazz'
>>> match = patn.match(subj)
>>> match.substring()
'foo bar'
>>> match.start(), match.end()
(8, 17)
```

Substitution is also supported, both from `Pattern` and `Match` objects,

```python
>>> repl = '$2 $1'
>>> patn.substitute(repl, subj)
'bar foo buzz bazz'
>>> patn.substitute(repl, subj, options=pcre2.G) # Global substitutions are also supported.
'bar foo bazz buzz'
>>> match.expand(repl)
'bar foo buzz bazz'
```

Additionally, `Pattern` objects support scanning over subjects for all non-overlapping matches,

```python
>>> for match in patn.scan(subj):
...     print(match.substring('head'))
...
foo
buzz
```

## Performance

PCRE2 provides a fast regular expression library, particularly with JIT compilation enabled.
Below are the `regex-redux` benchmark results included in this repository,

| Script              | Number of runs | Total time | Real time  | User time   | System time   |
| ------------------- | -------------- | ---------- | ---------- | ----------- | ------------- |
| `baseline.py`       |             10 |      3.020 |      0.302 |       0.020 |         0.086 |
| `vanilla.py`        |             10 |     51.380 |      5.138 |      11.408 |         0.529 |
| `hand_optimized.py` |             10 |     13.190 |      1.319 |       2.846 |         0.344 |
| `pcre2_module.py`   |             10 |     13.670 |      1.367 |       2.269 |         0.532 |
 
Script descriptions are as follows,

| Script              | Description                                                          |
| ------------------- | -------------------------------------------------------------------- |
| `baseline.py`       | Reads input file and outputs stored expected output                  |
| `vanilla.py`        | Pure Python version                                                  |
| `hand_optimized.py` | Manually written Python `ctypes` bindings for shared PCRE2 C library |
| `pcre2_module.py`   | Implementation using Python bindings written here                    |

Tests were performed on an M2 Macbook Air.
Note that to run benchmarks locally, [Git LFS](https://git-lfs.com/) must be installed to download the input dataset.
Additionally, a Python virtual environment must be created, and the package built
with `make init` and `make build` respectively.
For more information on this benchmark, see [The Computer Language Benchmarks Game](https://benchmarksgame-team.pages.debian.net/benchmarksgame/performance/regexredux.html).
See source code of benchmark scripts for details and original sources.
