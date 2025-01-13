from . import _cy

from enum import IntFlag
from itertools import islice
from functools import cached_property, cache

from sys import maxsize


# ============================================================================
#                                                                    Constants

__version__ = "0.4.0"
__libpcre2_version__ = _cy.__libpcre2_version__


NOFLAG = 0
IGNORECASE = I = _cy.CompileOption.IGNORECASE
UNICODE = U = _cy.CompileOption.UNICODE
MULTILINE = M = _cy.CompileOption.MULTILINE
DOTALL = S = _cy.CompileOption.DOTALL
VERBOSE = X = _cy.CompileOption.VERBOSE


# ============================================================================
#                                                            Top-Level Methods


def compile(pattern, flags=0, jit=True):
    pcre2_code = _cy.compile(pattern, flags)
    if jit:
        _cy.jit_compile(pcre2_code)
    return Pattern(pcre2_code, pattern, flags, jit)


def search(pattern, string, flags=0, jit=True):
    return compile(pattern, flags, jit).search(string)


def match(pattern, string, flags=0, jit=True):
    return compile(pattern, flags, jit).match(string)


def fullmatch(pattern, string, flags=0, jit=True):
    return compile(pattern, flags, jit).fullmatch(string)


def finditer(pattern, string, flags=0, jit=True):
    return compile(pattern, flags, jit).finditer(string)


def findall(pattern, string, flags=0, jit=True):
    return compile(pattern, flags, jit).findall(string)


def split(pattern, string, maxsplit=0, flags=0, jit=True):
    return compile(pattern, flags, jit).split(string, maxsplit)


def subn(pattern, repl, string, count=0, flags=0, jit=True):
    return compile(pattern, flags, jit).subn(repl, string, count)


def sub(pattern, repl, string, count=0, flags=0, jit=True):
    return compile(pattern, flags, jit).sub(repl, string, count)


# ============================================================================
#                                                               Pattern Object


class Pattern:
    def __init__(self, _pcre2_code, pattern, flags, jit):
        self._pcre2_code = _pcre2_code
        self.pattern = pattern
        self.flags = flags
        self.jit = jit

    @cached_property
    def groups(self):
        return _cy.pattern_capture_count(self._pcre2_code)

    @cached_property
    def groupindex(self):
        return _cy.pattern_name_dict(self._pcre2_code)

    def jit_compile(self):
        _cy.jit_compile(self._pcre2_code)
        self.jit = True

    def _match(self, string, pos=0, endpos=maxsize, options=0):
        pos = max(0, min(pos, len(string)))
        endpos = max(0, min(endpos, len(string)))
        match_data = _cy.match(self._pcre2_code, string, endpos, pos, options)
        return Match(match_data, self, string, pos, endpos) if match_data else None

    def search(self, string, pos=0, endpos=maxsize):
        return self._match(string, pos, endpos)

    def match(self, string, pos=0, endpos=maxsize):
        return self._match(string, pos, endpos, options=_cy.MatchOption.ANCHORED)

    def fullmatch(self, string, pos=0, endpos=maxsize):
        options = _cy.MatchOption.ANCHORED | _cy.MatchOption.ENDANCHORED
        return self._match(string, pos, endpos, options=options)

    def finditer(self, string, pos=0, endpos=maxsize):
        pos = max(0, min(pos, len(string)))
        endpos = max(0, min(endpos, len(string)))
        for match_data in _cy.match_generator(self._pcre2_code, string, endpos, pos):
            yield Match(match_data, self, string, pos, endpos)

    def findall(self, string, pos=0, endpos=maxsize):
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

    def suball(self, template, string):
        options = _cy.SubstituteOption.GLOBAL | _cy.SubstituteOption.UNSET_EMPTY
        return _cy.substitute(self._pcre2_code, template, string, options=options)

    def subn(self, repl, string, count=0):
        if count < 0:
            return (string, 0)

        # Short circuit for global substitute
        if count == 0 and not callable(repl):
            return self.suball(repl, string)

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
            end = 0
            for match in islice(self.finditer(string), count or None):
                end = match.end()
            expanded, numsubs = self.suball(repl, string[:end])
            parts = [expanded, string[end:]]

        return empty.join(parts), numsubs

    def sub(self, repl, string, count=0):
        return self.subn(repl, string, count)[0]


# ============================================================================
#                                                                 Match Object


class Match:
    def __init__(self, pcre2_match_data, re, string, pos, endpos):
        self._pcre2_match_data = pcre2_match_data
        self.re = re
        self.string = string
        self.pos = pos
        self.endpos = endpos

    def expand(self, template):
        options = _cy.SubstituteOption.REPLACEMENT_ONLY | _cy.SubstituteOption.UNSET_EMPTY
        res, _ = _cy.substitute(
            self.re._pcre2_code,
            template,
            self.string,
            options=options,
            match_data=self._pcre2_match_data,
        )
        return res

    def span(self, group=0):
        if not isinstance(group, int):
            try:
                group = self.re.groupindex[group]
            except KeyError:
                raise IndexError("Invalid group name")
        if not 0 <= group <= self.re.groups:
            raise IndexError("Invalid group index")
        return _cy.substring_span_bynumber(self._pcre2_match_data, self.string, group)

    def __getitem__(self, group):
        if not isinstance(group, int):
            try:
                group = self.re.groupindex[group]
            except KeyError:
                raise IndexError("Invalid group name")
        if not 0 <= group <= self.re.groups:
            raise IndexError("Invalid group index")
        return _cy.substring_bynumber(self._pcre2_match_data, self.string, group)

    def group(self, *groups):
        if not groups:
            groups = (0,)
        items = map(self.__getitem__, groups)
        return next(items) if len(groups) == 1 else tuple(items)

    def groups(self, default=None):
        items = []
        for group in range(1, self.re.groups + 1):
            item = self.__getitem__(group)
            items.append(default if item is None else item)
        return tuple(items)

    def groupdict(self, default=None):
        items = []
        for group, index in self.re.groupindex.items():
            item = self.__getitem__(index)
            items.append((group, default) if item is None else (group, item))
        return dict(items)

    def start(self, group=0):
        return self.span(group)[0]

    def end(self, group=0):
        return self.span(group)[1]

    @cached_property
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

    @cached_property
    def lastgroup(self):
        max_group = self.lastindex
        if not max_group:
            return None
        for group, index in self.re.groupindex.items():
            if max_group == index:
                return group
        return None
