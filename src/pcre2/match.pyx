# -*- coding:utf-8 -*-

# Standard libraries.
from enum import IntEnum
from libc.stdint cimport uint32_t
from libc.stdlib cimport malloc, free
from cpython cimport PyBuffer_Release
from cpython.unicode cimport PyUnicode_Check
cimport cython

# Local imports.
from .utils cimport *
from .libpcre2 cimport *
from .pattern cimport Pattern


@cython.freelist(8)
cdef class Match:
    """
    Object wrapper for a match block in PCRE2. Contains all relevant
    information of a successful match. Attributes defined in match.pxd, see
    below for an overview:
        _mtch: Raw match data block, managed by PCRE2
        _pattern: Pattern object used in match
        _subj: Subject the pattern was matched against
        _ofst: Byte offset (egardless of subject type) used in  match
        _opts: Option bits used in match call
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
        raise TypeError(f"Cannot create '{module}.{qualname}' instances")


    def __dealloc__(self):
        if self._subj is not NULL:
            PyBuffer_Release(self._subj)
        if self._mtch is not NULL:
            pcre2_match_data_free(self._mtch)


    @staticmethod
    cdef Match _from_data(
            pcre2_match_data_t *mtch,
            Pattern pattern,
            Py_buffer *subj,
            size_t ofst,
            uint32_t opts):
        """ Factory function to create Match objects from C-type fields. The
        ownership of the given pointers are stolen, which causes the extension
        type to free them when the object is deallocated.
        """

        # Fast call to __new__() that bypasses the __init__() constructor.
        cdef Match match = Match.__new__(Match)
        match._mtch = mtch
        match._pattern = pattern
        match._subj = subj
        match._ofst = ofst # Code unit offset
        match._opts = opts
        return match


    # ========================== #
    #         Properties         #
    # ========================== #

    @property
    def options(self):
        return self._opts

    
    @property
    def subject(self):
        return self._subj.obj

    
    @property
    def pattern(self):
        return self._pattern


    # ======================= #
    #         Methods         #
    # ======================= #

    def start(self, group=0):
        """ Get the starting index of the matched substring, or of a specified
        captured group.
        """
        ovec_count = pcre2_get_ovector_count(self._mtch)
        ovec_table = pcre2_get_ovector_pointer(self._mtch)
        
        cdef int grp_num
        cdef pcre2_sptr_t first_entry
        cdef pcre2_sptr_t last_entry
        if isinstance(group, int):
            grp_num = group
        else:
            grp_name = get_buffer(group)
            pcre2_substring_nametable_scan(
                self._pattern._code, <pcre2_sptr_t>grp_name.buf, &first_entry, &last_entry
            )
            grp_num = (first_entry[0] << 8) | first_entry[1]
            if grp_num < 0:
                raise_from_rc(grp_num, None)
            PyBuffer_Release(grp_name)

        if grp_num > <int>ovec_count:
            raise ValueError("Group referenced out of bounds")
        start = ovec_table[2 * grp_num]

        # Convert to code unit index as necessary.
        if PyUnicode_Check(self._subj.obj):
            _, start = codeunit_to_codepoint(self._subj, start, 0, 0)

        return start


    def end(self, group=0):
        """ Get the ending index of the matched substring, or of a specified
        captured group.
        """
        ovec_count = pcre2_get_ovector_count(self._mtch)
        ovec_table = pcre2_get_ovector_pointer(self._mtch)
        
        cdef int grp_num
        cdef pcre2_sptr_t first_entry
        cdef pcre2_sptr_t last_entry
        if isinstance(group, int):
            grp_num = group
        else:
            grp_name = get_buffer(group)
            pcre2_substring_nametable_scan(
                self._pattern._code, <pcre2_sptr_t>grp_name.buf, &first_entry, &last_entry
            )
            grp_num = (first_entry[0] << 8) | first_entry[1]
            if grp_num < 0:
                raise_from_rc(grp_num, None)
            PyBuffer_Release(grp_name)

        if grp_num > <int>ovec_count:
            raise ValueError("Group referenced out of bounds.")
        end = ovec_table[2 * grp_num + 1]

        # Convert to code unit index as necessary.
        if PyUnicode_Check(self._subj.obj):
            _, end = codeunit_to_codepoint(self._subj, end, 0, 0)

        return end


    def substring(self, group=0):
        """ Get the full matched substring, or that of a specified captured
        group.
        """
        cdef uint8_t *res
        cdef size_t res_len
        if isinstance(group, int):
            grp_num = <uint32_t>group
            get_rc = pcre2_substring_get_bynumber(self._mtch, grp_num, &res, &res_len)
            if get_rc < 0:
                raise_from_rc(get_rc, None)
        else:
            grp_name = get_buffer(group)
            get_rc = pcre2_substring_get_byname(
                self._mtch, <pcre2_sptr_t>grp_name.buf, &res, &res_len
            )
            if get_rc < 0:
                raise_from_rc(get_rc, None)
            PyBuffer_Release(grp_name)

        # Clean up result and convert to unicode as appropriate.
        result = (<pcre2_sptr_t>res)[:res_len]
        result = result.strip(b"\x00")
        if PyUnicode_Check(self._subj.obj):
            result = result.decode("utf-8")
            
        return result


    def __getitem__(self, group):
        """ Alias to substring.
        """
        return self.substring(group)


    def expand(self, replacement, offset=0, options=0, low_memory=False):
        """ Equivalent to calling substitute with the provided match. The type
        of the subject determines the type of the returned string.
        """
        is_subj_utf = <bint>PyUnicode_Check(self._subj.obj)
        is_repl_utf = <bint>PyUnicode_Check(replacement)
        if is_subj_utf ^ is_repl_utf:
            subj_type = "string" if is_subj_utf else "bytes-like"
            repl_type = "string" if is_repl_utf else "bytes-like"
            raise ValueError(f"Cannot use a {subj_type} subject with a {repl_type} replacement")

        # Convert Python objects to C strings.
        repl = get_buffer(replacement)
        cdef size_t obj_ofst = <size_t>offset
        cdef size_t ofst = obj_ofst
        cdef uint32_t opts = <uint32_t>options | PCRE2_SUBSTITUTE_MATCHED
        if is_subj_utf:
            ofst, obj_ofst = codepoint_to_codeunit(self._subj, obj_ofst, 0, 0)

        cdef size_t res_buf_len = 0
        if not low_memory:
            res_buf_len = self._subj.len + (self._subj.len // 2)

        cdef int rc = 0
        res, res_len = Pattern._substitute(
            self._pattern._code, repl, self._subj, res_buf_len, ofst, opts, self._mtch, &rc
        )
        if res is NULL:
            raise_from_rc(rc, None)

        # Clean up result and convert to unicode as appropriate.
        result = (<pcre2_sptr_t>res)[:res_len]
        result = result.strip(b"\x00")
        if is_subj_utf:
            result = result.decode("utf-8")
        
        free(res)
        PyBuffer_Release(repl)
        return result

    def groups(self):
        """Return a tuple containing all the subgroups of the match, from 1 up to however many groups are in the pattern."""
        return tuple(self.substring(g) for g in range(self.pattern.capture_count))
