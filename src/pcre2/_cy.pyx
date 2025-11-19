# -*- coding:utf-8 -*-
# cython: profile=True

from libc.stdint cimport uint8_t, uint32_t
from libc.stdlib cimport malloc, free
from libc.string cimport strlen
from cpython.unicode cimport PyUnicode_Check, PyUnicode_AsUTF8AndSize
from cpython.bytes cimport PyBytes_Check, PyBytes_AsStringAndSize

from _libpcre2 cimport *

from enum import IntFlag


__libpcre2_version__ = f"{PCRE2_MAJOR}.{PCRE2_MINOR}"


# ============================================================================
#                                                              Pointer Proxies

# Pointer wrappers to manage lifetime and expose to Python code
cdef class PCRE2Code:
    cdef pcre2_code_t *ptr
    cdef bint _pattern_is_str

    @staticmethod
    cdef PCRE2Code from_ptr(pcre2_code_t *ptr, bint pattern_is_str):
        """ Ownership of pointer is taken by the new instance """
        cdef PCRE2Code code
        code = PCRE2Code.__new__(PCRE2Code)
        code.ptr = ptr
        code._pattern_is_str = pattern_is_str
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
        char *sptr = NULL
        Py_ssize_t length = 0

    # Encode unicode strings as UTF-8 buffers
    if PyUnicode_Check(obj):
        sptr = <char *>PyUnicode_AsUTF8AndSize(obj, &length)
        assert(sptr is not NULL) # The function is supposed to throw on errors
    elif PyBytes_Check(obj):
        rc = PyBytes_AsStringAndSize(obj, &sptr, &length)
        assert(rc == 0)
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
    uint8_t *sptr, size_t sptr_size,
    size_t char_idx,
    size_t start_byte_idx = 0,
    size_t start_char_idx = 0,
):
    cdef:
        size_t cur_byte_idx = start_byte_idx
        size_t cur_char_idx = start_char_idx

    if cur_char_idx < char_idx:
        while cur_char_idx < char_idx:
            if (sptr[cur_byte_idx] & 0xC0) != 0x80:
                cur_char_idx += 1
            cur_byte_idx += 1

        while cur_byte_idx < sptr_size and (sptr[cur_byte_idx] & 0xC0) == 0x80:
            cur_byte_idx += 1

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
            errmsg = f"{ctxmsg}; {errmsg}"

        super().__init__(errmsg)
        self.msg = errmsg
        self.code = errcode


class PatternError(LibraryError):
    def __init__(self, int errcode, errpos):
        super().__init__(errcode, ctxmsg=f"compilation failed at position {errpos}")
        self.pos = errpos


cdef inline void raise_from_rc(int rc):
    if rc < 0:
        raise LibraryError(rc)


# ============================================================================
#                                                          Pattern Compilation


class CompileOption(IntFlag):
    CASELESS = PCRE2_CASELESS
    DOTALL = PCRE2_DOTALL
    MULTILINE = PCRE2_MULTILINE
    EXTENDED = PCRE2_EXTENDED

    # Controls the input codec (whether the input bytes are read into characters by UTF-8
    # decoding). If the input pattern is a `str`, the default behaviour is UNICODE (and this cannot
    # be unset). If the input pattern is a `bytes`, the default is ASCII/Latin-1 (one byte per
    # character), but UNICODE sets this to UTF-8.
    UTF = PCRE2_UTF

    # Controls the interpretation of character values. If characters are ASCII, then (for example)
    # '\w' does not match values outside the range 0-127. If the input pattern is a `str`, the
    # default behaviour is UNICODE_PROPS (and this cannot be unset). If the input pattern is a
    # `bytes`, the default is ASCII, but UNICODE_PROPS sets this to interpret character values
    # according to Unicode.
    UCP = PCRE2_UCP


def compile(object pattern, uint32_t options = 0, disabled_options = 0):
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

    # Set Python style '\uhhhh' syntax for literal unicode characters
    options = options | PCRE2_ALT_BSUX

    # Default to UNICODE and UNICODE_PROPS for 'str' patterns and always disable these options for
    # 'bytes' patterns
    if PyUnicode_Check(pattern):
        options = options | PCRE2_UTF

    # Always default to Unicode property support if we are interpreting strings as Unicode for both
    # 'str' and 'bytes' objects
    if options & PCRE2_UTF:
        options = options | PCRE2_UCP

    # Allow for disabling any of the options set
    options = options & ~disabled_options

    code = pcre2_compile(patn_sptr, patn_size, options, &rc, &errpos, NULL)
    if code is NULL:
        if PyUnicode_Check(pattern):
            errpos = idx_byte_to_char(patn_sptr, errpos)
        # PCRE2 puts errors after the bad character, so error positions may be after the end of the
        # string
        raise PatternError(rc, errpos)

    return PCRE2Code.from_ptr(code, PyUnicode_Check(pattern))


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
        const uint8_t *name_table
        const uint8_t *name
        uint32_t name_count, name_entry_size
        int idx, offset
        object encoding

    # Get name table related information
    raise_from_rc(pcre2_pattern_info(code.ptr, PCRE2_INFO_NAMECOUNT, &name_count))
    raise_from_rc(pcre2_pattern_info(code.ptr, PCRE2_INFO_NAMEENTRYSIZE, &name_entry_size))
    raise_from_rc(pcre2_pattern_info(code.ptr, PCRE2_INFO_NAMETABLE, &name_table))

    encoding = "UTF-8" if pattern_is_utf(code) else "Latin-1"

    # Convert byte table to dictionary mapping group names to numbers
    name_dict = {}
    for idx in range(name_count):
        # Name table is structured with first two bytes of name table contain group number followed
        # by name string (which can be assumed to be in Latin-1 for non-unicode patterns). Default
        # builds of PCRE2 only allow ASCII character names.
        offset = idx * name_entry_size
        name = &name_table[offset + 2]
        group_name = name[:strlen(<const char *>name)].decode(encoding)
        group_number = int((name_table[offset] << 8) | name_table[offset + 1])
        name_dict[group_name] = group_number

    return name_dict


def substring_span_bynumber(PCRE2MatchData match_data not None, object subject, size_t number):
    cdef:
        size_t *ovector
        uint8_t *subj_sptr
        size_t subj_size
        int rc
        size_t start
        size_t end

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

    return (-1, -1)


def substring_bynumber(PCRE2MatchData match_data not None, object subject, size_t number):
    cdef:
        size_t *ovector
        uint8_t *subj_sptr
        size_t subj_size
        int rc
        size_t start
        size_t end

    # Get views into object memory
    subj_sptr, subj_size = as_sptr_and_size(subject)

    # Only perform offset lookup if group has been set
    rc = pcre2_substring_length_bynumber(match_data.ptr, number, NULL)
    if rc == PCRE2_ERROR_UNSET:
        return None
    raise_from_rc(rc)

    ovector = pcre2_get_ovector_pointer(match_data.ptr)
    start = ovector[2 * number]
    end = ovector[2 * number + 1]

    res_obj = bytes(subj_sptr[start:end])
    if PyUnicode_Check(subject):
        res_obj = res_obj.decode("UTF-8")
    return res_obj


# ============================================================================
#                                                                     Matching

class MatchOption(IntFlag):
    ANCHORED = PCRE2_ANCHORED
    ENDANCHORED = PCRE2_ENDANCHORED

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

    # Attempt match of pattern onto the subject
    rc = _pcre2_match(code.ptr, subj_sptr, byte_length, byte_offset, options, match_data_ptr, NULL)
    if rc == PCRE2_ERROR_NOMATCH:
        return None
    raise_from_rc(rc)

    return PCRE2MatchData.from_ptr(match_data_ptr)

def match(
    PCRE2Code code not None,
    object subject,
    size_t length, # length & offset in logical (index) units
    size_t offset,
    uint32_t options = 0,
):
    cdef:
        uint8_t *subj_sptr
        size_t subj_size

    # Although the error message says "cannot use..." there would actually be nothing wrong at all
    # with removing this block and allowing it. It's simply a matter of policy and clarity, and to
    # match Python's re module.
    if code._pattern_is_str ^ PyUnicode_Check(subject):
        if code._pattern_is_str:
            raise TypeError("Cannot use a string pattern on a bytes-like object")
        else:
            raise TypeError("Cannot use a bytes pattern on a string-like object")

    # Get views into object memory
    subj_sptr, subj_size = as_sptr_and_size(subject)

    if PyUnicode_Check(subject):
        # Disable UTF-8 encoding checks for improved performance
        options |= PCRE2_NO_UTF_CHECK

        length = (
            subj_size if length == len(subject) else idx_char_to_byte(subj_sptr, subj_size, length)
        )
        offset = (
            subj_size if offset == len(subject) else idx_char_to_byte(subj_sptr, subj_size, offset)
        )

    return _match(code, subj_sptr, length, offset, options), offset, options


def match_generator(
    PCRE2Code code not None,
    object subject,
    size_t length, # length & offset in logical (index) units
    size_t offset,
):
    cdef:
        uint32_t starting_options = 0
        uint32_t state_options = 0
        uint32_t match_options
        size_t byte_length = length
        size_t byte_offset = offset
        size_t match_byte_offset

    # Although the error message says "cannot use..." there would actually be nothing wrong at all
    # with removing this block and allowing it. It's simply a matter of policy and clarity, and to
    # match Python's re module.
    if code._pattern_is_str ^ PyUnicode_Check(subject):
        if code._pattern_is_str:
            raise TypeError("Cannot use a string pattern on a bytes-like object")
        else:
            raise TypeError("Cannot use a bytes pattern on a string-like object")

    # Get views into object memory
    subj_sptr, subj_size = as_sptr_and_size(subject)

    if PyUnicode_Check(subject):
        # Disable UTF-8 encoding checks for improved performance
        starting_options |= PCRE2_NO_UTF_CHECK

        byte_length = (
            subj_size if length == len(subject) else idx_char_to_byte(subj_sptr, subj_size, length)
        )
        byte_offset = (
            subj_size if offset == len(subject) else idx_char_to_byte(subj_sptr, subj_size, offset)
        )

    while byte_offset <= byte_length:
        match_options = starting_options | state_options
        match_byte_offset = byte_offset
        match_data = _match(code, subj_sptr, byte_length, match_byte_offset, match_options)
        if not match_data:
            break

        else:
            ovector = pcre2_get_ovector_pointer(match_data.ptr)

            assert(match_byte_offset <= ovector[0] and ovector[0] <= ovector[1])
            assert(ovector[1] > match_byte_offset or state_options == 0)

            if ovector[0] == ovector[1]:
                # If the matched string is empty ensure the next match makes progress
                state_options = PCRE2_NOTEMPTY_ATSTART
            else:
                state_options = 0  # Reset options so empty strings can match at next offset

            byte_offset = ovector[1]

            yield match_data, match_byte_offset, match_options

            # No need to re-match after an empty match at the end (it will just find nothing)
            if ovector[0] == ovector[1] and ovector[1] >= byte_length:
                break


# ============================================================================
#                                                                 Substitution


class SubstituteOption(IntFlag):
    GLOBAL = PCRE2_SUBSTITUTE_GLOBAL
    UNSET_EMPTY = PCRE2_SUBSTITUTE_UNSET_EMPTY
    REPLACEMENT_ONLY = PCRE2_SUBSTITUTE_REPLACEMENT_ONLY

def substitute(
    PCRE2Code code not None,
    object replacement,
    object subject,
    size_t byte_offset, # in bytes - unlike _cy.match()
    uint32_t options = 0,
    PCRE2MatchData match_data = None,
):
    cdef:
        int rc
        pcre2_match_data_t *match_data_ptr = NULL
        uint8_t *subj_sptr
        uint8_t *repl_sptr
        uint8_t *res_sptr
        size_t subj_size, repl_size, res_size

    # Always compute the needed length if there is any overflow
    options |= PCRE2_SUBSTITUTE_OVERFLOW_LENGTH

    # Add support for backslash escape characters and Python substitution forms
    options |= PCRE2_SUBSTITUTE_EXTENDED

    # Although the error message says "cannot use..." there would actually be nothing wrong at all
    # with removing this block and allowing it. It's simply a matter of policy and clarity, and to
    # match Python's re module.
    if code._pattern_is_str ^ PyUnicode_Check(subject):
        if code._pattern_is_str:
            raise TypeError("Cannot use a string pattern on a bytes-like object")
        else:
            raise TypeError("Cannot use a bytes pattern on a string-like object")

    # Similarly, ensure that there is a match between the type of subject and replacement.
    #
    # Unlike the check that pattern and subject match, this one is cannot be simply removed. We
    # pass in the PCRE2_NO_UTF_CHECK flag based on the type of subject, and that flag also affects
    # the interpretation of replacement. So, we require a check that the replacement string is
    # valid UTF-8, if the subject is a 'str' object (note that we could do this either by enforcing
    # that replacement is a 'str', or by we could allow bytes as well if we do the decode here to
    # validate it).
    #
    # For policy and clarity, we additionally forbid using a 'str' replacement with a 'bytes'
    # subject, although there is no issue with that combination.
    if PyUnicode_Check(subject) ^ PyUnicode_Check(replacement):
        if PyUnicode_Check(subject):
            raise TypeError("Cannot use a string subject with a bytes-like template")
        else:
            raise TypeError("Cannot use a bytes subject with a string-like template")

    # Get views into object memory
    repl_sptr, repl_size = as_sptr_and_size(replacement)
    subj_sptr, subj_size = as_sptr_and_size(subject)

    # Disable UTF-8 encoding checks for improved performance
    if match_data is None and PyUnicode_Check(subject):
        options |= PCRE2_NO_UTF_CHECK

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
            byte_offset,
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
                byte_offset,
                options,
                match_data_ptr,
                NULL,
                repl_sptr, repl_size,
                res_sptr, &res_size,
            )
        raise_from_rc(rc)

        # Non-error return code contains the number of substitutions made
        res_obj = bytes(res_sptr[:res_size])
        if PyUnicode_Check(subject):
            # Match the type of the return object to the input object
            res_obj = res_obj.decode("UTF-8")
        return (res_obj, rc)

    finally:
        free(res_sptr)
