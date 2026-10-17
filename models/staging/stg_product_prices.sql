select product_id, unit_price
from {{ source('raw', 'product_prices') }}
