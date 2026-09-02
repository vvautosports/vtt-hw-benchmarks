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


def build_sku(dept, item_number, size):
    """Build a SKU string from components.

    Args:
        dept: Department code (e.g. 'HW', 'EL')
        item_number: Item number (0-9999)
        size: Size code (e.g. 'XS', 'S', 'M', 'L', 'XL')

    Returns:
        str: SKU in format '<DEPT>-<NNNN>-<SIZE>' with item number zero-padded to 4 digits

    Raises:
        ValueError: For unknown dept, unknown size, or item number outside 0..9999 range
        TypeError: For non-integer item number
    """
    if dept not in DEPTS:
        raise ValueError(f"unknown dept: {dept!r}")
    if size not in SIZES:
        raise ValueError(f"unknown size: {size!r}")
    if not isinstance(item_number, int):
        raise TypeError(f"item number must be an integer, got {type(item_number).__name__!r}")
    if not (0 <= item_number <= 9999):
        raise ValueError(f"item number out of range 0-9999: {item_number!r}")
    return f"{dept}-{item_number:04d}-{size}"
