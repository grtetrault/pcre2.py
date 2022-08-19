# -*- coding:utf-8 -*-

# _____________________________________________________________________________
#                                                                       Imports

# Standard libraries.
from libc.stdlib cimport malloc, free
from libc.stdint cimport uint32_t
from cpython cimport Py_buffer, PyBuffer_Release
from cpython.unicode cimport PyUnicode_Check

# Local imports.
from pcre2._libs.libpcre2 cimport (
    sptr_t, match_data_t, 
    match, match_data_create_from_pattern, match_data_free,
    substring_get_byname, substring_get_bynumber,
    substitute, SUBSTITUTE_MATCHED, SUBSTITUTE_REPLACEMENT_ONLY,
    ERROR_UNSET
)

from pcre2._utils.strings cimport get_buffer
from pcre2.core.exceptions cimport raise_from_rc
from pcre2.core.pattern cimport Pattern


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
        self.match_data = match_data_create_from_pattern(self.pattern.code, NULL)
        if not self.match_data:
            raise MemoryError()
        
        cdef int match_rc = match(
            self.pattern.code,
            <sptr_t>self.subject.buf, <size_t>self.subject.len,
            0, # Start offset.
            self.options,
            self.match_data,
            NULL
        )
        if match_rc < 0:
            raise_from_rc(match_rc, None)


    def __dealloc__(self):
        PyBuffer_Release(self.subject)
        match_data_free(self.match_data)
