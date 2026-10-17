-- Run once in a Snowsight worksheet with an administrative role.
-- Change AI_DWH_ROLE and AI_DWH_WH if your environment uses different names.
-- Requires an existing service role and warehouse.
USE ROLE ACCOUNTADMIN;

CREATE DATABASE IF NOT EXISTS DBT_SNAPSHOT_DQ;
CREATE SCHEMA IF NOT EXISTS DBT_SNAPSHOT_DQ.RAW;
CREATE SCHEMA IF NOT EXISTS DBT_SNAPSHOT_DQ.STAGING;
CREATE SCHEMA IF NOT EXISTS DBT_SNAPSHOT_DQ.MARTS;
CREATE SCHEMA IF NOT EXISTS DBT_SNAPSHOT_DQ.SNAPSHOTS;

GRANT USAGE ON DATABASE DBT_SNAPSHOT_DQ TO ROLE AI_DWH_ROLE;
GRANT USAGE ON WAREHOUSE AI_DWH_WH TO ROLE AI_DWH_ROLE;
GRANT USAGE ON ALL SCHEMAS IN DATABASE DBT_SNAPSHOT_DQ TO ROLE AI_DWH_ROLE;
GRANT CREATE TABLE, CREATE VIEW ON ALL SCHEMAS IN DATABASE DBT_SNAPSHOT_DQ TO ROLE AI_DWH_ROLE;

-- Existing objects may be owned by a different role. These grants allow
-- DML but do not confer OWNERSHIP (needed for some replace/drop operations).
GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE
  ON ALL TABLES IN DATABASE DBT_SNAPSHOT_DQ TO ROLE AI_DWH_ROLE;

-- No blanket future grants: objects created by AI_DWH_ROLE are owned by it.
-- For an existing deployment, resolve ownership separately before rebuilding.
