import pytest

from sku import build_sku, parse_sku


def test_build_sku_happy_path():
    """Test basic SKU building with valid inputs."""
    assert build_sku("HW", 42, "XL") == "HW-0042-XL"
    assert build_sku("EL", 1234, "M") == "EL-1234-M"
    assert build_sku("GR", 0, "XS") == "GR-0000-XS"


def test_build_sku_zero_padding():
    """Test that item numbers are zero-padded to 4 digits."""
    assert build_sku("HW", 1, "XL") == "HW-0001-XL"
    assert build_sku("HW", 12, "XL") == "HW-0012-XL"
    assert build_sku("HW", 123, "XL") == "HW-0123-XL"
    assert build_sku("HW", 1234, "XL") == "HW-1234-XL"


def test_build_sku_invalid_dept():
    """Test that unknown departments raise ValueError."""
    with pytest.raises(ValueError, match="unknown dept: 'XX'"):
        build_sku("XX", 1234, "XL")


def test_build_sku_invalid_size():
    """Test that unknown sizes raise ValueError."""
    with pytest.raises(ValueError, match="unknown size: 'XXL'"):
        build_sku("HW", 1234, "XXL")


def test_build_sku_invalid_item_number_range():
    """Test that item numbers outside 0-9999 raise ValueError."""
    with pytest.raises(ValueError, match="item number out of range 0-9999: -1"):
        build_sku("HW", -1, "XL")

    with pytest.raises(ValueError, match="item number out of range 0-9999: 10000"):
        build_sku("HW", 10000, "XL")


def test_build_sku_invalid_item_number_type():
    """Test that non-integer item numbers raise TypeError."""
    with pytest.raises(TypeError, match="item number must be an integer, got 'str'"):
        build_sku("HW", "1234", "XL")

    with pytest.raises(TypeError, match="item number must be an integer, got 'float'"):
        build_sku("HW", 12.34, "XL")


def test_build_sku_round_trip():
    """Test that build_sku and parse_sku are inverses of each other."""
    original_sku = "HW-0042-XL"
    dept, item_number, size = parse_sku(original_sku)
    rebuilt_sku = build_sku(dept, item_number, size)
    assert rebuilt_sku == original_sku

    original_sku = "GR-0007-S"
    dept, item_number, size = parse_sku(original_sku)
    rebuilt_sku = build_sku(dept, item_number, size)
    assert rebuilt_sku == original_sku