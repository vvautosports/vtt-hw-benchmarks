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
    result = []
    for chunk in s.split(","):
        chunk = chunk.strip()
        if not chunk:
            continue
        if "-" in chunk:
            lo_text, hi_text = chunk.split("-", 1)
            lo, hi = int(lo_text), int(hi_text)
            if lo > hi:
                raise ValueError(f"reversed range: {lo}-{hi}")
            result.extend(range(lo, hi + 1))
        else:
            result.append(int(chunk))
    return result
