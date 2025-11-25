import pcre2
import pytest

# Adapt some useful assertions from Python's unittest + regex testing framework


def assert_typed_equal(actual, expect):
    assert actual == expect

    def recurse(actual, expect):
        if isinstance(expect, (tuple, list)):
            for x, y in zip(actual, expect):
                recurse(x, y)
        else:
            assert type(actual) is type(expect)

    recurse(actual, expect)


def assert_raises(expected_exception, fn, *args, **kwargs):
    with pytest.raises(expected_exception):
        fn(*args, **kwargs)


def check_pattern_error(pattern):
    with pytest.raises(pcre2.PatternError):
        pcre2.compile(pattern)


def check_template_error(pattern, repl, string):
    with pytest.raises(pcre2.LibraryError):
        pcre2.sub(pattern, repl, string)
