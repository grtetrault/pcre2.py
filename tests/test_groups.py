import pytest
import pcre2

def test_match_groups():
    assert pcre2.match('a', 'a').groups() == ()
    assert pcre2.match('(a)', 'a').groups() == ('a',)

    assert pcre2.match(b'a', b'a').groups() == ()
    assert pcre2.match(b'(a)', b'a').groups() == (b'a',)

    for a in ("\xe0", "\u0430", "\U0001d49c"):
        assert pcre2.match(a, a).groups() == ()
        assert pcre2.match('(%s)' % a, a).groups() == (a,)
