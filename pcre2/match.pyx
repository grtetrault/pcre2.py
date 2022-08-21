# -*- coding:utf-8 -*-

# _____________________________________________________________________________
#                                                                       Imports

# Standard libraries.
from libc.stdlib cimport malloc, free
from libc.stdint cimport uint32_t
from cpython cimport Py_buffer, PyBuffer_Release
from cpython.unicode cimport PyUnicode_Check

from enum import Enum, Flag

# Local imports.
from pcre2._libs.libpcre2 cimport (
    pcre2_sptr_t,
    pcre2_match_data_t, 
    pcre2_match,
    pcre2_match_data_create_from_pattern,
    pcre2_match_data_free,
    pcre2_substring_get_byname,
    pcre2_substring_get_bynumber,
    pcre2_substitute,

    PCRE2_NOTBOL,
    PCRE2_NOTEOL,
    PCRE2_NOTEMPTY,
    PCRE2_NOTEMPTY_ATSTART,
    PCRE2_PARTIAL_SOFT,
    PCRE2_PARTIAL_HARD,
    PCRE2_DFA_RESTART,
    PCRE2_DFA_SHORTEST,
    PCRE2_SUBSTITUTE_GLOBAL,
    PCRE2_SUBSTITUTE_EXTENDED,
    PCRE2_SUBSTITUTE_UNSET_EMPTY,
    PCRE2_SUBSTITUTE_UNKNOWN_UNSET,
    PCRE2_SUBSTITUTE_OVERFLOW_LENGTH,
    PCRE2_NO_JIT,
    PCRE2_COPY_MATCHED_SUBJECT,
    PCRE2_SUBSTITUTE_LITERAL,
    PCRE2_SUBSTITUTE_MATCHED,
    PCRE2_SUBSTITUTE_REPLACEMENT_ONLY,

    PCRE2_ERROR_UNSET
)

from pcre2._utils.strings cimport get_buffer
from pcre2.exceptions cimport raise_from_rc
from pcre2.pattern cimport Pattern



# _____________________________________________________________________________
#                                                                     Constants

class MatchFlag(Flag):
    NONE = 0
    NOTBOL = PCRE2_NOTBOL
    NOTEOL = PCRE2_NOTEOL
    NOTEMPTY = PCRE2_NOTEMPTY
    NOTEMPTY_ATSTART = PCRE2_NOTEMPTY_ATSTART
    PARTIAL_SOFT = PCRE2_PARTIAL_SOFT
    PARTIAL_HARD = PCRE2_PARTIAL_HARD
    NO_JIT = PCRE2_NO_JIT


class ExpandFlag(Flag):
    NONE = 0

    # Option flags shared with matching.
    NOTBOL = PCRE2_NOTBOL
    NOTEOL = PCRE2_NOTEOL
    NOTEMPTY = PCRE2_NOTEMPTY
    NOTEMPTY_ATSTART = PCRE2_NOTEMPTY_ATSTART
    PARTIAL_SOFT = PCRE2_PARTIAL_SOFT
    PARTIAL_HARD = PCRE2_PARTIAL_HARD
    NO_JIT = PCRE2_NO_JIT

    # Substitute only flags.
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
        flags:
    """
    

    # _________________________________________________________________
    #                                    Lifetime and memory management

    def __cinit__(self, Pattern pattern, object subject, object flags=MatchFlag.NONE):
        if not isinstance(flags, MatchFlag):
            raise ValueError("Flags must be of type MatchFlag.")

        # Only allow for unicode-to-unicode and bytes-to-bytes comparisons.
        if PyUnicode_Check(subject) and not PyUnicode_Check(pattern.pattern.obj):
            raise ValueError("Cannot use a unicode pattern on a bytes-like object.")

        elif not PyUnicode_Check(subject) and PyUnicode_Check(pattern.pattern.obj):
            raise ValueError("Cannot use a bytes-like pattern on a unicode object.")

        self.pattern = pattern
        self.subject = get_buffer(subject)
        self.flags = flags

        # Attempt match of pattern onto subject.
        self.match_data = pcre2_match_data_create_from_pattern(self.pattern.code, NULL)
        if not self.match_data:
            raise MemoryError()
        
        cdef int match_rc = pcre2_match(
            self.pattern.code,
            <pcre2_sptr_t>self.subject.buf,
            <size_t>self.subject.len,
            0, # Start offset.
            self.flags.value,
            self.match_data,
            NULL
        )
        if match_rc < 0:
            raise_from_rc(match_rc, None)


    def __dealloc__(self):
        PyBuffer_Release(self.subject)
        pcre2_match_data_free(self.match_data)
