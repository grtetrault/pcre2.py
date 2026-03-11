import pytest
import pcre2
import re


# All tests should match successfully.
test_data_noop_callout_match_bounds = [
    (b".*", "aba•ba••ba•••b".encode(), 0, 0, None, 0, 0, 26),
    (".*", "aba•ba••ba•••b", 0, 0, None, 0, 0, 14),
    (r"\w+", "b•", 0, 0, None, 0, 0, 1),
    (r"\w+", "b•", 0, None, None, 0, 0, 1),
    (r"\w+", "•b", 0, 1, None, 0, 1, 2),
    (r"\w+", "•bc", 0, 2, None, 0, 2, 3),
    (r"\w+", "•bc", 0, 1, 2, 0, 1, 2),
]


@pytest.mark.parametrize(
    "pattern,subject,flags,pos,endpos,group,start,end", test_data_noop_callout_match_bounds
)
def test_noop_callout_match_bounds(pattern, subject, flags, pos, endpos, group, start, end):
    def noop_callout(callout_block):
        callout_block[0]
        callout_block.span()
        callout_block.group(0)
        callout_block.groups()
        callout_block.groupdict()
        return pcre2.CalloutReturn.PASS

    p = pcre2.compile(pattern, flags=flags, callout=noop_callout)
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


test_data_callout_substring_count = [
    ("aba•ba••ba•••b".encode(), pcre2.O0),
    ("aba•ba••ba•••b", pcre2.O0),
    ("b•", pcre2.O0),
    ("b•", pcre2.O0),
    ("•b", pcre2.O0),
    ("•bc", pcre2.O0),
    ("•bc", pcre2.O0),
    ("•bc", pcre2.NOFLAG),
]


@pytest.mark.parametrize("subject,flags", test_data_callout_substring_count)
def test_callout_substring_count(subject, flags):
    pattern = r".+(?C'')(*FAIL)" if isinstance(subject, str) else rb".+(?C'')(*FAIL)"

    substrings = []

    def substring_count_callout(callout_block):
        substrings.append(callout_block[0])

    pcre2.search(pattern, subject, flags=pcre2.O0, callout=substring_count_callout)
    assert len(substrings) == len(subject) * (len(subject) + 1) / 2


def test_callout_block_persist():
    callout_blocks = []

    def persist_blocks_callout(callout_block):
        callout_blocks.append(callout_block)

    pcre2.search(r".+(?C'')(*FAIL)", "•bc", flags=pcre2.O0, callout=persist_blocks_callout)
    assert [block[0] for block in callout_blocks] == ["•bc", "•b", "•", "bc", "b", "c"]
