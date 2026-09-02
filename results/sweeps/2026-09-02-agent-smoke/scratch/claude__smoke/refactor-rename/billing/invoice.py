from .core import calc_fee


def invoice_total(subtotal_cents, rate_bps):
    """Subtotal plus the processing fee, in cents."""
    return subtotal_cents + calc_fee(subtotal_cents, rate_bps)
