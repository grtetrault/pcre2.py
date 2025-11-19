from . import _cy

from enum import auto, IntFlag
import operator
from itertools import islice
from functools import lru_cache, reduce
from types import MappingProxyType
from sys import maxsize

# The below implementation uses as a base that of Google`s RE2 Python bindings:
# https://github.com/google/re2/tree/main/python


# ============================================================================
#                                                                    Constants

__version__ = "0.5.3"
__libpcre2_version__ = _cy.__libpcre2_version__


class RegexFlag(IntFlag):
    # Flags either enable (True) or disable (False) PCRE2 options
    NOFLAG = 0
    IGNORECASE = _cy.CompileOption.CASELESS  # Ignore case
    UNICODE = _cy.CompileOption.UTF  # Assume unicode "locale"
    MULTILINE = _cy.CompileOption.MULTILINE  # Make anchors look for newline
    DOTALL = _cy.CompileOption.DOTALL  # Make dot match newline
    VERBOSE = _cy.CompileOption.EXTENDED  # Ignore whitespace and comments

    # No corresponding flag in PCRE2, but is the opposite of `_cy.CompileOption.UCP`
    ASCII = auto()  # ASCII-only matching for character classes


NOFLAG = RegexFlag.NOFLAG
ASCII = A = RegexFlag.ASCII
IGNORECASE = I = RegexFlag.IGNORECASE
UNICODE = U = RegexFlag.UNICODE
MULTILINE = M = RegexFlag.MULTILINE
DOTALL = S = RegexFlag.DOTALL
VERBOSE = X = RegexFlag.VERBOSE


LibraryError = _cy.LibraryError
PatternError = error = _cy.PatternError


# ============================================================================
#                                                           Internal Utilities


def _typegaurd_strings(s):
    if isinstance(s, str):
        return str(s)
    elif isinstance(s, (bytes, bytearray, memoryview)):
        return bytes(s)
    raise TypeError(f"Cannot process type {s}")


# ============================================================================
#                                                          Top-Level Functions


def compile(pattern, flags=0, jit=True):
    """
    Compile a regular expression pattern, returning a Pattern object.
    """
    # Avoid recompilation if the pattern is already compiled with no option changes
    if isinstance(pattern, Pattern):
        if not flags == 0:
            raise ValueError("Cannot process flags argument with a compiled pattern")
        if pattern.jit == jit:
            return pattern
        # If options differ, extract the underlying string for recompilation
        pattern = pattern.pattern

    pattern = _typegaurd_strings(pattern)
    flags = RegexFlag(flags)

    # Handle ASCII flag, defined as the disabling of the UCP PCRE2 option
    options = flags & ~RegexFlag.ASCII
    disabled_options = _cy.CompileOption.UCP if flags & RegexFlag.ASCII else 0

    pcre2_code = _cy.compile(pattern, options, disabled_options)
    if jit:
        _cy.jit_compile(pcre2_code)
    return Pattern(pcre2_code, pattern, flags, jit)


def search(pattern, string, flags=0, jit=True):
    """
    Scan through `string` looking for a match to the pattern, returning a Match object, or None if
    no match was found.
    """
    return compile(pattern, flags, jit).search(string)


def match(pattern, string, flags=0, jit=True):
    """
    Match the pattern at the start of `string`, returning a Match object, or None if no match was
    found.
    """
    return compile(pattern, flags, jit).match(string)


def fullmatch(pattern, string, flags=0, jit=True):
    """
    Match the pattern to all of `string`, returning a Match object, or None if no match was found.
    """
    return compile(pattern, flags, jit).fullmatch(string)


def finditer(pattern, string, flags=0, jit=True):
    """
    Return an iterator of Match objects for each non-overlapping match in the string.
    """
    return compile(pattern, flags, jit).finditer(string)


def findall(pattern, string, flags=0, jit=True):
    """
    Return a list of all non-overlapping matches in `string`.

    If one or more capture groups are present, return a list of groups for each match. Empty
    matches are included in the result.
    """
    return compile(pattern, flags, jit).findall(string)


def split(pattern, string, maxsplit=0, flags=0, jit=True):
    """
    Split the source string by the occurrences of the pattern, returning a list containing the
    resulting substrings.

    If capture groups are used in pattern, then the text of all groups are also returned. If
    `maxsplit` is non-zero, at most `maxsplit` splits occur, and the remainder of `string` is
    returned as the final element of the list.
    """
    return compile(pattern, flags, jit).split(string, maxsplit)


def subn(pattern, repl, string, count=0, flags=0, jit=True):
    """
    Return a tuple containing `(res, number)`. `res` is the string obtained by replacing the
    leftmost non-overlapping occurrences of the pattern in `string` by the replacement `repl`.
    `number` is the number of substitutions that were made.

    `repl` can be either a string or a callable. If it is a callable, it's passed the Match object
    and must return a replacement string to be used.
    """
    return compile(pattern, flags, jit).subn(repl, string, count)


def sub(pattern, repl, string, count=0, flags=0, jit=True):
    """
    Return the string obtained by replacing the leftmost non-overlapping occurrences of the pattern
    in `string` by the replacement `repl`.

    `repl` can be either a string or a callable. If it is a callable, it's passed the Match object
    and must return a replacement string to be used.
    """
    return compile(pattern, flags, jit).sub(repl, string, count)


# ============================================================================
#                                                               Pattern Object


class Pattern:
    def __init__(self, pcre2_code, pattern, flags, jit):
        if not isinstance(pcre2_code, _cy.PCRE2Code):
            raise ValueError(
                "PCRE2 code must be of type `_cy.PCRE2Code`. It is not recommended to instantiate "
                "`Pattern` objects directly. Instead, use `pcre2.compile`."
            )
        self._pcre2_code = pcre2_code
        self.pattern = pattern
        self.flags = flags
        self.jit = jit

    def __getstate__(self):
        state = self.__dict__.copy()
        del state["_pcre2_code"]  # Remove the unpicklable pointer
        return state

    def __setstate__(self, state):
        self.__dict__.update(state)
        # Note that patterns are recompiled - and optionally JIT compiled - when unpickling
        self._pcre2_code = _cy.compile(self.pattern, self.flags)
        if self.jit:
            _cy.jit_compile(self._pcre2_code)

    @property
    @lru_cache(1)
    def groups(self):
        return _cy.pattern_capture_count(self._pcre2_code)

    @property
    @lru_cache(1)
    def groupindex(self):
        groupindex = _cy.pattern_name_dict(self._pcre2_code)
        return MappingProxyType(groupindex)

    def jit_compile(self):
        """
        JIT compile the pattern, or nothing if the pattern is already JIT compiled.
        """
        if not self.jit:
            _cy.jit_compile(self._pcre2_code)
            self.jit = True

    def _match(self, string, pos=0, endpos=maxsize, options=0):
        string = _typegaurd_strings(string)
        pos = max(0, min(pos, len(string)))
        endpos = max(0, min(endpos, len(string)))
        match_data, match_byte_offset, match_options = _cy.match(
            self._pcre2_code, string, endpos, pos, options
        )
        if match_data:
            return Match(match_data, self, string, pos, endpos, match_byte_offset, match_options)
        return None

    def search(self, string, pos=0, endpos=maxsize):
        """
        Scan through `string` looking for a match to the pattern, returning a Match object, or None
        if no match was found.
        """
        return self._match(string, pos, endpos)

    def match(self, string, pos=0, endpos=maxsize):
        """
        Match the pattern at the start of `string`, returning a Match object, or None if no match
        was found.
        """
        return self._match(string, pos, endpos, options=_cy.MatchOption.ANCHORED)

    def fullmatch(self, string, pos=0, endpos=maxsize):
        """
        Match the pattern to all of `string`, returning a Match object, or None if no match was
        found.
        """
        options = _cy.MatchOption.ANCHORED | _cy.MatchOption.ENDANCHORED
        return self._match(string, pos, endpos, options=options)

    def finditer(self, string, pos=0, endpos=maxsize):
        """
        Return an iterator of Match objects for each non-overlapping match in the string.
        """
        string = _typegaurd_strings(string)
        pos = max(0, min(pos, len(string)))
        endpos = max(0, min(endpos, len(string)))
        for match_data, match_byte_offset, match_options in _cy.match_generator(
            self._pcre2_code, string, endpos, pos
        ):
            yield Match(match_data, self, string, pos, endpos, match_byte_offset, match_options)

    def findall(self, string, pos=0, endpos=maxsize):
        """
        Return a list of all non-overlapping matches in `string`.

        If one or more capture groups are present, return a list of groups for each match. Empty
        matches are included in the result.
        """
        string = _typegaurd_strings(string)
        empty = type(string)()
        items = []
        for match in self.finditer(string, pos, endpos):
            if not self.groups:
                item = match.group()
            elif self.groups == 1:
                item = match.groups(default=empty)[0]
            else:
                item = match.groups(default=empty)
            items.append(item)
        return items

    def split(self, string, maxsplit=0):
        """
        Split the source string by the occurrences of the pattern, returning a list containing the
        resulting substrings.

        If capture groups are used in pattern, then the text of all groups are also returned. If
        `maxsplit` is non-zero, at most `maxsplit` splits occur, and the remainder of `string` is
        returned as the final element of the list.
        """
        string = _typegaurd_strings(string)
        if maxsplit < 0:
            return [string]
        parts = []
        start = 0
        for match in islice(self.finditer(string), maxsplit or None):
            parts.append(string[start : match.start()])
            parts.extend(map(match.__getitem__, range(1, self.groups + 1)))
            start = match.end()
        parts.append(string[start:])
        return parts

    def _suball(self, template, string):
        template = _typegaurd_strings(template)
        string = _typegaurd_strings(string)
        options = _cy.SubstituteOption.GLOBAL | _cy.SubstituteOption.UNSET_EMPTY
        byte_offset = 0
        return _cy.substitute(self._pcre2_code, template, string, byte_offset, options=options)

    def subn(self, repl, string, count=0):
        """
        Return a tuple containing `(res, number)`. `res` is the string obtained by replacing the
        leftmost non-overlapping occurrences of the pattern in `string` by the replacement `repl`.
        `number` is the number of substitutions that were made.

        `repl` can be either a string or a callable. If it is a callable, it's passed the Match
        object and must return a replacement string to be used.
        """
        string = _typegaurd_strings(string)
        if count < 0:
            return (string, 0)

        # Short circuit for global substitute
        if count == 0 and not callable(repl):
            return self._suball(repl, string)

        parts = []
        empty = type(string)()

        # Pure python needed to apply callback functions
        if callable(repl):
            start = 0
            numsubs = 0
            for match in islice(self.finditer(string), count or None):
                parts.append(string[start : match.start()])
                parts.append(repl(match))
                start = match.end()
                numsubs += 1
            parts.append(string[start:])
            empty = type(string)()
            return empty.join(parts), numsubs
        else:
            # Iterate through matches to get index of last match
            repl = _typegaurd_strings(repl)
            end = 0
            for match in islice(self.finditer(string), count or None):
                end = match.end()
            expanded, numsubs = self._suball(repl, string[:end])
            parts = [expanded, string[end:]]

        return empty.join(parts), numsubs

    def sub(self, repl, string, count=0):
        """
        Return the string obtained by replacing the leftmost non-overlapping occurrences of the
        pattern in `string` by the replacement `repl`.

        `repl` can be either a string or a callable. If it is a callable, it's passed the Match
        object and must return a replacement string to be used.
        """
        return self.subn(repl, string, count)[0]


# ============================================================================
#                                                                 Match Object


class Match:
    def __init__(self, pcre2_match_data, re, string, pos, endpos, byte_offset, options):
        if not isinstance(pcre2_match_data, _cy.PCRE2MatchData):
            raise ValueError(
                "PCRE2 match data must be of type `_cy.PCRE2MatchData`. It is not recommended to "
                "instantiate `Match` objects directly. Instead, use `Pattern.match`."
            )
        self._pcre2_match_data = pcre2_match_data
        self.re = re
        self.string = string
        self.pos = pos
        self.endpos = endpos
        self._byte_offset = byte_offset
        self._options = options

    def __repr__(self):
        return (
            f"<{self.__class__.__module__}.{self.__class__.__qualname__} object; "
            f"span={self.span()}, match={repr(self.group())}>"
        )

    def _groupgaurd(self, group):
        if isinstance(group, int):
            if not 0 <= group <= self.re.groups:
                raise IndexError("No such group")
            group_number = group
        elif isinstance(group, str):
            if group not in self.re.groupindex:
                raise IndexError("no such group")
            group_number = self.re.groupindex[group]
        elif hasattr(group, "__index__"):
            group_number = int(group.__index__())
        else:
            raise IndexError("No such group")
        return group_number

    def expand(self, template):
        """
        Return the string obtained by substitution on the template string `template`.
        """
        template = _typegaurd_strings(template)
        options = (
            self._options | _cy.SubstituteOption.REPLACEMENT_ONLY | _cy.SubstituteOption.UNSET_EMPTY
        )
        res, _ = _cy.substitute(
            self.re._pcre2_code,
            template,
            self.string,
            self._byte_offset,
            options=options,
            match_data=self._pcre2_match_data,
        )
        return res

    def span(self, group=0):
        """
        Return the start and end of `group` as the tuple `(start, end)`.

        If `group` did not contribute to the match, `(-1, -1)` is returned.
        """
        group_number = self._groupgaurd(group)
        return _cy.substring_span_bynumber(self._pcre2_match_data, self.string, group_number)

    def __getitem__(self, group):
        group_number = self._groupgaurd(group)
        return _cy.substring_bynumber(self._pcre2_match_data, self.string, group_number)

    def group(self, *groups):
        """
        Returns one or more subgroups of the match.

        If there is a single argument, the result is a single string. If there are multiple
        arguments, the result is a tuple with one item per argument. Without arguments, the whole
        match is returned.
        """
        if not groups:
            groups = (0,)
        items = map(self.__getitem__, groups)
        return next(items) if len(groups) == 1 else tuple(items)

    def groups(self, default=None):
        """
        Return a tuple containing all the subgroups of the match.
        """
        items = []
        for group in range(1, self.re.groups + 1):
            item = self.__getitem__(group)
            items.append(default if item is None else item)
        return tuple(items)

    def groupdict(self, default=None):
        """
        Return a dictionary mapping subgroup name to group number for all the named subgroups.
        """
        items = []
        for group, index in self.re.groupindex.items():
            item = self.__getitem__(index)
            items.append((group, default) if item is None else (group, item))
        return dict(items)

    def start(self, group=0):
        """
        Return the start index of the substring matched by `group`.
        """
        return self.span(group)[0]

    def end(self, group=0):
        """
        Return the end index of the substring matched by `group`.
        """
        return self.span(group)[1]

    @property
    @lru_cache(1)
    def lastindex(self):
        max_end = -1
        max_group = None
        # We look for the rightmost right parenthesis by keeping the first group that ends at
        # max_end because that is the leftmost/outermost group when there are nested groups!
        for group in range(1, self.re.groups + 1):
            end = self.end(group)
            if max_end < end:
                max_end = end
                max_group = group
        return max_group

    @property
    @lru_cache(1)
    def lastgroup(self):
        max_group = self.lastindex
        if not max_group:
            return None
        for group, index in self.re.groupindex.items():
            if max_group == index:
                return group
        return None
