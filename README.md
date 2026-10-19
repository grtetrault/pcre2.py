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

Callout functions may be provided and will be called during matching whenever a `(?C<arg>)` is
encountered.
Callouts can control whether a match continues without impact, fails and begins looking for the
next match, or aborts the matching job entirely.
Functions are expected to take a `CalloutBlock` and return a `CalloutReturn`, e.g.,
```python
>>> def callout(callout_block: CalloutBlock):
...     print(callout_block.value + callout_block[0])
...     return CalloutReturn.PASS
...
>>> pcre2.search(r"\w+(?C'temp: ')(*FAIL)", "abc", flags=pcre2.O0, callout=callout)
temp: abc
temp: ab
temp: a
temp: bc
temp: b
temp: c
```

For a more in depth discussion on PCRE2 callouts - and on this particular use of callouts - read [this post from Rex Egg](https://www.rexegg.com/pcre-callouts.php).

## Boolean search from a C extension

C extensions that only need a match/no-match result can use the versioned capsule
`pcre2._cy._MATCHER_API_v1`. This avoids a Python `Pattern.search` call and a
`Match` object for each subject. Compile a normal `pcre2.Pattern` once, prepare a
matcher through the capsule, and reuse it. Existing Python methods are unchanged.

The installed package includes `matcher_api.h`. Add the directory containing
`pcre2.__file__` to the calling extension's include directories. No PCRE2 library
linking or PCRE2 pointer access is needed.

The API table contains:

* `abi_version` and `struct_size`, for compatibility checks.
* `matcher_type`, a borrowed type belonging to the provider module.
* `new_matcher(matcher_type, pattern, provider)`, returning a new owned Python
  reference, or `NULL` with an exception. `pattern` must be a compiled
  `pcre2.Pattern`; `provider` is the imported `pcre2._cy` module.
* `search(matcher, subject)`, returning `1` for a match, `0` for no match, or `-1`
  with an exception. It searches the whole subject, with no implicit anchoring,
  just like `Pattern.search(subject)` without position arguments. String and
  bytes-like subjects have the same normalization and type checks as that method.

For example, a calling extension can retain the provider, capsule and table in
its module state as follows:

```c
#include <Python.h>
#include "matcher_api.h"

typedef struct {
    PyObject *provider;
    PyObject *capsule;
    const Pcre2MatcherAPI *api;
} MatcherState;

/* Initialize a zeroed state. Clear it on failure or module teardown. */
static int
load_matcher_api(MatcherState *state)
{
    state->provider = PyImport_ImportModule("pcre2._cy");
    if (state->provider == NULL) return -1;
    state->capsule = PyObject_GetAttrString(state->provider, "_MATCHER_API_v1");
    if (state->capsule == NULL) return -1;
    state->api = PyCapsule_GetPointer(state->capsule, PCRE2_MATCHER_API_NAME);
    if (state->api == NULL) return -1;
    if (state->api->abi_version != PCRE2_MATCHER_API_VERSION ||
            state->api->struct_size < sizeof(Pcre2MatcherAPI) ||
            state->api->matcher_type == NULL ||
            state->api->new_matcher == NULL || state->api->search == NULL) {
        PyErr_SetString(PyExc_RuntimeError, "Incompatible pcre2 matcher API");
        return -1;
    }
    return 0;
}

static void
clear_matcher_api(MatcherState *state)
{
    state->api = NULL;
    Py_CLEAR(state->capsule);
    Py_CLEAR(state->provider);
}

/* `pattern` is a pcre2.Pattern supplied to the calling extension. */
static PyObject *
prepare_matcher(MatcherState *state, PyObject *pattern)
{
    return state->api->new_matcher(state->api->matcher_type, pattern, state->provider);
}

static PyObject *
check_subject(MatcherState *state, PyObject *matcher, PyObject *subject)
{
    int result = state->api->search(matcher, subject);
    if (result < 0) return NULL;
    return PyBool_FromLong(result);
}
```

Check every returned pointer before use and release each matcher with
`Py_DECREF`. Retain both the provider module and capsule while using the borrowed
API table or type, and include those references in the calling module's traversal
and cleanup. The table is read-only. Use it only in the interpreter where it was
obtained. All calls require non-NULL arguments and the GIL. Free-threaded Python
builds are unsupported, even with the GIL enabled at runtime; matcher preparation
and search raise `NotImplementedError` on those builds.

A matcher retains the compiled code present at preparation time, its provider,
and reusable match storage. Deleting the original `Pattern`, or replacing its
compiled code later, does not invalidate the matcher or change its pattern. JIT
code already attached to that compiled code is used normally. The GIL remains
held during native matching, and Python callout callbacks are unsupported. Calls sharing a matcher therefore reuse its match storage without
a lock. Compilation and matcher preparation are outside the per-subject path.

This API does not return captures or accept position/end-position arguments.
Patterns with callout callbacks are rejected with `NotImplementedError`. Existing
PCRE2 matching errors and subject-type errors are propagated as Python exceptions.

## Performance

PCRE2 provides a fast regular expression library, particularly with JIT compilation enabled.
Below are the `regex-redux` benchmark results included in this repository,

| Script              | Number of runs | Total time | Real time  | User time   | System time   |
| ------------------- | -------------- | ---------- | ---------- | ----------- | ------------- |
| baseline.py         |             10 |      3.000 |      0.300 |       0.020 |         0.110 |
| re_vanilla.py       |             10 |     49.650 |      4.965 |      10.582 |         0.571 |
| pcre2_vanilla.py    |             10 |     19.770 |      1.977 |       3.375 |         0.481 |
| pcre2_optimized.py  |             10 |     14.960 |      1.496 |       3.546 |         0.590 |
| cffi_optimized.py   |             10 |     13.350 |      1.335 |       3.930 |         0.381 |
 
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
