"""Freight manifest helpers for the dock-scale report."""

TARE_G = {"crate": 3200, "drum": 5400, "envelope": 40}


def line_weight(item):
    """Gross weight in grams for one manifest line (qty x packed unit)."""
    tare = TARE_G[item["packaging"]]
    return item["qty"] * (item["unit_g"] + tare)


def total_shipment_weight(items):
    """Gross weight in grams for the whole manifest."""
    total = 0
    for item in items:
        total += line_weight(item)
    return total


def heaviest_line(items):
    """SKU of the manifest line with the greatest gross weight."""
    return max(items, key=line_weight)["sku"]
