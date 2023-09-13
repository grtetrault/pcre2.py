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
from .scanner cimport Scanner
from .consts import BsrChar, NewlineChar


def _rebuild(pattern, code_bytes_obj, options):
    """ Deserializes code object to allow for unpickling.
    """
    patn = get_buffer(pattern)
    opts = <uint32_t>options
    code_buf = get_buffer(code_bytes_obj)
    
    cdef pcre2_code_t *code
    number_of_codes = pcre2_serialize_decode(&code, 1, <const uint8_t *>code_buf.buf, NULL)
    if number_of_codes < 0:
        raise_from_rc(number_of_codes, None)

    return Pattern._from_data(code, patn, opts)


cdef class Pattern:
    """
    Object wrapper for a compiled pattern (known as a code struct) in PCRE2.
    Attributes defined in pattern.pxd, see below for an overview:
        _code: Raw compiled pattern, managed by PCRE2
        _patn: Python object passed to compile
        _opts: Option bits passed to compile call
        _jitc: Indicator if pattern was JIT compiled
    """

    # =================================== #
    #         Lifetime management         #
    # =================================== #

    def __cinit__(self):
        self._code = NULL
        self._patn = NULL
        self._opts = 0
        self._jitc = False


    def __init__(self, *args, **kwargs):
        # Prevent accidental instantiation from normal Python code since we
        # cannot pass pointers into a Python constructor.
        module = self.__class__.__module__
        qualname = self.__class__.__qualname__
        raise TypeError(f"Cannot create '{module}.{qualname}' instances")


    def __dealloc__(self):
        if self._patn is not NULL:
            PyBuffer_Release(self._patn)
        if self._code is not NULL:
            pcre2_code_free(self._code)


    @staticmethod
    cdef Pattern _from_data(pcre2_code_t *code, Py_buffer *patn, uint32_t opts):
        """ Factory function to create Pattern objects from C-type fields. The
        ownership of the given pointers are stolen, which causes the extension
        type to free them when the object is deallocated.
        """
        # Fast call to __new__() that bypasses the __init__() constructor.
        cdef Pattern pattern = Pattern.__new__(Pattern)
        pattern._code = code
        pattern._patn = patn
        pattern._opts = opts
        return pattern


    # ========================================= #
    #         Serialize and deserialize         #
    # ========================================= #

    def __reduce__(self):
        """ Serializes code object to allow for pickling.
        """
        cdef uint8_t *code_bytes
        cdef size_t code_count
        serialize_rc = pcre2_serialize_encode(
            <const pcre2_code_t **>&self._code, 1, &code_bytes, &code_count, NULL
        )
        if serialize_rc < 0:
            raise_from_rc(serialize_rc, None)

        return (_rebuild, (self._patn.obj, code_bytes[:code_count], self._opts))


    # =================================== #
    #         Pattern information         #
    # =================================== #

    @staticmethod
    cdef uint32_t _info_uint(pcre2_code_t *code, uint32_t what) except *:
        """ Safely access pattern info returned as uint32_t.
        """
        cdef uint32_t where
        pattern_info_rc = pcre2_pattern_info(code, what, &where)
        if pattern_info_rc < 0:
            raise_from_rc(pattern_info_rc, None)
        return where

    @staticmethod
    cdef size_t _info_size(pcre2_code_t *code, uint32_t what) except *:
        """ Safely access pattern info returned as size_t.
        """
        cdef size_t where
        pattern_info_rc = pcre2_pattern_info(code, what, &where)
        if pattern_info_rc < 0:
            raise_from_rc(pattern_info_rc, None)
        return where

    @staticmethod
    cdef bint _info_bint(pcre2_code_t *code, uint32_t what) except *:
        """ Safely access pattern info returned as bint.
        """
        cdef bint where
        pattern_info_rc = pcre2_pattern_info(code, what, &where)
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
        """ Returns the compile options as modified by any top-level (*XXX)
        option settings such as (*UTF) at the start of the pattern itself.
        """
        return Pattern._info_uint(self._code, PCRE2_INFO_ALLOPTIONS)


    @property
    def backslash_r(self):
        """ Return an indicator to what character sequences the \R escape
        sequence matches.
        """
        bsr = Pattern._info_uint(self._code, PCRE2_INFO_BSR)
        return BsrChar(bsr)


    @property
    def capture_count(self):
        """ Returns the highest capture group number in the pattern. In
        patterns where `(?|` is not used, this is also the total number of
        capture groups.
        """
        return Pattern._info_uint(self._code, PCRE2_INFO_CAPTURECOUNT)


    @property
    def jit_size(self):
        """ If the compiled pattern was successfully JIT compiled, return the
        size of the JIT compiled code, otherwise return zero.
        """
        return Pattern._info_size(self._code, PCRE2_INFO_JITSIZE)

    @property
    def min_length(self):
        """ Returns the minimum number of characters of matching subject strings.
        """
        return Pattern._info_uint(self._code, PCRE2_INFO_MINLENGTH)

    
    @property
    def name_count(self):
        """ Returns the number of named capture groups.
        """
        return Pattern._info_uint(self._code, PCRE2_INFO_NAMECOUNT)


    @property
    def newline(self):
        """ Returns the type of character sequence that will be recognized as
        a newline while matching.
        """
        newline = Pattern._info_uint(self._code, PCRE2_INFO_NEWLINE)
        return NewlineChar(newline)


    @property
    def size(self):
        """ Returns the size of the compiled pattern in bytes.
        """
        return Pattern._info_size(self._code, PCRE2_INFO_SIZE)


    def name_dict(self):
        """ Returns a mapping from capture group number to capture group name.
        """
        # Get name table related information.
        name_count = Pattern._info_uint(self._code, PCRE2_INFO_NAMECOUNT)
        name_entry_size = Pattern._info_uint(self._code, PCRE2_INFO_NAMEENTRYSIZE)

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
        """ JIT compile the pattern.
        """
        jit_compile_rc = pcre2_jit_compile(self._code, PCRE2_JIT_COMPLETE)
        if jit_compile_rc < 0:
            raise_from_rc(jit_compile_rc, None)
        self._jitc = True

    
    @staticmethod
    cdef pcre2_match_data_t * _match(
            pcre2_code_t *code,
            Py_buffer *subj,
            size_t ofst,
            uint32_t opts,
            int *rc):
        """ Safe wrapper around calling PCRE2 function directly.
        """
        # Allocate memory for match.
        mtch = pcre2_match_data_create_from_pattern(code, NULL)
        if mtch is NULL:
            rc[0] = PCRE2_ERROR_NOMEMORY
            return NULL
        
        # Attempt match of pattern onto subject.
        rc[0] = pcre2_match(
            code, <pcre2_sptr_t>subj.buf, <size_t>subj.len,
            ofst, opts, mtch, NULL
        )
        return mtch


    def findall(self, subject, offset=0):
        """
        Return all non-overlapping matches of our pattern in subject, as a list of strings or tuples.

        The string is scanned left-to-right, and matches are returned in the
        order found. Empty matches are included in the result.

        The result depends on the number of capturing groups in the pattern.
        If there are no groups, return a list of strings matching the whole
        pattern. If there is exactly one group, return a list of strings
        matching that group. If multiple groups are present, return a list of
        tuples of strings matching the groups. Non-capturing groups do not
        affect the form of the result.
        """
        matches = self.scan(subject, offset=offset)
        if self.capture_count == 0:
            return [m.substring() for m in matches]
        elif self.capture_count == 1:
            return [m.substring(1) for m in matches]
        result = []
        for m in matches:
            result.append(tuple(m.substring(g) for g in range(self.capture_count)))
        return result


    def match(self, subject, offset=0, options=0):
        """ If match exists, returns the corresponding Match object. Otherwise
        a MatchError is thrown in the case of no matches. See the following
        PCRE2 documentation for a brief overview of the relevant options:
            http://pcre.org/current/doc/html/pcre2_match.html
        """
        cdef bint is_patn_utf = PyUnicode_Check(self._patn.obj)
        cdef bint is_subj_utf = PyUnicode_Check(subject)
        if is_patn_utf ^ is_subj_utf:
            patn_type = "string" if is_patn_utf else "bytes-like"
            subj_type = "string" if is_subj_utf else "bytes-like"
            raise ValueError(f"Cannot use a {patn_type} pattern with a {subj_type} subject")

        cdef Py_buffer *subj = get_buffer(subject)
        cdef size_t obj_ofst = <size_t>offset
        cdef size_t ofst = obj_ofst
        cdef uint32_t opts = <uint32_t>options

        # Convert indices accordingly.
        if is_subj_utf:
            ofst, obj_ofst = codepoint_to_codeunit(subj, obj_ofst, 0, 0)

        cdef int match_rc = 0
        mtch = Pattern._match(self._code, subj, ofst, opts, &match_rc)
        if match_rc < 0:
            raise_from_rc(match_rc, None)
            
        return Match._from_data(mtch, self, subj, ofst, opts)


    def scan(self, subject, offset=0):
        """ Returns iterator over all non-overlapping matches in a subject,
        yielding Match objects.
        """
        cdef bint is_patn_utf = PyUnicode_Check(self._patn.obj)
        cdef bint is_subj_utf = PyUnicode_Check(subject)
        if is_patn_utf ^ is_subj_utf:
            patn_type = "string" if is_patn_utf else "bytes-like"
            subj_type = "string" if is_subj_utf else "bytes-like"
            raise ValueError(f"Cannot use a {patn_type} pattern with a {subj_type} subject")

        return Scanner._from_data(self, subject, offset)


    def split(self, subject, maxsplit=0, offset=0):
        """
        Split subject by occurances of our pattern.

        If capturing parentheses are used in pattern, then the text of all
        groups in the pattern are also returned as part of the resulting list.
        If maxsplit is nonzero, at most maxsplit splits occur, and the
        remainder of the string is returned as the final element of the list.

        If there are capturing groups in the separator and it matches at the
        start of the string, the result will start with an empty string. The
        same holds for the end of the string.

        That way, separator components are always found at the same relative
        indices within the result list.

        Empty matches for the pattern split the string only when not adjacent
        to a previous empty match.
        """
        output = []
        pos = n = 0
        for match in self.scan(subject, offset=offset):
            start = match.start()
            end = match.end()
            if start != end:
                output.append(subject[pos:start])
                output.extend(match.groups())
                pos = end
                n += 1
                if 0 < maxsplit <= n:
                    break
        output.append(subject[pos:])
        return output


    @staticmethod
    cdef (uint8_t *, size_t) _substitute(
            pcre2_code_t *code,
            Py_buffer *repl,
            Py_buffer *subj,
            size_t res_buf_len,
            size_t ofst,
            uint32_t opts,
            pcre2_match_data_t *mtch,
            int *rc):
        """ Safe wrapper around calling PCRE2 function directly.
        """
        cdef size_t res_len = res_buf_len
        cdef uint8_t *res
        res = <uint8_t *>malloc(res_len * sizeof(uint8_t))
        substitute_rc = pcre2_substitute(
            code,
            <pcre2_sptr_t>subj.buf, <size_t>subj.len,
            ofst, opts | PCRE2_SUBSTITUTE_OVERFLOW_LENGTH, mtch, NULL,
            <pcre2_sptr_t>repl.buf, <size_t>repl.len,
            res, &res_len
        )
        # Reattempt substitution, now with required size of buffer known.
        if substitute_rc == PCRE2_ERROR_NOMEMORY:
            free(res)
            res = <uint8_t *>malloc(res_len * sizeof(uint8_t))
            substitute_rc = pcre2_substitute(
                code,
                <pcre2_sptr_t>subj.buf, <size_t>subj.len,
                ofst, opts, mtch, NULL,
                <pcre2_sptr_t>repl.buf, <size_t>repl.len,
                res, &res_len
            )
        # Capture return codes from both substitute attempts.
        if substitute_rc < 0:
            free(res)
            PyBuffer_Release(subj)
            PyBuffer_Release(repl)
            rc[0] = substitute_rc
            return NULL, 0
        
        return res, res_len


    def substitute(self, replacement, subject, offset=0, options=0, low_memory=False):
        """ Returns the string obtained by replaces matches in subject with a
        replacement. Note that option bits can significantly change the
        functions behavior. See the following PCRE2 documentation for a brief
        overview of the relevant options:
            http://pcre.org/current/doc/html/pcre2_substitute.html
        """
        is_patn_utf = <bint>PyUnicode_Check(self._patn.obj)
        is_subj_utf = <bint>PyUnicode_Check(subject)
        is_repl_utf = <bint>PyUnicode_Check(replacement)
        if is_subj_utf ^ is_repl_utf:
            subj_type = "string" if is_subj_utf else "bytes-like"
            repl_type = "string" if is_repl_utf else "bytes-like"
            raise ValueError(f"Cannot use a {subj_type} subject with a {repl_type} replacement")
        if is_patn_utf ^ is_subj_utf:
            patn_type = "string" if is_patn_utf else "bytes-like"
            subj_type = "string" if is_subj_utf else "bytes-like"
            raise ValueError(f"Cannot use a {patn_type} pattern with a {subj_type} subject")

        # Convert Python objects to C types.
        subj = get_buffer(subject)
        repl = get_buffer(replacement)
        cdef size_t obj_ofst = <size_t>offset
        cdef size_t ofst = obj_ofst
        cdef uint32_t opts = <uint32_t>options
        if is_subj_utf:
            ofst, obj_ofst = codepoint_to_codeunit(subj, obj_ofst, 0, 0)

        cdef size_t res_buf_len = 0
        if not low_memory:
            res_buf_len = subj.len + (subj.len // 2)

        cdef int rc = 0
        res, res_len = Pattern._substitute(
            self._code, repl, subj, res_buf_len, ofst, opts, NULL, &rc
        )
        if res is NULL:
            raise_from_rc(rc, None)

        # Clean up result and convert to unicode as appropriate.
        result = (<pcre2_sptr_t>res)[:res_len]
        result = result.strip(b"\x00")
        if is_subj_utf:
            result = result.decode("utf-8")
        
        free(res)
        PyBuffer_Release(subj)
        PyBuffer_Release(repl)
        return result
