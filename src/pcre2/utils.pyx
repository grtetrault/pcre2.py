# -*- coding:utf-8 -*-

# Standard libraries.
from libc.stdlib cimport malloc, free
from libc.stdint cimport uint8_t
from cpython cimport Py_buffer
from cpython.buffer cimport (
    PyObject_CheckBuffer,
    PyBuffer_IsContiguous,
    PyObject_GetBuffer,
    PyBuffer_FillInfo,
    PyBuffer_Release
)
from cpython.unicode cimport (
    PyUnicode_Check
)
cdef extern from "Python.h":
    int PyUnicode_1BYTE_KIND
    int PyUnicode_2BYTE_KIND
    int PyUnicode_4BYTE_KIND
    unsigned int PyUnicode_KIND(object o)
    void *PyUnicode_DATA(object o)
    const char * PyUnicode_AsUTF8AndSize(object unicode, Py_ssize_t *size)

# Local imports.
from .libpcre2 cimport *
from .exceptions import LibraryError, CompileError, MatchError


cdef Py_buffer * get_buffer(object obj) except NULL:
    """ Get a Python buffer from an object, encoding via UTF-8 if unicode
    based
    """
    cdef const char *sptr = NULL
    cdef Py_ssize_t length = 0

    pybuf = <Py_buffer *>malloc(sizeof(Py_buffer))
    if not pybuf:
        raise MemoryError()

    # Process unicode and derivative objects.
    if PyUnicode_Check(obj):
        sptr = PyUnicode_AsUTF8AndSize(obj, &length)
        fill_buf_rc = PyBuffer_FillInfo(pybuf, obj, <void *>sptr, length, 1, 0)
        if fill_buf_rc < 0:
            PyBuffer_Release(pybuf)
            free(pybuf)
            raise ValueError("Could not fill internal buffer")
    
    # Handle all other bytes-like objects.
    else:
        if PyObject_CheckBuffer(obj):
            get_buffer_rc = PyObject_GetBuffer(obj, pybuf, 0)
            if not PyBuffer_IsContiguous(pybuf, b"A"):
                PyBuffer_Release(pybuf)
                free(pybuf)
                raise ValueError("Bytes-like object must be contiguous")
        else:
            free(pybuf)
            raise ValueError("Input must be string or bytes-like")

    return pybuf


cdef (size_t, size_t) codeunit_to_codepoint(
    Py_buffer *pybuf,
    size_t codeunit_idx,
    size_t cur_codeunit_idx, size_t cur_codepoint_idx
):
    """ Convert a code unit index to a code point index
    """
    while cur_codeunit_idx < codeunit_idx:
        if (((<uint8_t *>pybuf.buf)[cur_codeunit_idx]) & 0xC0) != 0x80:
            cur_codepoint_idx += 1
        cur_codeunit_idx += 1
    return cur_codeunit_idx, cur_codepoint_idx

    
cdef (size_t, size_t) codepoint_to_codeunit(
    Py_buffer *pybuf,
    size_t codepoint_idx,
    size_t cur_codeunit_idx, size_t cur_codepoint_idx
):
    """
    """
    while cur_codepoint_idx < codepoint_idx:
        cur_codeunit_idx += 1
        if (((<uint8_t *>pybuf.buf)[cur_codeunit_idx]) & 0xC0) != 0x80:
            cur_codepoint_idx += 1
    return cur_codeunit_idx, cur_codepoint_idx


cdef void * raise_from_rc(int errorcode, object context_msg) except NULL:
    """ Raise the appropriate error type from the given error code

    Raises one of the custom exception classes defined in this module. Each
    exception corresponds to a set of error codes defined in PCRE2. Error
    messages are retrieved from PCRE2.
    """
    # Match against error code classes.
    if errorcode > 0:
        raise CompileError(errorcode, context_msg)

    elif errorcode == PCRE2_ERROR_NOMATCH or errorcode == PCRE2_ERROR_PARTIAL:
        raise MatchError(errorcode, context_msg)

    else:
        raise LibraryError(errorcode, context_msg)
