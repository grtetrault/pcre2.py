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


def compile(pattern, options=0, jit=False):
    """ Factory function to compile regular expressions into Pattern objects.
    See the following PCRE2 documentation for a brief overview of the relevant
    options:
        http://pcre.org/current/doc/html/pcre2_compile.html
    """
    
    cdef Py_buffer *patn = get_buffer(pattern)
    cdef uint32_t opts = <uint32_t>options

    # Ensure unicode strings are processed with UTF-8 support.
    if PyUnicode_Check(pattern):
        opts = opts | PCRE2_UTF

    cdef int compile_rc
    cdef size_t compile_errpos
    cdef pcre2_code_t *code = pcre2_compile(
        <pcre2_sptr_t>patn.buf, <size_t>patn.len, opts, &compile_rc, &compile_errpos, NULL
    )

    if code is NULL:
        # If source was a unicode string, use the code point offset.
        if PyUnicode_Check(pattern):
            _, compile_errpos = codeunit_to_codepoint(patn, compile_errpos, 0, 0)
        additional_msg = f"Compilation failed at position {compile_errpos!r}"
        raise_from_rc(compile_rc, additional_msg)

    pattern_obj = Pattern._from_data(code, patn, opts)
    if jit:
        pattern_obj.jit_compile()
    return pattern_obj


def findall(pattern, subject, offset=0):
    """ Shorthand for compiling a pattern, then calling findall. Note that this
    will use JIT compilation.
    """
    return compile(pattern, jit=True).findall(subject, offset=offset)


def match(pattern, subject, offset=0, options=0):
    """ Shorthand for compiling a pattern, then calling match.
    """
    return compile(pattern).match(subject, offset=offset, options=options)


def scan(pattern, subject, offset=0):
    """ Shorthand for compiling a pattern, then calling scan. Note that this
    will use JIT compilation.
    """
    return compile(pattern, jit=True).scan(subject, offset=offset)


def split(pattern, subject, maxsplit=0, offset=0):
    """ Shorthand for compiling a pattern, then calling split. Note that this
    will use JIT compilation.
    """
    return compile(pattern, jit=True).split(subject, maxsplit=maxsplit, offset=offset)


def substitute(pattern, replacement, subject, offset=0, options=0, low_memory=False):
    """ Shorthand for compiling a pattern, then calling substitute.
    """
    pattern_obj = compile(pattern)
    if <int>options & PCRE2_SUBSTITUTE_GLOBAL:
        pattern_obj.jit_compile()
    return pattern_obj.substitute(
        replacement, subject, offset=offset, options=options, low_memory=low_memory
    )
