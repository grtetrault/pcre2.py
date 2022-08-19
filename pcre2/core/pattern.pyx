# -*- coding:utf-8 -*-

# _____________________________________________________________________________
#                                                                       Imports

# Standard libraries.
from libc.stdlib cimport malloc, free
from libc.stdint cimport uint8_t, uint32_t

from cpython cimport Py_buffer, PyBuffer_Release
from cpython.unicode cimport PyUnicode_Check

# Local imports.
from pcre2._libs.libpcre2 cimport (
    sptr_t, code_t, 
    compile, code_free, pattern_info,
    UTF, NO_UTF_CHECK, INFO_NAMECOUNT, INFO_NAMETABLE, INFO_NAMEENTRYSIZE
)

from pcre2._utils.strings cimport get_buffer, codeunit_to_codepoint
from pcre2.core.exceptions cimport raise_from_rc


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
            self.options = self.options | UTF | NO_UTF_CHECK

        cdef int compile_rc
        cdef size_t compile_errpos
        self.code = compile(
            <sptr_t>self.pattern.buf, <size_t>self.pattern.len,
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
        code_free(self.code)
