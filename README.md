# Historical revenue regression detection with dbt snapshots

A reproducible Snowflake/dbt demonstration of a failure that can slip through ordinary model tests: an accidental many-to-many join changes revenue for a previously closed reporting month, while the final mart still has one row per month and product.

## What the demo proves

- The revenue mart passes its `not_null` and `(revenue_month, product_id)` uniqueness checks.
- A duplicated product-price row doubles the affected product's calculated revenue.
- A dbt snapshot preserves both the original and recalculated monthly figures.
- A singular dbt test flags a changed value for the closed January 2026 period.

The snapshot **detects a change**, not its cause. In production, this policy would need an explicit reporting close calendar and exceptions for approved backfills, refunds, and corrections.

## Architecture

`RAW.ORDERS` + `RAW.PRODUCT_PRICES` → staging views → `MARTS.MART_MONTHLY_REVENUE` → `SNAPSHOTS.MONTHLY_REVENUE_SNAPSHOT` → regression test.

The example intentionally does **not** enforce uniqueness on `RAW.PRODUCT_PRICES`: that omission makes it possible to demonstrate how a grain violation propagates into an aggregate. A production model should validate reference-table grain before the join.

## Reproduce from a fresh environment

The setup is **not a reset script**. Use an empty `DBT_SNAPSHOT_DQ` database: if the demo source tables or snapshot already exist, `setup_dbt_snapshot_dq.sh` stops without replacing them.

### 1. Prerequisites

- Git, Snowflake CLI (`snow`), and `uv` installed on Linux.
- A Snowflake account, an existing virtual warehouse, and an existing service role/user with key-pair authentication.
- A working Snowflake CLI connection for that service user. The example name is `ai_dwh_svc`; your connection can have a different name.
- An administrator who can run the one-time provisioning SQL in Snowsight.

### 2. Clone the repository

```bash
git clone git@github.com:AlexG-Mtl/dbt-snapshot-data-quality.git
cd dbt-snapshot-data-quality
```

The repository must contain the tracked models, snapshots, tests, `scripts/seed.sql`, `scripts/introduce_bad_data.sql`, and both example configuration files. If any are missing, the setup script cannot reproduce the demo; commit those files first.

### 3. Provision Snowflake (once, as admin)

In Snowsight, open `scripts/setup_snowflake.sql` and execute it as `ACCOUNTADMIN` **after reviewing the role and warehouse names**. The script creates `DBT_SNAPSHOT_DQ` and the `RAW`, `STAGING`, `MARTS`, and `SNAPSHOTS` schemas, then grants the existing `AI_DWH_ROLE` access to them and to `AI_DWH_WH`.

It does **not** create a user, role, warehouse, or private key. Use your own existing service credentials and substitute your role/warehouse if necessary. It does not delete existing objects. Use a fresh demo database; do not drop a database containing valuable data just to rerun the example.

### 4. Configure local authentication

```bash
cp scripts/dbt_env.example.sh scripts/dbt_env.sh
cp profiles.example.yml profiles.yml
code scripts/dbt_env.sh
```

Set the correct `DBT_SNOWFLAKE_ACCOUNT`, `DBT_SNOWFLAKE_USER`, and `DBT_SNOWFLAKE_PRIVATE_KEY_PATH` in `scripts/dbt_env.sh`. The private key file stays outside Git. The dbt profile uses the repository root as `DBT_PROFILES_DIR` and defaults to database `DBT_SNAPSHOT_DQ`, role `AI_DWH_ROLE`, warehouse `AI_DWH_WH`, and schema `STAGING`. For another role/warehouse, set `DBT_SNOWFLAKE_ROLE` and `DBT_SNOWFLAKE_WAREHOUSE` in your local environment file.

The scripts use Snowflake CLI connection `ai_dwh_svc` unless `SNOW_CONNECTION` is set. A CLI connection and a dbt profile are separate configurations.

```bash
source scripts/dbt_env.sh
export SNOW_CONNECTION=ai_dwh_svc  # change to your CLI connection name
snow sql -c "$SNOW_CONNECTION" -q "SELECT CURRENT_USER(), CURRENT_ROLE(), CURRENT_WAREHOUSE();"
```

**Before running setup**, confirm that your `scripts/dbt_env.sh` exports all variables used by `profiles.yml` and that the key file is readable. The `snow` connection must target the same Snowflake account as dbt.

### 5. Create the valid baseline

```bash
bash setup_dbt_snapshot_dq.sh
```

The script checks for existing demo objects, installs dbt in `.venv/`, loads source data from `scripts/seed.sql`, builds the dbt models, captures the first valid snapshot, and runs the historical regression test. It stops at `BASELINE COMPLETE. STOP HERE.`

Expected January 2026 revenue: product `101` = **500**, product `102` = **200**.

### 6. Introduce the deliberate regression

```bash
bash scripts/run_failure_demo.sh
```

Enter `DEMO` at the confirmation prompt. This inserts the intentionally duplicated product-price row, rebuilds the mart, snapshots the changed revenue, and runs the regression test. **A failing `assert_historical_revenue_unchanged` test is the expected result.** The shell command may exit nonzero because dbt reports the intentional test failure.

Inspect the versions in Snowsight:

```sql
SELECT product_id, revenue_month, revenue_amount,
       dbt_valid_from, dbt_valid_to
FROM DBT_SNAPSHOT_DQ.SNAPSHOTS.MONTHLY_REVENUE_SNAPSHOT
ORDER BY product_id, dbt_valid_from;
```

Product `101` should show the baseline `500` and the changed `1000`; product `102` should remain at `200`. The historical test flags the changed value, not the root cause. The failure script should be run **only once per fresh demo**.

### 7. Verify the repository is safe to publish

```bash
git status --short
git add .
git diff --cached --name-only
```

Review staged files for credentials before committing. The templates and reproducible scripts belong in Git; local profiles, keys, virtual environments, and generated dbt output do not.

### Files kept out of Git

`profiles.yml`, `scripts/dbt_env.sh`, `.venv/`, `target/`, `logs/`, and all private keys. Commit `profiles.example.yml` and `scripts/dbt_env.example.sh` instead.

## Why not CDC?

CDC can tell us which source rows changed, but it does not by itself verify whether a downstream business KPI was recalculated unexpectedly. Here we compare historical *model outputs*. CDC and snapshots can be complementary.

## Production considerations

- Define which reporting periods are immutable and how approved restatements are recorded.
- Add source-grain tests on price reference data to prevent this particular failure earlier.
- Consider an immutable baseline or an alert acknowledgment table to avoid repeated alerts after a known restatement.
- Schedule snapshots after the mart finishes; ensure the first baseline is known-good.
- Avoid a global `generate_schema_name` override in a shared dbt deployment without considering schema collisions.
