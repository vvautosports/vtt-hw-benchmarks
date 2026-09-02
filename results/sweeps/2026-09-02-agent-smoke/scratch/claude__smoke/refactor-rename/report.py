"""Dock-side fee report."""
from billing.core import calc_fee

RATE_TABLE = [("standard", 250), ("express", 400)]


def fee_table(amount_cents):
    return {name: calc_fee(amount_cents, bps) for name, bps in RATE_TABLE}


if __name__ == "__main__":
    for name, fee in fee_table(25_000).items():
        print(f"{name}: {fee}")
