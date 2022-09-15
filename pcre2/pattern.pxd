# -*- coding:utf-8 -*-

# Standard libraries.
from cpython cimport Py_buffer
from libc.stdint cimport uint32_t

# Local imports.
from .libpcre2 cimport *


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

    cdef pcre2_match_data_t * _match(
        self, Py_buffer *subj, size_t ofst, uint32_t opts, int *rc
    )