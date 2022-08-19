# -*- coding:utf-8 -*-

# _____________________________________________________________________________
#                                                                       Imports

# Standard libraries.
from cpython cimport Py_buffer
from libc.stdint cimport uint8_t, uint32_t

# Local imports.
from pcre2._libs.libpcre2 cimport match_data_t
from pcre2.core.pattern cimport Pattern


# _____________________________________________________________________________
#                                                                   Definitions

cdef class Match:
    cdef match_data_t *match_data
    cdef Pattern pattern
    cdef Py_buffer *subject
    cdef readonly uint32_t options