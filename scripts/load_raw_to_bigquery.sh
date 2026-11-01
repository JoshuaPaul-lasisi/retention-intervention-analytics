#!/usr/bin/env bash
# Load the nine Olist CSVs from data/raw/ into BigQuery as-is.
#
#   GCP_PROJECT=my-project ./scripts/load_raw_to_bigquery.sh
#
# Needs the bq CLI, logged in with `gcloud auth login`. The dataset defaults to
# olist_raw (the raw_dataset var in dbt_project.yml) and location to US.
set -euo pipefail

: "${GCP_PROJECT:?set GCP_PROJECT to your Google Cloud project id}"
DATASET="${RAW_DATASET:-olist_raw}"
LOCATION="${BIGQUERY_LOCATION:-US}"
RAW_DIR="$(cd "$(dirname "$0")/.." && pwd)/data/raw"

TABLES=(
  olist_orders_dataset
  olist_order_items_dataset
  olist_order_payments_dataset
  olist_order_reviews_dataset
  olist_customers_dataset
  olist_sellers_dataset
  olist_products_dataset
  olist_geolocation_dataset
  product_category_name_translation
)

bq --location="$LOCATION" mk --dataset --force "$GCP_PROJECT:$DATASET" >/dev/null

for table in "${TABLES[@]}"; do
  file="$RAW_DIR/$table.csv"
  [[ -f "$file" ]] || { echo "missing $file" >&2; exit 1; }
  # The translation file starts with a byte order mark, which would end up in
  # the first column name.
  tmp="$(mktemp)"
  sed '1s/^\xEF\xBB\xBF//' "$file" > "$tmp"
  # Schema detection can't find the header when every column is text, so the
  # translation table gets its schema spelled out.
  if [[ "$table" == product_category_name_translation ]]; then
    schema_args=(--schema=product_category_name:STRING,product_category_name_english:STRING)
  else
    schema_args=(--autodetect)
  fi
  echo "loading $table"
  bq --location="$LOCATION" load \
    --replace \
    --source_format=CSV \
    "${schema_args[@]}" \
    --skip_leading_rows=1 \
    --allow_quoted_newlines \
    "$GCP_PROJECT:$DATASET.$table" "$tmp"
  rm -f "$tmp"
done
