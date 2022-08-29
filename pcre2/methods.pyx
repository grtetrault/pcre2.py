# -*- coding:utf-8 -*-

# _____________________________________________________________________________
#                                                                       Imports

# Standard libraries.
from libc.stdint cimport uint32_t
from cpython cimport Py_buffer
from cpython.unicode cimport PyUnicode_Check

# Local imports.
from pcre2._libs.libpcre2 cimport *
from pcre2.exceptions cimport raise_from_rc
from pcre2._utils.strings cimport (
    get_buffer, codeunit_to_codepoint
)
from pcre2.pattern cimport Pattern
from pcre2.match cimport Match


# _____________________________________________________________________________
#                                                           Class Level Methods

def compile(object string, uint32_t options=0):
        """ Factory function to create Pattern objects with newly compiled
        pattern.
        """

        cdef Py_buffer *pattern = get_buffer(string)

        cdef pcre2_code_t *code
        cdef int compile_rc
        cdef size_t compile_errpos
        code = pcre2_compile(
            <pcre2_sptr_t>pattern.buf,
            <size_t>pattern.len,
            options,
            &compile_rc, &compile_errpos,
            NULL
        )

        if code is NULL:
            # If source was a unicode string, use the code point offset.
            compile_errpos = codeunit_to_codepoint(pattern, compile_errpos)
            additional_msg = f"Compilation failed at position {compile_errpos!r}."
            raise_from_rc(compile_rc, additional_msg)

        return Pattern._from_data(code, pattern, options)