Add a build_sku(dept, item_number, size) function to sku.py — the inverse of parse_sku. It returns '<DEPT>-<NNNN>-<SIZE>' with the item number zero-padded to 4 digits, and raises ValueError for an unknown dept, an unknown size, or an item number outside 0..9999 (a non-integer item number may raise TypeError instead).

Also write pytest tests for build_sku in a new file under tests/ — cover the happy path, the zero-padding, at least two error cases, and a round-trip through parse_sku. Do not modify tests/test_parse_sku.py.
