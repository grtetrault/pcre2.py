# -*- coding:utf-8 -*-

# _____________________________________________________________________________
#                                                                       Imports

# Standard libraries.
from libc.stdlib cimport malloc, free
from libc.stdint cimport uint8_t, uint32_t


# Local imports.
from pcre2._libs.libpcre2 cimport (
    pcre2_get_error_message,
    PCRE2_ERROR_NOMEMORY,
    PCRE2_ERROR_NOMATCH,
    PCRE2_ERROR_PARTIAL
)
from pcre2._utils.strings cimport get_buffer


# _____________________________________________________________________________
#                                                             Exception classes

class LibraryError(Exception):
    """ Catch all for other PCRE2 errors (e.g. bad option bits).
    """

    def __init__(self, errorcode, context_msg=""):
        cdef uint8_t errormsg_buf[120]
        cdef int get_error_message_rc = pcre2_get_error_message(
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

        msg = errormsg_buf.decode("utf-8").capitalize() + "."
        if context_msg:
            msg = msg + " " + context_msg

        super().__init__(msg)
        self.errorcode = errorcode


class CompilationError(LibraryError):
    """ An error occured during libpcre2.compile().
    """
    
    def __init__(self, errorcode, context_msg=""):
        if not (errorcode > 0):
            raise ValueError("Compilation error codes are strictly positive.")
        
        super().__init__(errorcode, context_msg=context_msg)


class MatchingError(LibraryError):
    """ Raised when no or partial match found in libpcre2.match().
    """
    
    def __init__(self, errorcode, context_msg=""):
        if not (errorcode == PCRE2_ERROR_NOMATCH or errorcode == PCRE2_ERROR_PARTIAL):
            raise ValueError("Match error codes can only be of value ERROR_NOMATCH or ERROR_PARTIAL.")
        
        super().__init__(errorcode, context_msg=context_msg)


# _____________________________________________________________________________
#                                                            Exception handling

cdef raise_from_rc(int errorcode, object context_msg):
    """ Raise the appropriate error type from the given error code.

    Raises one of the custom exception classes defined in this module. Each
    exception corresponds to a set of error codes defined in PCRE2. Error
    messages are retrieved from PCRE2 directly.

    Args:
        errorcode: An error code from a PCRE2 API call.
        context_msg: Additional context to append to the PCRE2 error message.
    """

    # Match against error code classes.
    if errorcode > 0:
        raise CompilationError(errorcode, context_msg)

    elif errorcode == PCRE2_ERROR_NOMATCH or errorcode == PCRE2_ERROR_PARTIAL:
        raise MatchingError(errorcode, context_msg)

    else:
        raise LibraryError(errorcode, context_msg)
