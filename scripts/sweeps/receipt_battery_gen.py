#!/usr/bin/env python3
"""Generate the synthetic receipt battery + ground truth for the vision track.

Port of expense-agent scripts/gen_battery.py (the source of the banked
2026-08-27-receipt-battery-g1a run) into this repo's task-family conventions:
the battery lands IN the run dir, so truth travels with the run the same way
toolcall_cases.json does -- editing this file can never silently re-grade a
committed run.

Five receipts covering the real failure surface: clean diner (tip/tax split),
rideshare with addresses (qualifier inference), multi-line hotel folio (tax
summation), flight on a second card, and a rotated+noisy parking stub (photo
robustness). 31 gradeable fields total (asserted by the grader self-test at
scripts/testing/test_grade_receipt.py).

Usage:  py scripts/sweeps/receipt_battery_gen.py <run_dir>
Writes: <run_dir>/battery/rcpt*.jpg + <run_dir>/receipt_truth.json

Deterministic: fixed layouts, degrade pass seeded with 42. Requires Pillow for
image rendering only -- the RECEIPTS/truth data imports without it, which is
what the grader self-test relies on.
"""
import json
import random
import sys
from pathlib import Path

RECEIPTS = {
    "rcpt01_diner": {
        "lines": [
            (60, "THE TEST DINER", 40), (120, "123 Fake Street", 26),
            (152, "Columbus, OH 43215", 26),
            (205, "Date: 08/26/2026  7:42 PM", 26),
            (255, "Burger Deluxe          18.50", 26),
            (287, "Caesar Salad           12.00", 26),
            (319, "Iced Tea                3.50", 26),
            (370, "Subtotal               34.00", 26),
            (402, "Tax                     2.72", 26),
            (434, "Tip                     5.45", 26),
            (486, "TOTAL                  42.17", 38),
            (560, "VISA **** **** **** 4242", 26),
            (592, "AUTH: 052364  APPROVED", 26),
        ],
        "truth": {"merchant": "THE TEST DINER", "date": "2026-08-26",
                  "total": 42.17, "tax": 2.72, "tip": 5.45,
                  "category": "dinner", "card_last4": "4242"},
    },
    "rcpt02_uber": {
        "lines": [
            (60, "Uber", 44), (125, "Thanks for riding, Kal", 26),
            (175, "August 25, 2026  6:12 PM", 26),
            (230, "Trip fare              17.90", 26),
            (262, "Booking fee             2.94", 26),
            (294, "Tip                     3.00", 26),
            (346, "Total                 $23.84", 38),
            (415, "Payment: Visa ....4242", 26),
            (475, "6:01 PM  500 Innovation Way Suite 300,", 24),
            (505, "         Columbus, OH 43215", 24),
            (545, "6:12 PM  4512 Maple Grove Ln,", 24),
            (575, "         Columbus, OH 43221", 24),
        ],
        "truth": {"merchant": "Uber", "date": "2026-08-25", "total": 23.84,
                  "tip": 3.00, "category": "uber", "card_last4": "4242",
                  "qualifier": "home"},
    },
    "rcpt03_hotel": {
        "lines": [
            (60, "GRAND COLUMBUS HOTEL", 36), (115, "Guest Folio", 26),
            (165, "Guest: K. Roemer   Room 412", 26),
            (197, "Check-in 08/22/26  Check-out 08/24/26", 24),
            (255, "08/22 Room Charge         189.00", 26),
            (287, "08/22 Occupancy Tax        32.13", 26),
            (319, "08/23 Room Charge         189.00", 26),
            (351, "08/23 Occupancy Tax        32.13", 26),
            (415, "BALANCE                   442.26", 38),
            (485, "Settled to VISA x4242  08/24/2026", 26),
        ],
        "truth": {"merchant": "GRAND COLUMBUS HOTEL", "date": "2026-08-24",
                  "total": 442.26, "tax": 64.26, "category": "hotel",
                  "card_last4": "4242"},
    },
    "rcpt04_flight": {
        "lines": [
            (60, "AMERICAN AIRLINES", 36), (112, "E-Ticket Receipt", 26),
            (165, "Passenger: ROEMER/KALMAN", 26),
            (197, "Confirmation: XKCD42", 26),
            (250, "08/20/2026  CMH -> ORD  Flight AA1187", 24),
            (305, "Base fare             289.60", 26),
            (337, "Taxes and fees         43.44", 26),
            (390, "Total charged        $333.04", 38),
            (460, "MasterCard ending 9931", 26),
        ],
        "truth": {"merchant": "AMERICAN AIRLINES", "date": "2026-08-20",
                  "total": 333.04, "tax": 43.44, "category": "flight",
                  "card_last4": "9931"},
    },
    "rcpt05_parking": {
        "lines": [
            (60, "JOHN GLENN INTL AIRPORT", 32), (108, "PARKING RECEIPT", 30),
            (170, "Entry:  08/20/26 05:14", 26),
            (202, "Exit:   08/26/26 19:47", 26),
            (260, "Long Term Lot B", 26),
            (315, "TOTAL DUE   $36.00", 38),
            (385, "PAID - VISA 4242", 26),
        ],
        "truth": {"merchant": "JOHN GLENN INTL AIRPORT", "date": "2026-08-26",
                  "total": 36.00, "category": "parking", "card_last4": "4242"},
        "degrade": True,
    },
}


def truth_all():
    """task -> truth dict, the shape receipt_truth.json holds and the grader reads."""
    return {name: spec["truth"] for name, spec in RECEIPTS.items()}


def _font(sz):
    from PIL import ImageFont
    try:
        return ImageFont.load_default(size=sz)
    except TypeError:
        return ImageFont.load_default()


def render(lines, size=(700, 1000)):
    from PIL import Image, ImageDraw
    img = Image.new("RGB", size, "white")
    d = ImageDraw.Draw(img)
    for y, text, sz in lines:
        d.text((55, y), text, fill="black", font=_font(sz))
    return img


def degrade(img):
    """Simulate a hasty phone photo: slight rotation, blur, noise. Seeded -- deterministic."""
    from PIL import Image, ImageFilter
    rng = random.Random(42)
    img = img.rotate(7, expand=True, fillcolor="white", resample=Image.BICUBIC)
    img = img.filter(ImageFilter.GaussianBlur(0.8))
    px = img.load()
    w, h = img.size
    for _ in range(w * h // 60):
        x, y = rng.randrange(w), rng.randrange(h)
        g = rng.randrange(140, 240)
        px[x, y] = (g, g, g)
    return img


def main(argv):
    if len(argv) != 1:
        sys.exit(__doc__.strip())
    run_dir = Path(argv[0])
    out = run_dir / "battery"
    out.mkdir(parents=True, exist_ok=True)
    for name, spec in RECEIPTS.items():
        img = render(spec["lines"])
        if spec.get("degrade"):
            img = degrade(img)
        img.save(out / f"{name}.jpg", "JPEG", quality=88)
    (run_dir / "receipt_truth.json").write_text(
        json.dumps(truth_all(), indent=2), encoding="utf-8")
    print(f"battery: {len(RECEIPTS)} receipts -> {out}, truth -> {run_dir}/receipt_truth.json")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
