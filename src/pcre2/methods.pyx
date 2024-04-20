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


def findall(pattern, subject, offset=0, options=0, jit=True):
    """ Shorthand for compiling a pattern, then calling findall. Note that this
    will use JIT compilation.
    """
    return compile(pattern, options=options, jit=jit).findall(subject, offset=offset)


def match(pattern, subject, offset=0, options=0, jit=False):
    """ Shorthand for compiling a pattern, then calling match.
    """
    return compile(pattern, options=options, jit=jit).match(subject, offset=offset)


def scan(pattern, subject, offset=0, options=0, jit=True):
    """ Shorthand for compiling a pattern, then calling scan. Note that this
    will use JIT compilation.
    """
    return compile(pattern, options=options, jit=jit).scan(subject, offset=offset)


def split(pattern, subject, maxsplit=0, offset=0, options=0, jit=True):
    """ Shorthand for compiling a pattern, then calling split. Note that this
    will use JIT compilation.
    """
    pattern_obj = compile(pattern, options=options, jit=jit)
    return pattern_obj.split(subject, maxsplit=maxsplit, offset=offset)


def substitute(
    pattern,
    replacement,
    subject,
    offset=0,
    suball=True,
    literal=False,
    low_memory=False,
    options=0,
    jit=True
):
    """ Shorthand for compiling a pattern, then calling substitute.
    """
    pattern_obj = compile(pattern, options=options, jit=jit)
    if suball:
        pattern_obj.jit_compile()
    return pattern_obj.substitute(
        replacement, subject, offset=offset, suball=suball, literal=literal, low_memory=low_memory
    )
