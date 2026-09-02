import pytest

from sku import build_sku, parse_sku


def test_formats_and_pads():
    assert build_sku("HW", 42, "XL") == "HW-0042-XL"
    assert build_sku("GR", 7, "S") == "GR-0007-S"


def test_roundtrip():
    assert parse_sku(build_sku("TX", 123, "M")) == ("TX", 123, "M")


def test_rejects_unknown_dept():
    with pytest.raises(ValueError):
        build_sku("ZZ", 1, "M")


def test_rejects_out_of_range_item():
    with pytest.raises(ValueError):
        build_sku("HW", 12345, "M")
