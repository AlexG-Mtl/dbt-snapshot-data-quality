select order_id, order_date, product_id, quantity
from {{ source('raw', 'orders') }}
