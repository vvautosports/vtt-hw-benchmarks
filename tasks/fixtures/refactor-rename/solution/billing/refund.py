from .core import processing_fee


def refund_amount(charged_cents, rate_bps):
    """Refund for a charge; processing fees are not refunded."""
    return charged_cents - processing_fee(charged_cents, rate_bps=rate_bps)
