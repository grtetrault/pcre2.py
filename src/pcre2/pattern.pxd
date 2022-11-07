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
    cdef bint _jitc

    @staticmethod
    cdef Pattern _from_data(
        pcre2_code_t *code, Py_buffer *patn, uint32_t opts
    )

    @staticmethod
    cdef uint32_t _info_uint(pcre2_code_t *code, uint32_t what) except *
    @staticmethod
    cdef size_t _info_size(pcre2_code_t *code, uint32_t what) except *
    @staticmethod
    cdef bint _info_bint(pcre2_code_t *code, uint32_t what) except *

    @staticmethod
    cdef pcre2_match_data_t * _match(
        pcre2_code_t *code, Py_buffer *subj, size_t ofst, uint32_t opts, int *rc
    )

    @staticmethod
    cdef (uint8_t *, size_t) _substitute(
        pcre2_code_t *code, Py_buffer *repl, Py_buffer *subj, size_t res_buf_len,
        size_t ofst, uint32_t opts, pcre2_match_data_t *mtch, int *rc
    )
