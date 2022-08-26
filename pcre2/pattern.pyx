# -*- coding:utf-8 -*-

# _____________________________________________________________________________
#                                                                       Imports

# Standard libraries.
from enum import IntEnum
from libc.stdint cimport uint32_t
from cpython cimport PyBuffer_Release
from cpython.unicode cimport PyUnicode_Check

# Local imports.
from pcre2._libs.libpcre2 cimport *
from pcre2.exceptions cimport raise_from_rc
from pcre2._utils.strings cimport (
    get_buffer, codeunit_to_codepoint
)


# _____________________________________________________________________________
#                                                                     Constants

class CompileOption(IntEnum):
    ANCHORED = PCRE2_ANCHORED
    NO_UTF_CHECK = PCRE2_NO_UTF_CHECK
    ENDANCHORED = PCRE2_ENDANCHORED
    ALLOW_EMPTY_CLASS = PCRE2_ALLOW_EMPTY_CLASS
    ALT_BSUX = PCRE2_ALT_BSUX
    AUTO_CALLOUT = PCRE2_AUTO_CALLOUT
    CASELESS = PCRE2_CASELESS
    DOLLAR_ENDONLY = PCRE2_DOLLAR_ENDONLY
    DOTALL = PCRE2_DOTALL
    DUPNAMES = PCRE2_DUPNAMES
    EXTENDED = PCRE2_EXTENDED
    FIRSTLINE = PCRE2_FIRSTLINE
    MATCH_UNSET_BACKREF = PCRE2_MATCH_UNSET_BACKREF
    MULTILINE = PCRE2_MULTILINE
    NEVER_UCP = PCRE2_NEVER_UCP
    NEVER_UTF = PCRE2_NEVER_UTF
    NO_AUTO_CAPTURE = PCRE2_NO_AUTO_CAPTURE
    NO_AUTO_POSSESS = PCRE2_NO_AUTO_POSSESS
    NO_DOTSTAR_ANCHOR = PCRE2_NO_DOTSTAR_ANCHOR
    NO_START_OPTIMIZE = PCRE2_NO_START_OPTIMIZE
    UCP = PCRE2_UCP
    UNGREEDY = PCRE2_UNGREEDY
    UTF = PCRE2_UTF
    NEVER_BACKSLASH_C = PCRE2_NEVER_BACKSLASH_C
    ALT_CIRCUMFLEX = PCRE2_ALT_CIRCUMFLEX
    ALT_VERBNAMES = PCRE2_ALT_VERBNAMES
    USE_OFFSET_LIMIT = PCRE2_USE_OFFSET_LIMIT
    EXTENDED_MORE = PCRE2_EXTENDED_MORE
    LITERAL = PCRE2_LITERAL
    MATCH_INVALID_UTF = PCRE2_MATCH_INVALID_UTF


class SubstituteOption(IntEnum):
    # Option flags shared with matching.
    NOTBOL = PCRE2_NOTBOL
    NOTEOL = PCRE2_NOTEOL
    NOTEMPTY = PCRE2_NOTEMPTY
    NOTEMPTY_ATSTART = PCRE2_NOTEMPTY_ATSTART
    PARTIAL_SOFT = PCRE2_PARTIAL_SOFT
    PARTIAL_HARD = PCRE2_PARTIAL_HARD
    NO_JIT = PCRE2_NO_JIT

    # Substitute only flags.
    GLOBAL = PCRE2_SUBSTITUTE_GLOBAL
    EXTENDED = PCRE2_SUBSTITUTE_EXTENDED
    UNSET_EMPTY = PCRE2_SUBSTITUTE_UNSET_EMPTY
    UNKNOWN_UNSET = PCRE2_SUBSTITUTE_UNKNOWN_UNSET
    OVERFLOW_LENGTH = PCRE2_SUBSTITUTE_OVERFLOW_LENGTH
    LITERAL = PCRE2_SUBSTITUTE_LITERAL
    REPLACEMENT_ONLY = PCRE2_SUBSTITUTE_REPLACEMENT_ONLY


class BsrEnum(IntEnum):
    UNICODE = PCRE2_BSR_UNICODE
    ANYCRLF = PCRE2_BSR_ANYCRLF


class NewlineEnum(IntEnum):
    CR = PCRE2_NEWLINE_CR
    LF = PCRE2_NEWLINE_LF
    CRLF = PCRE2_NEWLINE_CRLF
    ANY = PCRE2_NEWLINE_ANY
    ANYCRLF = PCRE2_NEWLINE_ANYCRLF
    NUL = PCRE2_NEWLINE_NUL


# _____________________________________________________________________________
#                                                                 Pattern class

cdef class Pattern:
    """

    Attributes:

        See code.pxd for attribute definitions.
        Dynamic attributes are enabled for this class.

        code: Compiled PCRE2 code.
        options: PCRE2 compilation options.
        pattern: Buffer containing source pattern expression including byte
            string and a reference to source object.
    """

    
    # _________________________________________________________________
    #                                    Lifetime and memory management

    def __cinit__(self, object pattern, uint32_t options=0):
        self.pattern = get_buffer(pattern)
        self.options = options

        # Ensure unicode strings are processed with UTF-8 support.
        if PyUnicode_Check(self.pattern.obj):
            self.options = self.options | PCRE2_UTF | PCRE2_NO_UTF_CHECK

        cdef int compile_rc
        cdef size_t compile_errpos
        self.code = pcre2_compile(
            <pcre2_sptr_t>self.pattern.buf,
            <size_t>self.pattern.len,
            self.options,
            &compile_rc, &compile_errpos,
            NULL
        )

        if not self.code:
            # If source was a unicode string, use the code point offset.
            compile_errpos = codeunit_to_codepoint(self.pattern, compile_errpos)
            additional_msg = f"Compilation failed at position {compile_errpos!r}."
            raise_from_rc(compile_rc, additional_msg)


    def __dealloc__(self):
        PyBuffer_Release(self.pattern)
        pcre2_code_free(self.code)


    # _________________________________________________________________
    #                                               Pattern information

    @property
    def all_options(self):
        """ Returns the compile options as modified by any top-level (*XXX)
        option settings such as (*UTF) at the start of the pattern itself.
        """
        cdef uint32_t all_options
        cdef int pattern_info_rc
        pattern_info_rc = pcre2_pattern_info(self.code, PCRE2_INFO_ALLOPTIONS, &all_options)
        if pattern_info_rc < 0:
            raise_from_rc(pattern_info_rc, None)
        return all_options

    @property
    def backslash_r(self):
        """ Return an indicator to what character sequences the \R escape
        sequence matches.
        """
        cdef uint32_t bsr
        cdef int pattern_info_rc
        pattern_info_rc = pcre2_pattern_info(self.code, PCRE2_INFO_BSR, &bsr)
        if pattern_info_rc < 0:
            raise_from_rc(pattern_info_rc, None)

        if bsr == PCRE2_BSR_UNICODE:
            return BsrEnum.UNICODE
        elif bsr == PCRE2_BSR_ANYCRLF:
            return BsrEnum.ANYCRLF
        else:
            return None

    @property
    def capture_count(self):
        """ Return the highest capture group number in the pattern. In patterns
        where (?| is not used, this is also the total number of capture groups.
        """
        cdef uint32_t capture_count
        cdef int pattern_info_rc
        pattern_info_rc = pcre2_pattern_info(self.code, PCRE2_INFO_CAPTURECOUNT, &capture_count)
        if pattern_info_rc < 0:
            raise_from_rc(pattern_info_rc, None)
        return capture_count

    @property
    def jit_size(self):
        """ If the compiled pattern was successfully JIT compiled, return the
        size of the JIT compiled code, otherwise return zero.
        """
        cdef uint32_t jit_size
        cdef int pattern_info_rc
        pattern_info_rc = pcre2_pattern_info(self.code, PCRE2_INFO_JITSIZE, &jit_size)
        if pattern_info_rc < 0:
            raise_from_rc(pattern_info_rc, None)
        return jit_size

    @property
    def newline(self):
        """ If the compiled pattern was successfully JIT compiled, return the
        size of the JIT compiled code, otherwise return zero.
        """
        cdef uint32_t newline
        cdef int pattern_info_rc
        pattern_info_rc = pcre2_pattern_info(self.code, PCRE2_INFO_NEWLINE, &newline)
        
        if newline == PCRE2_NEWLINE_CR:
            return NewlineEnum.CR
        elif newline == PCRE2_NEWLINE_LF:
            return  NewlineEnum.LF
        elif newline == PCRE2_NEWLINE_CRLF:
            return  NewlineEnum.CRLF
        elif newline == PCRE2_NEWLINE_ANY:
            return  NewlineEnum.ANY
        elif newline == PCRE2_NEWLINE_ANYCRLF:
            return  NewlineEnum.ANYCRLF
        elif newline == PCRE2_NEWLINE_NUL:
            return  NewlineEnum.NUL
        else:
            return None


    # _________________________________________________________________
    #                                                           Methods

    def name_dict(self):
        """ Dictionary from capture group index to capture group name.
        """
        cdef pcre2_sptr_t name_table
        cdef uint32_t name_count
        cdef uint32_t name_entry_size
        cdef int pattern_info_rc

        # Safely get relevant information from pattern.
        pattern_info_rc = pcre2_pattern_info(self.code, PCRE2_INFO_NAMECOUNT, &name_count)
        if pattern_info_rc < 0:
            raise_from_rc(pattern_info_rc, None)

        pattern_info_rc = pcre2_pattern_info(self.code, PCRE2_INFO_NAMETABLE, &name_table)
        if pattern_info_rc < 0:
            raise_from_rc(pattern_info_rc, None)

        pattern_info_rc = pcre2_pattern_info(self.code, PCRE2_INFO_NAMEENTRYSIZE, &name_entry_size)
        if pattern_info_rc < 0:
            raise_from_rc(pattern_info_rc, None)

        # Convert byte table to dictionary.
        name_dict = {}
        for offset in range(0, name_count * name_entry_size, name_entry_size):
            # First two bytes of name table contain index, followed by possibly
            # unicode byte string.
            entry_idx = int((name_table[offset] << 8) | name_table[offset + 1])
            entry_name = name_table[offset + 2:offset + name_entry_size]

            # Clean up entry and convert to unicode as appropriate.
            entry_name = <bytes>entry_name.strip(b"\x00")
            if PyUnicode_Check(self.pattern.obj):
                entry_name = entry_name.decode("utf-8")

            name_dict[entry_idx] = entry_name

        return name_dict