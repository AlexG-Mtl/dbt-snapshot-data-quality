select revenue_month, product_id
from {{ ref('mart_monthly_revenue') }}
group by 1, 2
having count(*) > 1
