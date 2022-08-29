# -*- coding:utf-8 -*-

# _____________________________________________________________________________
#                                                                       Imports

# Standard libraries.
from cpython cimport Py_buffer


# _____________________________________________________________________________
#                                                                   Definitions

cdef Py_buffer * get_buffer(object obj)
cdef size_t codeunit_to_codepoint(Py_buffer *pybuf, size_t codeunit_idx)
cdef size_t codepoint_to_codeunit(Py_buffer *pybuf, size_t codepoint_idx)