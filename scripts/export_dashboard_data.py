"""
Export the analytics marts to site/data.json for the dashboard.

Reads the DuckDB database that `dbt build --target duckdb` writes (the same
models as BigQuery, built from the same CSVs) and writes one JSON file the
static dashboard loads.

Usage:
    python scripts/export_dashboard_data.py [--db olist.duckdb] [--out site/data.json]
"""

import argparse
import json
import sys
from pathlib import Path

import duckdb

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(Path(__file__).resolve().parent))
from assign_holdout import minimum_detectable_rate  # noqa: E402

SCHEMA = "olist"


def rows(con, sql):
    cur = con.execute(sql.format(s=SCHEMA))
    cols = [d[0] for d in cur.description]
    out = []
    for record in cur.fetchall():
        row = {}
        for col, value in zip(cols, record):
            if hasattr(value, "isoformat"):
                value = value.isoformat()
            elif isinstance(value, float):
                value = round(value, 6)
            elif value is not None and not isinstance(value, (int, str, bool)):
                value = float(value)
            row[col] = value
        out.append(row)
    return out


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", default=str(ROOT / "olist.duckdb"))
    parser.add_argument("--out", default=str(ROOT / "site" / "data.json"))
    args = parser.parse_args()

    con = duckdb.connect(args.db, read_only=True)

    kpis = rows(con, """
        select
            count(*) filter (where has_qualifying_order)                           as customers,
            count(*) filter (where is_repeat_buyer)                                as repeat_buyers,
            count(*) filter (where is_repeat_window_observed)                      as observed_customers,
            avg(case when is_repeat_within_window then 1.0 else 0.0 end)
                filter (where is_repeat_window_observed)                           as repeat_rate_180d
        from {s}_core.dim_customers
    """)[0]
    kpis.update(rows(con, """
        select
            count(*)                                                               as qualifying_orders,
            avg(case when is_late_delivery then 1.0 else 0.0 end)
                filter (where is_delivered)                                        as late_delivery_rate
        from {s}_core.fct_orders
        where is_completed and is_in_analysis_window
    """)[0])
    kpis["voucher_eligible"] = rows(con, "select count(*) as n from {s}_analytics.mart_voucher_holdout_framework")[0]["n"]

    categories = rows(con, """
        select first_order_category, observed_buyers, repeat_buyers_within_window, repeat_rate,
               repeat_rate_ci_low, repeat_rate_ci_high, lift_vs_overall, propensity_rank,
               is_high_propensity, overall_repeat_rate
        from {s}_analytics.mart_category_repeat_propensity
        where is_ranked
        order by propensity_rank
    """)

    timing = rows(con, """
        select first_order_category, repeat_buyers, p25_days_to_repeat, median_days_to_repeat,
               p75_days_to_repeat, share_within_30_days, share_within_60_days, suggested_send_day
        from {s}_analytics.mart_email_timing_windows_by_category
        where has_enough_repeaters
        order by case when first_order_category = 'all_categories' then 0 else 1 end,
                 median_days_to_repeat
    """)

    delivery_monthly = rows(con, """
        select
            order_month,
            sum(order_count)                                                       as orders,
            sum(delivered_order_count)                                             as delivered_orders,
            sum(late_order_count)                                                  as late_orders,
            sum(late_order_count) * 1.0 / nullif(sum(delivered_order_count), 0)    as late_delivery_rate,
            sum(on_time_rate * delivered_order_count) / nullif(sum(delivered_order_count), 0) as on_time_rate,
            sum(gmv)                                                               as gmv
        from {s}_analytics.mart_delivery_performance
        group by order_month
        order by order_month
    """)

    # Sellers with enough recent volume whose late rate is worst over the last
    # three full months of data.
    worst_sellers = rows(con, """
        with recent as (
            select
                seller_id,
                any_value(seller_state)                                            as seller_state,
                sum(delivered_order_count)                                         as delivered_orders,
                sum(late_order_count)                                              as late_orders,
                sum(gmv)                                                           as gmv,
                sum(avg_review_score * order_count) / sum(order_count)             as avg_review_score,
                any_value(seller_lifetime_late_delivery_rate)                      as lifetime_late_rate
            from {s}_analytics.mart_delivery_performance
            where order_month >= date '2018-06-01'
            group by seller_id
        )
        select *, late_orders * 1.0 / delivered_orders as late_delivery_rate
        from recent
        where delivered_orders >= 30
        order by late_delivery_rate desc, delivered_orders desc
        limit 10
    """)

    voucher = rows(con, """
        select first_order_category, count(*) as eligible_customers,
               min(days_since_first_order) as min_days, max(days_since_first_order) as max_days
        from {s}_analytics.mart_voucher_holdout_framework
        group by first_order_category
        order by eligible_customers desc
    """)

    # Baseline: observed buyers in the high-propensity categories who had not
    # come back by day 14, and the share who came back in the next 60 days.
    baseline = rows(con, """
        select avg(case when days_to_second_purchase > 14 and days_to_second_purchase <= 74
                        then 1.0 else 0.0 end) as rate
        from {s}_core.dim_customers c
        inner join {s}_analytics.mart_category_repeat_propensity p
            on p.first_order_category = c.first_order_category and p.is_high_propensity
        where c.is_repeat_window_observed
          and (c.days_to_second_purchase is null or c.days_to_second_purchase > 14)
    """)[0]["rate"]
    eligible = kpis["voucher_eligible"]
    half = eligible // 2
    tenth = round(eligible * 0.1)
    design = {
        "baseline_rate_60d": baseline,
        "split_50_50": {"holdout": half, "treatment": eligible - half,
                        "min_detectable_rate": minimum_detectable_rate(baseline, half, eligible - half)},
        "split_90_10": {"holdout": tenth, "treatment": eligible - tenth,
                        "min_detectable_rate": minimum_detectable_rate(baseline, tenth, eligible - tenth)},
    }

    snapshot = rows(con, "select max(eligibility_snapshot_date) as d from {s}_analytics.mart_voucher_holdout_framework")[0]["d"]

    data = {
        "snapshot_date": snapshot,
        "kpis": kpis,
        "categories": categories,
        "timing": timing,
        "delivery_monthly": delivery_monthly,
        "worst_sellers": worst_sellers,
        "voucher": {"by_category": voucher, "design": design},
    }
    Path(args.out).parent.mkdir(parents=True, exist_ok=True)
    Path(args.out).write_text(json.dumps(data, indent=1))
    print(f"wrote {args.out}")


if __name__ == "__main__":
    main()
