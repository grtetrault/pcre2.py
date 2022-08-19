# -*- coding:utf-8 -*-

# _____________________________________________________________________________
#                                                                       Imports

from libc.stdint cimport uint8_t, uint32_t

# _____________________________________________________________________________
#                                                                  External API

cdef extern from "pcre2.h":

    # Option bits passed to pcre2_compile().
    cdef unsigned int PCRE2_ALLOW_EMPTY_CLASS
    cdef unsigned int PCRE2_ALT_BSUX
    cdef unsigned int PCRE2_AUTO_CALLOUT
    cdef unsigned int PCRE2_CASELESS
    cdef unsigned int PCRE2_DOLLAR_ENDONLY
    cdef unsigned int PCRE2_DOTALL
    cdef unsigned int PCRE2_DUPNAMES
    cdef unsigned int PCRE2_EXTENDED
    cdef unsigned int PCRE2_FIRSTLINE
    cdef unsigned int PCRE2_MATCH_UNSET_BACKREF
    cdef unsigned int PCRE2_MULTILINE
    cdef unsigned int PCRE2_NEVER_UCP
    cdef unsigned int PCRE2_NEVER_UTF
    cdef unsigned int PCRE2_NO_AUTO_CAPTURE
    cdef unsigned int PCRE2_NO_AUTO_POSSESS
    cdef unsigned int PCRE2_NO_DOTSTAR_ANCHOR
    cdef unsigned int PCRE2_NO_START_OPTIMIZE
    cdef unsigned int PCRE2_UCP
    cdef unsigned int PCRE2_UNGREEDY
    cdef unsigned int PCRE2_UTF
    cdef unsigned int PCRE2_NEVER_BACKSLASH_C
    cdef unsigned int PCRE2_ALT_CIRCUMFLEX
    cdef unsigned int PCRE2_ALT_VERBNAMES
    cdef unsigned int PCRE2_USE_OFFSET_LIMIT
    cdef unsigned int PCRE2_EXTENDED_MORE
    cdef unsigned int PCRE2_LITERAL
    cdef unsigned int PCRE2_MATCH_INVALID_UTF

    # Request types for pcre2_pattern_info().
    cdef unsigned int PCRE2_INFO_ALLOPTIONS
    cdef unsigned int PCRE2_INFO_ARGOPTIONS
    cdef unsigned int PCRE2_INFO_BACKREFMAX
    cdef unsigned int PCRE2_INFO_BSR
    cdef unsigned int PCRE2_INFO_CAPTURECOUNT
    cdef unsigned int PCRE2_INFO_FIRSTCODEUNIT
    cdef unsigned int PCRE2_INFO_FIRSTCODETYPE
    cdef unsigned int PCRE2_INFO_FIRSTBITMAP
    cdef unsigned int PCRE2_INFO_HASCRORLF
    cdef unsigned int PCRE2_INFO_JCHANGED
    cdef unsigned int PCRE2_INFO_JITSIZE
    cdef unsigned int PCRE2_INFO_LASTCODEUNIT
    cdef unsigned int PCRE2_INFO_LASTCODETYPE
    cdef unsigned int PCRE2_INFO_MATCHEMPTY
    cdef unsigned int PCRE2_INFO_MATCHLIMIT
    cdef unsigned int PCRE2_INFO_MAXLOOKBEHIND
    cdef unsigned int PCRE2_INFO_MINLENGTH
    cdef unsigned int PCRE2_INFO_NAMECOUNT
    cdef unsigned int PCRE2_INFO_NAMEENTRYSIZE
    cdef unsigned int PCRE2_INFO_NAMETABLE
    cdef unsigned int PCRE2_INFO_NEWLINE
    cdef unsigned int PCRE2_INFO_DEPTHLIMIT
    cdef unsigned int PCRE2_INFO_RECURSIONLIMIT
    cdef unsigned int PCRE2_INFO_SIZE
    cdef unsigned int PCRE2_INFO_HASBACKSLASHC
    cdef unsigned int PCRE2_INFO_FRAMESIZE
    cdef unsigned int PCRE2_INFO_HEAPLIMIT
    cdef unsigned int PCRE2_INFO_EXTRAOPTIONS

    # Option bits passed to pcre2_jit_compile().
    cdef unsigned int PCRE2_JIT_COMPLETE
    cdef unsigned int PCRE2_JIT_PARTIAL_SOFT
    cdef unsigned int PCRE2_JIT_PARTIAL_HARD
    cdef unsigned int PCRE2_JIT_INVALID_UTF

    # Option bits passed to pcre2_match() and pcre2_substitute().
    cdef unsigned int PCRE2_NOTBOL
    cdef unsigned int PCRE2_NOTEOL
    cdef unsigned int PCRE2_NOTEMPTY
    cdef unsigned int PCRE2_NOTEMPTY_ATSTART
    cdef unsigned int PCRE2_PARTIAL_SOFT
    cdef unsigned int PCRE2_PARTIAL_HARD
    cdef unsigned int PCRE2_DFA_RESTART
    cdef unsigned int PCRE2_DFA_SHORTEST
    cdef unsigned int PCRE2_SUBSTITUTE_GLOBAL
    cdef unsigned int PCRE2_SUBSTITUTE_EXTENDED
    cdef unsigned int PCRE2_SUBSTITUTE_UNSET_EMPTY
    cdef unsigned int PCRE2_SUBSTITUTE_UNKNOWN_UNSET
    cdef unsigned int PCRE2_SUBSTITUTE_OVERFLOW_LENGTH
    cdef unsigned int PCRE2_NO_JIT
    cdef unsigned int PCRE2_NO_UTF_CHECK
    cdef unsigned int PCRE2_COPY_MATCHED_SUBJECT
    cdef unsigned int PCRE2_SUBSTITUTE_LITERAL
    cdef unsigned int PCRE2_SUBSTITUTE_MATCHED
    cdef unsigned int PCRE2_SUBSTITUTE_REPLACEMENT_ONLY
    
    # Error codes below are defined as contiguous ranges in PCRE2. This allows
    # for upper and lower bounds checks to determine class of error from error
    # code. For more details on error codes, see "pcre2.h".

    # Error codes returned from pcre2_compile(). Only compilation errors are
    # positive.
    cdef int PCRE2_ERROR_END_BACKSLASH
    cdef int PCRE2_ERROR_END_BACKSLASH
    cdef int PCRE2_ERROR_END_BACKSLASH_C
    cdef int PCRE2_ERROR_UNKNOWN_ESCAPE
    cdef int PCRE2_ERROR_QUANTIFIER_OUT_OF_ORDER
    cdef int PCRE2_ERROR_QUANTIFIER_TOO_BIG
    cdef int PCRE2_ERROR_MISSING_SQUARE_BRACKET
    cdef int PCRE2_ERROR_ESCAPE_INVALID_IN_CLASS
    cdef int PCRE2_ERROR_CLASS_RANGE_ORDER
    cdef int PCRE2_ERROR_QUANTIFIER_INVALID
    cdef int PCRE2_ERROR_INTERNAL_UNEXPECTED_REPEAT
    cdef int PCRE2_ERROR_INVALID_AFTER_PARENS_QUERY
    cdef int PCRE2_ERROR_POSIX_CLASS_NOT_IN_CLASS
    cdef int PCRE2_ERROR_POSIX_NO_SUPPORT_COLLATING
    cdef int PCRE2_ERROR_MISSING_CLOSING_PARENTHESIS
    cdef int PCRE2_ERROR_BAD_SUBPATTERN_REFERENCE
    cdef int PCRE2_ERROR_NULL_PATTERN
    cdef int PCRE2_ERROR_BAD_OPTIONS
    cdef int PCRE2_ERROR_MISSING_COMMENT_CLOSING
    cdef int PCRE2_ERROR_PARENTHESES_NEST_TOO_DEEP
    cdef int PCRE2_ERROR_PATTERN_TOO_LARGE
    cdef int PCRE2_ERROR_HEAP_FAILED
    cdef int PCRE2_ERROR_UNMATCHED_CLOSING_PARENTHESIS
    cdef int PCRE2_ERROR_INTERNAL_CODE_OVERFLOW
    cdef int PCRE2_ERROR_MISSING_CONDITION_CLOSING
    cdef int PCRE2_ERROR_LOOKBEHIND_NOT_FIXED_LENGTH
    cdef int PCRE2_ERROR_ZERO_RELATIVE_REFERENCE
    cdef int PCRE2_ERROR_TOO_MANY_CONDITION_BRANCHES
    cdef int PCRE2_ERROR_CONDITION_ASSERTION_EXPECTED
    cdef int PCRE2_ERROR_BAD_RELATIVE_REFERENCE
    cdef int PCRE2_ERROR_UNKNOWN_POSIX_CLASS
    cdef int PCRE2_ERROR_INTERNAL_STUDY_ERROR
    cdef int PCRE2_ERROR_UNICODE_NOT_SUPPORTED
    cdef int PCRE2_ERROR_PARENTHESES_STACK_CHECK
    cdef int PCRE2_ERROR_CODE_POINT_TOO_BIG
    cdef int PCRE2_ERROR_LOOKBEHIND_TOO_COMPLICATED
    cdef int PCRE2_ERROR_LOOKBEHIND_INVALID_BACKSLASH_C
    cdef int PCRE2_ERROR_UNSUPPORTED_ESCAPE_SEQUENCE
    cdef int PCRE2_ERROR_CALLOUT_NUMBER_TOO_BIG
    cdef int PCRE2_ERROR_MISSING_CALLOUT_CLOSING
    cdef int PCRE2_ERROR_ESCAPE_INVALID_IN_VERB
    cdef int PCRE2_ERROR_UNRECOGNIZED_AFTER_QUERY_P
    cdef int PCRE2_ERROR_MISSING_NAME_TERMINATOR
    cdef int PCRE2_ERROR_DUPLICATE_SUBPATTERN_NAME
    cdef int PCRE2_ERROR_INVALID_SUBPATTERN_NAME
    cdef int PCRE2_ERROR_UNICODE_PROPERTIES_UNAVAILABLE
    cdef int PCRE2_ERROR_MALFORMED_UNICODE_PROPERTY
    cdef int PCRE2_ERROR_UNKNOWN_UNICODE_PROPERTY
    cdef int PCRE2_ERROR_SUBPATTERN_NAME_TOO_LONG
    cdef int PCRE2_ERROR_TOO_MANY_NAMED_SUBPATTERNS
    cdef int PCRE2_ERROR_CLASS_INVALID_RANGE
    cdef int PCRE2_ERROR_OCTAL_BYTE_TOO_BIG
    cdef int PCRE2_ERROR_INTERNAL_OVERRAN_WORKSPACE
    cdef int PCRE2_ERROR_INTERNAL_MISSING_SUBPATTERN
    cdef int PCRE2_ERROR_DEFINE_TOO_MANY_BRANCHES
    cdef int PCRE2_ERROR_BACKSLASH_O_MISSING_BRACE
    cdef int PCRE2_ERROR_INTERNAL_UNKNOWN_NEWLINE
    cdef int PCRE2_ERROR_BACKSLASH_G_SYNTAX
    cdef int PCRE2_ERROR_PARENS_QUERY_R_MISSING_CLOSING
    cdef int PCRE2_ERROR_VERB_ARGUMENT_NOT_ALLOWED
    cdef int PCRE2_ERROR_VERB_UNKNOWN
    cdef int PCRE2_ERROR_SUBPATTERN_NUMBER_TOO_BIG
    cdef int PCRE2_ERROR_SUBPATTERN_NAME_EXPECTED
    cdef int PCRE2_ERROR_INTERNAL_PARSED_OVERFLOW
    cdef int PCRE2_ERROR_INVALID_OCTAL
    cdef int PCRE2_ERROR_SUBPATTERN_NAMES_MISMATCH
    cdef int PCRE2_ERROR_MARK_MISSING_ARGUMENT
    cdef int PCRE2_ERROR_INVALID_HEXADECIMAL
    cdef int PCRE2_ERROR_BACKSLASH_C_SYNTAX
    cdef int PCRE2_ERROR_BACKSLASH_K_SYNTAX
    cdef int PCRE2_ERROR_INTERNAL_BAD_CODE_LOOKBEHINDS
    cdef int PCRE2_ERROR_BACKSLASH_N_IN_CLASS
    cdef int PCRE2_ERROR_CALLOUT_STRING_TOO_LONG
    cdef int PCRE2_ERROR_UNICODE_DISALLOWED_CODE_POINT
    cdef int PCRE2_ERROR_UTF_IS_DISABLED
    cdef int PCRE2_ERROR_UCP_IS_DISABLED
    cdef int PCRE2_ERROR_VERB_NAME_TOO_LONG
    cdef int PCRE2_ERROR_BACKSLASH_U_CODE_POINT_TOO_BIG
    cdef int PCRE2_ERROR_MISSING_OCTAL_OR_HEX_DIGITS
    cdef int PCRE2_ERROR_VERSION_CONDITION_SYNTAX
    cdef int PCRE2_ERROR_INTERNAL_BAD_CODE_AUTO_POSSESS
    cdef int PCRE2_ERROR_CALLOUT_NO_STRING_DELIMITER
    cdef int PCRE2_ERROR_CALLOUT_BAD_STRING_DELIMITER
    cdef int PCRE2_ERROR_BACKSLASH_C_CALLER_DISABLED
    cdef int PCRE2_ERROR_QUERY_BARJX_NEST_TOO_DEEP
    cdef int PCRE2_ERROR_BACKSLASH_C_LIBRARY_DISABLED
    cdef int PCRE2_ERROR_PATTERN_TOO_COMPLICATED
    cdef int PCRE2_ERROR_LOOKBEHIND_TOO_LONG
    cdef int PCRE2_ERROR_PATTERN_STRING_TOO_LONG
    cdef int PCRE2_ERROR_INTERNAL_BAD_CODE
    cdef int PCRE2_ERROR_INTERNAL_BAD_CODE_IN_SKIP
    cdef int PCRE2_ERROR_NO_SURROGATES_IN_UTF16
    cdef int PCRE2_ERROR_BAD_LITERAL_OPTIONS
    cdef int PCRE2_ERROR_SUPPORTED_ONLY_IN_UNICODE
    cdef int PCRE2_ERROR_INVALID_HYPHEN_IN_OPTIONS
    cdef int PCRE2_ERROR_ALPHA_ASSERTION_UNKNOWN
    cdef int PCRE2_ERROR_SCRIPT_RUN_NOT_AVAILABLE
    cdef int PCRE2_ERROR_TOO_MANY_CAPTURES
    cdef int PCRE2_ERROR_CONDITION_ATOMIC_ASSERTION_EXPECTED
    cdef int PCRE2_ERROR_BACKSLASH_K_IN_LOOKAROUND
    cdef int PCRE2_ERROR_BACKSLASH_K_IN_LOOKAROUND

    # Error codes for expected matching errors: no match and partial match. All
    # matching errors are negative.
    cdef int PCRE2_ERROR_NOMATCH
    cdef int PCRE2_ERROR_NOMATCH
    cdef int PCRE2_ERROR_PARTIAL
    cdef int PCRE2_ERROR_PARTIAL

    # Error codes for unicode validity checks. All unicode error codes are
    # negative.
    cdef int PCRE2_ERROR_UTF8_ERR1
    cdef int PCRE2_ERROR_UTF8_ERR1
    cdef int PCRE2_ERROR_UTF8_ERR2
    cdef int PCRE2_ERROR_UTF8_ERR3
    cdef int PCRE2_ERROR_UTF8_ERR4
    cdef int PCRE2_ERROR_UTF8_ERR5
    cdef int PCRE2_ERROR_UTF8_ERR6
    cdef int PCRE2_ERROR_UTF8_ERR7
    cdef int PCRE2_ERROR_UTF8_ERR8
    cdef int PCRE2_ERROR_UTF8_ERR9
    cdef int PCRE2_ERROR_UTF8_ERR10
    cdef int PCRE2_ERROR_UTF8_ERR11
    cdef int PCRE2_ERROR_UTF8_ERR12
    cdef int PCRE2_ERROR_UTF8_ERR13
    cdef int PCRE2_ERROR_UTF8_ERR14
    cdef int PCRE2_ERROR_UTF8_ERR15
    cdef int PCRE2_ERROR_UTF8_ERR16
    cdef int PCRE2_ERROR_UTF8_ERR17
    cdef int PCRE2_ERROR_UTF8_ERR18
    cdef int PCRE2_ERROR_UTF8_ERR19
    cdef int PCRE2_ERROR_UTF8_ERR20
    cdef int PCRE2_ERROR_UTF8_ERR21

    cdef int PCRE2_ERROR_UTF16_ERR1
    cdef int PCRE2_ERROR_UTF16_ERR2
    cdef int PCRE2_ERROR_UTF16_ERR3
    
    cdef int PCRE2_ERROR_UTF32_ERR1
    cdef int PCRE2_ERROR_UTF32_ERR2
    cdef int PCRE2_ERROR_UTF32_ERR2

    
    # Miscellaneous error codes. All miscellaneous errors are negative.
    cdef int PCRE2_ERROR_BADDATA
    cdef int PCRE2_ERROR_BADDATA
    cdef int PCRE2_ERROR_MIXEDTABLES
    cdef int PCRE2_ERROR_BADMAGIC
    cdef int PCRE2_ERROR_BADMODE
    cdef int PCRE2_ERROR_BADOFFSET
    cdef int PCRE2_ERROR_BADOPTION
    cdef int PCRE2_ERROR_BADREPLACEMENT
    cdef int PCRE2_ERROR_BADUTFOFFSET
    cdef int PCRE2_ERROR_CALLOUT
    cdef int PCRE2_ERROR_DFA_BADRESTART
    cdef int PCRE2_ERROR_DFA_RECURSE
    cdef int PCRE2_ERROR_DFA_UCOND
    cdef int PCRE2_ERROR_DFA_UFUNC
    cdef int PCRE2_ERROR_DFA_UITEM
    cdef int PCRE2_ERROR_DFA_WSSIZE
    cdef int PCRE2_ERROR_INTERNAL
    cdef int PCRE2_ERROR_JIT_BADOPTION
    cdef int PCRE2_ERROR_JIT_STACKLIMIT
    cdef int PCRE2_ERROR_MATCHLIMIT
    cdef int PCRE2_ERROR_NOMEMORY
    cdef int PCRE2_ERROR_NOSUBSTRING
    cdef int PCRE2_ERROR_NOUNIQUESUBSTRING
    cdef int PCRE2_ERROR_NULL
    cdef int PCRE2_ERROR_RECURSELOOP
    cdef int PCRE2_ERROR_DEPTHLIMIT
    cdef int PCRE2_ERROR_RECURSIONLIMIT
    cdef int PCRE2_ERROR_UNAVAILABLE
    cdef int PCRE2_ERROR_UNSET
    cdef int PCRE2_ERROR_BADOFFSETLIMIT
    cdef int PCRE2_ERROR_BADREPESCAPE
    cdef int PCRE2_ERROR_REPMISSINGBRACE
    cdef int PCRE2_ERROR_BADSUBSTITUTION
    cdef int PCRE2_ERROR_BADSUBSPATTERN
    cdef int PCRE2_ERROR_TOOMANYREPLACE
    cdef int PCRE2_ERROR_BADSERIALIZEDDATA
    cdef int PCRE2_ERROR_HEAPLIMIT
    cdef int PCRE2_ERROR_CONVERT_SYNTAX
    cdef int PCRE2_ERROR_INTERNAL_DUPMATCH
    cdef int PCRE2_ERROR_DFA_UINVALID_UTF
    cdef int PCRE2_ERROR_DFA_UINVALID_UTF


    # Opaque handles for PCRE2 defined structs.
    ctypedef struct pcre2_code_t "pcre2_code":
        pass
    ctypedef struct pcre2_match_data_t "pcre2_match_data":
        pass
    ctypedef struct pcre2_general_context_t "pcre2_general_context":
        pass
    ctypedef struct pcre2_compile_context_t "pcre2_compile_context":
        pass
    ctypedef struct pcre2_match_context_t "pcre2_match_context":
        pass

    # Basic string definition. Note that this assumes PCRE2 in compiled to
    # support 8-bit strings.
    ctypedef const uint8_t *pcre2_sptr_t "PCRE2_SPTR"

    
    # Error handling functions.
    int pcre2_get_error_message(
        int errorcode,
        uint8_t *buffer,
        size_t bufflen
    )

    # Pattern compilation functions.
    pcre2_code_t * pcre2_compile(
        pcre2_sptr_t pattern, 
        size_t length,
        uint32_t options,
        int *errorcode,
        size_t *erroroffset,
        pcre2_compile_context_t *ccontext
    )

    void pcre2_code_free(pcre2_code_t *code)

    # Information on compiled pattern.
    int pcre2_pattern_info(
        const pcre2_code_t *code,
        uint32_t what,
        void *where
    )
    
    # Matching and match data functions.
    pcre2_match_data_t * pcre2_match_data_create(
        uint32_t ovecsize,
        pcre2_general_context_t *gcontext
    )
    
    pcre2_match_data_t * pcre2_match_data_create_from_pattern(
        const pcre2_code_t *code,
        pcre2_general_context_t *gcontext
    )
    
    int pcre2_match(
        const pcre2_code_t *code,
        pcre2_sptr_t subject,
        size_t length,
        size_t startoffset,
        uint32_t options,
        pcre2_match_data_t *match_data,
        pcre2_match_context_t *mcontext
    )
    
    void pcre2_match_data_free(pcre2_match_data_t *match_data)

    # String extraction from match data blocks.
    int pcre2_substring_get_byname(
        pcre2_match_data_t *match_data,
        pcre2_sptr_t name, 
        uint8_t **bufferptr,
        size_t *bufflen
    )

    int pcre2_substring_get_bynumber(
        pcre2_match_data_t *match_data,
        uint32_t number,
        uint8_t **bufferptr,
        size_t *bufflen
    )

    # Substitution.
    int pcre2_substitute(
        const pcre2_code_t *code,
        pcre2_sptr_t subject,
        size_t length,
        size_t startoffset,
        uint32_t options,
        pcre2_match_data_t *match_data,
        pcre2_match_context_t *mcontext,
        pcre2_sptr_t replacement,
        size_t rlength,
        uint8_t *outputbuffer,
        size_t *outlengthptr
    )

