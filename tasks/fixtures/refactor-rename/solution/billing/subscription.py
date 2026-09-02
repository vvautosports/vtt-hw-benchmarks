from . import core


def monthly_charge(base_cents, rate_bps, months):
    """Total charged over a subscription term, fee applied each month."""
    fee = core.processing_fee(base_cents, rate_bps=rate_bps)
    return (base_cents + fee) * months
