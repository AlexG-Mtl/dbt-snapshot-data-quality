select
    date_trunc('month', o.order_date)::date as revenue_month,
    o.product_id,
    sum(o.quantity * p.unit_price)::number(18,2) as revenue_amount
from {{ ref('stg_orders') }} o
join {{ ref('stg_product_prices') }} p
  on o.product_id = p.product_id
group by 1, 2
