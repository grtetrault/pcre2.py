import gc
import sys
import weakref
from concurrent.futures import ThreadPoolExecutor

import pcre2
from pcre2 import _cy
import pytest


@pytest.mark.parametrize("jit", [False, True])
@pytest.mark.parametrize(
    "pattern, subject, expected",
    [
        (r"^[A-Z]{2}$", "US", True),
        (r"^[A-Z]{2}$", "usa", False),
        (r"airport", "international airport", True),
        (r"airport", "station", False),
        (r"", "", True),
        (r"^a.b$", "a\0b", True),
        (r"\w+", "é日本", True),
        (r"^(a)(b)$", "ab", True),
        (r"a(?=b)", "ab", True),
        (r"^US$", "US\n", True),
        (r"^US$", "US\r\n", False),
        (rb"^a.b$", b"a\0b", True),
        (rb"^a.b$", bytearray(b"a\0b"), True),
        (rb"^a.b$", memoryview(b"a\0b"), True),
    ],
)
def test_search(matcher_api, jit, pattern, subject, expected):
    compiled = pcre2.compile(pattern, jit=jit)
    matcher = matcher_api.prepare(compiled)
    assert matcher_api.search(matcher, subject) is expected
    assert (compiled.search(subject) is not None) is expected


@pytest.mark.parametrize("jit", [False, True])
@pytest.mark.parametrize(
    "pattern, subject, exception",
    [
        ("x", b"x", TypeError),
        (b"x", "x", TypeError),
        ("x", 42, TypeError),
        ("x", "\ud800", UnicodeEncodeError),
        (rb"(*UTF).", b"\xff", pcre2.LibraryError),
        (r"(*LIMIT_MATCH=1)(a+)+$", "a" * 30 + "!", pcre2.LibraryError),
    ],
)
def test_errors_match_public_search(matcher_api, jit, pattern, subject, exception):
    compiled = pcre2.compile(pattern, jit=jit)
    matcher = matcher_api.prepare(compiled)
    with pytest.raises(exception) as public:
        compiled.search(subject)
    with pytest.raises(exception) as native:
        matcher_api.search(matcher, subject)
    assert str(native.value) == str(public.value)
    if isinstance(public.value, pcre2.LibraryError):
        assert native.value.code == public.value.code


def test_invalid_arguments(matcher_api):
    compiled = pcre2.compile("x")
    for invalid in [None, "x", object(), _cy.PCRE2Code.__new__(_cy.PCRE2Code)]:
        with pytest.raises(TypeError):
            matcher_api.prepare(invalid)
    with pytest.raises(TypeError):
        matcher_api.prepare(compiled, object)
    with pytest.raises(TypeError):
        matcher_api.prepare(compiled, _cy._BooleanMatcher, None)
    with pytest.raises(TypeError):
        matcher_api.search(object(), "x")
    with pytest.raises(TypeError):
        matcher_api.search(_cy._BooleanMatcher.__new__(_cy._BooleanMatcher), "x")
    with pytest.raises(TypeError):
        _cy._BooleanMatcher()
    broken = pcre2.compile("x")
    broken._pcre2_code = None
    with pytest.raises(TypeError):
        matcher_api.prepare(broken)


def test_callouts_rejected(matcher_api):
    def callout(block):
        raise AssertionError("No callout expected")

    compiled = pcre2.compile(r"x(?C1)", callout=callout)
    with pytest.raises(NotImplementedError, match="callouts"):
        matcher_api.prepare(compiled)


def test_compiled_code_snapshot(matcher_api):
    compiled = pcre2.compile("airport", jit=False)
    reference = weakref.ref(compiled)
    matcher = matcher_api.prepare(compiled)
    compiled.jit_compile()
    compiled._pcre2_code = pcre2.compile("station")._pcre2_code
    compiled.callout = lambda block: pcre2.CalloutReturn.ABORT
    del compiled
    gc.collect()
    assert reference() is None
    assert matcher_api.search(matcher, "airport") is True
    assert matcher_api.search(matcher, "station") is False


def test_provider_reference_released(matcher_api):
    compiled = pcre2.compile("x")
    # Initialize the consumer's retained module reference before measuring.
    matcher = matcher_api.prepare(compiled)
    del matcher
    gc.collect()
    before = sys.getrefcount(_cy)
    matchers = [matcher_api.prepare(compiled) for _ in range(100)]
    assert sys.getrefcount(_cy) == before + 100
    del matchers
    gc.collect()
    assert sys.getrefcount(_cy) == before


def test_subject_subclasses_and_reentry(matcher_api):
    matcher = matcher_api.prepare(pcre2.compile("x"))

    class Subject(str):
        def __str__(self):
            assert matcher_api.search(matcher, "x") is True
            return "no match"

    assert matcher_api.search(matcher, Subject("x")) is False

    class BinarySubject(bytes):
        def __bytes__(self):
            return b"no match"

    matcher = matcher_api.prepare(pcre2.compile(b"x"))
    assert matcher_api.search(matcher, BinarySubject(b"x")) is False


def test_reentry_while_reporting_engine_error(matcher_api, monkeypatch):
    compiled = pcre2.compile(rb"(*UTF).", jit=False)
    matcher = matcher_api.prepare(compiled)
    with pytest.raises(pcre2.LibraryError) as public:
        compiled.search(b"\xff")
    original = pcre2.LibraryError.__init__
    calls = []

    def initialize(error, *args, **kwargs):
        calls.append(matcher_api.search(matcher, b"x"))
        original(error, *args, **kwargs)

    monkeypatch.setattr(pcre2.LibraryError, "__init__", initialize)
    with pytest.raises(pcre2.LibraryError) as native:
        matcher_api.search(matcher, b"\xff")
    assert str(native.value) == str(public.value)
    assert native.value.code == public.value.code
    assert calls == [True]
    assert matcher_api.search(matcher, b"x") is True


def test_reuse_from_threads(matcher_api):
    matcher = matcher_api.prepare(pcre2.compile(r"^[A-Z]{2}$"))

    def check(_):
        for _ in range(100):
            assert matcher_api.search(matcher, "US") is True
            assert matcher_api.search(matcher, "usa") is False

    with ThreadPoolExecutor(max_workers=4) as pool:
        list(pool.map(check, range(16)))


def test_c_consumer_batch(matcher_api):
    compiled = pcre2.compile(r"^[A-Z]{2}$")
    matcher = matcher_api.prepare(compiled)
    subjects = ["US", "usa", "DE", "日本", "", "FR"]
    assert matcher_api.count_matches(matcher, subjects) == 3
    assert matcher_api.count_matches(compiled, subjects, True) == 3
    with pytest.raises(TypeError):
        matcher_api.count_matches(matcher, ["US", object()])
