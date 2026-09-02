import pathlib

import pytest

from sku import build_sku, parse_sku


def test_happy_path():
    assert build_sku("HW", 42, "XL") == "HW-0042-XL"


def test_zero_pads_to_four():
    assert build_sku("GR", 0, "XS") == "GR-0000-XS"


def test_max_item():
    assert build_sku("TX", 9999, "M") == "TX-9999-M"


def test_roundtrip():
    assert parse_sku(build_sku("EL", 7, "L")) == ("EL", 7, "L")


@pytest.mark.parametrize(
    "dept,item,size",
    [("XX", 1, "M"), ("HW", 10000, "M"), ("HW", -1, "M"), ("HW", 1, "XXL")],
)
def test_rejects_bad_inputs(dept, item, size):
    with pytest.raises((ValueError, TypeError)):
        build_sku(dept, item, size)


def test_agent_added_tests():
    tests_dir = pathlib.Path(__file__).resolve().parent.parent / "tests"
    new_tests = [
        p
        for p in tests_dir.glob("test_*.py")
        if p.name != "test_parse_sku.py" and "build_sku" in p.read_text(encoding="utf-8")
    ]
    assert new_tests, "no new test file exercising build_sku found under tests/"
