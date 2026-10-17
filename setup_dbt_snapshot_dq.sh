#!/usr/bin/env bash
set -Eeuo pipefail

# Bootstrap a cloned project without regenerating tracked source files.
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
for cmd in snow uv; do command -v "$cmd" >/dev/null || fail "$cmd is not installed"; done

# All of these are source-controlled project files, never generated here.
for file in dbt_project.yml profiles.example.yml scripts/dbt_env.example.sh \
            scripts/seed.sql models/marts/mart_monthly_revenue.sql \
            snapshots/monthly_revenue_snapshot.sql \
            tests/assert_historical_revenue_unchanged.sql; do
  [[ -f "$file" ]] || fail "Missing $file. Commit the project files before using this bootstrap script."
done

# Do not overwrite existing local configuration.
if [[ ! -f scripts/dbt_env.sh ]]; then
  cp scripts/dbt_env.example.sh scripts/dbt_env.sh
  fail 'Created scripts/dbt_env.sh. Edit its connection settings, then rerun this script.'
fi
if [[ ! -f profiles.yml ]]; then
  cp profiles.example.yml profiles.yml
  fail 'Created profiles.yml. Check its role, warehouse and database, then rerun this script.'
fi

# shellcheck disable=SC1091
source scripts/dbt_env.sh
export DBT_PROFILES_DIR="$PROJECT_DIR"
[[ -n "${DBT_SNOWFLAKE_ACCOUNT:-}" ]] || fail 'DBT_SNOWFLAKE_ACCOUNT is unset'
[[ -n "${DBT_SNOWFLAKE_USER:-}" ]] || fail 'DBT_SNOWFLAKE_USER is unset'
[[ -r "${DBT_SNOWFLAKE_PRIVATE_KEY_PATH:-/nonexistent}" ]] || fail 'Snowflake private key file is not readable'

SNOW_CONNECTION="${SNOW_CONNECTION:-ai_dwh_svc}"
DB='DBT_SNAPSHOT_DQ'

printf '\n== Check Snowflake CLI connection and schemas ==\n'
snow sql -c "$SNOW_CONNECTION" -q "SELECT CURRENT_USER(), CURRENT_ROLE(), CURRENT_WAREHOUSE();" 
snow sql -c "$SNOW_CONNECTION" -q "SHOW SCHEMAS IN DATABASE $DB;"

# Safety: the bootstrap only runs against a fresh, empty demo. It must not
# silently reset the baseline or overwrite the intentionally broken state.
scalar() {
  snow sql -c "$SNOW_CONNECTION" --format CSV -q "$1" | tail -n 1 | tr -d '[:space:]\r"'
}
raw_count="$(scalar "SELECT COUNT(*) FROM $DB.INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'RAW' AND TABLE_NAME IN ('ORDERS','PRODUCT_PRICES');")"
snapshot_count="$(scalar "SELECT COUNT(*) FROM $DB.INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'SNAPSHOTS' AND TABLE_NAME = 'MONTHLY_REVENUE_SNAPSHOT';")"
[[ "$raw_count" =~ ^[0-9]+$ && "$snapshot_count" =~ ^[0-9]+$ ]] || fail 'Could not inspect existing Snowflake objects'
[[ "$raw_count" == 0 && "$snapshot_count" == 0 ]] || fail "Existing demo objects detected (raw tables=$raw_count, snapshot=$snapshot_count). No changes made. Use a fresh database to reproduce the baseline."

printf '\n== Install dbt in the local virtual environment ==\n'
if [[ ! -x .venv/bin/dbt ]]; then
  uv venv .venv
  uv pip install --python .venv/bin/python 'dbt-snowflake>=1.9,<2'
fi
DBT="$PROJECT_DIR/.venv/bin/dbt"
"$DBT" debug

printf '\n== Seed demo source data ==\n'
snow sql -c "$SNOW_CONNECTION" -f scripts/seed.sql

printf '\n== Build models and run standard tests ==\n'
# Snapshot is deliberately excluded until after the valid mart is built.
"$DBT" build --select 'resource_type:model' 'resource_type:test' --exclude assert_historical_revenue_unchanged

printf '\n== Capture the initial valid snapshot ==\n'
"$DBT" snapshot --select monthly_revenue_snapshot

printf '\n== Validate unchanged baseline ==\n'
"$DBT" test --select assert_historical_revenue_unchanged

printf '\nBASELINE COMPLETE. STOP HERE.\n'
printf 'Next, in a separate step: bash scripts/run_failure_demo.sh\n'
