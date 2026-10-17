#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "$0")/.."
source scripts/dbt_env.sh
SNOW_CONNECTION="${SNOW_CONNECTION:-ai_dwh_svc}"

if [[ ! -x .venv/bin/dbt ]]; then
  echo 'dbt environment missing: expected .venv/bin/dbt' >&2
  exit 1
fi

# Fail before modifying data if the duplicate is already present.
# Snowflake CLI outputs a table; inspect a simple scalar via CSV instead.
count=$(snow sql -c "$SNOW_CONNECTION" --format CSV -q \
  "SELECT COUNT(*) AS N FROM DBT_SNAPSHOT_DQ.RAW.PRODUCT_PRICES WHERE PRODUCT_ID = 101;" \
  | tail -n 1 | tr -d '[:space:]\r"')
if [[ "$count" != "1" ]]; then
  echo "Expected exactly one price row for product 101; found: $count. Refusing to insert again." >&2
  exit 1
fi

printf '%s\n' 'This will insert a duplicate price for product 101 in the demo database.'
read -r -p 'Type DEMO to continue: ' answer
[[ "$answer" == DEMO ]] || exit 1

snow sql -c "$SNOW_CONNECTION" -f scripts/introduce_bad_data.sql
.venv/bin/dbt run --select +mart_monthly_revenue
.venv/bin/dbt snapshot --select monthly_revenue_snapshot

# A failing test is the intended outcome; propagate its exit status.
.venv/bin/dbt test --select assert_historical_revenue_unchanged
