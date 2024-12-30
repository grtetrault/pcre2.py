import pytest
import pcre2


# All tests should match successfully.
test_data_match_bounds = [
    (b".*", "aba•ba••ba•••b".encode(), 0, 0, 0, 0, 26),
    (".*", "aba•ba••ba•••b", 0, 0, 0, 0, 14),
]
@pytest.mark.parametrize("pattern,subject,flags,pos,group,start,end", test_data_match_bounds)
def test_match_bounds(pattern, subject, flags, pos, group, start, end):
    p = pcre2.compile(pattern, flags=flags)
    m = p.match(subject, pos=pos)
    assert (m.start(group), m.end(group)) == (start, end)


test_data_match_substring = [
    (b".*", "aba•ba••ba•••b".encode(), 0, 0, "aba•ba••ba•••b".encode()),
    (".*", "aba•ba••ba•••b", 0, 0, "aba•ba••ba•••b"),
]
@pytest.mark.parametrize("pattern,subject,flags,pos,substring", test_data_match_substring)
def test_match_substring(pattern, subject, flags, pos, substring):
    p = pcre2.compile(pattern, flags=flags)
    m = p.match(subject, pos=pos)
    assert m[0] == substring


test_data_match_expand = [
    (b"[abc]*", b"", b"dabacbaccbacccb", 0, 0, b"dabacbaccbacccb"),
    ("[abc]*", "", "dabacbaccbacccb", 0, 0, "dabacbaccbacccb"),
    ("[abc]*", "", "dabacbaccbacccb", 0, 1, "d"),
]
@pytest.mark.parametrize(
    "pattern,replacement,subject,flags,pos,result", test_data_match_expand
)
def test_match_expand(pattern, replacement, subject, flags, pos, result):
    p = pcre2.compile(pattern, flags=flags)
    m = p.search(subject, pos=pos)
    assert m.expand(replacement) == result
