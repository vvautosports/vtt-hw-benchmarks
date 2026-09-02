def processing_fee(amount_cents, *, rate_bps):
    """Fee in cents for a charge of amount_cents at rate_bps basis points.

    Rounds half-up in integer arithmetic so ledger math never sees floats.
    """
    if amount_cents < 0:
        raise ValueError("amount_cents must be >= 0")
    return (amount_cents * rate_bps + 5000) // 10000
