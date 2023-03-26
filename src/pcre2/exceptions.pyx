# -*- coding:utf-8 -*-

# Standard libraries.
from libc.stdint cimport uint8_t


# Local imports.
from .utils cimport *
from .libpcre2 cimport *


class LibraryError(Exception):
    """ Catch all for other PCRE2 errors (e.g. bad option bits).
    """

    def __init__(self, errorcode, context_msg=""):
        cdef uint8_t errormsg_buf[120]
        get_error_message_rc = pcre2_get_error_message(
            errorcode, 
            errormsg_buf, sizeof(errormsg_buf)
        )

        # Handle errors in fetching error message.
        if get_error_message_rc == PCRE2_ERROR_NOMEMORY:
            raise MemoryError()
        elif get_error_message_rc < 0:
            raise LibraryError(
                get_error_message_rc,
                context_msg=f"Could not retrieve message for error code {get_error_message_rc}."
            )

        msg = errormsg_buf.decode("utf-8").capitalize()
        if context_msg:
            msg = context_msg + ". " + msg

        super().__init__(msg)
        self.errorcode = errorcode


class CompileError(LibraryError):
    """ Raised when pattern is malformed or is otherwise unable to be
    compiled.
    """
    
    def __init__(self, errorcode, context_msg=""):
        if not (errorcode > 0):
            raise ValueError("Compilation error codes are strictly positive")
        
        super().__init__(errorcode, context_msg=context_msg)


class MatchError(LibraryError):
    """ Raised when no or partial match found.
    """
    
    def __init__(self, errorcode, context_msg=""):
        if not (errorcode == PCRE2_ERROR_NOMATCH or errorcode == PCRE2_ERROR_PARTIAL):
            raise ValueError(
                f"Invalid error code '{errorcode}'. "
                "Match error codes can only be of value PCRE2_ERROR_NOMATCH or PCRE2_ERROR_PARTIAL"
            )
        
        super().__init__(errorcode, context_msg=context_msg)
