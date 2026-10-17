#!/usr/bin/env bash

# Project root for dbt profiles
export DBT_PROFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Snowflake connection settings
export DBT_SNOWFLAKE_ACCOUNT="${DBT_SNOWFLAKE_ACCOUNT:-your_account_identifier}"
export DBT_SNOWFLAKE_USER="${DBT_SNOWFLAKE_USER:-your_service_user}"
export DBT_SNOWFLAKE_PRIVATE_KEY_PATH="${DBT_SNOWFLAKE_PRIVATE_KEY_PATH:-$HOME/.snowflake/keys/your_key.p8}"