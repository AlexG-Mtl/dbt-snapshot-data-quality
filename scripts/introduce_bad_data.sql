-- Intentional duplicate reference row; makes the product JOIN multiply revenue.
-- Run only AFTER a valid baseline snapshot exists.
insert into DBT_SNAPSHOT_DQ.RAW.PRODUCT_PRICES (PRODUCT_ID, UNIT_PRICE)
values (101, 100.00);
