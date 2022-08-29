# -*- coding:utf-8 -*-

# _____________________________________________________________________________
#                                                                       Imports

# Standard libraries.
from cpython cimport Py_buffer
from libc.stdint cimport uint32_t

# Local imports.
from pcre2._libs.libpcre2 cimport *
from pcre2.pattern cimport Pattern


# _____________________________________________________________________________
#                                                                   Definitions

cdef class Match:
    cdef pcre2_match_data_t *_mtch
    cdef Pattern _pattern
    cdef Py_buffer *_subj
    cdef uint32_t _opts

    @staticmethod
    cdef Match _from_data(
        pcre2_match_data_t *mtch,
        Pattern pattern,
        Py_buffer *subj,
        uint32_t opts
    )