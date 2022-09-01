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
            Py_buffer *subj, size_t ofst, uint32_t opts
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
        match._ofst = ofst
        match._opts = opts
        return match


    # ========================== #
    #         Properties         #
    # ========================== #

    @property
    def options(self):
        return self._opts


    @property
    def offset(self):
        return self._ofst

    
    @property
    def subject(self):
        return self._subj.obj

    
    @property
    def pattern(self):
        return self._pattern


    # ======================= #
    #         Methods         #
    # ======================= #

    def startpos(self, group=0):
        cdef uint32_t ofst
        cdef uint32_t epos
        if isinstance(group, int):
            pass
        else:
            pass


    def endpos(self, group=0):
        if isinstance(group, int):
            pass
        else:
            pass


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


    def expand(self, replacement, offset=0, uint32_t options=0):
        """ Equivlanet to calling substitute with the provided match.
        The type of the subject determines the type of the returned string.
        """
        options = options | PCRE2_SUBSTITUTE_MATCHED

        # Convert Python objects to C strings.
        repl = get_buffer(replacement)
        if PyUnicode_Check(self._subj.obj):
            offset = codepoint_to_codeunit(self._subj, offset)

        # Dry run of substitution to get required replacement length.
        cdef uint8_t *res = NULL
        cdef size_t res_len = 0
        substitute_rc = pcre2_substitute(
            self._pattern._code,
            <pcre2_sptr_t>self._subj.buf, <size_t>self._subj.len,
            offset,
            options | PCRE2_SUBSTITUTE_OVERFLOW_LENGTH,
            self._mtch,
            NULL,
            <pcre2_sptr_t>repl.buf, <size_t>repl.len,
            res, &res_len
        )
        if substitute_rc != PCRE2_ERROR_NOMEMORY and substitute_rc < 0:
            raise_from_rc(substitute_rc, None)
        
        # Attempt string substitution.
        res = <uint8_t *>malloc(res_len * sizeof(uint8_t))
        substitute_rc = pcre2_substitute(
            self._pattern._code,
            <pcre2_sptr_t>self._subj.buf, <size_t>self._subj.len,
            offset,
            options,
            self._mtch,
            NULL,
            <pcre2_sptr_t>repl.buf, <size_t>repl.len,
            res, &res_len
        )
        if substitute_rc < 0:
            raise_from_rc(substitute_rc, None)

        # Clean up result and convert to unicode as appropriate.
        result = (<pcre2_sptr_t>res)[:res_len]
        result = result.strip(b"\x00")
        if PyUnicode_Check(self._subj.obj):
            result = result.decode("utf-8")
            
        return result