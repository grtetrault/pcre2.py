# -*- coding:utf-8 -*-

from libc.stdint cimport uint8_t, uint32_t, int32_t


cdef extern from "pcre2.h":
    cdef unsigned int PCRE2_MAJOR
    cdef unsigned int PCRE2_MINOR

    # The following option bits can be passed to pcre2_compile(),
    # pcre2_match(), or pcre2_dfa_match(). PCRE2_NO_UTF_CHECK affects only the
    # function to which it is passed. Put these bits at the most significant
    # end of the options word so others can be added next to them.
    cdef unsigned int PCRE2_ANCHORED
    cdef unsigned int PCRE2_NO_UTF_CHECK
    cdef unsigned int PCRE2_ENDANCHORED

    # The following option bits can be passed only to pcre2_compile(). However,
    # they may affect compilation, JIT compilation, and/or interpretive
    # execution. The following tags indicate which:
    # C   alters what is compiled by pcre2_compile()
    # J   alters what is compiled by pcre2_jit_compile()
    # M   is inspected during pcre2_match() execution
    # D   is inspected during pcre2_dfa_match() execution
    cdef unsigned int PCRE2_ALLOW_EMPTY_CLASS    # C       
    cdef unsigned int PCRE2_ALT_BSUX             # C       
    cdef unsigned int PCRE2_AUTO_CALLOUT         # C       
    cdef unsigned int PCRE2_CASELESS             # C       
    cdef unsigned int PCRE2_DOLLAR_ENDONLY       #   J M D 
    cdef unsigned int PCRE2_DOTALL               # C       
    cdef unsigned int PCRE2_DUPNAMES             # C       
    cdef unsigned int PCRE2_EXTENDED             # C       
    cdef unsigned int PCRE2_FIRSTLINE            #   J M D 
    cdef unsigned int PCRE2_MATCH_UNSET_BACKREF  # C J M   
    cdef unsigned int PCRE2_MULTILINE            # C       
    cdef unsigned int PCRE2_NEVER_UCP            # C       
    cdef unsigned int PCRE2_NEVER_UTF            # C       
    cdef unsigned int PCRE2_NO_AUTO_CAPTURE      # C       
    cdef unsigned int PCRE2_NO_AUTO_POSSESS      # C       
    cdef unsigned int PCRE2_NO_DOTSTAR_ANCHOR    # C       
    cdef unsigned int PCRE2_NO_START_OPTIMIZE    #   J M D 
    cdef unsigned int PCRE2_UCP                  # C J M D 
    cdef unsigned int PCRE2_UNGREEDY             # C       
    cdef unsigned int PCRE2_UTF                  # C J M D 
    cdef unsigned int PCRE2_NEVER_BACKSLASH_C    # C       
    cdef unsigned int PCRE2_ALT_CIRCUMFLEX       #   J M D 
    cdef unsigned int PCRE2_ALT_VERBNAMES        # C       
    cdef unsigned int PCRE2_USE_OFFSET_LIMIT     #   J M D 
    cdef unsigned int PCRE2_EXTENDED_MORE        # C       
    cdef unsigned int PCRE2_LITERAL              # C       
    cdef unsigned int PCRE2_MATCH_INVALID_UTF    #   J M D

    # An additional compile options word is available in the compile context. 
    cdef unsigned int PCRE2_EXTRA_ALLOW_SURROGATE_ESCAPES  # C 
    cdef unsigned int PCRE2_EXTRA_BAD_ESCAPE_IS_LITERAL    # C 
    cdef unsigned int PCRE2_EXTRA_MATCH_WORD               # C 
    cdef unsigned int PCRE2_EXTRA_MATCH_LINE               # C 
    cdef unsigned int PCRE2_EXTRA_ESCAPED_CR_IS_LF         # C 
    cdef unsigned int PCRE2_EXTRA_ALT_BSUX                 # C 
    cdef unsigned int PCRE2_EXTRA_ALLOW_LOOKAROUND_BSK     # C 

    # These are for pcre2_jit_compile(). 
    cdef unsigned int PCRE2_JIT_COMPLETE  # For full matching.
    cdef unsigned int PCRE2_JIT_PARTIAL_SOFT
    cdef unsigned int PCRE2_JIT_PARTIAL_HARD
    cdef unsigned int PCRE2_JIT_INVALID_UTF

    # These are for pcre2_match(), pcre2_dfa_match(), pcre2_jit_match(), and
    # pcre2_substitute(). Some are allowed only for one of the functions, and
    # in these cases it is noted below. Note that PCRE2_ANCHORED,
    # PCRE2_ENDANCHORED and PCRE2_NO_UTF_CHECK can also be passed to these
    # functions (though pcre2_jit_match() ignores the latter since it bypasses
    # all sanity checks).
    cdef unsigned int PCRE2_NOTBOL
    cdef unsigned int PCRE2_NOTEOL
    cdef unsigned int PCRE2_NOTEMPTY          # ) These two must be kept
    cdef unsigned int PCRE2_NOTEMPTY_ATSTART  # ) adjacent to each other. 
    cdef unsigned int PCRE2_PARTIAL_SOFT
    cdef unsigned int PCRE2_PARTIAL_HARD
    cdef unsigned int PCRE2_DFA_RESTART  # pcre2_dfa_match() only 
    cdef unsigned int PCRE2_DFA_SHORTEST  # pcre2_dfa_match() only 
    cdef unsigned int PCRE2_SUBSTITUTE_GLOBAL  # pcre2_substitute() only 
    cdef unsigned int PCRE2_SUBSTITUTE_EXTENDED  # pcre2_substitute() only 
    cdef unsigned int PCRE2_SUBSTITUTE_UNSET_EMPTY  # pcre2_substitute() only 
    cdef unsigned int PCRE2_SUBSTITUTE_UNKNOWN_UNSET  # pcre2_substitute() only 
    cdef unsigned int PCRE2_SUBSTITUTE_OVERFLOW_LENGTH  # pcre2_substitute() only 
    cdef unsigned int PCRE2_NO_JIT  # Not for pcre2_dfa_match() 
    cdef unsigned int PCRE2_COPY_MATCHED_SUBJECT
    cdef unsigned int PCRE2_SUBSTITUTE_LITERAL  # pcre2_substitute() only 
    cdef unsigned int PCRE2_SUBSTITUTE_MATCHED  # pcre2_substitute() only 
    cdef unsigned int PCRE2_SUBSTITUTE_REPLACEMENT_ONLY  # pcre2_substitute() only 

    # Options for pcre2_pattern_convert(). 
    cdef unsigned int PCRE2_CONVERT_UTF
    cdef unsigned int PCRE2_CONVERT_NO_UTF_CHECK
    cdef unsigned int PCRE2_CONVERT_POSIX_BASIC
    cdef unsigned int PCRE2_CONVERT_POSIX_EXTENDED
    cdef unsigned int PCRE2_CONVERT_GLOB
    cdef unsigned int PCRE2_CONVERT_GLOB_NO_WILD_SEPARATOR
    cdef unsigned int PCRE2_CONVERT_GLOB_NO_STARSTAR

    # Newline and \R settings, for use in compile contexts. The newline values
    # must be kept in step with values set in config.h and both sets must all
    # be greater than zero.
    cdef int PCRE2_NEWLINE_CR
    cdef int PCRE2_NEWLINE_LF
    cdef int PCRE2_NEWLINE_CRLF
    cdef int PCRE2_NEWLINE_ANY
    cdef int PCRE2_NEWLINE_ANYCRLF
    cdef int PCRE2_NEWLINE_NUL

    cdef int PCRE2_BSR_UNICODE
    cdef int PCRE2_BSR_ANYCRLF

    # Error codes for pcre2_compile(). Some of these are also used by
    # pcre2_pattern_convert().
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
    # Error 159 is obsolete and should now never occur 
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

    # "Expected" matching error codes: no match and partial match. 
    cdef int PCRE2_ERROR_NOMATCH
    cdef int PCRE2_ERROR_PARTIAL

    # Error codes for UTF-8 validity checks.
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

    # Error codes for UTF-16 validity checks. 
    cdef int PCRE2_ERROR_UTF16_ERR1
    cdef int PCRE2_ERROR_UTF16_ERR2
    cdef int PCRE2_ERROR_UTF16_ERR3

    # Error codes for UTF-32 validity checks.
    cdef int PCRE2_ERROR_UTF32_ERR1
    cdef int PCRE2_ERROR_UTF32_ERR2

    # Miscellaneous error codes for pcre2[_dfa]_match(), substring extraction
    # functions, context functions, and serializing functions. They are in
    # numerical order. Originally they were in alphabetical order too, but now
    # that PCRE2 is released, the numbers must not be changed.
    cdef int PCRE2_ERROR_BADDATA
    cdef int PCRE2_ERROR_MIXEDTABLES  # Name was changed.
    cdef int PCRE2_ERROR_BADMAGIC
    cdef int PCRE2_ERROR_BADMODE
    cdef int PCRE2_ERROR_BADOFFSET
    cdef int PCRE2_ERROR_BADOPTION
    cdef int PCRE2_ERROR_BADREPLACEMENT
    cdef int PCRE2_ERROR_BADUTFOFFSET
    cdef int PCRE2_ERROR_CALLOUT  # Never used by PCRE2 itself.
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
    cdef int PCRE2_ERROR_RECURSIONLIMIT  # Obsolete synonym. 
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

    # Request types for pcre2_pattern_info().
    cdef int PCRE2_INFO_ALLOPTIONS
    cdef int PCRE2_INFO_ARGOPTIONS
    cdef int PCRE2_INFO_BACKREFMAX
    cdef int PCRE2_INFO_BSR
    cdef int PCRE2_INFO_CAPTURECOUNT
    cdef int PCRE2_INFO_FIRSTCODEUNIT
    cdef int PCRE2_INFO_FIRSTCODETYPE
    cdef int PCRE2_INFO_FIRSTBITMAP
    cdef int PCRE2_INFO_HASCRORLF
    cdef int PCRE2_INFO_JCHANGED
    cdef int PCRE2_INFO_JITSIZE
    cdef int PCRE2_INFO_LASTCODEUNIT
    cdef int PCRE2_INFO_LASTCODETYPE
    cdef int PCRE2_INFO_MATCHEMPTY
    cdef int PCRE2_INFO_MATCHLIMIT
    cdef int PCRE2_INFO_MAXLOOKBEHIND
    cdef int PCRE2_INFO_MINLENGTH
    cdef int PCRE2_INFO_NAMECOUNT
    cdef int PCRE2_INFO_NAMEENTRYSIZE
    cdef int PCRE2_INFO_NAMETABLE
    cdef int PCRE2_INFO_NEWLINE
    cdef int PCRE2_INFO_DEPTHLIMIT
    cdef int PCRE2_INFO_RECURSIONLIMIT  # Obsolete synonym 
    cdef int PCRE2_INFO_SIZE
    cdef int PCRE2_INFO_HASBACKSLASHC
    cdef int PCRE2_INFO_FRAMESIZE
    cdef int PCRE2_INFO_HEAPLIMIT
    cdef int PCRE2_INFO_EXTRAOPTIONS

    # Request types for pcre2_config(). 
    cdef int PCRE2_CONFIG_BSR
    cdef int PCRE2_CONFIG_JIT
    cdef int PCRE2_CONFIG_JITTARGET
    cdef int PCRE2_CONFIG_LINKSIZE
    cdef int PCRE2_CONFIG_MATCHLIMIT
    cdef int PCRE2_CONFIG_NEWLINE
    cdef int PCRE2_CONFIG_PARENSLIMIT
    cdef int PCRE2_CONFIG_DEPTHLIMIT
    cdef int PCRE2_CONFIG_RECURSIONLIMIT  # Obsolete synonym 
    cdef int PCRE2_CONFIG_STACKRECURSE  # Obsolete 
    cdef int PCRE2_CONFIG_UNICODE
    cdef int PCRE2_CONFIG_UNICODE_VERSION
    cdef int PCRE2_CONFIG_VERSION
    cdef int PCRE2_CONFIG_HEAPLIMIT
    cdef int PCRE2_CONFIG_NEVER_BACKSLASH_C
    cdef int PCRE2_CONFIG_COMPILED_WIDTHS
    cdef int PCRE2_CONFIG_TABLES_LENGTH


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

    int pcre2_jit_compile(
        pcre2_code_t *code,
        uint32_t options
    )


    void pcre2_code_free(pcre2_code_t *code)

    # Information on compiled pattern.
    int pcre2_pattern_info(
        const pcre2_code_t *code,
        uint32_t what,
        void *where
    )

    int pcre2_substring_number_from_name(
        const pcre2_code_t *code,
        pcre2_sptr_t name
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
    int pcre2_jit_match(
        const pcre2_code_t *code,
        pcre2_sptr_t subject,
        size_t length,
        size_t startoffset,
        uint32_t options,
        pcre2_match_data_t *match_data,
        pcre2_match_context_t *mcontext
    )
    
    void pcre2_match_data_free(pcre2_match_data_t *match_data)

    uint32_t pcre2_get_ovector_count(pcre2_match_data_t *match_data)

    size_t *pcre2_get_ovector_pointer(pcre2_match_data_t *match_data)

    int pcre2_substring_nametable_scan(
        const pcre2_code_t *code,
        pcre2_sptr_t name,
        pcre2_sptr_t *first,
        pcre2_sptr_t *last
    )

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

    # Serialization.
    int32_t pcre2_serialize_decode(
        pcre2_code_t **codes,
        int32_t number_of_codes,
        const uint8_t *code_bytes,
        pcre2_general_context_t *gcontex
    )
    int32_t pcre2_serialize_encode(
        pcre2_code_t **codes,
        int32_t number_of_codes,
        uint8_t **serialized_bytes,
        size_t *serialized_size,
        pcre2_general_context_t *gcontex
    )
    void pcre2_serialize_free(uint8_t *bytes)
