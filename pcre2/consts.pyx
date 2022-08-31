# -*- coding:utf-8 -*-

# Standard libraries.
from enum import IntEnum

# Local imports.
from .utils cimport *
from .libpcre2 cimport *


class MetaOption(IntEnum):
    def __repr__(self):
        return f"<{self.__class__.__name__}.{self._name_}: 0x{self._value_:x}>"

    @classmethod
    def verify(cls, options):
        """ Verify a number is composed of compile options.
        """
        tmp = options
        for opt in cls:
            tmp ^= (opt & tmp)
        return tmp == 0


    @classmethod
    def decompose(cls, options):
        """ Decompose a number into its components compile options.

        Return a list of CompileOption enums that are components of the given
        optins. Note that left over bits are ignored, and veracity can not be
        determined from the result.
        """
        return [opt for opt in cls if (opt & options)]


class CompileOption(MetaOption):
    ANCHORED = PCRE2_ANCHORED
    NO_UTF_CHECK = PCRE2_NO_UTF_CHECK
    ENDANCHORED = PCRE2_ENDANCHORED
    ALLOW_EMPTY_CLASS = PCRE2_ALLOW_EMPTY_CLASS
    ALT_BSUX = PCRE2_ALT_BSUX
    AUTO_CALLOUT = PCRE2_AUTO_CALLOUT
    CASELESS = PCRE2_CASELESS
    DOLLAR_ENDONLY = PCRE2_DOLLAR_ENDONLY
    DOTALL = PCRE2_DOTALL
    DUPNAMES = PCRE2_DUPNAMES
    EXTENDED = PCRE2_EXTENDED
    FIRSTLINE = PCRE2_FIRSTLINE
    MATCH_UNSET_BACKREF = PCRE2_MATCH_UNSET_BACKREF
    MULTILINE = PCRE2_MULTILINE
    NEVER_UCP = PCRE2_NEVER_UCP
    NEVER_UTF = PCRE2_NEVER_UTF
    NO_AUTO_CAPTURE = PCRE2_NO_AUTO_CAPTURE
    NO_AUTO_POSSESS = PCRE2_NO_AUTO_POSSESS
    NO_DOTSTAR_ANCHOR = PCRE2_NO_DOTSTAR_ANCHOR
    NO_START_OPTIMIZE = PCRE2_NO_START_OPTIMIZE
    UCP = PCRE2_UCP
    UNGREEDY = PCRE2_UNGREEDY
    UTF = PCRE2_UTF
    NEVER_BACKSLASH_C = PCRE2_NEVER_BACKSLASH_C
    ALT_CIRCUMFLEX = PCRE2_ALT_CIRCUMFLEX
    ALT_VERBNAMES = PCRE2_ALT_VERBNAMES
    USE_OFFSET_LIMIT = PCRE2_USE_OFFSET_LIMIT
    EXTENDED_MORE = PCRE2_EXTENDED_MORE
    LITERAL = PCRE2_LITERAL
    MATCH_INVALID_UTF = PCRE2_MATCH_INVALID_UTF


class MatchOption(MetaOption):
    NOTBOL = PCRE2_NOTBOL
    NOTEOL = PCRE2_NOTEOL
    NOTEMPTY = PCRE2_NOTEMPTY
    NOTEMPTY_ATSTART = PCRE2_NOTEMPTY_ATSTART
    NO_JIT = PCRE2_NO_JIT


class SubstituteOption(MetaOption):
    NOTBOL = PCRE2_NOTBOL
    NOTEOL = PCRE2_NOTEOL
    NOTEMPTY = PCRE2_NOTEMPTY
    NOTEMPTY_ATSTART = PCRE2_NOTEMPTY_ATSTART
    NO_JIT = PCRE2_NO_JIT
    GLOBAL = PCRE2_SUBSTITUTE_GLOBAL
    EXTENDED = PCRE2_SUBSTITUTE_EXTENDED
    UNSET_EMPTY = PCRE2_SUBSTITUTE_UNSET_EMPTY
    UNKNOWN_UNSET = PCRE2_SUBSTITUTE_UNKNOWN_UNSET
    LITERAL = PCRE2_SUBSTITUTE_LITERAL
    REPLACEMENT_ONLY = PCRE2_SUBSTITUTE_REPLACEMENT_ONLY

# Type alias.
ExpandOption = SubstituteOption


class BsrChar(IntEnum):
    UNICODE = PCRE2_BSR_UNICODE
    ANYCRLF = PCRE2_BSR_ANYCRLF


class NewlineChar(IntEnum):
    CR = PCRE2_NEWLINE_CR
    LF = PCRE2_NEWLINE_LF
    CRLF = PCRE2_NEWLINE_CRLF
    ANY = PCRE2_NEWLINE_ANY
    ANYCRLF = PCRE2_NEWLINE_ANYCRLF
    NUL = PCRE2_NEWLINE_NUL