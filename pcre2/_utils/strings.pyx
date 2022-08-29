# -*- coding:utf-8 -*-

# _____________________________________________________________________________
#                                                                       Imports

# Standard libraries.
from libc.stdlib cimport malloc
from libc.stdint cimport uint8_t
from cpython cimport Py_buffer
from cpython.unicode cimport PyUnicode_Check
from cpython.buffer cimport (
    PyObject_CheckBuffer,
    PyBuffer_IsContiguous,
    PyObject_GetBuffer,
    PyBuffer_FillInfo
)

cdef extern from "Python.h":
    # Unicode string handling.
    const char * PyUnicode_AsUTF8AndSize(object unicode, Py_ssize_t *size)


# _____________________________________________________________________________
#                                                              String utilities

cdef Py_buffer * get_buffer(object obj):
    """ Get a Python buffer from an object, encoding via UTF-8 if unicode
    based.
    """
    cdef const char *sptr = NULL
    cdef Py_ssize_t length = 0

    pybuf = <Py_buffer *>malloc(sizeof(Py_buffer))
    if not pybuf:
        raise MemoryError()

    # Process unicode and derivative objects.
    if PyUnicode_Check(obj):
        sptr = PyUnicode_AsUTF8AndSize(obj, &length)
        PyBuffer_FillInfo(pybuf, obj, <void *>sptr, length, 1, 0)
    
    # Handle all other bytes-like objects.
    else:
        if PyObject_CheckBuffer(obj):
            get_buffer_rc = PyObject_GetBuffer(obj, pybuf, 0)
            if not PyBuffer_IsContiguous(pybuf, b"C"):
                raise ValueError("Bytes-like object must be C-style contiguous.")
        else:
            raise ValueError("Input must be string or bytes-like.")

    return pybuf


cdef size_t codeunit_to_codepoint(Py_buffer *pybuf, size_t codeunit_idx):
    """ Convert a code unit index to a code point index.
    """
    cdef size_t cur_codeunit_idx = 0
    cdef size_t cur_codepoint_idx = 0
    for cur_codeunit_idx in range(codeunit_idx):
        if (((<uint8_t *>pybuf.buf)[cur_codeunit_idx]) & 0xC0) != 0x80:
            cur_codepoint_idx += 1
    return cur_codepoint_idx

    
cdef size_t codepoint_to_codeunit(Py_buffer *pybuf, size_t codepoint_idx):
    """
    """

    cdef size_t cur_codeunit_idx = 0
    cdef size_t cur_codepoint_idx = 0
    while cur_codepoint_idx <= codepoint_idx:
        if (((<uint8_t *>pybuf.buf)[cur_codeunit_idx]) & 0xC0) != 0x80:
            cur_codepoint_idx += 1
        cur_codeunit_idx += 1
    return cur_codeunit_idx
