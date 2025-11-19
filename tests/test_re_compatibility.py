import pcre2 as re
import string
import multiprocessing
from weakref import proxy
import pytest

from tests.utils import (
    assert_raises,
    assert_typed_equal,
    check_pattern_error,
    check_template_error,
)

# This file is a modified version of the tests from CPython's regex test suite, meant to provide
# coverage for the built-in module's behavior. However, the intention is not to cover 100% of
# Python tests. Some functionality will remain different, such as the equality of compiled
# patterns. The goal is to cover enough of the API to make using PCRE2 feel like using the built-in
# module. For the tests included, you can find original versions in the link below (Python bug IDs
# are preserved for searching):
#     https://github.com/python/cpython/blob/3.14/Lib/test/test_re.py


class S(str):
    def __getitem__(self, index):
        return S(super().__getitem__(index))


class B(bytes):
    def __getitem__(self, index):
        return B(super().__getitem__(index))


def test_weakref():
    s = "QabbbcR"
    x = re.compile("ab+c")
    y = proxy(x)
    assert x.findall("QabbbcR") == y.findall("QabbbcR")


def test_search_star_plus():
    assert re.search("x*", "axx").span(0) == (0, 0)
    assert re.search("x*", "axx").span() == (0, 0)
    assert re.search("x+", "axx").span(0) == (1, 3)
    assert re.search("x+", "axx").span() == (1, 3)
    assert re.search("x", "aaa") is None
    assert re.match("a*", "xxx").span(0) == (0, 0)
    assert re.match("a*", "xxx").span() == (0, 0)
    assert re.match("x*", "xxxa").span(0) == (0, 3)
    assert re.match("x*", "xxxa").span() == (0, 3)
    assert re.match("a+", "xxx") is None


def test_branching():
    """Test Branching
    Test expressions using the OR ('|') operator."""
    assert re.match("(ab|ba)", "ab").span() == (0, 2)
    assert re.match("(ab|ba)", "ba").span() == (0, 2)
    assert re.match("(abc|bac|ca|cb)", "abc").span() == (0, 3)
    assert re.match("(abc|bac|ca|cb)", "bac").span() == (0, 3)
    assert re.match("(abc|bac|ca|cb)", "ca").span() == (0, 2)
    assert re.match("(abc|bac|ca|cb)", "cb").span() == (0, 2)
    assert re.match("((a)|(b)|(c))", "a").span() == (0, 1)
    assert re.match("((a)|(b)|(c))", "b").span() == (0, 1)
    assert re.match("((a)|(b)|(c))", "c").span() == (0, 1)


def bump_num(matchobj):
    int_value = int(matchobj.group(0))
    return str(int_value + 1)


def test_basic_re_sub():
    assert_typed_equal(re.sub("y", "a", "xyz"), "xaz")
    assert_typed_equal(re.sub("y", S("a"), S("xyz")), "xaz")
    assert_typed_equal(re.sub(b"y", b"a", b"xyz"), b"xaz")
    assert_typed_equal(re.sub(b"y", B(b"a"), B(b"xyz")), b"xaz")
    assert_typed_equal(re.sub(b"y", bytearray(b"a"), bytearray(b"xyz")), b"xaz")
    assert_typed_equal(re.sub(b"y", memoryview(b"a"), memoryview(b"xyz")), b"xaz")

    for y in ("\xe0", "\u0430", "\U0001d49c"):
        assert re.sub(y, "a", "x%sz" % y) == "xaz"

    assert re.sub("(?i)b+", "x", "bbbb BBBB") == "x x"
    assert re.sub(r"\d+", bump_num, "08.2 -2 23x99y") == "9.3 -3 24x100y"

    assert re.sub(r"\d+", bump_num, "08.2 -2 23x99y", count=3) == "9.3 -3 23x99y"

    assert re.sub(".", lambda m: r"\n", "x") == "\\n"
    assert re.sub(".", r"\n", "x") == "\n"

    s = r"\g<1>\g<1>"
    assert re.sub("(.)", s, "x") == "xx"
    assert re.sub("(.)", s.replace("\\", r"\\"), "x") == s
    assert re.sub("(.)", lambda m: s, "x") == s

    assert re.sub("(?P<a>x)", r"\g<a>\g<a>", "xx") == "xxxx"
    assert re.sub("(?P<a>x)", r"\g<a>\g<1>", "xx") == "xxxx"
    assert re.sub("(?P<unk>x)", r"\g<unk>\g<unk>", "xx") == "xxxx"
    assert re.sub("(?P<unk>x)", r"\g<1>\g<1>", "xx") == "xxxx"
    assert re.sub("()x", r"\g<0>\g<0>", "xx") == "xxxx"

    assert re.sub("a", r"\t\n\v\r\f\a\b", "a") == "\t\n\v\r\f\a\b"
    assert re.sub("a", "\t\n\v\r\f\a\b", "a") == "\t\n\v\r\f\a\b"
    assert re.sub("a", "\t\n\v\r\f\a\b", "a") == (
        chr(9) + chr(10) + chr(11) + chr(13) + chr(12) + chr(7) + chr(8)
    )

    # Note that we removed the reserved characters in PCRE2 extended substitution syntax
    for c in "cdhijkmopqswxyzABCDFGHIJKMNOPRSTVWXYZ":
        with pytest.raises(re.LibraryError):
            assert re.sub("a", "\\" + c, "a") == "\\" + c

    assert re.sub(r"^\s*", "X", "test") == "Xtest"


def test_bug_449964():
    # fails for group followed by other escape
    assert re.sub(r"(?P<unk>x)", r"\g<1>\g<1>\b", "xx") == "xx\bxx\b"


def test_bug_449000():
    # Test for sub() on escaped characters
    assert re.sub(r"\r\n", r"\n", "abc\r\ndef\r\n") == "abc\ndef\n"
    assert re.sub("\r\n", r"\n", "abc\r\ndef\r\n") == "abc\ndef\n"
    assert re.sub(r"\r\n", "\n", "abc\r\ndef\r\n") == "abc\ndef\n"
    assert re.sub("\r\n", "\n", "abc\r\ndef\r\n") == "abc\ndef\n"


def test_bug_1661():
    # Verify that flags do not get silently ignored with compiled patterns
    pattern = re.compile(".")
    assert_raises(ValueError, re.match, pattern, "A", re.I)
    assert_raises(ValueError, re.search, pattern, "A", re.I)
    assert_raises(ValueError, re.findall, pattern, "A", re.I)
    assert_raises(ValueError, re.compile, pattern, re.I)


def test_bug_3629():
    # A regex that triggered a bug in the sre-code validator
    re.compile("(?P<quote>)(?(quote))")


def test_sub_template_numeric_escape():
    # bug 776311 and friends
    assert re.sub("x", r"\0", "x") == "\0"
    assert re.sub("x", r"\000", "x") == "\000"
    assert re.sub("x", r"\001", "x") == "\001"
    assert re.sub("x", r"\008", "x") == "\0" + "8"
    assert re.sub("x", r"\009", "x") == "\0" + "9"
    assert re.sub("x", r"\111", "x") == "\111"
    assert re.sub("x", r"\117", "x") == "\117"
    assert re.sub("x", r"\377", "x") == "\377"

    assert re.sub("x", r"\1111", "x") == "\1111"
    assert re.sub("x", r"\1111", "x") == "\111" + "1"

    assert re.sub("x", r"\00", "x") == "\x00"
    assert re.sub("x", r"\07", "x") == "\x07"
    assert re.sub("x", r"\08", "x") == "\0" + "8"
    assert re.sub("x", r"\09", "x") == "\0" + "9"
    assert re.sub("x", r"\0a", "x") == "\0" + "a"

    # in python2.3 (etc), these loop endlessly in sre_parser.py

    assert re.sub("(((((((((((x)))))))))))", r"\11", "x") == "x"
    assert re.sub("((((((((((y))))))))))(.)", r"\11a", "xyz") == "xza"

    # Modified for different parsing behavior in PCRE2
    assert re.sub("((((((((((y))))))))))(.)", r"\g<11>8", "xyz") == "xz8"


def test_qualified_re_sub():
    assert re.sub("a", "b", "aaaaa") == "bbbbb"
    assert re.sub("a", "b", "aaaaa", count=1) == "baaaa"

    with pytest.raises(TypeError, match=r"sub\(\) got multiple values for argument 'count'"):
        re.sub("a", "b", "aaaaa", 1, count=1)
    with pytest.raises(TypeError, match=r"sub\(\) got multiple values for argument 'flags'"):
        re.sub("a", "b", "aaaaa", 1, 0, flags=0)
    with pytest.raises(
        TypeError, match=r"sub\(\) takes from 3 to 6 positional arguments but 7 were given"
    ):
        re.sub("a", "b", "aaaaa", 1, 0, False, 0)


def test_bug_114660():
    assert re.sub(r"(\S)\s+(\S)", r"\1 \2", "hello  there") == "hello there"


def test_symbolic_groups():
    re.compile(r"(?P<a>x)(?P=a)(?(a)y)")
    re.compile(r"(?P<a1>x)(?P=a1)(?(a1)y)")
    re.compile(r"(?P<a1>x)\1(?(1)y)")
    re.compile(b"(?P<a1>x)(?P=a1)(?(a1)y)")
    # New valid identifiers in Python 3
    re.compile("(?P<µ>x)(?P=µ)(?(µ)y)")
    re.compile("(?P<𝔘𝔫𝔦𝔠𝔬𝔡𝔢>x)(?P=𝔘𝔫𝔦𝔠𝔬𝔡𝔢)(?(𝔘𝔫𝔦𝔠𝔬𝔡𝔢)y)")
    # Support > 100 groups.
    pat = "|".join("x(?P<a%d>%x)y" % (i, i) for i in range(1, 200 + 1))
    pat = "(?:%s)(?(200)z|t)" % pat
    assert re.match(pat, "xc8yz").span() == (0, 5)


def test_symbolic_groups_errors():
    # This test originally tested error messages, but we only test failure of compilation as
    # messages are managed bt PCRE2
    check_pattern_error(r"(?P<a>)(?P<a>)")
    check_pattern_error(r"(?Pxy)")
    check_pattern_error(r"(?P<a>)(?P=a")
    check_pattern_error(r"(?P=")
    check_pattern_error(r"(?P=)aaaaaaaaaaaaaaa")
    check_pattern_error(r"(?P=1)")
    check_pattern_error(r"(?P=a)")
    check_pattern_error(r"(?P=a1)")
    check_pattern_error(r"(?P=a.)")
    check_pattern_error(r"(?P<)")
    check_pattern_error(r"(?P<a")
    check_pattern_error(r"(?P<")
    check_pattern_error(r"(?P<>)")
    check_pattern_error(r"(?P<1>)")
    check_pattern_error(r"(?P<a.>)")
    check_pattern_error(r"(?(")
    check_pattern_error(r"(?())")
    check_pattern_error(r"(?(a))")
    check_pattern_error(r"(?(-1))")
    check_pattern_error(r"(?(1a))")
    check_pattern_error(r"(?(a.))")
    check_pattern_error("(?P<©>x)")
    check_pattern_error("(?P=©)")
    check_pattern_error("(?(©)y)")
    check_pattern_error(b"(?P<\xc2\xb5>x)")
    check_pattern_error(b"(?P=\xc2\xb5)")
    check_pattern_error(b"(?(\xc2\xb5)y)")


def test_symbolic_refs():
    assert re.sub("(?P<a>x)|(?P<b>y)", r"\g<b>", "xx") == ""
    assert re.sub("(?P<a>x)|(?P<b>y)", r"\2", "xx") == ""
    assert re.sub(b"(?P<a1>x)", rb"\g<a1>", b"xx") == b"xx"
    # New valid identifiers in Python 3
    assert re.sub("(?P<µ>x)", r"\g<µ>", "xx") == "xx"
    assert re.sub("(?P<𝔘𝔫𝔦𝔠𝔬𝔡𝔢>x)", r"\g<𝔘𝔫𝔦𝔠𝔬𝔡𝔢>", "xx") == "xx"
    # Support > 100 groups.
    pat = "|".join("x(?P<a%d>%x)y" % (i, i) for i in range(1, 200 + 1))
    assert re.sub(pat, r"\g<200>", "xc8yzxc8y") == "c8zc8"


def test_symbolic_refs_errors():
    check_template_error("(?P<a>x)", r"\g<a", "xx")
    check_template_error("(?P<a>x)", r"\g<", "xx")
    check_template_error("(?P<a>x)", r"\g", "xx")
    check_template_error("(?P<a>x)", r"\g<a a>", "xx")
    check_template_error("(?P<a>x)", r"\g<>", "xx")
    check_template_error("(?P<a>x)", r"\g<1a1>", "xx")
    check_template_error("(?P<a>x)", r"\g<2>", "xx")
    check_template_error("(?P<a>x)", r"\2", "xx")
    check_template_error("(?P<a>x)", r"\g<ab>", "xx")
    check_template_error("(?P<a>x)", r"\g<-1>", "xx")
    check_template_error("(?P<a>x)", r"\g<+1>", "xx")
    check_template_error("()" * 10, r"\g<1_0>", "xx")
    check_template_error("(?P<a>x)", r"\g< 1 >", "xx")
    check_template_error("(?P<a>x)", r"\g<©>", "xx")
    check_template_error(b"(?P<a>x)", b"\\g<\xc2\xb5>", b"xx")
    check_template_error("(?P<a>x)", r"\g<㊀>", "xx")
    check_template_error("(?P<a>x)", r"\g<¹>", "xx")
    check_template_error("(?P<a>x)", r"\g<१>", "xx")


def test_re_subn():
    assert re.subn("(?i)b+", "x", "bbbb BBBB") == ("x x", 2)
    assert re.subn("b+", "x", "bbbb BBBB") == ("x BBBB", 1)
    assert re.subn("b+", "x", "xyz") == ("xyz", 0)
    assert re.subn("b*", "x", "xyz") == ("xxxyxzx", 4)
    assert re.subn("b*", "x", "xyz", count=2) == ("xxxyz", 2)

    with pytest.raises(TypeError):
        re.subn("a", "b", "aaaaa", 1, count=1)
    with pytest.raises(TypeError):
        re.subn("a", "b", "aaaaa", 1, 0, flags=0)


def test_re_split():
    for string in (":a:b::c", S(":a:b::c")):
        assert_typed_equal(re.split(":", string), ["", "a", "b", "", "c"])
        assert_typed_equal(re.split(":+", string), ["", "a", "b", "c"])
        assert_typed_equal(re.split("(:+)", string), ["", ":", "a", ":", "b", "::", "c"])
    for string in (b":a:b::c", B(b":a:b::c"), bytearray(b":a:b::c"), memoryview(b":a:b::c")):
        assert_typed_equal(re.split(b":", string), [b"", b"a", b"b", b"", b"c"])
        assert_typed_equal(re.split(b":+", string), [b"", b"a", b"b", b"c"])
        assert_typed_equal(re.split(b"(:+)", string), [b"", b":", b"a", b":", b"b", b"::", b"c"])
    for a, b, c in ("\xe0\xdf\xe7", "\u0430\u0431\u0432", "\U0001d49c\U0001d49e\U0001d4b5"):
        string = ":%s:%s::%s" % (a, b, c)
        assert re.split(":", string) == ["", a, b, "", c]
        assert re.split(":+", string) == ["", a, b, c]
        assert re.split("(:+)", string) == ["", ":", a, ":", b, "::", c]

    assert re.split("(?::+)", ":a:b::c") == ["", "a", "b", "c"]
    assert re.split("(:)+", ":a:b::c") == ["", ":", "a", ":", "b", ":", "c"]
    assert re.split("([b:]+)", ":a:b::c") == ["", ":", "a", ":b::", "c"]
    assert re.split("(b)|(:+)", ":a:b::c") == [
        "",
        None,
        ":",
        "a",
        None,
        ":",
        "",
        "b",
        None,
        "",
        None,
        "::",
        "c",
    ]
    assert re.split("(?:b)|(?::+)", ":a:b::c") == ["", "a", "", "", "c"]

    for sep, expected in [
        (":*", ["", "", "a", "", "b", "", "c", ""]),
        ("(?::*)", ["", "", "a", "", "b", "", "c", ""]),
        ("(:*)", ["", ":", "", "", "a", ":", "", "", "b", "::", "", "", "c", "", ""]),
        ("(:)*", ["", ":", "", None, "a", ":", "", None, "b", ":", "", None, "c", None, ""]),
    ]:
        assert_typed_equal(re.split(sep, ":a:b::c"), expected)

    for sep, expected in [
        ("", ["", ":", "a", ":", "b", ":", ":", "c", ""]),
        (r"\b", [":", "a", ":", "b", "::", "c", ""]),
        (r"(?=:)", ["", ":a", ":b", ":", ":c"]),
        (r"(?<=:)", [":", "a:", "b:", ":", "c"]),
    ]:
        assert_typed_equal(re.split(sep, ":a:b::c"), expected)


def test_qualified_re_split():
    assert re.split(":", ":a:b::c", maxsplit=2) == ["", "a", "b::c"]
    assert re.split(":", "a:b:c:d", maxsplit=2) == ["a", "b", "c:d"]
    assert re.split("(:)", ":a:b::c", maxsplit=2) == ["", ":", "a", ":", "b::c"]
    assert re.split("(:+)", ":a:b::c", maxsplit=2) == ["", ":", "a", ":", "b::c"]
    assert re.split("(:*)", ":a:b::c", maxsplit=2) == ["", ":", "", "", "a:b::c"]

    with pytest.raises(TypeError):
        re.split(":", ":a:b::c", 2, maxsplit=2)
    with pytest.raises(TypeError):
        re.split(":", ":a:b::c", 2, 0, flags=0)


def test_re_findall():
    assert re.findall(":+", "abc") == []
    for string in ("a:b::c:::d", S("a:b::c:::d")):
        assert_typed_equal(re.findall(":+", string), [":", "::", ":::"])
        assert_typed_equal(re.findall("(:+)", string), [":", "::", ":::"])
        assert_typed_equal(re.findall("(:)(:*)", string), [(":", ""), (":", ":"), (":", "::")])
    for string in (
        b"a:b::c:::d",
        B(b"a:b::c:::d"),
        bytearray(b"a:b::c:::d"),
        memoryview(b"a:b::c:::d"),
    ):
        assert_typed_equal(re.findall(b":+", string), [b":", b"::", b":::"])
        assert_typed_equal(re.findall(b"(:+)", string), [b":", b"::", b":::"])
        assert_typed_equal(
            re.findall(b"(:)(:*)", string), [(b":", b""), (b":", b":"), (b":", b"::")]
        )
    for x in ("\xe0", "\u0430", "\U0001d49c"):
        xx = x * 2
        xxx = x * 3
        string = "a%sb%sc%sd" % (x, xx, xxx)
        assert re.findall("%s+" % x, string) == [x, xx, xxx]
        assert re.findall("(%s+)" % x, string) == [x, xx, xxx]
        assert re.findall("(%s)(%s*)" % (x, x), string), [(x, ""), (x, x) == (x, xx)]


def test_bug_117612():
    assert re.findall(r"(a|(b))", "aba"), [("a", ""), ("b", "b") == ("a", "")]


def test_re_match():
    for string in ("a", S("a")):
        assert re.match("a", string).groups() == ()
        assert re.match("(a)", string).groups() == ("a",)
        assert re.match("(a)", string).group(0) == "a"
        assert re.match("(a)", string).group(1) == "a"
        assert re.match("(a)", string).group(1, 1) == ("a", "a")
    for string in (b"a", B(b"a"), bytearray(b"a"), memoryview(b"a")):
        assert re.match(b"a", string).groups() == ()
        assert re.match(b"(a)", string).groups() == (b"a",)
        assert re.match(b"(a)", string).group(0) == b"a"
        assert re.match(b"(a)", string).group(1) == b"a"
        assert re.match(b"(a)", string).group(1, 1) == (b"a", b"a")
    for a in ("\xe0", "\u0430", "\U0001d49c"):
        assert re.match(a, a).groups() == ()
        assert re.match("(%s)" % a, a).groups() == (a,)
        assert re.match("(%s)" % a, a).group(0) == a
        assert re.match("(%s)" % a, a).group(1) == a
        assert re.match("(%s)" % a, a).group(1, 1) == (a, a)

    pat = re.compile("((a)|(b))(c)?")
    assert pat.match("a").groups() == ("a", "a", None, None)
    assert pat.match("b").groups() == ("b", None, "b", None)
    assert pat.match("ac").groups() == ("a", "a", None, "c")
    assert pat.match("bc").groups() == ("b", None, "b", "c")
    assert pat.match("bc").groups("") == ("b", "", "b", "c")

    pat = re.compile("(?:(?P<a1>a)|(?P<b2>b))(?P<c3>c)?")
    assert pat.match("a").group(1, 2, 3) == ("a", None, None)
    assert pat.match("b").group("a1", "b2", "c3") == (None, "b", None)
    assert pat.match("ac").group(1, "b2", 3) == ("a", None, "c")


def test_group():
    class Index:
        def __init__(self, value):
            self.value = value

        def __index__(self):
            return self.value

    # A single group
    m = re.match("(a)(b)", "ab")
    assert m.group() == "ab"
    assert m.group(0) == "ab"
    assert m.group(1) == "a"
    assert m.group(Index(1)) == "a"
    assert_raises(IndexError, m.group, -1)
    assert_raises(IndexError, m.group, 3)
    assert_raises(IndexError, m.group, 1 << 1000)

    # Unclear why the below fails
    # assert_raises(IndexError, m.group, Index(1 << 1000))

    assert_raises(IndexError, m.group, "x")
    # Multiple groups
    assert m.group(2, 1) == ("b", "a")
    assert m.group(Index(2), Index(1)) == ("b", "a")


def test_match_getitem():
    pat = re.compile("(?:(?P<a1>a)|(?P<b2>b))(?P<c3>c)?")

    m = pat.match("a")
    assert m["a1"] == "a"
    assert m["b2"] == None
    assert m["c3"] == None
    assert "a1={a1} b2={b2} c3={c3}".format_map(m) == "a1=a b2=None c3=None"
    assert m[0] == "a"
    assert m[1] == "a"
    assert m[2] == None
    assert m[3] == None
    with pytest.raises(IndexError):
        m["X"]
    with pytest.raises(IndexError):
        m[-1]
    with pytest.raises(IndexError):
        m[4]
    with pytest.raises(IndexError):
        m[0, 1]
    with pytest.raises(IndexError):
        m[(0,)]
    with pytest.raises(IndexError):
        m[(0, 1)]
    with pytest.raises(IndexError):
        "a1={a2}".format_map(m)

    m = pat.match("ac")
    assert m["a1"] == "a"
    assert m["b2"] == None
    assert m["c3"] == "c"
    assert "a1={a1} b2={b2} c3={c3}".format_map(m) == "a1=a b2=None c3=c"
    assert m[0] == "ac"
    assert m[1] == "a"
    assert m[2] == None
    assert m[3] == "c"

    # Cannot assign.
    with pytest.raises(TypeError):
        m[0] = 1

    # No len().
    assert_raises(TypeError, len, m)


def test_re_fullmatch():
    # Issue 16203: Proposal: add re.fullmatch() method.
    assert re.fullmatch(r"a", "a").span() == (0, 1)
    for string in "ab", S("ab"):
        assert re.fullmatch(r"a|ab", string).span() == (0, 2)
    for string in (b"ab", B(b"ab"), bytearray(b"ab"), memoryview(b"ab")):
        assert re.fullmatch(rb"a|ab", string).span() == (0, 2)
    for a, b in "\xe0\xdf", "\u0430\u0431", "\U0001d49c\U0001d49e":
        r = r"%s|%s" % (a, a + b)
        assert re.fullmatch(r, a + b).span() == (0, 2)
    assert re.fullmatch(r".*?$", "abc").span() == (0, 3)
    assert re.fullmatch(r".*?", "abc").span() == (0, 3)
    assert re.fullmatch(r"a.*?b", "ab").span() == (0, 2)
    assert re.fullmatch(r"a.*?b", "abb").span() == (0, 3)
    assert re.fullmatch(r"a.*?b", "axxb").span() == (0, 4)
    assert re.fullmatch(r"a+", "ab") is None
    assert re.fullmatch(r"abc$", "abc\n") is None
    assert re.fullmatch(r"abc\z", "abc\n") is None
    assert re.fullmatch(r"abc\Z", "abc\n") is None
    assert re.fullmatch(r"(?m)abc$", "abc\n") is None
    assert re.fullmatch(r"ab(?=c)cd", "abcd").span() == (0, 4)
    assert re.fullmatch(r"ab(?<=b)cd", "abcd").span() == (0, 4)
    assert re.fullmatch(r"(?=a|ab)ab", "ab").span() == (0, 2)

    assert re.compile(r"bc").fullmatch("abcd", pos=1, endpos=3).span() == (1, 3)
    assert re.compile(r".*?$").fullmatch("abcd", pos=1, endpos=3).span() == (1, 3)
    assert re.compile(r".*?").fullmatch("abcd", pos=1, endpos=3).span() == (1, 3)


def test_re_groupref_exists():
    assert re.match(r"^(\()?([^()]+)(?(1)\))$", "(a)").groups() == ("(", "a")
    assert re.match(r"^(\()?([^()]+)(?(1)\))$", "a").groups() == (None, "a")
    assert re.match(r"^(\()?([^()]+)(?(1)\))$", "a)") is None
    assert re.match(r"^(\()?([^()]+)(?(1)\))$", "(a") is None
    assert re.match("^(?:(a)|c)((?(1)b|d))$", "ab").groups() == ("a", "b")
    assert re.match(r"^(?:(a)|c)((?(1)b|d))$", "cd").groups() == (None, "d")
    assert re.match(r"^(?:(a)|c)((?(1)|d))$", "cd").groups() == (None, "d")
    assert re.match(r"^(?:(a)|c)((?(1)|d))$", "a").groups() == ("a", "")

    # Tests for bug #1177831: exercise groups other than the first group
    p = re.compile("(?P<g1>a)(?P<g2>b)?((?(g2)c|d))")
    assert p.match("abc").groups() == ("a", "b", "c")
    assert p.match("ad").groups() == ("a", None, "d")
    assert p.match("abd") is None
    assert p.match("ac") is None

    # Support > 100 groups.
    pat = "|".join("x(?P<a%d>%x)y" % (i, i) for i in range(1, 200 + 1))
    pat = "(?:%s)(?(200)z)" % pat
    assert re.match(pat, "xc8yz").span() == (0, 5)


def test_re_groupref_exists_errors():
    check_pattern_error(r"(?P<a>)(?(0)a|b)")
    check_pattern_error(r"()(?(+1)a|b)")
    check_pattern_error(r"()" * 10 + r"(?(1_0)a|b)")
    check_pattern_error(r"()(?( 1 )a|b)")
    check_pattern_error(r"()(?(㊀)a|b)")
    check_pattern_error(r"()(?(¹)a|b)")
    check_pattern_error(r"()(?(१)a|b)")
    check_pattern_error(r"()(?(1")
    check_pattern_error(r"()(?(1)a")
    check_pattern_error(r"()(?(1)a|b")
    check_pattern_error(r"()(?(1)a|b|c")
    check_pattern_error(r"()(?(1)a|b|c)")
    check_pattern_error(r"()(?(2)a)")


def test_re_groupref_exists_validation_bug():
    for i in range(256):
        re.compile(r"()(?(1)\x%02x?)" % i)


def test_re_groupref():
    assert re.match(r"^(\|)?([^()]+)\1$", "|a|").groups() == ("|", "a")
    assert re.match(r"^(\|)?([^()]+)\1?$", "a").groups() == (None, "a")
    assert re.match(r"^(\|)?([^()]+)\1$", "a|") is None
    assert re.match(r"^(\|)?([^()]+)\1$", "|a") is None
    assert re.match(r"^(?:(a)|c)(\1)$", "aa").groups() == ("a", "a")
    assert re.match(r"^(?:(a)|c)(\1)?$", "c").groups() == (None, None)


def test_groupdict():
    assert re.match("(?P<first>first) (?P<second>second)", "first second").groupdict() == {
        "first": "first",
        "second": "second",
    }


def test_expand():
    assert (
        re.match("(?P<first>first) (?P<second>second)", "first second").expand(
            r"\2 \1 \g<second> \g<first>"
        )
        == "second first second first"
    )
    assert re.match("(?P<first>first)|(?P<second>second)", "first").expand(r"\2 \g<second>") == " "


def test_repeat_minmax():
    assert re.match(r"^(\w){1}$", "abc") is None
    assert re.match(r"^(\w){1}?$", "abc") is None
    assert re.match(r"^(\w){1,2}$", "abc") is None
    assert re.match(r"^(\w){1,2}?$", "abc") is None

    assert re.match(r"^(\w){3}$", "abc").group(1) == "c"
    assert re.match(r"^(\w){1,3}$", "abc").group(1) == "c"
    assert re.match(r"^(\w){1,4}$", "abc").group(1) == "c"
    assert re.match(r"^(\w){3,4}?$", "abc").group(1) == "c"
    assert re.match(r"^(\w){3}?$", "abc").group(1) == "c"
    assert re.match(r"^(\w){1,3}?$", "abc").group(1) == "c"
    assert re.match(r"^(\w){1,4}?$", "abc").group(1) == "c"
    assert re.match(r"^(\w){3,4}?$", "abc").group(1) == "c"

    assert re.match(r"^x{1}$", "xxx") is None
    assert re.match(r"^x{1}?$", "xxx") is None
    assert re.match(r"^x{1,2}$", "xxx") is None
    assert re.match(r"^x{1,2}?$", "xxx") is None

    assert re.match(r"^x{3}$", "xxx")
    assert re.match(r"^x{1,3}$", "xxx")
    assert re.match(r"^x{3,3}$", "xxx")
    assert re.match(r"^x{1,4}$", "xxx")
    assert re.match(r"^x{3,4}?$", "xxx")
    assert re.match(r"^x{3}?$", "xxx")
    assert re.match(r"^x{1,3}?$", "xxx")
    assert re.match(r"^x{1,4}?$", "xxx")
    assert re.match(r"^x{3,4}?$", "xxx")

    assert re.match(r"^x{}$", "xxx") is None
    assert re.match(r"^x{}$", "x{}")

    check_pattern_error(r"x{2,1}")


def test_getattr():
    assert re.compile("(?i)(a)(b)").pattern == "(?i)(a)(b)"
    # assert re.compile("(?i)(a)(b)").flags ==  re.I | re.U  # TODO: Look into why not
    assert re.compile("(?i)(a)(b)").groups == 2
    assert re.compile("(?i)(a)(b)").groupindex == {}
    assert re.compile("(?i)(?P<first>a)(?P<other>b)").groupindex == {"first": 1, "other": 2}

    assert re.match("(a)", "a").pos == 0
    assert re.match("(a)", "a").endpos == 1
    assert re.match("(a)", "a").string == "a"
    assert re.match("(a)", "a").re

    # Issue 14260. groupindex should be non-modifiable mapping.
    p = re.compile(r"(?i)(?P<first>a)(?P<other>b)")
    assert sorted(p.groupindex) == ["first", "other"]
    assert p.groupindex["other"] == 2

    with pytest.raises(TypeError):
        p.groupindex["other"] = 0

    assert p.groupindex["other"] == 2


def test_special_escapes():
    assert re.search(r"\b(b.)\b", "abcd abc bcd bx").group(1) == "bx"
    assert re.search(r"\B(b.)\B", "abc bcd bc abxd").group(1) == "bx"

    # TODO: Add ASCII
    assert re.search(r"\b(b.)\b", "abcd abc bcd bx", re.ASCII).group(1) == "bx"
    assert re.search(r"\B(b.)\B", "abc bcd bc abxd", re.ASCII).group(1) == "bx"

    assert re.search(r"^abc$", "\nabc\n", re.M).group(0) == "abc"
    assert re.search(r"^\Aabc\z$", "abc", re.M).group(0) == "abc"
    assert re.search(r"^\Aabc\z$", "\nabc\n", re.M) is None
    assert re.search(r"^\Aabc\Z$", "abc", re.M).group(0) == "abc"
    assert re.search(r"^\Aabc\Z$", "\nabc\n", re.M) is None
    assert re.search(rb"\b(b.)\b", b"abcd abc bcd bx").group(1) == b"bx"
    assert re.search(rb"\B(b.)\B", b"abc bcd bc abxd").group(1) == b"bx"
    assert re.search(rb"^abc$", b"\nabc\n", re.M).group(0) == b"abc"
    assert re.search(rb"^\Aabc\z$", b"abc", re.M).group(0) == b"abc"
    assert re.search(rb"^\Aabc\z$", b"\nabc\n", re.M) is None
    assert re.search(rb"^\Aabc\Z$", b"abc", re.M).group(0) == b"abc"
    assert re.search(rb"^\Aabc\Z$", b"\nabc\n", re.M) is None
    assert re.search(r"\d\D\w\W\s\S", "1aa! a").group(0) == "1aa! a"
    assert re.search(rb"\d\D\w\W\s\S", b"1aa! a").group(0) == b"1aa! a"
    assert re.search(r"\d\D\w\W\s\S", "1aa! a", re.ASCII).group(0) == "1aa! a"


def test_other_escapes():
    check_pattern_error("\\")

    assert re.match(r"\(", "(").group() == "("
    assert re.match(r"\(", ")") is None
    assert re.match(r"\\", "\\").group() == "\\"
    assert re.match(r"[\]]", "]").group() == "]"
    assert re.match(r"[\]]", "[") is None
    assert re.match(r"[a\-c]", "-").group() == "-"
    assert re.match(r"[a\-c]", "b") is None
    assert re.match(r"[\^a]+", "a^").group() == "a^"
    assert re.match(r"[\^a]+", "b") is None

    for c in "cijlmopqyCFIJLMOPTY":
        check_pattern_error("\\%c" % c)
    for c in "cijlmopqyzABCFIJLMOPTYZ":
        check_pattern_error("[\\%c]" % c)


def test_word_boundaries():
    # See http://bugs.python.org/issue10713
    assert re.search(r"\b(abc)\b", "abc").group(1) == "abc"
    assert re.search(r"\b(abc)\b", "abc", re.ASCII).group(1) == "abc"
    assert re.search(rb"\b(abc)\b", b"abc").group(1) == b"abc"
    assert re.search(r"\b(ьюя)\b", "ьюя").group(1) == "ьюя"
    assert re.search(r"\b(ьюя)\b", "ьюя", re.ASCII) is None
    # There's a word boundary between a word and a non-word.
    assert re.match(r".\b", "a=")
    assert re.match(r".\b", "a=", re.ASCII)
    assert re.match(rb".\b", b"a=")
    assert re.match(r".\b", "я=")
    assert re.match(r".\b", "я=", re.ASCII) is None
    # There's a word boundary between a non-word and a word.
    assert re.match(r".\b", "=a")
    assert re.match(r".\b", "=a", re.ASCII)
    assert re.match(rb".\b", b"=a")
    assert re.match(r".\b", "=я")
    assert re.match(r".\b", "=я", re.ASCII) is None
    # There is no word boundary inside a word.
    assert re.match(r".\b", "ab") is None
    assert re.match(r".\b", "ab", re.ASCII) is None
    assert re.match(rb".\b", b"ab") is None
    assert re.match(r".\b", "юя") is None
    assert re.match(r".\b", "юя", re.ASCII) is None
    # There is no word boundary between a non-word characters.
    assert re.match(r".\b", "=-") is None
    assert re.match(r".\b", "=-", re.ASCII) is None
    assert re.match(rb".\b", b"=-") is None
    # There is no non-boundary match between a word and a non-word.
    assert re.match(r".\B", "a=") is None
    assert re.match(r".\B", "a=", re.ASCII) is None
    assert re.match(rb".\B", b"a=") is None
    assert re.match(r".\B", "я=") is None
    assert re.match(r".\B", "я=", re.ASCII)
    # There is no non-boundary match between a non-word and a word.
    assert re.match(r".\B", "=a") is None
    assert re.match(r".\B", "=a", re.ASCII) is None
    assert re.match(rb".\B", b"=a") is None
    assert re.match(r".\B", "=я") is None
    assert re.match(r".\B", "=я", re.ASCII)
    # There's a non-boundary match inside a word.
    assert re.match(r".\B", "ab")
    assert re.match(r".\B", "ab", re.ASCII)
    assert re.match(rb".\B", b"ab")
    assert re.match(r".\B", "юя")
    assert re.match(r".\B", "юя", re.ASCII)
    # There's a non-boundary match between a non-word characters.
    assert re.match(r".\B", "=-")
    assert re.match(r".\B", "=-", re.ASCII)
    assert re.match(rb".\B", b"=-")
    # There's a word boundary at the start of a string.
    assert re.match(r"\b", "abc")
    assert re.match(r"\b", "abc", re.ASCII)
    assert re.match(rb"\b", b"abc")
    assert re.match(r"\b", "ьюя")
    assert re.match(r"\b", "ьюя", re.ASCII) is None
    # There's a word boundary at the end of a string.
    assert re.fullmatch(r".+\b", "abc")
    assert re.fullmatch(r".+\b", "abc", re.ASCII)
    assert re.fullmatch(rb".+\b", b"abc")
    assert re.fullmatch(r".+\b", "ьюя")
    assert re.search(r"\b", "ьюя", re.ASCII) is None
    # A non-empty string includes a non-boundary zero-length match.
    assert re.search(r"\B", "abc").span() == (1, 1)
    assert re.search(r"\B", "abc", re.ASCII).span() == (1, 1)
    assert re.search(rb"\B", b"abc").span() == (1, 1)
    assert re.search(r"\B", "ьюя").span() == (1, 1)
    assert re.search(r"\B", "ьюя", re.ASCII).span() == (0, 0)
    # There is no non-boundary match at the start of a string.
    assert re.match(r"\B", "abc") is None
    assert re.match(r"\B", "abc", re.ASCII) is None
    assert re.match(rb"\B", b"abc") is None
    assert re.match(r"\B", "ьюя") is None
    assert re.match(r"\B", "ьюя", re.ASCII)
    # There is no non-boundary match at the end of a string.
    assert re.fullmatch(r".+\B", "abc") is None
    assert re.fullmatch(r".+\B", "abc", re.ASCII) is None
    assert re.fullmatch(rb".+\B", b"abc") is None
    assert re.fullmatch(r".+\B", "ьюя") is None
    assert re.fullmatch(r".+\B", "ьюя", re.ASCII)
    # However, an empty string contains no word boundaries.
    assert re.search(r"\b", "") is None
    assert re.search(r"\b", "", re.ASCII) is None
    assert re.search(rb"\b", b"") is None
    assert re.search(r"\B", "")
    assert re.search(r"\B", "", re.ASCII)
    assert re.search(rb"\B", b"")
    # A single word-character string has two boundaries, but no
    # non-boundary gaps.
    assert len(re.findall(r"\b", "a")) == 2
    assert len(re.findall(r"\b", "a", re.ASCII)) == 2
    assert len(re.findall(rb"\b", b"a")) == 2
    assert len(re.findall(r"\B", "a")) == 0
    assert len(re.findall(r"\B", "a", re.ASCII)) == 0
    assert len(re.findall(rb"\B", b"a")) == 0
    # If there are no words, there are no boundaries
    assert len(re.findall(r"\b", " ")) == 0
    assert len(re.findall(r"\b", " ", re.ASCII)) == 0
    assert len(re.findall(rb"\b", b" ")) == 0
    assert len(re.findall(r"\b", "   ")) == 0
    assert len(re.findall(r"\b", "   ", re.ASCII)) == 0
    assert len(re.findall(rb"\b", b"   ")) == 0
    # Can match around the whitespace.
    assert len(re.findall(r"\B", " ")) == 2
    assert len(re.findall(r"\B", " ", re.ASCII)) == 2
    assert len(re.findall(rb"\B", b" ")) == 2


def test_bigcharset():
    assert re.match("([\u2222\u2223])", "\u2222").group(1) == "\u2222"


def test_big_codesize():
    # Issue #1160
    r = re.compile("|".join(("%d" % x for x in range(5000))))
    assert r.match("1000")
    assert r.match("9999")


def test_anyall():
    assert re.match("a.b", "a\nb", re.DOTALL).group(0) == "a\nb"
    assert re.match("a.*b", "a\n\nb", re.DOTALL).group(0) == "a\n\nb"


def test_lookahead():
    assert re.match(r"(a(?=\s[^a]))", "a b").group(1) == "a"
    assert re.match(r"(a(?=\s[^a]*))", "a b").group(1) == "a"
    assert re.match(r"(a(?=\s[abc]))", "a b").group(1) == "a"
    assert re.match(r"(a(?=\s[abc]*))", "a bc").group(1) == "a"
    assert re.match(r"(a)(?=\s\1)", "a a").group(1) == "a"
    assert re.match(r"(a)(?=\s\1*)", "a aa").group(1) == "a"
    assert re.match(r"(a)(?=\s(abc|a))", "a a").group(1) == "a"

    assert re.match(r"(a(?!\s[^a]))", "a a").group(1) == "a"
    assert re.match(r"(a(?!\s[abc]))", "a d").group(1) == "a"
    assert re.match(r"(a)(?!\s\1)", "a b").group(1) == "a"
    assert re.match(r"(a)(?!\s(abc|a))", "a b").group(1) == "a"

    # Group reference.
    assert re.match(r"(a)b(?=\1)a", "aba")
    assert re.match(r"(a)b(?=\1)c", "abac") is None
    # Conditional group reference.
    assert re.match(r"(?:(a)|(x))b(?=(?(2)x|c))c", "abc")
    assert re.match(r"(?:(a)|(x))b(?=(?(2)c|x))c", "abc") is None
    assert re.match(r"(?:(a)|(x))b(?=(?(2)x|c))c", "abc")
    assert re.match(r"(?:(a)|(x))b(?=(?(1)b|x))c", "abc") is None
    assert re.match(r"(?:(a)|(x))b(?=(?(1)c|x))c", "abc")
    # Group used before defined.
    assert re.match(r"(a)b(?=(?(2)x|c))(c)", "abc")
    assert re.match(r"(a)b(?=(?(2)b|x))(c)", "abc") is None
    assert re.match(r"(a)b(?=(?(1)c|x))(c)", "abc")


def test_lookbehind():
    assert re.match(r"ab(?<=b)c", "abc")
    assert re.match(r"ab(?<=c)c", "abc") is None
    assert re.match(r"ab(?<!b)c", "abc") is None
    assert re.match(r"ab(?<!c)c", "abc")
    # Group reference.
    assert re.match(r"(a)a(?<=\1)c", "aac")
    assert re.match(r"(a)b(?<=\1)a", "abaa") is None
    assert re.match(r"(a)a(?<!\1)c", "aac") is None
    assert re.match(r"(a)b(?<!\1)a", "abaa")
    # Conditional group reference.
    assert re.match(r"(?:(a)|(x))b(?<=(?(2)x|c))c", "abc") is None
    assert re.match(r"(?:(a)|(x))b(?<=(?(2)b|x))c", "abc") is None
    assert re.match(r"(?:(a)|(x))b(?<=(?(2)x|b))c", "abc")
    assert re.match(r"(?:(a)|(x))b(?<=(?(1)c|x))c", "abc") is None
    assert re.match(r"(?:(a)|(x))b(?<=(?(1)b|x))c", "abc")
    # Group used before defined.
    assert re.match(r"(a)b(?<=(?(1)c|x))(c)", "abc") is None
    assert re.match(r"(a)b(?<=(?(1)b|x))(c)", "abc")


def test_ignore_case():
    assert re.match("abc", "ABC", re.I).group(0) == "ABC"
    assert re.match(b"abc", b"ABC", re.I).group(0) == b"ABC"
    assert re.match(r"(a\s[^a])", "a b", re.I).group(1) == "a b"
    assert re.match(r"(a\s[^a]*)", "a bb", re.I).group(1) == "a bb"
    assert re.match(r"(a\s[abc])", "a b", re.I).group(1) == "a b"
    assert re.match(r"(a\s[abc]*)", "a bb", re.I).group(1) == "a bb"
    assert re.match(r"((a)\s\2)", "a a", re.I).group(1) == "a a"
    assert re.match(r"((a)\s\2*)", "a aa", re.I).group(1) == "a aa"
    assert re.match(r"((a)\s(abc|a))", "a a", re.I).group(1) == "a a"
    assert re.match(r"((a)\s(abc|a)*)", "a aa", re.I).group(1) == "a aa"

    # Two different characters have the same lowercase.
    assert "K".lower() == "\u212a".lower() == "k"  # 'K'
    assert re.match(r"K", "\u212a", re.I)
    assert re.match(r"k", "\u212a", re.I)
    assert re.match(r"\N{U+212a}", "K", re.I)
    assert re.match(r"\N{U+212a}", "k", re.I)

    # Two different characters have the same uppercase.
    assert "s".upper() == "\u017f".upper() == "S"  # 'ſ'
    assert re.match(r"S", "\u017f", re.I)
    assert re.match(r"s", "\u017f", re.I)
    assert re.match(r"\u017f", "S", re.I)
    assert re.match(r"\u017f", "s", re.I)

    # Two different characters have the same uppercase. Unicode 9.0+.
    assert "\u0432".upper() == "\u1c80".upper() == "\u0412"  # 'в', 'ᲀ', 'В'
    assert re.match(r"\u0412", "\u0432", re.I)
    assert re.match(r"\u0412", "\u1c80", re.I)
    assert re.match(r"\u0432", "\u0412", re.I)
    assert re.match(r"\u0432", "\u1c80", re.I)
    assert re.match(r"\u1c80", "\u0412", re.I)
    assert re.match(r"\u1c80", "\u0432", re.I)

    # Two different characters have the same multicharacter uppercase.
    assert "\ufb05".upper() == "\ufb06".upper() == "ST"  # 'ﬅ', 'ﬆ'
    assert re.match(r"\ufb05", "\ufb06", re.I)
    assert re.match(r"\ufb06", "\ufb05", re.I)


def test_ignore_case_set():
    assert re.match(r"[19A]", "A", re.I)
    assert re.match(r"[19a]", "a", re.I)
    assert re.match(r"[19a]", "A", re.I)
    assert re.match(r"[19A]", "a", re.I)
    assert re.match(rb"[19A]", b"A", re.I)
    assert re.match(rb"[19a]", b"a", re.I)
    assert re.match(rb"[19a]", b"A", re.I)
    assert re.match(rb"[19A]", b"a", re.I)
    assert re.match(r"[19\xc7]", "\xc7", re.I)
    assert re.match(r"[19\xc7]", "\xe7", re.I)
    assert re.match(r"[19\xe7]", "\xc7", re.I)
    assert re.match(r"[19\xe7]", "\xe7", re.I)
    assert re.match(r"[19\u0400]", "\u0400", re.I)
    assert re.match(r"[19\u0400]", "\u0450", re.I)
    assert re.match(r"[19\u0450]", "\u0400", re.I)
    assert re.match(r"[19\u0450]", "\u0450", re.I)

    assert re.match(rb"[19A]", b"A", re.I)
    assert re.match(rb"[19a]", b"a", re.I)
    assert re.match(rb"[19a]", b"A", re.I)
    assert re.match(rb"[19A]", b"a", re.I)

    # Two different characters have the same lowercase.
    assert "K".lower() == "\u212a".lower() == "k"  # 'K'
    assert re.match(r"[19K]", "\u212a", re.I)
    assert re.match(r"[19k]", "\u212a", re.I)
    assert re.match(r"[19\u212a]", "K", re.I)
    assert re.match(r"[19\u212a]", "k", re.I)

    # Two different characters have the same uppercase.
    assert "s".upper() == "\u017f".upper() == "S"  # 'ſ'
    assert re.match(r"[19S]", "\u017f", re.I)
    assert re.match(r"[19s]", "\u017f", re.I)
    assert re.match(r"[19\u017f]", "S", re.I)
    assert re.match(r"[19\u017f]", "s", re.I)

    # Two different characters have the same uppercase. Unicode 9.0+.
    assert "\u0432".upper() == "\u1c80".upper() == "\u0412"  # 'в', 'ᲀ', 'В'
    assert re.match(r"[19\u0412]", "\u0432", re.I)
    assert re.match(r"[19\u0412]", "\u1c80", re.I)
    assert re.match(r"[19\u0432]", "\u0412", re.I)
    assert re.match(r"[19\u0432]", "\u1c80", re.I)
    assert re.match(r"[19\u1c80]", "\u0412", re.I)
    assert re.match(r"[19\u1c80]", "\u0432", re.I)

    # Two different characters have the same multicharacter uppercase.
    assert "\ufb05".upper() == "\ufb06".upper() == "ST"  # 'ﬅ', 'ﬆ'
    assert re.match(r"[19\ufb05]", "\ufb06", re.I)
    assert re.match(r"[19\ufb06]", "\ufb05", re.I)


def test_ignore_case_range():
    # Issues #3511, #17381.
    assert re.match(r"[9-a]", "_", re.I)
    assert re.match(r"[9-A]", "_", re.I) is None
    assert re.match(rb"[9-a]", b"_", re.I)
    assert re.match(rb"[9-A]", b"_", re.I) is None
    assert re.match(r"[\xc0-\xde]", "\xd7", re.I)
    assert re.match(r"[\xc0-\xde]", "\xe7", re.I)
    assert re.match(r"[\xc0-\xde]", "\xf7", re.I) is None
    assert re.match(r"[\xe0-\xfe]", "\xf7", re.I)
    assert re.match(r"[\xe0-\xfe]", "\xc7", re.I)
    assert re.match(r"[\xe0-\xfe]", "\xd7", re.I) is None
    assert re.match(r"[\u0430-\u045f]", "\u0450", re.I)
    assert re.match(r"[\u0430-\u045f]", "\u0400", re.I)
    assert re.match(r"[\u0400-\u042f]", "\u0450", re.I)
    assert re.match(r"[\u0400-\u042f]", "\u0400", re.I)

    assert re.match(r"[N-\x7f]", "A", re.I | re.A)
    assert re.match(r"[n-\x7f]", "Z", re.I | re.A)
    assert re.match(r"[N-\uffff]", "A", re.I | re.A)
    assert re.match(r"[n-\uffff]", "Z", re.I | re.A)

    # Two different characters have the same lowercase.
    assert "K".lower() == "\u212a".lower() == "k"  # 'K'
    assert re.match(r"[J-M]", "\u212a", re.I)
    assert re.match(r"[j-m]", "\u212a", re.I)
    assert re.match(r"[\u2129-\u212b]", "K", re.I)
    assert re.match(r"[\u2129-\u212b]", "k", re.I)

    # Two different characters have the same uppercase.
    assert "s".upper() == "\u017f".upper() == "S"  # 'ſ'
    assert re.match(r"[R-T]", "\u017f", re.I)
    assert re.match(r"[r-t]", "\u017f", re.I)
    assert re.match(r"[\u017e-\u0180]", "S", re.I)
    assert re.match(r"[\u017e-\u0180]", "s", re.I)

    # Two different characters have the same uppercase. Unicode 9.0+.
    assert "\u0432".upper() == "\u1c80".upper() == "\u0412"  # 'в', 'ᲀ', 'В'
    assert re.match(r"[\u0411-\u0413]", "\u0432", re.I)
    assert re.match(r"[\u0411-\u0413]", "\u1c80", re.I)
    assert re.match(r"[\u0431-\u0433]", "\u0412", re.I)
    assert re.match(r"[\u0431-\u0433]", "\u1c80", re.I)
    assert re.match(r"[\u1c80-\u1c82]", "\u0412", re.I)
    assert re.match(r"[\u1c80-\u1c82]", "\u0432", re.I)

    # Two different characters have the same multicharacter uppercase.
    assert "\ufb05".upper() == "\ufb06".upper() == "ST"  # 'ﬅ', 'ﬆ'
    assert re.match(r"[\ufb04-\ufb05]", "\ufb06", re.I)
    assert re.match(r"[\ufb06-\ufb07]", "\ufb05", re.I)


def test_category():
    assert re.match(r"(\s)", " ").group(1) == " "


def test_not_literal():
    assert re.search(r"\s([^a])", " b").group(1) == "b"
    assert re.search(r"\s([^a]*)", " bb").group(1) == "bb"


def test_possible_set_operations():
    s = bytes(range(128)).decode()
    assert re.findall(r"[0-9--1]", s) == list("-./0123456789")
    assert re.findall(r"[0-9--2]", s) == list("-./0123456789")
    assert re.findall(r"[--1]", s) == list("-./01")
    assert re.findall(r"[%--1]", s) == list("%&'()*+,-1")
    assert re.findall(r"[%--]", s) == list("%&'()*+,-")
    assert re.findall(r"[0-9&&1]", s) == list("&0123456789")
    assert re.findall(r"[0-8&&1]", s) == list("&012345678")
    assert re.findall(r"[\d&&1]", s) == list("&0123456789")
    assert re.findall(r"[&&1]", s) == list("&1")
    assert re.findall(r"[0-9||a]", s) == list("0123456789a|")
    assert re.findall(r"[\d||a]", s) == list("0123456789a|")
    assert re.findall(r"[||1]", s) == list("1|")
    assert re.findall(r"[0-9~~1]", s) == list("0123456789~")
    assert re.findall(r"[\d~~1]", s) == list("0123456789~")
    assert re.findall(r"[~~1]", s) == list("1~")
    assert re.findall(r"[[0-9]|]", s) == list("0123456789[]")
    assert re.findall(r"[[0-8]|]", s) == list("012345678[]")
    assert re.findall(r"[[:digit:]|]", s) == list("0123456789|")


def test_search_coverage():
    assert re.search(r"\s(b)", " b").group(1) == "b"
    assert re.search(r"a\s", "a ").group(0) == "a "


def test_pickling():
    import pickle

    oldpat = re.compile("a(?:b|(c|e){1,2}?|d)+?(.)", re.UNICODE)
    for proto in range(pickle.HIGHEST_PROTOCOL + 1):
        pickled = pickle.dumps(oldpat, proto)
        newpat = pickle.loads(pickled)
        assert newpat.pattern == oldpat.pattern
    # current pickle expects the _compile() reconstructor in re module
    from re import _compile  # noqa: F401


def test_constants():
    assert re.I == re.IGNORECASE
    assert re.M == re.MULTILINE
    assert re.S == re.DOTALL
    assert re.X == re.VERBOSE


def test_flags():
    for flag in [re.I, re.M, re.X, re.S, re.U]:  # TODO: Add re.A back
        assert re.compile("^pattern$", flag)
    for flag in [re.I, re.M, re.X, re.S]:  # TODO: Add re.A, re.L back
        assert re.compile(b"^pattern$", flag)


def test_character_set_errors():
    check_pattern_error(r"[")
    check_pattern_error(r"[^")
    check_pattern_error(r"[a")
    # bug 545855 -- This pattern failed to cause a compile error as it
    # should, instead provoking a TypeError.
    check_pattern_error(r"[a-")
    check_pattern_error(r"[\w-b]")
    check_pattern_error(r"[a-\w]")
    check_pattern_error(r"[b-a]")


def test_bug_113254():
    assert re.match(r"(a)|(b)", "b").start(1) == -1
    assert re.match(r"(a)|(b)", "b").end(1) == -1
    assert re.match(r"(a)|(b)", "b").span(1) == (-1, -1)


def test_bug_527371():
    # bug described in patches 527371/672491
    assert re.match(r"(a)?a", "a").lastindex is None
    assert re.match(r"(a)(b)?b", "ab").lastindex == 1
    assert re.match(r"(?P<a>a)(?P<b>b)?b", "ab").lastgroup == "a"
    assert re.match(r"(?P<a>a(b))", "ab").lastgroup == "a"
    assert re.match(r"((a))", "a").lastindex == 1


def test_bug_418626():
    # bugs 418626 at al. -- Testing Greg Chapman's addition of op code
    # SRE_OP_MIN_REPEAT_ONE for eliminating recursion on simple uses of
    # pattern '*?' on a long string.
    assert re.match(".*?c", 10000 * "ab" + "cd").end(0) == 20001
    assert re.match(".*?cd", 5000 * "ab" + "c" + 5000 * "ab" + "cde").end(0) == 20003
    assert re.match(".*?cd", 20000 * "abc" + "de").end(0) == 60001
    # non-simple '*?' still used to hit the recursion limit, before the
    # non-recursive scheme was implemented.
    assert re.search("(a|b)*?c", 10000 * "ab" + "cd", jit=False).end(0) == 20001


def test_stack_overflow():
    # nasty cases that used to overflow the straightforward recursive
    # implementation of repeated groups.
    assert re.match("(x)*", 50000 * "x").group(1) == "x"
    assert re.match("(x)*y", 50000 * "x" + "y").group(1) == "x"
    assert re.match("(x)*?y", 50000 * "x" + "y").group(1) == "x"


def test_nothing_to_repeat():
    for reps in "*", "+", "?", "{1,2}":
        for mod in "", "?":
            check_pattern_error("%s%s" % (reps, mod))
            check_pattern_error("(?:%s%s)" % (reps, mod))


def test_multiple_repeat():
    for outer_reps in "*", "+", "?", "{1,2}":
        for outer_mod in "", "?", "+":
            outer_op = outer_reps + outer_mod
            for inner_reps in "*", "+", "?", "{1,2}":
                for inner_mod in "", "?", "+":
                    if inner_mod + outer_reps in ("?", "+"):
                        continue
                    inner_op = inner_reps + inner_mod
                    check_pattern_error(r"x%s%s" % (inner_op, outer_op))


def test_unlimited_zero_width_repeat():
    # Issue #9669
    assert re.match(r"(?:a?)*y", "z") is None
    assert re.match(r"(?:a?)+y", "z") is None
    assert re.match(r"(?:a?){2,}y", "z") is None
    assert re.match(r"(?:a?)*?y", "z") is None
    assert re.match(r"(?:a?)+?y", "z") is None
    assert re.match(r"(?:a?){2,}?y", "z") is None


def test_bug_448951():
    # bug 448951 (similar to 429357, but with single char match)
    # (Also test greedy matches.)
    for op in "", "?", "*":
        assert re.match(r"((.%s):)?z" % op, "z").groups() == (None, None)
        assert re.match(r"((.%s):)?z" % op, "a:z").groups() == ("a:", "a")


def test_bug_725106():
    # capturing groups in alternatives in repeats
    assert re.match("^((a)|b)*", "abc").groups() == ("b", "a")
    assert re.match("^(([ab])|c)*", "abc").groups() == ("c", "b")
    assert re.match("^((d)|[ab])*", "abc").groups() == ("b", None)
    assert re.match("^((a)c|[ab])*", "abc").groups() == ("b", None)
    assert re.match("^((a)|b)*?c", "abc").groups() == ("b", "a")
    assert re.match("^(([ab])|c)*?d", "abcd").groups() == ("c", "b")
    assert re.match("^((d)|[ab])*?c", "abc").groups() == ("b", None)
    assert re.match("^((a)c|[ab])*?c", "abc").groups() == ("b", None)


def test_bug_725149():
    # mark_stack_base restoring before restoring marks
    assert re.match("(a)(?:(?=(b)*)c)*", "abb").groups() == ("a", None)
    assert re.match("(a)((?!(b)*))*", "abb").groups() == ("a", None, None)


def test_bug_764548():
    # bug 764548, re.compile() barfs on str/unicode subclasses
    class my_unicode(str):
        pass

    pat = re.compile(my_unicode("abc"))
    assert pat.match("xyz") is None


def test_finditer():
    iter = re.finditer(r":+", "a:b::c:::d")
    assert [item.group(0) for item in iter] == [":", "::", ":::"]

    pat = re.compile(r":+")
    iter = pat.finditer("a:b::c:::d", 1, 10)
    assert [item.group(0) for item in iter] == [":", "::", ":::"]

    pat = re.compile(r":+")
    iter = pat.finditer("a:b::c:::d", pos=1, endpos=10)
    assert [item.group(0) for item in iter] == [":", "::", ":::"]

    pat = re.compile(r":+")
    iter = pat.finditer("a:b::c:::d", endpos=10, pos=1)
    assert [item.group(0) for item in iter] == [":", "::", ":::"]

    pat = re.compile(r":+")
    iter = pat.finditer("a:b::c:::d", pos=3, endpos=8)
    assert [item.group(0) for item in iter] == ["::", "::"]


def test_bug_926075():
    assert re.compile("bug_926075") is not re.compile(b"bug_926075")


def test_bug_931848():
    pattern = "[\u002e\u3002\uff0e\uff61]"
    assert re.compile(pattern).split("a.b.c") == ["a", "b", "c"]


def test_bug_581080():
    iter = re.finditer(r"\s", "a b")
    assert next(iter).span() == (1, 2)
    assert_raises(StopIteration, next, iter)


def test_bug_817234():
    iter = re.finditer(r".*", "asdf")
    assert next(iter).span() == (0, 4)
    assert next(iter).span() == (4, 4)
    assert_raises(StopIteration, next, iter)


def test_bug_6561():
    # '\d' should match characters in Unicode category 'Nd'
    # (Number, Decimal Digit), but not those in 'Nl' (Number,
    # Letter) or 'No' (Number, Other).
    decimal_digits = [
        "\u0037",  # '\N{DIGIT SEVEN}', category 'Nd'
        "\u0e58",  # '\N{THAI DIGIT SIX}', category 'Nd'
        "\uff10",  # '\N{FULLWIDTH DIGIT ZERO}', category 'Nd'
    ]
    for x in decimal_digits:
        assert re.match(r"^\d$", x).group(0) == x

    not_decimal_digits = [
        "\u2165",  # '\N{ROMAN NUMERAL SIX}', category 'Nl'
        "\u3039",  # '\N{HANGZHOU NUMERAL TWENTY}', category 'Nl'
        "\u2082",  # '\N{SUBSCRIPT TWO}', category 'No'
        "\u32b4",  # '\N{CIRCLED NUMBER THIRTY NINE}', category 'No'
    ]
    for x in not_decimal_digits:
        assert re.match(r"^\d$", x) is None


def test_inline_flags():
    # Bug #1700
    upper_char = "\u1ea0"  # Latin Capital Letter A with Dot Below
    lower_char = "\u1ea1"  # Latin Small Letter A with Dot Below

    p = re.compile("." + upper_char, re.I | re.S)
    q = p.match("\n" + lower_char)
    assert q

    p = re.compile("." + lower_char, re.I | re.S)
    q = p.match("\n" + upper_char)
    assert q

    p = re.compile("(?i)." + upper_char, re.S)
    q = p.match("\n" + lower_char)
    assert q

    p = re.compile("(?i)." + lower_char, re.S)
    q = p.match("\n" + upper_char)
    assert q

    p = re.compile("(?is)." + upper_char)
    q = p.match("\n" + lower_char)
    assert q

    p = re.compile("(?is)." + lower_char)
    q = p.match("\n" + upper_char)
    assert q

    p = re.compile("(?s)(?i)." + upper_char)
    q = p.match("\n" + lower_char)
    assert q

    p = re.compile("(?s)(?i)." + lower_char)
    q = p.match("\n" + upper_char)
    assert q

    assert re.match("(?ix) " + upper_char, lower_char)
    assert re.match("(?ix) " + lower_char, upper_char)
    assert re.match(" (?i) " + upper_char, lower_char, re.X)
    assert re.match("(?x) (?i) " + upper_char, lower_char)
    assert re.match(" (?x) (?i) " + upper_char, lower_char, re.X)


def test_dollar_matches_twice():
    r"""Test that $ does not include \n
    $ matches the end of string, and just before the terminating \n"""
    pattern = re.compile("$")
    assert pattern.sub("#", "a\nb\n") == "a\nb#\n#"
    assert pattern.sub("#", "a\nb\nc") == "a\nb\nc#"
    assert pattern.sub("#", "\n") == "#\n#"

    pattern = re.compile("$", re.MULTILINE)
    assert pattern.sub("#", "a\nb\n") == "a#\nb#\n#"
    assert pattern.sub("#", "a\nb\nc") == "a#\nb#\nc#"
    assert pattern.sub("#", "\n") == "#\n#"


def test_bytes_str_mixing():
    # Mixing str and bytes is disallowed
    pat = re.compile(".")
    bpat = re.compile(b".")
    assert_raises(TypeError, pat.match, b"b")
    assert_raises(TypeError, bpat.match, "b")
    assert_raises(TypeError, pat.sub, b"b", "c")
    assert_raises(TypeError, pat.sub, "b", b"c")
    assert_raises(TypeError, pat.sub, b"b", b"c")
    assert_raises(TypeError, bpat.sub, b"b", "c")
    assert_raises(TypeError, bpat.sub, "b", b"c")
    assert_raises(TypeError, bpat.sub, "b", "c")


def test_ascii_and_unicode_flag():
    # String patterns
    for flags in (0, re.UNICODE):
        pat = re.compile("\xc0", flags | re.IGNORECASE)
        assert pat.match("\xe0")
        pat = re.compile(r"\w", flags)
        assert pat.match("\xe0")
    pat = re.compile(r"\w", re.ASCII)
    assert pat.match("\xe0") is None
    pat = re.compile(r"(?a)\w")
    assert pat.match("\xe0") is None
    # Bytes patterns
    for flags in (0, re.ASCII):
        pat = re.compile(b"\xc0", flags | re.IGNORECASE)
        assert pat.match(b"\xe0") is None
        pat = re.compile(rb"\w", flags)
        assert pat.match(b"\xe0") is None
    # Incompatibilities
    check_pattern_error(rb"(?u)\w")
    assert_raises(re.PatternError, re.compile, r"(?u)\w", re.ASCII)
    check_pattern_error(r"(?au)\w")


def test_scoped_flags():
    assert re.match(r"(?i:a)b", "Ab")
    assert re.match(r"(?i:a)b", "aB") is None
    assert re.match(r"(?-i:a)b", "Ab", re.IGNORECASE) is None
    assert re.match(r"(?-i:a)b", "aB", re.IGNORECASE)
    assert re.match(r"(?i:(?-i:a)b)", "Ab") is None
    assert re.match(r"(?i:(?-i:a)b)", "aB")
    assert re.match(r"\w(?a:\W)\w", "\xe0\xe0\xe0")

    check_pattern_error(rb"(?aL:a)")
    check_pattern_error(r"(?-")
    check_pattern_error(r"(?-+")
    check_pattern_error(r"(?-z")
    check_pattern_error(r"(?-i")
    check_pattern_error(r"(?-i+")
    check_pattern_error(r"(?-iz")
    check_pattern_error(r"(?i:")
    check_pattern_error(r"(?i")
    check_pattern_error(r"(?i+")
    check_pattern_error(r"(?iz")


def test_ignore_spaces():
    for space in " \t\n\r\v\f":
        assert re.fullmatch(space + "a", "a", re.VERBOSE)
    for space in b" ", b"\t", b"\n", b"\r", b"\v", b"\f":
        assert re.fullmatch(space + b"a", b"a", re.VERBOSE)
    assert re.fullmatch("(?x) a", "a")
    assert re.fullmatch(" (?x) a", "a", re.VERBOSE)
    assert re.fullmatch("(?x) (?x) a", "a")
    assert re.fullmatch(" a(?x: b) c", " ab c")
    assert re.fullmatch(" a(?-x: b) c", "a bc", re.VERBOSE)
    assert re.fullmatch("(?x) a(?-x: b) c", "a bc")
    assert re.fullmatch("(?x) a| b", "a")
    assert re.fullmatch("(?x) a| b", "b")


def test_comments():
    assert re.fullmatch("#x\na", "a", re.VERBOSE)
    assert re.fullmatch(b"#x\na", b"a", re.VERBOSE)
    assert re.fullmatch("(?x)#x\na", "a")
    assert re.fullmatch("#x\n(?x)#y\na", "a", re.VERBOSE)
    assert re.fullmatch("(?x)#x\n(?x)#y\na", "a")
    assert re.fullmatch("#x\na(?x:#y\nb)#z\nc", "#x\nab#z\nc")
    assert re.fullmatch("#x\na(?-x:#y\nb)#z\nc", "a#y\nbc", re.VERBOSE)
    assert re.fullmatch("(?x)#x\na(?-x:#y\nb)#z\nc", "a#y\nbc")
    assert re.fullmatch("(?x)#x\na|#y\nb", "a")
    assert re.fullmatch("(?x)#x\na|#y\nb", "b")


def test_bug_6509():
    # Replacement strings of both types must parse properly.
    # all strings
    assert re.sub(r"a(\w)", "b\\1", "ac") == "bc"
    assert re.sub("a(.)", "b\\1", "a\u1234") == "b\u1234"
    assert re.sub("..", lambda m: "str", "a5") == "str"

    # all bytes
    assert re.sub(rb"a(\w)", b"b\\1", b"ac") == b"bc"
    assert re.sub(b"a(.)", b"b\\1", b"a\xcd") == b"b\xcd"
    assert re.sub(b"..", lambda m: b"bytes", b"a5") == b"bytes"


def test_search_dot_unicode():
    assert re.search("123.*-", "123abc-")
    assert re.search("123.*-", "123\xe9-")
    assert re.search("123.*-", "123\u20ac-")
    assert re.search("123.*-", "123\U0010ffff-")
    assert re.search("123.*-", "123\xe9\u20ac\U0010ffff-")


def test_compile():
    # Test return value when given string and pattern as parameter
    pattern = re.compile("random pattern")
    assert isinstance(pattern, re.Pattern)
    same_pattern = re.compile(pattern)
    assert isinstance(same_pattern, re.Pattern)
    assert same_pattern is pattern
    # Test behaviour when not given a string or pattern as parameter
    assert_raises(TypeError, re.compile, 0)


def test_large_search():
    # Issue #10182: indices were 32-bit-truncated.
    size = 2  # * 1024 ** 2  # TODO: Works but is expensive for iterative tests
    s = "a" * size
    m = re.search("$", s)
    assert m is not None
    assert m.start() == size
    assert m.end() == size


def test_large_subn():
    # Issue #10182: indices were 32-bit-truncated.
    size = 2  # * 1024 ** 2  # TODO: Works but is expensive for iterative tests
    s = "a" * size
    r, n = re.subn("", "", s)
    assert r == s
    assert n == size + 1


def test_bug_16688():
    # Issue 16688: Backreferences make case-insensitive regex fail on
    # non-ASCII strings.
    assert re.findall(r"(?i)(a)\1", "aa \u0100") == ["a"]
    assert re.match(r"(?s).{1,3}", "\u0100\u0100").span() == (0, 2)


def test_repeat_minmax_overflow():
    # Issue #13169
    string = "x" * 100000
    assert re.match(r".{65535}", string).span() == (0, 65535)
    assert re.match(r".{,65535}", string).span() == (0, 65535)
    assert re.match(r".{65535,}?", string).span() == (0, 65535)


def test_look_behind_overflow():
    string = "x" * 2_500_000
    p1 = r"(?<=((.{%d}){%d}){%d})"
    p2 = r"(?<!((.{%d}){%d}){%d})"
    # But 2**66 is too large for look-behind width.
    assert_raises(re.error, re.compile, p1 % (2**22, 2**22, 2**22))
    assert_raises(re.error, re.compile, p2 % (2**22, 2**22, 2**22))


def test_issue17998():
    for reps in "*", "+", "?", "{1}":
        for mod in "", "?":
            pattern = "." + reps + mod + "yz"
            assert re.compile(pattern, re.S).findall("xyz") == ["xyz"]
            pattern = pattern.encode()
            assert re.compile(pattern, re.S).findall(b"xyz") == [b"xyz"]


def test_match_repr():
    for string in "[abracadabra]", S("[abracadabra]"):
        m = re.search(r"(.+)(.*?)\1", string)
        pattern = r"<(%s\.)?%s object; span=\(1, 12\), match='abracadabra'>" % (
            type(m).__module__,
            type(m).__qualname__,
        )
        assert re.search(pattern, repr(m))
    for string in (
        b"[abracadabra]",
        B(b"[abracadabra]"),
        bytearray(b"[abracadabra]"),
        memoryview(b"[abracadabra]"),
    ):
        m = re.search(rb"(.+)(.*?)\1", string)
        pattern = r"<(%s\.)?%s object; span=\(1, 12\), match=b'abracadabra'>" % (
            type(m).__module__,
            type(m).__qualname__,
        )
        assert re.search(pattern, repr(m))

    first, second = list(re.finditer("(aa)|(bb)", "aa bb"))
    pattern = r"<(%s\.)?%s object; span=\(0, 2\), match='aa'>" % (
        type(second).__module__,
        type(second).__qualname__,
    )
    assert re.search(pattern, repr(first))
    pattern = r"<(%s\.)?%s object; span=\(3, 5\), match='bb'>" % (
        type(second).__module__,
        type(second).__qualname__,
    )
    assert re.search(pattern, repr(second))


def test_zerowidth():
    # Issues 852532, 1647489, 3262, 25054.
    assert re.split(r"\b", "a::bc") == ["", "a", "::", "bc", ""]
    assert re.split(r"\b|:+", "a::bc") == ["", "a", "", "", "bc", ""]
    assert re.split(r"(?<!\w)(?=\w)|:+", "a::bc") == ["", "a", "", "bc"]
    assert re.split(r"(?<=\w)(?!\w)|:+", "a::bc") == ["a", "", "bc", ""]

    assert re.sub(r"\b", "-", "a::bc") == "-a-::-bc-"
    assert re.sub(r"\b|:+", "-", "a::bc") == "-a---bc-"
    assert re.sub(r"(\b|:+)", r"[\1]", "a::bc") == "[]a[][::][]bc[]"

    assert re.findall(r"\b|:+", "a::bc") == ["", "", "::", "", ""]
    assert re.findall(r"\b|\w+", "a::bc") == ["", "a", "", "", "bc", ""]

    assert [m.span() for m in re.finditer(r"\b|:+", "a::bc")] == [
        (0, 0),
        (1, 1),
        (1, 3),
        (3, 3),
        (5, 5),
    ]
    assert [m.span() for m in re.finditer(r"\b|\w+", "a::bc")] == [
        (0, 0),
        (0, 1),
        (1, 1),
        (3, 3),
        (3, 5),
        (5, 5),
    ]


def test_bug_2537():
    # issue 2537: empty submatches
    for outer_op in ("{0,}", "*", "+", "{1,187}"):
        for inner_op in ("{0,}", "*", "?"):
            r = re.compile("^((x|y)%s)%s" % (inner_op, outer_op))
            m = r.match("xyyzy")
            assert m.group(0) == "xyy"
            assert m.group(1) == ""
            assert m.group(2) == "y"


def test_keyword_parameters():
    # Issue #20283: Accepting the string keyword parameter.
    pat = re.compile(r"(ab)")
    assert pat.match(string="abracadabra", pos=7, endpos=10).span() == (7, 9)
    assert pat.fullmatch(string="abracadabra", pos=7, endpos=9).span() == (7, 9)
    assert pat.search(string="abracadabra", pos=3, endpos=10).span() == (7, 9)
    assert pat.findall(string="abracadabra", pos=3, endpos=10) == ["ab"]
    assert pat.split(string="abracadabra", maxsplit=1) == ["", "ab", "racadabra"]


def test_bug_20998():
    # Issue #20998: Fullmatch of repeated single character pattern
    # with ignore case.
    assert re.fullmatch("[a-c]+", "ABC", re.I).span() == (0, 3)


def test_misc_errors():
    check_pattern_error(r"(")
    check_pattern_error(r"((a|b)")
    check_pattern_error(r"(a|b))")
    check_pattern_error(r"(?P")
    check_pattern_error(r"(?z)")
    check_pattern_error(r"(?iz)")
    check_pattern_error(r"(?i")
    check_pattern_error(r"(?#abc")
    check_pattern_error(r"(?<")
    check_pattern_error(r"(?<>)")
    check_pattern_error(r"(?")


def test_enum():
    # Issue #28082: Check that str(flag) returns a human readable string
    # instead of an integer
    # TODO: Change representation of enums
    # self.assertIn("IGNORECASE", str(re.I))
    # self.assertIn("DOTALL", str(re.S))
    pass


def test_bug_34294():
    # Issue 34294: wrong capturing groups
    # exists since Python 2
    s = "a\tx"
    p = r"\b(?=(\t)|(x))x"
    assert re.search(p, s).groups() == (None, "x")

    # introduced in Python 3.7.0
    s = "ab"
    p = r"(?=(.)(.)?)"
    assert re.findall(p, s), [("a", "b") == ("b", "")]
    assert [m.groups() for m in re.finditer(p, s)], [("a", "b") == ("b", None)]

    # test-cases provided by issue34294, introduced in Python 3.7.0
    p = r"(?=<(?P<tag>\w+)/?>(?:(?P<text>.+?)</(?P=tag)>)?)"
    s = "<test><foo2/></test>"
    assert re.findall(p, s), [("test", "<foo2/>") == ("foo2", "")]
    assert [m.groupdict() for m in re.finditer(p, s)] == [
        {"tag": "test", "text": "<foo2/>"},
        {"tag": "foo2", "text": None},
    ]
    s = "<test>Hello</test><foo/>"
    assert [m.groupdict() for m in re.finditer(p, s)] == [
        {"tag": "test", "text": "Hello"},
        {"tag": "foo", "text": None},
    ]
    s = "<test>Hello</test><foo/><foo/>"
    assert [m.groupdict() for m in re.finditer(p, s)] == [
        {"tag": "test", "text": "Hello"},
        {"tag": "foo", "text": None},
        {"tag": "foo", "text": None},
    ]


def test_MARK_PUSH_macro_bug():
    # issue35859, MARK_PUSH() macro didn't protect MARK-0 if it
    # was the only available mark.
    assert re.match(r"(ab|a)*?b", "ab").groups() == ("a",)
    assert re.match(r"(ab|a)+?b", "ab").groups() == ("a",)
    assert re.match(r"(ab|a){0,2}?b", "ab").groups() == ("a",)
    assert re.match(r"(.b|a)*?b", "ab").groups() == ("a",)


def test_MIN_UNTIL_mark_bug():
    # Fixed in issue35859, reported in issue9134.
    # JUMP_MIN_UNTIL_2 should MARK_PUSH() if in a repeat
    s = "axxzbcz"
    p = r"(?:(?:a|bc)*?(xx)??z)*"
    assert re.match(p, s).groups() == ("xx",)

    # test-case provided by issue9134
    s = "xtcxyzxc"
    p = r"((x|yz)+?(t)??c)*"
    m = re.match(p, s)
    assert m.span() == (0, 8)
    assert m.span(2) == (6, 7)
    assert m.groups() == ("xyzxc", "x", "t")


def test_REPEAT_ONE_mark_bug():
    # issue35859
    # JUMP_REPEAT_ONE_1 should MARK_PUSH() if in a repeat
    s = "aabaab"
    p = r"(?:[^b]*a(?=(b)|(a))ab)*"
    m = re.match(p, s)
    assert m.span() == (0, 6)
    assert m.span(2) == (4, 5)
    assert m.groups() == (None, "a")

    # JUMP_REPEAT_ONE_2 should MARK_PUSH() if in a repeat
    s = "abab"
    p = r"(?:[^b]*(?=(b)|(a))ab)*"
    m = re.match(p, s)
    assert m.span() == (0, 4)
    assert m.span(2) == (2, 3)
    assert m.groups() == (None, "a")

    assert re.match(r"(ab?)*?b", "ab").groups() == ("a",)


def test_MIN_REPEAT_ONE_mark_bug():
    # issue35859
    # JUMP_MIN_REPEAT_ONE should MARK_PUSH() if in a repeat
    s = "abab"
    p = r"(?:.*?(?=(a)|(b))b)*"
    m = re.match(p, s)
    assert m.span() == (0, 4)
    assert m.span(2) == (3, 4)
    assert m.groups() == (None, "b")

    s = "axxzaz"
    p = r"(?:a*?(xx)??z)*"
    assert re.match(p, s).groups() == ("xx",)


def test_ASSERT_NOT_mark_bug():
    # Fixed in issue35859, reported in issue725149.
    # JUMP_ASSERT_NOT should LASTMARK_SAVE()
    assert re.match(r"(?!(..)c)", "ab").groups() == (None,)

    # JUMP_ASSERT_NOT should MARK_PUSH() if in a repeat
    m = re.match(r"((?!(ab)c)(.))*", "abab")
    assert m.span() == (0, 4)
    assert m.span(1) == (3, 4)
    assert m.span(3) == (3, 4)
    assert m.groups() == ("b", None, "b")


def test_bug_40736():
    with pytest.raises(TypeError):
        re.search("x*", 5)
    with pytest.raises(TypeError):
        re.search("x*", type)


def test_search_anchor_at_beginning():
    s = "x" * 10**7
    for p in r"\Ay", r"^y":
        assert re.search(p, s) is None
        assert re.split(p, s) == [s]
        assert re.findall(p, s) == []
        assert list(re.finditer(p, s)) == []
        assert re.sub(p, "", s) == s


def test_possessive_quantifiers():
    """Test Possessive Quantifiers
    Test quantifiers of the form @+ for some repetition operator @,
    e.g. x{3,5}+ meaning match from 3 to 5 greadily and proceed
    without creating a stack frame for rolling the stack back and
    trying 1 or more fewer matches."""
    assert re.match("e*+e", "eeee") is None
    assert re.match("e++a", "eeea").group(0) == "eeea"
    assert re.match("e?+a", "ea").group(0) == "ea"
    assert re.match("e{2,4}+a", "eeea").group(0) == "eeea"
    assert re.match("(.)++.", "ee") is None
    assert re.match("(ae)*+a", "aea").groups() == ("ae",)
    assert re.match("([ae][ae])?+a", "aea").groups() == ("ae",)
    assert re.match("(e?){2,4}+a", "eeea").groups() == ("",)
    assert re.match("()*+a", "a").groups() == ("",)
    assert re.search("x*+", "axx").span() == (0, 0)
    assert re.search("x++", "axx").span() == (1, 3)
    assert re.match("a*+", "xxx").span() == (0, 0)
    assert re.match("x*+", "xxxa").span() == (0, 3)
    assert re.match("a++", "xxx") is None
    assert re.match(r"^(\w){1}+$", "abc") is None
    assert re.match(r"^(\w){1,2}+$", "abc") is None

    assert re.match(r"^(\w){3}+$", "abc").group(1) == "c"
    assert re.match(r"^(\w){1,3}+$", "abc").group(1) == "c"
    assert re.match(r"^(\w){1,4}+$", "abc").group(1) == "c"

    assert re.match("^x{1}+$", "xxx") is None
    assert re.match("^x{1,2}+$", "xxx") is None

    assert re.match("^x{3}+$", "xxx")
    assert re.match("^x{1,3}+$", "xxx")
    assert re.match("^x{1,4}+$", "xxx")

    assert re.match("^x{}+$", "xxx") is None
    assert re.match("^x{}+$", "x{}")


def test_fullmatch_possessive_quantifiers():
    assert re.fullmatch(r"a++", "a")
    assert re.fullmatch(r"a*+", "a")
    assert re.fullmatch(r"a?+", "a")
    assert re.fullmatch(r"a{1,3}+", "a")
    assert re.fullmatch(r"a++", "ab") is None
    assert re.fullmatch(r"a*+", "ab") is None
    assert re.fullmatch(r"a?+", "ab") is None
    assert re.fullmatch(r"a{1,3}+", "ab") is None
    assert re.fullmatch(r"a++b", "ab")
    assert re.fullmatch(r"a*+b", "ab")
    assert re.fullmatch(r"a?+b", "ab")
    assert re.fullmatch(r"a{1,3}+b", "ab")

    assert re.fullmatch(r"(?:ab)++", "ab")
    assert re.fullmatch(r"(?:ab)*+", "ab")
    assert re.fullmatch(r"(?:ab)?+", "ab")
    assert re.fullmatch(r"(?:ab){1,3}+", "ab")
    assert re.fullmatch(r"(?:ab)++", "abc") is None
    assert re.fullmatch(r"(?:ab)*+", "abc") is None
    assert re.fullmatch(r"(?:ab)?+", "abc") is None
    assert re.fullmatch(r"(?:ab){1,3}+", "abc") is None
    assert re.fullmatch(r"(?:ab)++c", "abc")
    assert re.fullmatch(r"(?:ab)*+c", "abc")
    assert re.fullmatch(r"(?:ab)?+c", "abc")
    assert re.fullmatch(r"(?:ab){1,3}+c", "abc")


def test_findall_possessive_quantifiers():
    assert re.findall(r"a++", "aab") == ["aa"]
    assert re.findall(r"a*+", "aab") == ["aa", "", ""]
    assert re.findall(r"a?+", "aab") == ["a", "a", "", ""]
    assert re.findall(r"a{1,3}+", "aab") == ["aa"]

    assert re.findall(r"(?:ab)++", "ababc") == ["abab"]
    assert re.findall(r"(?:ab)*+", "ababc") == ["abab", "", ""]
    assert re.findall(r"(?:ab)?+", "ababc") == ["ab", "ab", "", ""]
    assert re.findall(r"(?:ab){1,3}+", "ababc") == ["abab"]


def test_atomic_grouping():
    """Test Atomic Grouping
    Test non-capturing groups of the form (?>...), which does
    not maintain any stack point created within the group once the
    group is finished being evaluated."""
    pattern1 = re.compile(r"a(?>bc|b)c")
    assert pattern1.match("abc") is None
    assert pattern1.match("abcc")
    assert re.match(r"(?>.*).", "abc") is None
    assert re.match(r"(?>x)++", "xxx")
    assert re.match(r"(?>x++)", "xxx")
    assert re.match(r"(?>x)++x", "xxx") is None
    assert re.match(r"(?>x++)x", "xxx") is None


def test_fullmatch_atomic_grouping():
    assert re.fullmatch(r"(?>a+)", "a")
    assert re.fullmatch(r"(?>a*)", "a")
    assert re.fullmatch(r"(?>a?)", "a")
    assert re.fullmatch(r"(?>a{1,3})", "a")
    assert re.fullmatch(r"(?>a+)", "ab") is None
    assert re.fullmatch(r"(?>a*)", "ab") is None
    assert re.fullmatch(r"(?>a?)", "ab") is None
    assert re.fullmatch(r"(?>a{1,3})", "ab") is None
    assert re.fullmatch(r"(?>a+)b", "ab")
    assert re.fullmatch(r"(?>a*)b", "ab")
    assert re.fullmatch(r"(?>a?)b", "ab")
    assert re.fullmatch(r"(?>a{1,3})b", "ab")

    assert re.fullmatch(r"(?>(?:ab)+)", "ab")
    assert re.fullmatch(r"(?>(?:ab)*)", "ab")
    assert re.fullmatch(r"(?>(?:ab)?)", "ab")
    assert re.fullmatch(r"(?>(?:ab){1,3})", "ab")
    assert re.fullmatch(r"(?>(?:ab)+)", "abc") is None
    assert re.fullmatch(r"(?>(?:ab)*)", "abc") is None
    assert re.fullmatch(r"(?>(?:ab)?)", "abc") is None
    assert re.fullmatch(r"(?>(?:ab){1,3})", "abc") is None
    assert re.fullmatch(r"(?>(?:ab)+)c", "abc")
    assert re.fullmatch(r"(?>(?:ab)*)c", "abc")
    assert re.fullmatch(r"(?>(?:ab)?)c", "abc")
    assert re.fullmatch(r"(?>(?:ab){1,3})c", "abc")


def test_findall_atomic_grouping():
    assert re.findall(r"(?>a+)", "aab") == ["aa"]
    assert re.findall(r"(?>a*)", "aab") == ["aa", "", ""]
    assert re.findall(r"(?>a?)", "aab") == ["a", "a", "", ""]
    assert re.findall(r"(?>a{1,3})", "aab") == ["aa"]

    assert re.findall(r"(?>(?:ab)+)", "ababc") == ["abab"]
    assert re.findall(r"(?>(?:ab)*)", "ababc") == ["abab", "", ""]
    assert re.findall(r"(?>(?:ab)?)", "ababc") == ["ab", "ab", "", ""]
    assert re.findall(r"(?>(?:ab){1,3})", "ababc") == ["abab"]


def test_bug_gh91616():
    assert re.fullmatch(r"(?s:(?>.*?\.).*)\z", "a.txt")  # reproducer
    assert re.fullmatch(r"(?s:(?=(?P<g0>.*?\.))(?P=g0).*)\z", "a.txt")


def test_bug_gh100061():
    # gh-100061
    assert re.match("(?>(?:.(?!D))+)", "ABCDE").span() == (0, 2)
    assert re.match("(?:.(?!D))++", "ABCDE").span() == (0, 2)
    assert re.match("(?>(?:.(?!D))*)", "ABCDE").span() == (0, 2)
    assert re.match("(?:.(?!D))*+", "ABCDE").span() == (0, 2)
    assert re.match("(?>(?:.(?!D))?)", "CDE").span() == (0, 0)
    assert re.match("(?:.(?!D))?+", "CDE").span() == (0, 0)
    assert re.match("(?>(?:.(?!D)){1,3})", "ABCDE").span() == (0, 2)
    assert re.match("(?:.(?!D)){1,3}+", "ABCDE").span() == (0, 2)
    # gh-106052
    assert re.match("(?>(?:ab?c)+)", "aca").span() == (0, 2)
    assert re.match("(?:ab?c)++", "aca").span() == (0, 2)
    assert re.match("(?>(?:ab?c)*)", "aca").span() == (0, 2)
    assert re.match("(?:ab?c)*+", "aca").span() == (0, 2)
    assert re.match("(?>(?:ab?c)?)", "a").span() == (0, 0)
    assert re.match("(?:ab?c)?+", "a").span() == (0, 0)
    assert re.match("(?>(?:ab?c){1,3})", "aca").span() == (0, 2)
    assert re.match("(?:ab?c){1,3}+", "aca").span() == (0, 2)


def test_bug_gh101955():
    # Possessive quantifier with nested alternative with capture groups
    assert re.match("((x)|y|z)*+", "xyz").groups() == ("z", "x")
    assert re.match("((x)|y|z){3}+", "xyz").groups() == ("z", "x")
    assert re.match("((x)|y|z){3,}+", "xyz").groups() == ("z", "x")


def test_regression_gh94675():
    # TODO: Multiprocessing requires pickling
    pattern = re.compile(
        r"(?<=[({}])(((//[^\n]*)?[\n])([\000-\040])*)*"
        r"((/[^/\[\n]*(([^\n]|(\[\n]*(]*)*\]))"
        r"[^/\[]*)*/))((((//[^\n]*)?[\n])"
        r"([\000-\040]|(/\*[^*]*\*+"
        r"([^/*]\*+)*/))*)+(?=[^\000-\040);\]}]))"
    )
    input_js = """a(function() {
        ///////////////////////////////////////////////////////////////////
    });"""
    p = multiprocessing.Process(target=pattern.sub, args=("", input_js))
    p.start()
    p.join(30.0)
    try:
        assert not p.is_alive(), "pattern.sub() timed out"
    finally:
        if p.is_alive():
            p.terminate()
            p.join()


def test_fail():
    assert re.search(r"12(?!)|3", "123")[0] == "3"


def test_character_set_any():
    # The union of complementary character sets matches any character
    # and is equivalent to "(?s:.)".
    s = "1x\n"
    for p in r"[\s\S]", r"[\d\D]", r"[\w\W]", r"[\S\s]", r"\s|\S":
        assert re.findall(p, s) == list(s)
        assert re.fullmatch("(?:" + p + ")+", s).group() == s


def test_character_set_none():
    # Negation of the union of complementary character sets does not match
    # any character.
    s = "1x\n"
    for p in r"[^\s\S]", r"[^\d\D]", r"[^\w\W]", r"[^\S\s]":
        assert re.search(p, s) is None
        assert re.search("(?s:.)" + p, s) is None
