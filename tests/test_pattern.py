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

def test_pattern_findall():
    p = pcre2.compile(r'(\w+)=(\d+)')
    assert p.findall('set width=20 and height=10') == [('width=20', 'width'), ('height=10', 'height')]
    s = bytes(range(128)).decode()
    p2 = pcre2.compile(r'[0-9--1]')
    assert p2.findall(s) == list('-./0123456789')
    p3 = pcre2.compile(r'[%--1]')
    assert p3.findall(s) == list("%&'()*+,-1")
    p4 = pcre2.compile(r'[%--]')
    assert p4.findall(s) == list("%&'()*+,-")
    p5 = pcre2.compile(r'[0-9&&1]')
    assert p5.findall(s) == list('&0123456789')
    p6 = pcre2.compile(r'[\d&&1]')
    assert p6.findall(s) == list('&0123456789')
    p7 = pcre2.compile(r'[0-9||a]')
    assert p7.findall(s) == list('0123456789a|')
    p8 = pcre2.compile(r'[\d||a]')
    assert p8.findall(s) == list('0123456789a|')
    p9 = pcre2.compile(r'[0-9~~1]')
    assert p9.findall(s) == list('0123456789~')
    p10 = pcre2.compile(r'[\d~~1]')
    assert p10.findall(s) == list('0123456789~')
    p11 = pcre2.compile(r'[[0-9]|]')
    assert p11.findall(s) == list('0123456789[]')

    for reps in '*', '+', '?', '{1}':
        for mod in '', '?':
            pattern = '.' + reps + mod + 'yz'
            assert pcre2.compile(pattern, pcre2.S).findall('xyz') == ['xyz'], pattern
            pattern = pattern.encode()
            assert pcre2.compile(pattern, pcre2.S).findall(b'xyz') == [b'xyz'], pattern


def test_pattern_jit_findall():
    assert pcre2.findall(r'(\w+)=(\d+)', 'set width=20 and height=10') == [('width=20', 'width'), ('height=10', 'height')]
    assert pcre2.findall(":+", "abc") == []
    assert pcre2.findall(":+", "a:b::c:::d") == [":", "::", ":::"]
    assert pcre2.findall("(:+)", "a:b::c:::d") == [":", "::", ":::"]

    for x in ("\xe0", "\u0430", "\U0001d49c"):
        xx = x * 2
        xxx = x * 3
        string = "a%sb%sc%sd" % (x, xx, xxx)
        assert pcre2.findall("%s+" % x, string) == [x, xx, xxx]
        assert pcre2.findall("(%s+)" % x, string) == [x, xx, xxx]

    assert len(pcre2.findall(r"\b", "a")) == 2
    assert len(pcre2.findall(r"\B", "a")) == 0
    assert len(pcre2.findall(r"\b", " ")) == 0
    assert len(pcre2.findall(r"\b", "   ")) == 0
    assert len(pcre2.findall(r"\B", " ")) == 2

    s = bytes(range(128)).decode()
    assert pcre2.findall(r'[--1]', s) ==  list('-./01')
    assert pcre2.findall(r'[&&1]', s) ==  list('&1')
    assert pcre2.findall(r'[||1]', s) ==  list('1|')
    assert pcre2.findall(r'[~~1]', s) ==  list('1~')

    assert pcre2.findall(r"(?i)(a)\1", "aa \u0100") == ['a']

    assert pcre2.findall(r'a++', 'aab') == ['aa']
    assert pcre2.findall(r'a*+', 'aab') == ['aa', '', '']
    assert pcre2.findall(r'a?+', 'aab') == ['a', 'a', '', '']
    assert pcre2.findall(r'a{1,3}+', 'aab') == ['aa']

    assert pcre2.findall(r'(?:ab)++', 'ababc') == ['abab']
    assert pcre2.findall(r'(?:ab)*+', 'ababc') == ['abab', '', '']
    assert pcre2.findall(r'(?:ab)?+', 'ababc') == ['ab', 'ab', '', '']
    assert pcre2.findall(r'(?:ab){1,3}+', 'ababc') == ['abab']

    assert pcre2.findall(r'(?>a+)', 'aab') == ['aa']
    assert pcre2.findall(r'(?>a*)', 'aab') == ['aa', '', '']
    assert pcre2.findall(r'(?>a?)', 'aab') == ['a', 'a', '', '']
    assert pcre2.findall(r'(?>a{1,3})', 'aab') == ['aa']

    assert pcre2.findall(r'(?>(?:ab)+)', 'ababc') == ['abab']
    assert pcre2.findall(r'(?>(?:ab)*)', 'ababc') == ['abab', '', '']
    assert pcre2.findall(r'(?>(?:ab)?)', 'ababc') == ['ab', 'ab', '', '']
    assert pcre2.findall(r'(?>(?:ab){1,3})', 'ababc') == ['abab']

    import re
    b = 'y\u2620y\u2620y'.encode('utf-8')
    assert len(pcre2.findall(re.escape('\u2620'.encode('utf-8')), b)) == 2


def test_pattern_split():
    pattern = "[\u002E\u3002\uFF0E\uFF61]"
    assert pcre2.compile(pattern).split("a.b.c") == ['a','b','c']


def test_pattern_jit_split():
    assert pcre2.split(":", ":a:b::c") == ['', 'a', 'b', '', 'c']
    assert pcre2.split(":+", ":a:b::c") == ['', 'a', 'b', 'c']
    assert pcre2.split("(:+)", ":a:b::c") == ['', ':', 'a', ':', 'b', '::', 'c']

    assert pcre2.split(b":", b":a:b::c") == [b'', b'a', b'b', b'', b'c']
    assert pcre2.split(b":+", b":a:b::c") == [b'', b'a', b'b', b'c']
    assert pcre2.split(b"(:+)", b":a:b::c") == [b'', b':', b'a', b':', b'b', b'::', b'c']

    for a, b, c in ("\xe0\xdf\xe7", "\u0430\u0431\u0432",
                    "\U0001d49c\U0001d49e\U0001d4b5"):
        string = ":%s:%s::%s" % (a, b, c)
        assert pcre2.split(":", string) == ['', a, b, '', c]
        assert pcre2.split(":+", string) == ['', a, b, c]
        assert pcre2.split("(:+)", string) == ['', ':', a, ':', b, '::', c]

    assert pcre2.split("(?::+)", ":a:b::c") == ['', 'a', 'b', 'c']
    assert pcre2.split("([b:]+)", ":a:b::c") == ['', ':', 'a', ':b::', 'c']
    assert pcre2.split("(?:b)|(?::+)", ":a:b::c") == ['', 'a', '', '', 'c']

    assert pcre2.split(":", ":a:b::c", 2) == ['', 'a', 'b::c']
    assert pcre2.split(":", ":a:b::c", maxsplit=2) == ['', 'a', 'b::c']
    assert pcre2.split(':', 'a:b:c:d', maxsplit=2) == ['a', 'b', 'c:d']
    assert pcre2.split("(:)", ":a:b::c", maxsplit=2) == ['', ':', 'a', ':', 'b::c']
    assert pcre2.split("(:+)", ":a:b::c", maxsplit=2) == ['', ':', 'a', ':', 'b::c']
