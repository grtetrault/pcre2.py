# -*- coding:utf-8 -*-

# Standard libraries.
from cpython cimport Py_buffer
from libc.stdint cimport uint32_t

# Local imports.
from .libpcre2 cimport *
from .pattern cimport Pattern


cdef class Match:
    cdef pcre2_match_data_t *_mtch
    cdef Pattern _pattern
    cdef Py_buffer *_subj
    cdef size_t _ofst # Byte offset, regardless of subject type.
    cdef uint32_t _opts

    @staticmethod
    cdef Match _from_data(
        pcre2_match_data_t *mtch, Pattern pattern, Py_buffer *subj, size_t ofst, uint32_t opts
    )
