# -*- coding:utf-8 -*-

# Standard libraries.
from enum import IntEnum
from libc.stdint cimport uint32_t
from libc.stdlib cimport malloc, free
from cpython cimport Py_buffer, PyBuffer_Release
from cpython.unicode cimport PyUnicode_Check

# Local imports.
from .utils cimport *
from .libpcre2 cimport *
from .match cimport Match
from .consts import BsrChar, NewlineChar
from .exceptions import MatchError


cdef class Pattern:
    """

    Attributes:

        See pattern.pxd for attribute definitions.
        Dynamic attributes are enabled for this class.

        code: Compiled PCRE2 code.
        opts: PCRE2 compilation options.
        patn: Buffer containing source pattern expression including byte string
            and a reference to source object.
    """

    # =================================== #
    #         Lifetime management         #
    # =================================== #

    def __cinit__(self):
        self._code = NULL
        self._patn = NULL
        self._opts = 0


    def __init__(self, *args, **kwargs):
        # Prevent accidental instantiation from normal Python code since we
        # cannot pass pointers into a Python constructor.
        module = self.__class__.__module__
        qualname = self.__class__.__qualname__
        raise TypeError(f"Cannot create '{module}.{qualname}' instances.")


    def __dealloc__(self):
        if self._patn is not NULL:
            PyBuffer_Release(self._patn)
        if self._code is not NULL:
            pcre2_code_free(self._code)


    @staticmethod
    cdef Pattern _from_data(pcre2_code_t *code, Py_buffer *patn, uint32_t opts):
        """ Factory function to create Pattern objects from C-type fields.

        The ownership of the given pointers are stolen, which causes the
        extension type to free them when the object is deallocated.
        """
        # Fast call to __new__() that bypasses the __init__() constructor.
        cdef Pattern pattern = Pattern.__new__(Pattern)
        pattern._code = code
        pattern._patn = patn
        pattern._opts = opts
        return pattern


    # =================================== #
    #         Pattern information         #
    # =================================== #

    cdef uint32_t _pcre2_pattern_info_uint(self, uint32_t what):
        """ Safely access pattern info returned as uint32_t. 
        """
        cdef uint32_t where
        pattern_info_rc = pcre2_pattern_info(self._code, what, &where)
        if pattern_info_rc < 0:
            raise_from_rc(pattern_info_rc, None)
        return where


    cdef bint _pcre2_pattern_info_bint(self, uint32_t what):
        """ Safely access pattern info returned as bint. 
        """
        cdef bint where
        pattern_info_rc = pcre2_pattern_info(self._code, what, &where)
        if pattern_info_rc < 0:
            raise_from_rc(pattern_info_rc, None)
        return where


    @property
    def pattern(self):
        """ Return the pattern the object was compiled with.
        """
        return self._patn.obj

    
    @property
    def options(self):
        """ Return the options the object was compiled with.
        """
        return self._opts


    @property
    def all_options(self):
        """ Returns the compile options as modified by any top-level (*XXX)
        option settings such as (*UTF) at the start of the pattern itself.
        """
        return self._pcre2_pattern_info_uint(PCRE2_INFO_ALLOPTIONS)


    @property
    def backref_max(self):
        """ Return the number of the highest backreference in the pattern.
        """
        return self._pcre2_pattern_info_uint(PCRE2_INFO_BACKREFMAX)


    @property
    def backslash_r(self):
        """ Return an indicator to what character sequences the \R escape
        sequence matches.
        """
        bsr = self._pcre2_pattern_info_uint(PCRE2_INFO_BSR)
        return BsrChar(bsr)


    @property
    def capture_count(self):
        """ Return the highest capture group number in the pattern. In patterns
        where (?| is not used, this is also the total number of capture groups.
        """
        return self._pcre2_pattern_info_uint(PCRE2_INFO_CAPTURECOUNT)


    @property
    def depth_limit(self):
        """ If the pattern set a backtracking depth limit by including an item
        of the form (*LIMIT_DEPTH=nnnn) at the start, the value is returned. 
        """
        return self._pcre2_pattern_info_uint(PCRE2_INFO_DEPTHLIMIT)


    @property
    def has_blackslash_c(self):
        """ Return True if the pattern contains any instances of \C, otherwise
        False. 
        """
        return self._pcre2_pattern_info_bint(PCRE2_INFO_HASBACKSLASHC)


    @property
    def has_crorlf(self):
        """ Return True if the pattern contains any explicit matches for CR or
        LF characters, otherwise False. 
        """
        return self._pcre2_pattern_info_bint(PCRE2_INFO_HASCRORLF)


    @property
    def j_changed(self):
        """ Return True if the (?J) or (?-J) option setting is used in the
        pattern, otherwise False. 
        """
        return self._pcre2_pattern_info_bint(PCRE2_INFO_JCHANGED)


    @property
    def jit_size(self):
        """ If the compiled pattern was successfully JIT compiled, return the
        size of the JIT compiled code, otherwise return zero.
        """
        return self._pcre2_pattern_info_uint(PCRE2_INFO_JITSIZE)
    

    @property
    def match_empty(self):
        """ Return True if the pattern might match an empty string, otherwise
        False.
        """
        return self._pcre2_pattern_info_bint(PCRE2_INFO_MATCHEMPTY)


    @property
    def match_limit(self):
        """ If the pattern set a match limit by including an item of the form
        (*LIMIT_MATCH=nnnn) at the start, the value is returned. 
        """
        return self._pcre2_pattern_info_uint(PCRE2_INFO_MATCHLIMIT)


    @property
    def max_lookbehind(self):
        """ A lookbehind assertion moves back a certain number of characters
        (not code units) when it starts to process each of its branches. This
        request returns the largest of these backward moves.
        """
        return self._pcre2_pattern_info_uint(PCRE2_INFO_MAXLOOKBEHIND)


    @property
    def min_length(self):
        """ If a minimum length for matching subject strings was computed, its
        value is returned. Otherwise the returned value is 0. This value is not
        computed when CompileOption.NO_START_OPTIMIZE is set.
        """
        return self._pcre2_pattern_info_uint(PCRE2_INFO_MINLENGTH)

    
    @property
    def name_count(self):
        """ Returns the number of named capture groups.
        """
        return self._pcre2_pattern_info_uint(PCRE2_INFO_NAMECOUNT)


    @property
    def newline(self):
        """ Returns the type of character sequence that will be recognized as 
        meaning "newline" while matching.
        """
        newline = self._pcre2_pattern_info_uint(PCRE2_INFO_NEWLINE)
        return NewlineChar(newline)


    @property
    def size(self):
        """ Return the size of the compiled pattern in bytes.
        """
        return self._pcre2_pattern_info_uint(PCRE2_INFO_SIZE)


    def name_dict(self):
        """ Returns a dictionary mapping capture group number to capture group
        name.
        """
        # Get name table related information.
        name_count = self._pcre2_pattern_info_uint(PCRE2_INFO_NAMECOUNT)
        name_entry_size = self._pcre2_pattern_info_uint(PCRE2_INFO_NAMEENTRYSIZE)

        cdef pcre2_sptr_t name_table
        pattern_info_rc = pcre2_pattern_info(self._code, PCRE2_INFO_NAMETABLE, &name_table)
        if pattern_info_rc < 0:
            raise_from_rc(pattern_info_rc, None)

        # Convert byte table to dictionary.
        name_dict = {}
        cdef uint32_t i
        for i in range(name_count):
            offset = i * name_entry_size

            # First two bytes of name table contain index, followed by possibly
            # unicode byte string.
            entry_idx = int((name_table[offset] << 8) | name_table[offset + 1])
            entry_name = name_table[offset + 2:offset + name_entry_size]

            # Clean up entry and convert to unicode as appropriate.
            entry_name = entry_name.strip(b"\x00")
            if PyUnicode_Check(self._patn.obj):
                entry_name = entry_name.decode("utf-8")

            name_dict[entry_idx] = entry_name

        return name_dict


    # ======================= #
    #         Methods         #
    # ======================= #

    def jit_compile(self):
        """
        """
        jit_compile_rc = pcre2_jit_compile(self._code, PCRE2_JIT_COMPLETE)
        if jit_compile_rc < 0:
            raise_from_rc(jit_compile_rc, None)


    def match(self, subject, size_t offset=0, uint32_t options=0):
        """
        """
        subj = get_buffer(subject)

        # Convert indices accordingly.
        if PyUnicode_Check(subject):
            offset = codepoint_to_codeunit(subj, offset)

        # Allocate memory for match.
        mtch = pcre2_match_data_create_from_pattern(
            self._code,
            NULL
        )
        if not mtch:
            raise MemoryError()

        # Attempt match of pattern onto subject.
        match_rc = pcre2_match(
            self._code,
            <pcre2_sptr_t>subj.buf, <size_t>subj.len,
            offset,
            options,
            mtch,
            NULL
        )
        if match_rc < 0:
            raise_from_rc(match_rc, None)
            
        return Match._from_data(mtch, self, subj, offset, options)


    def finditer(self, subject, size_t offset=0):
        """
        """
        all_options = self._pcre2_pattern_info_uint(PCRE2_INFO_ALLOPTIONS)
        is_utf = (all_options & PCRE2_UTF) != 0

        newline = self._pcre2_pattern_info_uint(PCRE2_INFO_NEWLINE)
        is_crlf_newline = (
            newline == PCRE2_NEWLINE_ANY or
            newline == PCRE2_NEWLINE_CRLF or
            newline == PCRE2_NEWLINE_ANYCRLF
        )
        
        iter_offset = offset
        options = <uint32_t>0
        while True:
            print(iter_offset)
            # Ensure all new match data blocks created own their buffers to 
            # avoid multiple buffer releases. Note that Python strings cache
            # their UTF-8 encodings, so no repeated work is done.
            subj = get_buffer(subject)
            if iter_offset > subj.len:
                break

            # Attempt match of pattern onto subject.
            try:
                match = <Match>self.match(subject, iter_offset, options)
                ovec_table = pcre2_get_ovector_pointer(match._mtch)
                endpos = ovec_table[1]

                # If the matched string is empty ensure next is not. Otherwise
                # reset options and allow for empty matches.
                options = (
                    options | PCRE2_NOTEMPTY_ATSTART | PCRE2_ANCHORED
                    if endpos == iter_offset else 0
                )
                iter_offset = endpos
                yield match

            except MatchError:
                iter_offset += 1

                # If we are at a CRLF that is matched as a newline.
                if (
                    is_crlf_newline and 
                    (iter_offset < subj.len - 1) and
                    subj.buf[iter_offset] == b"\r" and
                    subj.buf[iter_offset + 1] == b"\n"
                ):
                    iter_offset += 1
  
                # Otherwise ensure we advance a whole codepoint.
                elif is_utf:
                    while iter_offset < subj.len:
                        if (((<uint8_t *>subj.buf)[iter_offset]) & 0xC0) != 0x80:
                            break
                        iter_offset += 1

                # Reset options so empty strings can match at next offset.
                options = 0


    def substitute(self, replacement, subject, size_t offset=0, uint32_t options=0):
        """ The type of the subject determines the type of the returned string.
        """
        # Convert Python objects to C strings.
        subj = get_buffer(subject)
        repl = get_buffer(replacement)
        if PyUnicode_Check(subject):
            offset = codepoint_to_codeunit(subj, offset)

        # Dry run of substitution to get required replacement length.
        cdef uint8_t *res = NULL
        cdef size_t res_len = 0
        substitute_rc = pcre2_substitute(
            self._code,
            <pcre2_sptr_t>subj.buf, <size_t>subj.len,
            offset,
            options | PCRE2_SUBSTITUTE_OVERFLOW_LENGTH,
            NULL,
            NULL,
            <pcre2_sptr_t>repl.buf, <size_t>repl.len,
            res, &res_len
        )
        if substitute_rc != PCRE2_ERROR_NOMEMORY and substitute_rc < 0:
            raise_from_rc(substitute_rc, None)
        
        # Attempt string substitution.
        res = <uint8_t *>malloc(res_len * sizeof(uint8_t))
        substitute_rc = pcre2_substitute(
            self._code,
            <pcre2_sptr_t>subj.buf, <size_t>subj.len,
            offset,
            options,
            NULL,
            NULL,
            <pcre2_sptr_t>repl.buf, <size_t>repl.len,
            res, &res_len
        )
        if substitute_rc < 0:
            raise_from_rc(substitute_rc, None)
        PyBuffer_Release(subj)
        PyBuffer_Release(repl)

        # Clean up result and convert to unicode as appropriate.
        result = (<pcre2_sptr_t>res)[:res_len]
        result = result.strip(b"\x00")
        if PyUnicode_Check(subject):
            result = result.decode("utf-8")
            
        return result
