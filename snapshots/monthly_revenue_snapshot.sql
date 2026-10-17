{% snapshot monthly_revenue_snapshot %}
{{ config(
    target_database='DBT_SNAPSHOT_DQ',
    target_schema='SNAPSHOTS',
    unique_key="revenue_month || '|' || product_id",
    strategy='check',
    check_cols=['revenue_amount'],
    invalidate_hard_deletes=True
) }}
select revenue_month, product_id, revenue_amount
from {{ ref('mart_monthly_revenue') }}
{% endsnapshot %}
