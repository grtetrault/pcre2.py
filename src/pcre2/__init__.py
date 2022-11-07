import importlib.metadata
from .methods import compile, match, scan, substitute
from .consts import (
    __libpcre2_version__,
    CompileOption, MatchOption, SubstituteOption, ExpandOption,
    A, I, G, M, NE, NS, U, S, X
)


__version__ = importlib.metadata.version("pcre2")


def versions():
    return {
        "PCRE2": __libpcre2_version__,
        "python": __version__
    }