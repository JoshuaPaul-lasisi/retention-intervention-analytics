#!/usr/bin/env bash
# Download the nine Olist CSVs into data/raw/.
#
# Olist publishes the same files on GitHub (olist/work-at-olist-data), which
# needs no Kaggle login. The Kaggle copy (olistbr/brazilian-ecommerce) is
# identical; unzip it into data/raw/ instead if you prefer.
set -euo pipefail

BASE="https://raw.githubusercontent.com/olist/work-at-olist-data/master/datasets"
RAW_DIR="$(cd "$(dirname "$0")/.." && pwd)/data/raw"
mkdir -p "$RAW_DIR"

for table in olist_orders_dataset olist_order_items_dataset olist_order_payments_dataset \
             olist_order_reviews_dataset olist_customers_dataset olist_sellers_dataset \
             olist_products_dataset olist_geolocation_dataset product_category_name_translation; do
  echo "downloading $table"
  curl -sSfL -o "$RAW_DIR/$table.csv" "$BASE/$table.csv"
done
