"""
Assign the voucher test population to treatment and holdout, outside dbt.

Reads the eligible population (an export of mart_voucher_holdout_framework),
splits it within each first-order category so both groups have the same
category mix, and writes seeds/voucher_test_assignments.csv. Running
`dbt seed && dbt build -s mart_voucher_holdout_framework+` then fills
assigned_group in the mart.

The split is deterministic: each customer is ranked by a SHA-256 hash of the
salt and their customer_unique_id, and the ranks alternate between groups.
The same salt and population always give the same assignment, and nobody can
pick who lands where.

It also prints the sample size check: how many customers per arm the test
needs to detect the target lift, against how many are eligible.

Usage:
    python scripts/assign_holdout.py eligible.csv --salt voucher-2018-09 \
        --assigned-at 2018-09-01 --treatment-share 0.5 \
        --baseline 0.0113 --target 0.0226

Standard library only.
"""

import argparse
import csv
import hashlib
import math
from collections import defaultdict
from pathlib import Path
from statistics import NormalDist

SEED_PATH = Path(__file__).resolve().parents[1] / "seeds" / "voucher_test_assignments.csv"


def per_arm_sample_size(baseline, target, alpha=0.05, power=0.8, ratio=1.0):
    """Customers needed in the holdout arm for a two-sided test of two proportions.

    ratio is treatment size divided by holdout size.
    """
    z_alpha = NormalDist().inv_cdf(1 - alpha / 2)
    z_power = NormalDist().inv_cdf(power)
    variance = baseline * (1 - baseline) + target * (1 - target) / ratio
    return math.ceil((z_alpha + z_power) ** 2 * variance / (target - baseline) ** 2)


def minimum_detectable_rate(baseline, n_holdout, n_treatment, alpha=0.05, power=0.8):
    """Smallest treatment rate the test can detect with the given group sizes."""
    z = NormalDist().inv_cdf(1 - alpha / 2) + NormalDist().inv_cdf(power)
    rate = baseline
    while rate < 1:
        se = math.sqrt(baseline * (1 - baseline) / n_holdout + rate * (1 - rate) / n_treatment)
        if rate - baseline >= z * se:
            return rate
        rate += 0.0001
    return None


def assign(rows, salt, treatment_share):
    by_category = defaultdict(list)
    for row in rows:
        by_category[row["first_order_category"]].append(row["customer_unique_id"])

    assignments = {}
    for category, ids in by_category.items():
        ranked = sorted(ids, key=lambda cid: hashlib.sha256(f"{salt}:{cid}".encode()).hexdigest())
        n_treatment = round(len(ranked) * treatment_share)
        for i, cid in enumerate(ranked):
            assignments[cid] = "treatment" if i < n_treatment else "holdout"
    return assignments


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("eligible_csv", help="export of mart_voucher_holdout_framework")
    parser.add_argument("--salt", required=True, help="fixed string per test, e.g. voucher-2018-09")
    parser.add_argument("--assigned-at", required=True, help="assignment date, YYYY-MM-DD")
    parser.add_argument("--treatment-share", type=float, default=0.5)
    parser.add_argument("--baseline", type=float, default=0.0113,
                        help="expected repeat rate within 60 days without a voucher")
    parser.add_argument("--target", type=float, default=0.0226,
                        help="repeat rate the voucher has to reach to be worth its cost")
    parser.add_argument("--out", default=str(SEED_PATH))
    args = parser.parse_args()

    with open(args.eligible_csv, newline="") as f:
        rows = list(csv.DictReader(f))

    assignments = assign(rows, args.salt, args.treatment_share)
    n_treatment = sum(1 for g in assignments.values() if g == "treatment")
    n_holdout = len(assignments) - n_treatment

    ratio = args.treatment_share / (1 - args.treatment_share)
    needed = per_arm_sample_size(args.baseline, args.target, ratio=ratio)
    mdr = minimum_detectable_rate(args.baseline, n_holdout, n_treatment)
    print(f"eligible customers:   {len(assignments):,}")
    print(f"treatment / holdout:  {n_treatment:,} / {n_holdout:,}")
    print(f"needed to detect {args.baseline:.2%} -> {args.target:.2%}: "
          f"{math.ceil(needed * ratio):,} treatment / {needed:,} holdout")
    if mdr is not None:
        print(f"smallest detectable treatment rate with these groups: {mdr:.2%}")
    if n_holdout < needed:
        print("warning: the holdout is too small for the target lift; widen eligibility or run longer")

    with open(args.out, "w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["customer_unique_id", "assigned_group", "assigned_at"])
        for cid in sorted(assignments):
            writer.writerow([cid, assignments[cid], args.assigned_at])
    print(f"wrote {args.out}")


if __name__ == "__main__":
    main()
