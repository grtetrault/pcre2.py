# -*- coding:utf-8 -*-

# Standard libraries.
from libc.stdint cimport uint32_t
from cpython cimport Py_buffer
from cpython.unicode cimport PyUnicode_Check

# Local imports.
from .utils cimport *
from .libpcre2 cimport *
from .pattern cimport Pattern
from .match cimport Match


def compile(pattern, uint32_t options=0):
        """ Factory function to create Pattern objects with newly compiled
        pattern.
        """
        
        cdef Py_buffer *patn = get_buffer(pattern)

        # Ensure unicode strings are processed with UTF-8 support.
        if PyUnicode_Check(pattern):
            options = options | PCRE2_UTF

        cdef int compile_rc
        cdef size_t compile_errpos
        cdef pcre2_code_t *code = pcre2_compile(
            <pcre2_sptr_t>patn.buf, <size_t>patn.len,
            options,
            &compile_rc, &compile_errpos,
            NULL
        )

        if code is NULL:
            # If source was a unicode string, use the code point offset.
            if PyUnicode_Check(pattern):
                compile_errpos = codeunit_to_codepoint(patn, compile_errpos)
            additional_msg = f"Compilation failed at position {compile_errpos!r}."
            raise_from_rc(compile_rc, additional_msg)

        return Pattern._from_data(code, patn, options)