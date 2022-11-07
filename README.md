# PCRE2.py: Python bindings for the PCRE2 regular expression library

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

Regular expressions are compiled with `pcre2.compile()` which accepts both unicode strings and bytes-like objects.
This returns a `Pattern` object.
Expressions can be compiled with a number of options (combined with the bitwise-or operator) and can be JIT compiled,

```python
>>> import pcre2
>>> expr = r'(?<head>\w+)\s+(?<tail>\w+)'
>>> patn = pcre2.compile(expr, options=pcre2.I, jit=True)
>>> patn.jit_compile()  # Patterns can also be JIT compiled after initialization.
```

Inspection of `Pattern` objects is done as follows,

```python
>>> patn.jit_size
980
>>> patn.name_dict()
{1: 'head', 2: 'tail'}
>>> patn.options
524296
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

Additionally, `Pattern` objects support for scanning over subjects for all non-overlapping matches,

```python
>>> for match in patn.scan(subj):
...     print(match.substring('head'))
...
foo
buzz
```

## Performance

PCRE2 provides aa fast regular expression library, particularly with JIT compilation enabled.
Below are the `regex-redux` benchmark results included in this repository,

| Script              | Number of runs | Total time | Real time  | User time   | System time   |
| ------------------- | -------------- | ---------- | ---------- | ----------- | ------------- |
| `vanilla.py `       |             10 |     51.470 |      5.147 |      11.409 |         0.533 |
| `hand_optimized.py` |             10 |     12.310 |      1.231 |       2.484 |         0.212 |
| `pcre2_module.py`   |             10 |     14.040 |      1.404 |       2.309 |         0.548 |
 
Tests were performed on an M2 Macbook Air.
For more information on this benchmark, see [The Computer Language Benchmarks Game](https://benchmarksgame-team.pages.debian.net/benchmarksgame/performance/regexredux.html).
See source code of benchmark scripts for details and original sources.
