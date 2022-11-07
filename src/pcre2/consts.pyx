# -*- coding:utf-8 -*-

# Standard libraries.
from enum import IntEnum

# Local imports.
from .utils cimport *
from .libpcre2 cimport *


__libpcre2_version__ = f"{PCRE2_MAJOR}.{PCRE2_MINOR}"


class MetaOption(IntEnum):
    def __repr__(self):
        return f"<{self.__class__.__name__}.{self._name_}: 0x{self._value_:x}>"

    @classmethod
    def verify(cls, options):
        """ Verify a number is composed of options.
        """
        tmp = options
        for opt in cls:
            tmp ^= (opt & tmp)
        return tmp == 0


    @classmethod
    def decompose(cls, options):
        """ Decompose a number into its component options, returning a list of
        MetaOption enums that are components of the given options. Note that
        left over bits are ignored, and veracity can not be determined from
        the result.
        """
        return [opt for opt in cls if (opt & options)]


class CompileOption(MetaOption):
    """ Option bits to be used in pattern compilation. See the following PCRE2
    documentation for a brief overview of the relevant options:
    http://pcre.org/current/doc/html/pcre2_compile.html
    """

    ALLOW_EMPTY_CLASS = PCRE2_ALLOW_EMPTY_CLASS
    ALT_BSUX = PCRE2_ALT_BSUX
    ALT_CIRCUMFLEX = PCRE2_ALT_CIRCUMFLEX
    ALT_VERBNAMES = PCRE2_ALT_VERBNAMES
    ANCHORED = PCRE2_ANCHORED
    CASELESS = PCRE2_CASELESS
    DOLLAR_ENDONLY = PCRE2_DOLLAR_ENDONLY
    DOTALL = PCRE2_DOTALL
    DUPNAMES = PCRE2_DUPNAMES
    ENDANCHORED = PCRE2_ENDANCHORED
    EXTENDED = PCRE2_EXTENDED
    EXTENDED_MORE = PCRE2_EXTENDED_MORE
    FIRSTLINE = PCRE2_FIRSTLINE
    LITERAL = PCRE2_LITERAL
    MATCH_UNSET_BACKREF = PCRE2_MATCH_UNSET_BACKREF
    MULTILINE = PCRE2_MULTILINE
    UCP = PCRE2_UCP
    UNGREEDY = PCRE2_UNGREEDY
    UTF = PCRE2_UTF


class MatchOption(MetaOption):
    """ Option bits to be used when matching. See the following PCRE2
    documentation for a brief overview of the relevant options:
    http://pcre.org/current/doc/html/pcre2_match.html
    """
    NOTBOL = PCRE2_NOTBOL
    NOTEOL = PCRE2_NOTEOL
    NOTEMPTY = PCRE2_NOTEMPTY
    NOTEMPTY_ATSTART = PCRE2_NOTEMPTY_ATSTART


class SubstituteOption(MetaOption):
    """ Option bits to be used when making pattern substitutions. See the
    following PCRE2 documentation for a brief overview of the relevant
    options:
    http://pcre.org/current/doc/html/pcre2_substitute.html
    """
    NOTBOL = PCRE2_NOTBOL
    NOTEOL = PCRE2_NOTEOL
    NOTEMPTY = PCRE2_NOTEMPTY
    NOTEMPTY_ATSTART = PCRE2_NOTEMPTY_ATSTART
    GLOBAL = PCRE2_SUBSTITUTE_GLOBAL
    EXTENDED = PCRE2_SUBSTITUTE_EXTENDED
    UNSET_EMPTY = PCRE2_SUBSTITUTE_UNSET_EMPTY
    UNKNOWN_UNSET = PCRE2_SUBSTITUTE_UNKNOWN_UNSET
    LITERAL = PCRE2_SUBSTITUTE_LITERAL
    REPLACEMENT_ONLY = PCRE2_SUBSTITUTE_REPLACEMENT_ONLY

# Type alias.
ExpandOption = SubstituteOption


class BsrChar(IntEnum):
    """ Indicator for what character(s) are denoted by `\r`.
    """
    UNICODE = PCRE2_BSR_UNICODE
    ANYCRLF = PCRE2_BSR_ANYCRLF


class NewlineChar(IntEnum):
    """ Indicator for what character(s) denote a newline.
    """
    CR = PCRE2_NEWLINE_CR
    LF = PCRE2_NEWLINE_LF
    CRLF = PCRE2_NEWLINE_CRLF
    ANY = PCRE2_NEWLINE_ANY
    ANYCRLF = PCRE2_NEWLINE_ANYCRLF
    NUL = PCRE2_NEWLINE_NUL


# Shorthands
A = CompileOption.ANCHORED
I = CompileOption.CASELESS
G = SubstituteOption.GLOBAL
M = CompileOption.MULTILINE
NE = MatchOption.NOTEMPTY
NS = MatchOption.NOTEMPTY_ATSTART
U = CompileOption.UTF
S = CompileOption.DOTALL
X = CompileOption.EXTENDED
