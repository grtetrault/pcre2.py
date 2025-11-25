import pytest
import pcre2
import re


# All tests should match successfully.
test_data_match_bounds = [
    (b".*", "aba•ba••ba•••b".encode(), 0, 0, None, 0, 0, 26),
    (".*", "aba•ba••ba•••b", 0, 0, None, 0, 0, 14),
    (r"\w+", "b•", 0, 0, None, 0, 0, 1),
    (r"\w+", "b•", 0, None, None, 0, 0, 1),
    (r"\w+", "•b", 0, 1, None, 0, 1, 2),
    (r"\w+", "•bc", 0, 2, None, 0, 2, 3),
    (r"\w+", "•bc", 0, 1, 2, 0, 1, 2),
]


@pytest.mark.parametrize("pattern,subject,flags,pos,endpos,group,start,end", test_data_match_bounds)
def test_match_bounds(pattern, subject, flags, pos, endpos, group, start, end):
    p = pcre2.compile(pattern, flags=flags)
    kwargs = {}
    if endpos is not None:
        kwargs["endpos"] = endpos
    if pos is not None:
        kwargs["pos"] = pos
    m = p.match(subject, **kwargs)
    assert (m.start(group), m.end(group)) == (start, end)
    if endpos is not None:
        assert m.endpos == endpos
    if pos is not None:
        assert m.pos == pos


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
    (b"[abc]+", b"$0", b"dabacbaccbacccb", 0, 0, b"abacbaccbacccb"),
    ("[abc]+", "$0", "dabacbaccbacccb", 0, 0, "abacbaccbacccb"),
    ("[abc]+", "$0", "dabacbaccbacccb", 0, 10, "acccb"),
]


@pytest.mark.parametrize("pattern,replacement,subject,flags,pos,result", test_data_match_expand)
def test_match_expand(pattern, replacement, subject, flags, pos, result):
    p = pcre2.compile(pattern, flags=flags)
    m = p.search(subject, pos=pos)
    assert m.expand(replacement) == result
