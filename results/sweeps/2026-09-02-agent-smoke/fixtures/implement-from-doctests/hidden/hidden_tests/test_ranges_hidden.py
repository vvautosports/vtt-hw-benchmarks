import pytest

from ranges import parse_ranges


def test_basic():
    assert parse_ranges("1-3,5,7-9") == [1, 2, 3, 5, 7, 8, 9]


def test_whitespace():
    assert parse_ranges(" 4 - 6 , 10 ") == [4, 5, 6, 10]


def test_empty():
    assert parse_ranges("") == []


def test_blank():
    assert parse_ranges("   ") == []


def test_single():
    assert parse_ranges("7") == [7]


def test_degenerate_range():
    assert parse_ranges("2-2") == [2]


def test_reversed_raises():
    with pytest.raises(ValueError):
        parse_ranges("9-7")
