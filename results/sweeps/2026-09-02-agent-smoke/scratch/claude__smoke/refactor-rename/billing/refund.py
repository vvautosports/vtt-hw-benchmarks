from .core import calc_fee


def refund_amount(charged_cents, rate_bps):
    """Refund for a charge; processing fees are not refunded."""
    return charged_cents - calc_fee(charged_cents, rate_bps)
