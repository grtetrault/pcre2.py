# -*- coding:utf-8 -*-

# Standard libraries.
from cpython cimport Py_buffer
from libc.stdint cimport uint32_t

# Local imports.
from .libpcre2 cimport *
from .pattern cimport Pattern


cdef class Scanner:
    cdef Pattern _pattern
    cdef Py_buffer *_subj

    cdef bint _is_crlf_newline
    cdef bint _is_patn_utf

    cdef uint32_t _state_opts
    cdef size_t _state_ofst
    cdef size_t _state_obj_ofst

    @staticmethod
    cdef Scanner _from_data(
        Pattern pattern, Py_buffer *subject, size_t offset
    )
