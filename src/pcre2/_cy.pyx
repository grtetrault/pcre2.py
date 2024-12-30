# -*- coding:utf-8 -*-
# cython: profile=True

from libc.stdint cimport uint8_t, uint32_t
from libc.stdlib cimport malloc, free
from libc.string cimport strlen
from cpython.unicode cimport PyUnicode_Check
cdef extern from "Python.h":
    const char * PyUnicode_AsUTF8AndSize(object unicode, Py_ssize_t *size)
    int PyBytes_AsStringAndSize(object obj, char **buffer, Py_ssize_t *length)

from _libpcre2 cimport *

from enum import IntEnum


__libpcre2_version__ = f"{PCRE2_MAJOR}.{PCRE2_MINOR}"


# ============================================================================
#                                                              Pointer Proxies

# Pointer wrappers to manage lifetime and expose to Python code
cdef class PCRE2Code:
    cdef pcre2_code_t *ptr

    @staticmethod
    cdef PCRE2Code from_ptr(pcre2_code_t *ptr):
        """ Ownership of pointer is taken by the new instance """
        cdef PCRE2Code code
        code = PCRE2Code.__new__(PCRE2Code)
        code.ptr = ptr
        return code

    def __init__(self, *args, **kwargs):
        # Prevent accidental instantiation from normal Python code
        raise TypeError(f"Cannot create 'PCRE2Code' instances")

    def __dealloc__(self):
        if self.ptr is not NULL:
            pcre2_code_free(self.ptr)


cdef class PCRE2MatchData:
    cdef pcre2_match_data_t *ptr

    @staticmethod
    cdef PCRE2MatchData from_ptr(pcre2_match_data_t *ptr):
        """ Ownership of pointer is always taken by the new instance """
        cdef PCRE2MatchData match_data
        match_data = PCRE2MatchData.__new__(PCRE2MatchData)
        match_data.ptr = ptr
        return match_data

    def __init__(self, *args, **kwargs):
        # Prevent accidental instantiation from normal Python code
        raise TypeError(f"Cannot create 'PCRE2MatchData' instances")

    def __dealloc__(self):
        if self.ptr is not NULL:
            pcre2_match_data_free(self.ptr)


# ============================================================================
#                                                            Buffer Aquisition

cdef (uint8_t *, size_t) as_sptr_and_size(object obj) except *:
    cdef:
        int rc
        const char *sptr = NULL
        Py_ssize_t length = 0

    # Encode unicode strings as UTF-8 buffers
    if isinstance(obj, str):
        sptr = PyUnicode_AsUTF8AndSize(obj, &length)
    elif isinstance(obj, bytes):
        rc = PyBytes_AsStringAndSize(obj, &sptr, &length)
    else:
        raise ValueError("Only objects of type 'str' and 'bytes' are supported")
    return <uint8_t *>sptr, length


# ============================================================================
#                                                             Unicode Indexing

cdef size_t idx_byte_to_char(
    uint8_t *sptr, size_t byte_idx, size_t start_byte_idx = 0, size_t start_char_idx = 0
):
    cdef:
        size_t cur_byte_idx = start_byte_idx
        size_t cur_char_idx = start_char_idx

    while cur_byte_idx < byte_idx:
        if (sptr[cur_byte_idx] & 0xC0) != 0x80:
            cur_char_idx += 1
        cur_byte_idx += 1

    return cur_char_idx


cdef size_t idx_char_to_byte(
    uint8_t *sptr, size_t char_idx, size_t start_byte_idx = 0, size_t start_char_idx = 0
):
    cdef:
        size_t cur_byte_idx = start_byte_idx
        size_t cur_char_idx = start_char_idx

    while cur_char_idx < char_idx:
        cur_byte_idx += 1
        if (sptr[cur_byte_idx] & 0xC0) != 0x80:
            cur_char_idx += 1

    return cur_byte_idx


# ============================================================================
#                                                                   Exceptions

class LibraryError(Exception):
    def __init__(self, int errcode, object ctxmsg = None):
        cdef:
            uint8_t errmsg_sptr[120]
            int rc

        rc = pcre2_get_error_message(errcode, errmsg_sptr, sizeof(errmsg_sptr))
        if rc == PCRE2_ERROR_NOMEMORY:
            raise MemoryError
        elif rc == PCRE2_ERROR_BADDATA:
            raise ValueError(f"Unrecognized PCRE2 error code {errcode}")
        elif rc < 0:
            raise RuntimeError(f"Unhandled error code {rc} raised when getting error message")

        # For non-negative values, return code is the length of the message
        errmsg = errmsg_sptr[:rc].decode("UTF-8")
        if ctxmsg:
            errmsg = f"{errmsg}; {ctxmsg}"

        super().__init__(errmsg)
        self.errcode = errcode


cdef inline void raise_from_rc(int rc):
    if rc < 0:
        raise LibraryError(rc)


# ============================================================================
#                                                          Pattern Compilation

class CompileOption(IntEnum):
    IGNORECASE = PCRE2_CASELESS
    MULTILINE = PCRE2_MULTILINE
    DOTALL = PCRE2_DOTALL
    UNICODE = PCRE2_UTF
    VERBOSE = PCRE2_EXTENDED


def compile(object pattern, uint32_t options = 0):
    cdef:
        pcre2_code_t *code
        uint8_t *patn_sptr
        size_t patn_size
        int rc
        size_t errpos

    # Get views into object memory
    patn_sptr, patn_size = as_sptr_and_size(pattern)

    # Lock out the use of \C which can lead to patterns matching within characters
    options = options | PCRE2_NEVER_BACKSLASH_C
    if PyUnicode_Check(pattern):
        options = options | PCRE2_UTF

    code = pcre2_compile(patn_sptr, patn_size, options, &rc, &errpos, NULL)
    if code is NULL:
        raise LibraryError(rc, ctxmsg=f"Compilation failed at byte {errpos}")

    return PCRE2Code.from_ptr(code)


def jit_compile(PCRE2Code code not None):
    raise_from_rc(pcre2_jit_compile(code.ptr, PCRE2_JIT_COMPLETE))


# ============================================================================
#                                                       Information Extraction

def pattern_is_utf(PCRE2Code code not None):
    cdef uint32_t all_options
    raise_from_rc(pcre2_pattern_info(code.ptr, PCRE2_INFO_ALLOPTIONS, &all_options))
    return bool(all_options & PCRE2_UTF)


def pattern_capture_count(PCRE2Code code not None):
    cdef uint32_t capture_count
    raise_from_rc(pcre2_pattern_info(code.ptr, PCRE2_INFO_CAPTURECOUNT, &capture_count))
    return int(capture_count)


def pattern_name_dict(PCRE2Code code not None):
    cdef:
        const uint8_t *name_table, *name
        uint32_t name_count, name_entry_size
        int idx, offset

    # Get name table related information
    raise_from_rc(pcre2_pattern_info(code.ptr, PCRE2_INFO_NAMECOUNT, &name_count))
    raise_from_rc(pcre2_pattern_info(code.ptr, PCRE2_INFO_NAMEENTRYSIZE, &name_entry_size))
    raise_from_rc(pcre2_pattern_info(code.ptr, PCRE2_INFO_NAMETABLE, &name_table))

    # Convert byte table to dictionary mapping group names to numbers
    name_dict = {}
    for idx in range(name_count):
        # Name table is structured with first two bytes of name table contain group number
        # followed by name string (gaurunteed to be ASCII for non-unicode patterns)
        offset = idx * name_entry_size
        name = &name_table[offset + 2]
        group_name = name[:strlen(<const char *>name)].decode("UTF-8")
        group_number = int((name_table[offset] << 8) | name_table[offset + 1])
        name_dict[group_name] = group_number

    return name_dict


def substring_span_bynumber(PCRE2MatchData match_data not None, object subject, size_t number):
    cdef:
        size_t *ovector
        uint8_t *subj_sptr
        size_t subj_size
        int rc
        int start = -1
        int end = -1

    # Get views into object memory
    subj_sptr, subj_size = as_sptr_and_size(subject)

    # Only perform offset lookup if group has been set
    rc = pcre2_substring_length_bynumber(match_data.ptr, number, NULL)
    if rc == 0:
        ovector = pcre2_get_ovector_pointer(match_data.ptr)
        start = ovector[2 * number]
        end = ovector[2 * number + 1]

        if PyUnicode_Check(subject):
            start = idx_byte_to_char(subj_sptr, start)
            end = idx_byte_to_char(subj_sptr, end)

    return (start, end)


def substring_bynumber(PCRE2MatchData match_data not None, object subject, size_t number):
    cdef:
        size_t *ovector
        uint8_t *subj_sptr
        size_t subj_size
        int rc
        int start = -1
        int end = -1

    # Get views into object memory
    subj_sptr, subj_size = as_sptr_and_size(subject)

    # Only perform offset lookup if group has been set
    raise_from_rc(pcre2_substring_length_bynumber(match_data.ptr, number, NULL))

    ovector = pcre2_get_ovector_pointer(match_data.ptr)
    start = ovector[2 * number]
    end = ovector[2 * number + 1]

    res_obj = bytes(subj_sptr[start:end])
    if PyUnicode_Check(subject):
        res_obj = res_obj.decode("UTF-8")
    return res_obj


# ============================================================================
#                                                                     Matching

class MatchOption(IntEnum):
    ANCHORED = PCRE2_ANCHORED
    ENDANCHORED = PCRE2_ENDANCHORED
    NOTEMPTY = PCRE2_NOTEMPTY
    NOTEMPTY_ATSTART = PCRE2_NOTEMPTY_ATSTART

cdef pcre2_match_data_t * _pcre2_match_data_create_from_pattern(
    const pcre2_code_t *code, pcre2_general_context_t *gcontext
):
    return pcre2_match_data_create_from_pattern(code, gcontext)

cdef int _pcre2_match(
    const pcre2_code_t *code,
    pcre2_sptr_t subject,
    size_t length,
    size_t startoffset,
    uint32_t options,
    pcre2_match_data_t *match_data,
    pcre2_match_context_t *mcontext
):
    return pcre2_match(code, subject, length, startoffset, options, match_data, mcontext)

cdef PCRE2MatchData _match(
    PCRE2Code code,
    uint8_t *subj_sptr,
    size_t byte_length,
    size_t byte_offset,
    uint32_t options,
) except *:
    cdef:
        pcre2_match_data_t *match_data_ptr
        int rc

    # Allocate memory for match data, returning NULL if the memory could not be obtained
    match_data_ptr = _pcre2_match_data_create_from_pattern(code.ptr, NULL)
    if match_data_ptr is NULL:
        raise MemoryError

    # Disable UTF-8 encoding checks for improved performance; it must be gaurunteed that UTF-8
    # patterns are only run with unicode strings
    if pattern_is_utf(code):
        options |= PCRE2_NO_UTF_CHECK

    # Attempt match of pattern onto the subject
    rc = _pcre2_match(code.ptr, subj_sptr, byte_length, byte_offset, options, match_data_ptr, NULL)
    if rc == PCRE2_ERROR_NOMATCH:
        return None
    raise_from_rc(rc)

    return PCRE2MatchData.from_ptr(match_data_ptr)

def match(
    PCRE2Code code not None,
    object subject,
    size_t length,
    size_t offset,
    uint32_t options = 0,
):
    cdef:
        uint8_t *subj_sptr
        size_t subj_size

    if pattern_is_utf(code) ^ PyUnicode_Check(subject):
        if pattern_is_utf(code):
            raise ValueError("Cannot use a string pattern on a bytes-like object")
        else:
            raise ValueError("Cannot use a bytes pattern on a string-like object")

    # Get views into object memory
    subj_sptr, subj_size = as_sptr_and_size(subject)

    if pattern_is_utf(code):
        length = idx_char_to_byte(subj_sptr, length)
        offset = idx_char_to_byte(subj_sptr, offset)

    return _match(code, subj_sptr, length, offset, options)


def match_generator(code, object subject, size_t length, size_t offset):
    cdef:
        size_t options = 0
        size_t byte_length = length
        size_t cur_char_offset = offset
        size_t cur_byte_offset = offset
        size_t next_char_offset
        size_t next_byte_offset

    if pattern_is_utf(code) ^ PyUnicode_Check(subject):
        if pattern_is_utf(code):
            raise ValueError("Cannot use a string pattern on a bytes-like object")
        else:
            raise ValueError("Cannot use a bytes pattern on a string-like object")

    # Get views into object memory
    subj_sptr, subj_size = as_sptr_and_size(subject)

    if pattern_is_utf(code):
            byte_length = idx_char_to_byte(subj_sptr, length)
            cur_byte_offset = idx_char_to_byte(subj_sptr, offset)

    while cur_byte_offset < byte_length:
        match_data = _match(code, subj_sptr, byte_length, cur_byte_offset, options)
        if not match_data:
            # Default match is not achored so if no match found at current offset, then there
            # will not be any ahead either
            if options == 0:
                break
            options = 0  # Reset options so empty strings can match at next offset

            # Increment to next object and byte offsets
            next_char_offset = cur_char_offset + 1
            if pattern_is_utf(code):
                cur_byte_offset = idx_char_to_byte(
                    subj_sptr, next_char_offset, cur_byte_offset, cur_char_offset
                )
            else:
                cur_byte_offset = next_char_offset
            cur_char_offset = next_char_offset
        else:
            ovector = pcre2_get_ovector_pointer(match_data.ptr)
            match_byte_end = ovector[1]

            if cur_byte_offset == match_byte_end:
                # If the matched string is empty ensure next is not
                options = PCRE2_NOTEMPTY_ATSTART | PCRE2_ANCHORED
            else:
                options = 0  # Reset options so empty strings can match at next offset

                # Convert the end in the byte string to the end in the object
                next_byte_offset = match_byte_end
                if pattern_is_utf(code):
                    cur_char_offset = idx_byte_to_char(
                        subj_sptr, next_byte_offset, cur_byte_offset, cur_char_offset
                    )
                else:
                    cur_char_offset = next_byte_offset
                cur_byte_offset = next_byte_offset

            yield match_data


# ============================================================================
#                                                                 Substitution

class SubstituteOption(IntEnum):
    GLOBAL = PCRE2_SUBSTITUTE_GLOBAL
    UNSET_EMPTY = PCRE2_SUBSTITUTE_UNSET_EMPTY
    REPLACEMENT_ONLY = PCRE2_SUBSTITUTE_REPLACEMENT_ONLY

def substitute(
    PCRE2Code code not None,
    object replacement,
    object subject,
    uint32_t options = 0,
    PCRE2MatchData match_data = None,
):
    cdef:
        int rc
        pcre2_match_data_t *match_data_ptr = NULL
        uint8_t *subj_sptr, *repl_sptr, *res_sptr
        size_t subj_size, repl_size, res_size

    # Always compute the needed length if there is any overflow
    options |= PCRE2_SUBSTITUTE_OVERFLOW_LENGTH

    if (
        pattern_is_utf(code) ^ PyUnicode_Check(replacement)
        or pattern_is_utf(code) ^ PyUnicode_Check(subject)
    ):
        if pattern_is_utf(code):
            raise ValueError("Cannot use a string pattern on a bytes-like object")
        else:
            raise ValueError("Cannot use a bytes pattern on a string-like object")

    # Get views into object memory
    repl_sptr, repl_size = as_sptr_and_size(replacement)
    subj_sptr, subj_size = as_sptr_and_size(subject)

    if match_data is not None:
        match_data_ptr = match_data.ptr
        options |= PCRE2_SUBSTITUTE_MATCHED

    # Make simple attempt at guess for required memory, unless match has already been made
    res_size = subj_size + (subj_size // 2) if match_data is None else 0
    res_sptr = <uint8_t *>malloc(res_size * sizeof(uint8_t))
    try:
        rc = pcre2_substitute(
            code.ptr,
            subj_sptr, subj_size,
            0,
            options,
            match_data_ptr,
            NULL,
            repl_sptr, repl_size,
            res_sptr, &res_size,
        )
        # Reattempt substitution if no memory, now with required size of buffer known
        if rc == PCRE2_ERROR_NOMEMORY:
            free(res_sptr)
            res_sptr = <uint8_t *>malloc(res_size * sizeof(uint8_t))
            rc = pcre2_substitute(
                code.ptr,
                subj_sptr, subj_size,
                0,
                options,
                match_data_ptr,
                NULL,
                repl_sptr, repl_size,
                res_sptr, &res_size,
            )
        raise_from_rc(rc)

        # Non-error return code contains the number of substitutions made
        res_obj = bytes(res_sptr[:res_size])
        if pattern_is_utf(code):
            res_obj = res_obj.decode("UTF-8")
        return (res_obj, rc)

    finally:
        free(res_sptr)
