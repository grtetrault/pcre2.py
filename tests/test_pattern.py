import pytest
import pcre2
from pcre2.exceptions import CompileError, MatchError, LibraryError
from pcre2.consts import CompileOption, MatchOption, SubstituteOption


test_data_pattern_compile_success = [
    (b"a+b+c*d*", 0, "SUCCESS"),
    (b"(?<foo>a+b+)c*d*", 0, "SUCCESS"),
    (b"(?<foo>a+b+))c*d*", 0, "COMPILE_ERROR"),
    ("å+∫+ç*∂*".encode(), 0, "SUCCESS"),
    ("a+b+c*d*", 0, "SUCCESS"),
    ("(?<foo>a+b+)c*d*", 0, "SUCCESS"),
    ("(?<foo>a+b+))c*d*", 0, "COMPILE_ERROR"),
    ("(?<<foo>a+b+)c*d*", 0, "COMPILE_ERROR"),
    ("(?<foo>a+b+)c*d*(?<foo>a+b+)", 0, "COMPILE_ERROR"),
    ("(?<foo>a+b+)c*d*(?<foo>a+b+)", pcre2.CompileOption.DUPNAMES, "SUCCESS"),
    ("å+∫+ç*∂*", 0, "SUCCESS"),
    ("(?<ƒøø>a+b+)c*d*", 0, "SUCCESS"),
]
@pytest.mark.parametrize("pattern,options,return_code", test_data_pattern_compile_success)
def test_pattern_compile_success(pattern, options, return_code):
    try:
        p = pcre2.compile(pattern, options=options)
        rc = "SUCCESS"
        assert p.jit_size == 0
    except CompileError as e:
        rc = "COMPILE_ERROR"
    except LibraryError as e:
        rc = "LIB_ERROR"
    assert rc == return_code

@pytest.mark.parametrize("pattern,options,return_code", test_data_pattern_compile_success)
def test_pattern_jit_compile_success(pattern, options, return_code):
    try:
        p = pcre2.compile(pattern, options=options, jit=True)
        rc = "SUCCESS"
        assert p.jit_size > 0
    except CompileError as e:
        rc = "COMPILE_ERROR"
    except LibraryError as e:
        rc = "LIB_ERROR"
    assert rc == return_code


test_data_pattern_name_dict = [
    (b"(?<foo>a+b+)c*d*", 0, {1: b"foo"}),
    ("(?<foo>a+b+)c*d*", 0, {1: "foo"}),
    ("(?<ƒøø>a+b+)c*d*", 0, {1: "ƒøø"}),
    ("(?<foo>a+b+)c*d*(?<bar>a+b+)", 0, {1: "foo", 2: "bar"}),
    ("(?<foo>a+b+)c*(.+)d*(?<bar>a+b+)", 0, {1: "foo", 3: "bar"}),
    ("(?<foo>a+b+)c*d*(?<foo>a+b+)", pcre2.CompileOption.DUPNAMES, {1: "foo", 2: "foo"}),
]
@pytest.mark.parametrize("pattern,options,name_dict", test_data_pattern_name_dict)
def test_pattern_name_dict(pattern, options, name_dict):
    p = pcre2.compile(pattern, options=options)
    assert p.name_dict() == name_dict


test_data_pattern_match_success = [
    (b".*", b"abacbaccbacccb", 0, 0, "SUCCESS"),
    (".*", "abacbaccbacccb", 0, 0, "SUCCESS"),
    ("ac{3,}b", "abacbaccbacccb", 0, 0, "SUCCESS"),
    ("a•{3,}b", "aba•ba••ba•••b", 0, 0, "SUCCESS"),
    ("ab", "abacbaccbacccb", 0, 2, "MATCH_ERROR"),
    ("((((((((((((((()))))))))))))))", "", 0, 0, "SUCCESS"),
]
@pytest.mark.parametrize(
    "pattern,subject,options,offset,return_code", test_data_pattern_match_success
)
def test_pattern_match_success(pattern, subject, options, offset, return_code):
    p = pcre2.compile(pattern)
    try:
        m = p.match(subject, options=options, offset=offset)
        rc = "SUCCESS"
    except MatchError as e:
        rc = "MATCH_ERROR"
    except LibraryError as e:
        rc = "LIB_ERROR"
    assert rc == return_code


test_data_pattern_scan_length = [
    (b".+", b"abacbaccbacccb", 0, 1),
    (b".*", b"abacbaccbacccb", 0, 2),
    (".+", "abacbaccbacccb", 0, 1),
    (".*", "abacbaccbacccb", 0, 2),
    ("[abc]*", "dabacbaccbacccb", 0, 3),
    ("ac{2,}b", "abacbaccbacccb", 0, 2),
    ("a•{2,}b", "aba•ba••ba•••b", 0, 2),
    ("a•*b", "aba•ba••ba•••b", 0, 4),
    ("ab", "abacbaccbacccb", 2, 0),
]
@pytest.mark.parametrize(
    "pattern,subject,offset,iter_length", test_data_pattern_scan_length
)
def test_pattern_scan_length(pattern, subject, offset, iter_length):
    p = pcre2.compile(pattern)
    s = p.scan(subject, offset=offset)
    assert len(list(iter(s))) == iter_length


test_pattern_substitute = [
    (b"[abc]*", b"", b"dabacbaccbacccb", 0, 0, b"dabacbaccbacccb"),
    ("[abc]*", "", "dabacbaccbacccb", 0, 0, "dabacbaccbacccb"),
    ("[abc]*", "", "dabacbaccbacccb", 0, 1, "d"),
    ("a(•{2,})b", "a•b", "aba•ba••ba•••b", SubstituteOption.GLOBAL, 0, "aba•ba•ba•b"),
    ("a(•{2,})b", "a•b", "aba•ba••ba•••b", SubstituteOption.GLOBAL | SubstituteOption.REPLACEMENT_ONLY, 0, "a•ba•b"),
]
@pytest.mark.parametrize(
    "pattern,replacement,subject,options,offset,result", test_pattern_substitute
)
def test_pattern_substitute(pattern, replacement, subject, options, offset, result):
    p = pcre2.compile(pattern)
    assert p.substitute(replacement, subject, options=options, offset=offset) == result