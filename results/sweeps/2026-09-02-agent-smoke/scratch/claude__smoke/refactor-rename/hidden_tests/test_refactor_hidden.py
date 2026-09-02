import pathlib

import pytest

import billing
from billing import core, invoice, refund, subscription

ROOT = pathlib.Path(__file__).resolve().parent.parent


def test_new_name_exists_and_works():
    assert core.processing_fee(10_000, rate_bps=250) == 250


def test_rate_is_keyword_only():
    with pytest.raises(TypeError):
        core.processing_fee(10_000, 250)


def test_old_name_gone_from_sources():
    sources = sorted((ROOT / "billing").glob("*.py")) + [ROOT / "report.py"]
    for path in sources:
        assert "calc_fee" not in path.read_text(encoding="utf-8"), str(path)


def test_package_export_updated():
    assert hasattr(billing, "processing_fee")
    assert not hasattr(billing, "calc_fee")
    assert not hasattr(core, "calc_fee")


def test_call_sites_still_work():
    assert invoice.invoice_total(20_000, 250) == 20_500
    assert subscription.monthly_charge(10_000, 100, 3) == 3 * (10_000 + 100)
    assert refund.refund_amount(10_000, 250) == 10_000 - 250


def test_negative_amount_still_rejected():
    with pytest.raises(ValueError):
        core.processing_fee(-1, rate_bps=100)
