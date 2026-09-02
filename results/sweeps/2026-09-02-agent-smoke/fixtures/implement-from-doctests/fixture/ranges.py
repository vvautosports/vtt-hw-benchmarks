"""Range-spec parsing for the batch picker."""


def parse_ranges(s):
    """Parse a range spec like '1-3,5,7-9' into a flat list of ints.

    Whitespace around numbers and commas is ignored. A reversed range
    raises ValueError. Empty or whitespace-only input returns [].

    >>> parse_ranges('1-3,5,7-9')
    [1, 2, 3, 5, 7, 8, 9]
    >>> parse_ranges(' 4 - 6 , 10 ')
    [4, 5, 6, 10]
    >>> parse_ranges('')
    []
    >>> parse_ranges('   ')
    []
    >>> parse_ranges('7')
    [7]
    >>> parse_ranges('2-2')
    [2]
    >>> parse_ranges('9-7')
    Traceback (most recent call last):
    ...
    ValueError: reversed range: 9-7
    """
    raise NotImplementedError("TODO: implement parse_ranges")
