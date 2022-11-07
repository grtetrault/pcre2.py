# -*- coding:utf-8 -*-

# Standard libraries.
from libc.stdint cimport uint32_t
from libc.stdlib cimport malloc, free
from cpython cimport Py_buffer, PyBuffer_Release
from cpython cimport array
from cpython.unicode cimport PyUnicode_Check
from cpython.memoryview cimport PyMemoryView_FromMemory

# Local imports.
from .utils cimport *
from .libpcre2 cimport *
from .match cimport Match
from .pattern cimport Pattern
from .consts import BsrChar, NewlineChar


cdef class Scanner:
    """ Iterator object that scans a subject all non-overlapping matches of a
    pattern. Attributes defined in scanner.pxd, see below for an overview:
        _pattern: Pattern object to use for matching
        _subject: Subject to scan
        _is_crlf_newline: Whether the character sequence CRLF denotes a newline
        _is_patn_utf: Whether the pattern was compiled with UTF support
        _state_opts: Options to pass to match
        _state_ofst: Byte offset to match at
        _state_obj_ofst: Object offset to match at
    """


    # =================================== #
    #         Lifetime management         #
    # =================================== #

    def __cinit__(self):
        self._pattern = None
        self._subject = None

        self._is_patn_utf = False
        self._is_crlf_newline = False

        self._state_opts = 0
        self._state_ofst = 0
        self._state_obj_ofst = 0


    def __init__(self, *args, **kwargs):
        # Prevent accidental instantiation from normal Python code since we
        # cannot pass pointers into a Python constructor.
        module = self.__class__.__module__
        qualname = self.__class__.__qualname__
        raise TypeError(f"Cannot create '{module}.{qualname}' instances")


    def __dealloc__(self):
        pass


    @staticmethod
    cdef Scanner _from_data(Pattern pattern, object subject, size_t offset):
        """ Factory function to create Scanner objects from C-type fields. The
        ownership of the given pointers are stolen, which causes the extension
        type to free them when the object is deallocated.
        """
        # Fast call to __new__() that bypasses the __init__() constructor.
        cdef Scanner scanner = Scanner.__new__(Scanner)
        scanner._pattern = pattern
        scanner._subject = subject

        patn_opts = Pattern._info_uint(pattern._code, PCRE2_INFO_ALLOPTIONS)
        scanner._is_patn_utf = (patn_opts & PCRE2_UTF) != 0
        newline = Pattern._info_uint(pattern._code, PCRE2_INFO_NEWLINE)
        scanner._is_crlf_newline = (
            newline == PCRE2_NEWLINE_ANY or
            newline == PCRE2_NEWLINE_CRLF or
            newline == PCRE2_NEWLINE_ANYCRLF
        )
        scanner._state_opts = 0

        # Compute and set byte equivalent offset.
        if scanner._is_patn_utf:
            subj = get_buffer(scanner._subject)
            ofst, obj_ofst = codepoint_to_codeunit(subj, offset, 0, 0)
            scanner._state_ofst = ofst
            scanner._state_obj_ofst = obj_ofst
        else:
            scanner._state_obj_ofst = offset
            scanner._state_ofst = scanner._state_obj_ofst
        return scanner


    # ======================================== #
    #         Iteration implementation         #
    # ======================================== #

    def __iter__(self):
        return self


    def __next__(self):
        """ Yields next match object found in subject.
        """
        if self._state_obj_ofst > <size_t>len(self._subject):
            raise StopIteration

        # Attempt match of pattern onto subject.
        match_rc = <int>0
        subj = get_buffer(self._subject)
        mtch = Pattern._match(
            self._pattern._code, subj, self._state_ofst, self._state_opts, &match_rc
        )

        # Handle no matches in result.
        if match_rc == PCRE2_ERROR_NOMATCH:
            # Default match is not achored so if no match found at current offset, then there
            # will not be any ahead either.
            if self._state_opts == 0:
                PyBuffer_Release(subj)
                raise StopIteration

            # Reset options so empty strings can match at next offset.
            self._state_opts = 0

            # Increment to next character and handle possible CRLF newlines.
            obj_ofst_increment = 1
            if self._is_crlf_newline and (self._state_ofst + 1) < <size_t>subj.len:
                if (<bytes>subj.buf)[self._state_ofst:self._state_ofst + 2] == b"\r\n": # and subj.buf[self._state_ofst + 1] == b"\n":
                    obj_ofst_increment += 1

            # Convert indices accordingly.
            if self._is_patn_utf:
                self._state_ofst, self._state_obj_ofst = codepoint_to_codeunit(
                    subj, self._state_obj_ofst + obj_ofst_increment,
                    self._state_ofst, self._state_obj_ofst
                )
            else:
                self._state_obj_ofst = self._state_obj_ofst + obj_ofst_increment
                self._state_ofst = self._state_obj_ofst
            return self.__next__()

        # Handle all other errors.
        elif mtch is NULL or match_rc < 0:
            raise_from_rc(match_rc, None)

        # If the match was successful.
        else:
            ovec_table = pcre2_get_ovector_pointer(mtch)
            mtch_end = ovec_table[1]

            if self._state_ofst == mtch_end:
                # If the matched string is empty ensure next is not.
                self._state_opts = PCRE2_NOTEMPTY_ATSTART | PCRE2_ANCHORED
            else:
                # Convert the end in the byte string to the end in the object.
                self._state_opts = 0
                if self._is_patn_utf:
                    self._state_ofst, self._state_obj_ofst = codeunit_to_codepoint(
                        subj, mtch_end,
                        self._state_ofst, self._state_obj_ofst
                    )
                else:
                    self._state_obj_ofst = mtch_end
                    self._state_ofst = self._state_obj_ofst

            return Match._from_data(mtch, self._pattern, subj, self._state_ofst,self._state_opts)
