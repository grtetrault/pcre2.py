# -*- coding:utf-8 -*-

# Standard libraries.
from enum import IntEnum
from libc.stdint cimport uint32_t
from libc.stdlib cimport malloc, free
from cpython cimport PyBuffer_Release
from cpython.unicode cimport PyUnicode_Check

# Local imports.
from .utils cimport *
from .libpcre2 cimport *
from .pattern cimport Pattern


cdef class Match:
    """

    See match.pxd for attribute definitions.

    Attributes:
        mtch:
        pattern: 
        subj:
        opts:
    """

    # =================================== #
    #         Lifetime management         #
    # =================================== #

    def __cinit__(self):
        self._mtch = NULL
        self._pattern = None
        self._subj = NULL
        self._opts = 0


    def __init__(self, *args, **kwargs):
        # Prevent accidental instantiation from normal Python code since we
        # cannot pass pointers into a Python constructor.
        module = self.__class__.__module__
        qualname = self.__class__.__qualname__
        raise TypeError(f"Cannot create '{module}.{qualname}' instances.")


    def __dealloc__(self):
        if self._subj is not NULL:
            PyBuffer_Release(self._subj)
        if self._mtch is not NULL:
            pcre2_match_data_free(self._mtch)


    @staticmethod
    cdef Match _from_data(pcre2_match_data_t *mtch, Pattern pattern,
            Py_buffer *subj, size_t spos, uint32_t opts
    ):
        """ Factory function to create Match objects from C-type fields.

        The ownership of the given pointers are stolen, which causes the
        extension type to free them when the object is deallocated.
        """

        # Fast call to __new__() that bypasses the __init__() constructor.
        cdef Match match = Match.__new__(Match)
        match._mtch = mtch
        match._pattern = pattern
        match._subj = subj
        match._spos = spos
        match._opts = opts
        return match


    # ======================= #
    #         Methods         #
    # ======================= #

    def substring(self, group=0):
        cdef uint8_t *res
        cdef size_t res_len
        if isinstance(group, int):
            grp_num = <uint32_t>group
            get_rc = pcre2_substring_get_bynumber(
                self._mtch, grp_num, &res, &res_len
            )
            if get_rc < 0:
                raise_from_rc(get_rc, None)
        else:
            grp_name = get_buffer(group)
            get_rc = pcre2_substring_get_byname(
                self._mtch, <pcre2_sptr_t>grp_name.buf, &res, &res_len
            )
            if get_rc < 0:
                raise_from_rc(get_rc, None)

        # Clean up result and convert to unicode as appropriate.
        result = (<pcre2_sptr_t>res)[:res_len]
        result = result.strip(b"\x00")
        if PyUnicode_Check(self._subj.obj):
            result = result.decode("utf-8")
            
        return result