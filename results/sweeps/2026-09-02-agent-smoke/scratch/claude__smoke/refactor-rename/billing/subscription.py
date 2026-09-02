from . import core


def monthly_charge(base_cents, rate_bps, months):
    """Total charged over a subscription term, fee applied each month."""
    fee = core.calc_fee(base_cents, rate_bps)
    return (base_cents + fee) * months
