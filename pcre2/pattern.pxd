# -*- coding:utf-8 -*-

# _____________________________________________________________________________
#                                                                       Imports

# Standard libraries.
from cpython cimport Py_buffer
from libc.stdint cimport uint32_t

# Local imports.
from pcre2._libs.libpcre2 cimport *


# _____________________________________________________________________________
#                                                                   Definitions

cdef class Pattern:
    cdef pcre2_code_t *_code
    cdef Py_buffer *_patn
    cdef uint32_t _opts

    @staticmethod
    cdef Pattern _from_data(
        pcre2_code_t *code,
        Py_buffer *patn,
        uint32_t opts
    )

    cdef uint32_t _pcre2_pattern_info_uint(self, uint32_t what)

    cdef bint _pcre2_pattern_info_bint(self, uint32_t what)