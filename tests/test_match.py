import pytest
import pcre2
from pcre2.exceptions import CompileError, MatchError, LibraryError
from pcre2.consts import CompileOption, MatchOption, SubstituteOption


# All tests should match successfully.
test_data_match_bounds = [
    (b".*", "aba•ba••ba•••b".encode(), 0, 0, 0, 0, 26),
    (".*", "aba•ba••ba•••b", 0, 0, 0, 0, 14),
]
@pytest.mark.parametrize("pattern,subject,options,offset,group,start,end", test_data_match_bounds)
def test_match_bounds(pattern, subject, options, offset, group, start, end):
    p = pcre2.compile(pattern)
    m = p.match(subject, options=options, offset=offset)
    assert (m.start(group), m.end(group)) == (start, end)


test_data_match_substring = [
    (b".*", "aba•ba••ba•••b".encode(), 0, 0, "aba•ba••ba•••b".encode()),
    (".*", "aba•ba••ba•••b", 0, 0, "aba•ba••ba•••b"),
]
@pytest.mark.parametrize("pattern,subject,options,offset,substring", test_data_match_substring)
def test_match_substring(pattern, subject, options, offset, substring):
    p = pcre2.compile(pattern)
    m = p.match(subject, options=options, offset=offset)
    assert m.substring() == substring


test_data_match_expand = [
    (b"[abc]*", b"", b"dabacbaccbacccb", 0, 0, b"dabacbaccbacccb"),
    ("[abc]*", "", "dabacbaccbacccb", 0, 0, "dabacbaccbacccb"),
    ("[abc]*", "", "dabacbaccbacccb", 0, 1, "d"),
]
@pytest.mark.parametrize(
    "pattern,replacement,subject,options,offset,result", test_data_match_expand
)
def test_match_expand(pattern, replacement, subject, options, offset, result):
    p = pcre2.compile(pattern)
    m = p.match(subject, options=options, offset=offset)
    assert m.expand(replacement) == result