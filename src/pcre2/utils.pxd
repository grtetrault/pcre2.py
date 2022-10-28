# -*- coding:utf-8 -*-

# Standard libraries.
from cpython cimport Py_buffer


cdef Py_buffer * get_buffer(object obj) except NULL

cdef (size_t, size_t) codeunit_to_codepoint(
    Py_buffer *pybuf,
    size_t codeunit_idx,
    size_t cur_codeunit_idx, size_t cur_codepoint_idx
)
cdef (size_t, size_t) codepoint_to_codeunit(
    Py_buffer *pybuf,
    size_t codepoint_idx,
    size_t cur_codeunit_idx, size_t cur_codepoint_idx
)

cdef void * raise_from_rc(int errorcode, object context_msg) except NULL
