from freight import heaviest_line, line_weight, total_shipment_weight

MANIFEST = [
    {"sku": "HW-0042-XL", "packaging": "crate", "qty": 3, "unit_g": 1800},
    {"sku": "GR-0007-S", "packaging": "envelope", "qty": 12, "unit_g": 220},
    {"sku": "EL-1200-M", "packaging": "drum", "qty": 1, "unit_g": 9500},
]


def test_line_weight_single_qty():
    assert line_weight(MANIFEST[2]) == 9500 + 5400


def test_line_weight_multi_qty():
    assert line_weight(MANIFEST[0]) == 3 * (1800 + 3200)


def test_total_shipment_weight():
    expected = 3 * (1800 + 3200) + 12 * (220 + 40) + 1 * (9500 + 5400)
    assert total_shipment_weight(MANIFEST) == expected


def test_total_empty():
    assert total_shipment_weight([]) == 0


def test_heaviest_line():
    assert heaviest_line(MANIFEST) == "HW-0042-XL"
