from .core import processing_fee


def invoice_total(subtotal_cents, rate_bps):
    """Subtotal plus the processing fee, in cents."""
    return subtotal_cents + processing_fee(subtotal_cents, rate_bps=rate_bps)
