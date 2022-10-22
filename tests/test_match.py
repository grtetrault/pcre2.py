import pytest
import pcre2
from pcre2.exceptions import CompileError, MatchError, LibraryError
from pcre2.consts import CompileOption, MatchOption, SubstituteOption


test_data_match_bounds = [
]
@pytest.mark.parametrize("pattern,subject,options,offset,start,end", test_data_match_bounds)
def test_match_bounds(pattern, subject, options, offset, start, end):
    pass


test_data_match_substring = [
]
@pytest.mark.parametrize("pattern,subject,options,offset,substring", test_data_match_substring)
def test_match_substring(pattern, subject, options, offset, substring):
    pass


test_data_match_expand = [
]
@pytest.mark.parametrize(
    "pattern,replacement,subject,options,offset,result", test_data_match_expand
)
def test_match_expand(pattern, replacement, subject, options, offset, result):
    pass