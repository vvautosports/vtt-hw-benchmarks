"""SKU helpers.

A SKU is '<DEPT>-<NNNN>-<SIZE>', e.g. 'HW-0042-XL'.
"""

DEPTS = {"HW", "EL", "GR", "TX"}
SIZES = {"XS", "S", "M", "L", "XL"}


def parse_sku(sku):
    """Split a SKU string into (dept, item_number, size)."""
    parts = sku.split("-")
    if len(parts) != 3:
        raise ValueError(f"malformed sku: {sku!r}")
    dept, item, size = parts
    if dept not in DEPTS:
        raise ValueError(f"unknown dept: {dept!r}")
    if not (item.isdigit() and len(item) == 4):
        raise ValueError(f"bad item number: {item!r}")
    if size not in SIZES:
        raise ValueError(f"unknown size: {size!r}")
    return dept, int(item), size
