import pytest

from sku import parse_sku


def test_parse_fields():
    assert parse_sku("HW-0042-XL") == ("HW", 42, "XL")


def test_parse_leading_zeros():
    assert parse_sku("GR-0007-S") == ("GR", 7, "S")


@pytest.mark.parametrize("bad", ["HW-0042", "XX-0042-XL", "HW-42-XL", "HW-0042-XXL", ""])
def test_parse_rejects(bad):
    with pytest.raises(ValueError):
        parse_sku(bad)
