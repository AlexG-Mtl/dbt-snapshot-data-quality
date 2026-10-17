-- January 2026 is a closed reporting period in this demo.
-- Any changed revenue version is an exception requiring investigation.
with versions as (
    select
        revenue_month,
        product_id,
        revenue_amount,
        lag(revenue_amount) over (
            partition by revenue_month, product_id
            order by dbt_valid_from, dbt_scd_id
        ) as previous_revenue
    from {{ ref('monthly_revenue_snapshot') }}
    where revenue_month = '2026-01-01'::date
)
select
    revenue_month,
    product_id,
    previous_revenue,
    revenue_amount as current_revenue
from versions
where previous_revenue is not null
  and revenue_amount is distinct from previous_revenue
