-- Isolated demo database only. Idempotent on first run; does not delete existing rows.
create table if not exists DBT_SNAPSHOT_DQ.RAW.ORDERS (
  ORDER_ID number, ORDER_DATE date, PRODUCT_ID number, QUANTITY number
);
create table if not exists DBT_SNAPSHOT_DQ.RAW.PRODUCT_PRICES (
  PRODUCT_ID number, UNIT_PRICE number(12,2)
);
insert into DBT_SNAPSHOT_DQ.RAW.ORDERS (ORDER_ID, ORDER_DATE, PRODUCT_ID, QUANTITY)
select column1, to_date(column2), column3, column4
from values
  (1, '2026-01-05', 101, 3),
  (2, '2026-01-10', 101, 2),
  (3, '2026-01-11', 102, 4)
where not exists (select 1 from DBT_SNAPSHOT_DQ.RAW.ORDERS);
insert into DBT_SNAPSHOT_DQ.RAW.PRODUCT_PRICES (PRODUCT_ID, UNIT_PRICE)
select column1, column2
from values (101, 100.00), (102, 50.00)
where not exists (select 1 from DBT_SNAPSHOT_DQ.RAW.PRODUCT_PRICES);
