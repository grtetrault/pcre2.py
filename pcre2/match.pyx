# -*- coding:utf-8 -*-

# _____________________________________________________________________________
#                                                                       Imports

# Standard libraries.
from enum import IntEnum
from libc.stdint cimport uint32_t
from cpython cimport PyBuffer_Release
from cpython.unicode cimport PyUnicode_Check

# Local imports.
from pcre2._libs.libpcre2 cimport *
from pcre2.exceptions cimport raise_from_rc
from pcre2._utils.strings cimport (
    get_buffer, codeunit_to_codepoint
)
from pcre2.pattern cimport Pattern



# _____________________________________________________________________________
#                                                                     Constants

class MatchOption(IntEnum):
    NOTBOL = PCRE2_NOTBOL
    NOTEOL = PCRE2_NOTEOL
    NOTEMPTY = PCRE2_NOTEMPTY
    NOTEMPTY_ATSTART = PCRE2_NOTEMPTY_ATSTART
    PARTIAL_SOFT = PCRE2_PARTIAL_SOFT
    PARTIAL_HARD = PCRE2_PARTIAL_HARD
    NO_JIT = PCRE2_NO_JIT


class ExpandOption(IntEnum):
    # Options shared with matching.
    NOTBOL = PCRE2_NOTBOL
    NOTEOL = PCRE2_NOTEOL
    NOTEMPTY = PCRE2_NOTEMPTY
    NOTEMPTY_ATSTART = PCRE2_NOTEMPTY_ATSTART
    PARTIAL_SOFT = PCRE2_PARTIAL_SOFT
    PARTIAL_HARD = PCRE2_PARTIAL_HARD
    NO_JIT = PCRE2_NO_JIT

    # Substitute only options.
    GLOBAL = PCRE2_SUBSTITUTE_GLOBAL
    EXTENDED = PCRE2_SUBSTITUTE_EXTENDED
    UNSET_EMPTY = PCRE2_SUBSTITUTE_UNSET_EMPTY
    UNKNOWN_UNSET = PCRE2_SUBSTITUTE_UNKNOWN_UNSET
    OVERFLOW_LENGTH = PCRE2_SUBSTITUTE_OVERFLOW_LENGTH
    LITERAL = PCRE2_SUBSTITUTE_LITERAL
    REPLACEMENT_ONLY = PCRE2_SUBSTITUTE_REPLACEMENT_ONLY


# _____________________________________________________________________________
#                                                                   Match class
cdef class Match:
    """

    See match.pxd for attribute definitions.

    Attributes:
        match_data:
        pattern: 
        subject:
        options:
    """
    

    # _________________________________________________________________
    #                                    Lifetime and memory management

    def __cinit__(self, Pattern pattern, object subject, uint32_t options=0):
        # Only allow for unicode-to-unicode and bytes-to-bytes comparisons.
        if PyUnicode_Check(subject) and not PyUnicode_Check(pattern.pattern.obj):
            raise ValueError("Cannot use a unicode pattern on a bytes-like object.")

        elif not PyUnicode_Check(subject) and PyUnicode_Check(pattern.pattern.obj):
            raise ValueError("Cannot use a bytes-like pattern on a unicode object.")

        self.pattern = pattern
        self.subject = get_buffer(subject)
        self.options = options

        # Attempt match of pattern onto subject.
        self.match_data = pcre2_match_data_create_from_pattern(self.pattern.code, NULL)
        if not self.match_data:
            raise MemoryError()
        
        cdef int match_rc = pcre2_match(
            self.pattern.code,
            <pcre2_sptr_t>self.subject.buf,
            <size_t>self.subject.len,
            0, # Start offset.
            self.options,
            self.match_data,
            NULL
        )
        if match_rc < 0:
            raise_from_rc(match_rc, None)


    def __dealloc__(self):
        PyBuffer_Release(self.subject)
        pcre2_match_data_free(self.match_data)
