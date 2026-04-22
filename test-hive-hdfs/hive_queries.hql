-- ─────────────────────────────────────────────────────────────────────────────
-- hive_queries.hql
-- Hive + HDFS integration test queries
-- Run with: beeline -u jdbc:hive2://localhost:10000 -f /tmp/hive_queries.hql
-- ─────────────────────────────────────────────────────────────────────────────


-- ── 1. Create database ────────────────────────────────────────────────────────
CREATE DATABASE IF NOT EXISTS company;
USE company;


-- ── 2. External table: employees (data lives in HDFS, not managed by Hive) ───
-- "EXTERNAL" means dropping the table does NOT delete the HDFS files.
CREATE EXTERNAL TABLE IF NOT EXISTS employees (
    id          INT,
    name        STRING,
    department  STRING,
    salary      INT,
    hire_date   STRING
)
ROW FORMAT DELIMITED
    FIELDS TERMINATED BY ','
STORED AS TEXTFILE
LOCATION 'hdfs://namenode:9000/data/employees'
TBLPROPERTIES ("skip.header.line.count"="1");


-- ── 3. External table: departments ───────────────────────────────────────────
CREATE EXTERNAL TABLE IF NOT EXISTS departments (
    dept_name   STRING,
    location    STRING,
    budget      INT
)
ROW FORMAT DELIMITED
    FIELDS TERMINATED BY ','
STORED AS TEXTFILE
LOCATION 'hdfs://namenode:9000/data/departments'
TBLPROPERTIES ("skip.header.line.count"="1");


-- ── 4. Basic queries ──────────────────────────────────────────────────────────

-- List all employees
SELECT * FROM employees;

-- Count employees per department
SELECT department, COUNT(*) AS total_employees
FROM employees
GROUP BY department
ORDER BY total_employees DESC;

-- Average salary per department
SELECT department,
       ROUND(AVG(salary), 2) AS avg_salary,
       MIN(salary)           AS min_salary,
       MAX(salary)           AS max_salary
FROM employees
GROUP BY department;


-- ── 5. JOIN: employees with department details ────────────────────────────────
SELECT
    e.id,
    e.name,
    e.salary,
    e.hire_date,
    d.location,
    d.budget
FROM employees e
JOIN departments d ON e.department = d.dept_name
ORDER BY e.salary DESC;


-- ── 6. Managed (internal) table built from query results ─────────────────────
-- This table IS managed by Hive; dropping it removes the data from HDFS.
CREATE TABLE IF NOT EXISTS high_earners
STORED AS ORC
AS
SELECT id, name, department, salary
FROM employees
WHERE salary > 70000
ORDER BY salary DESC;

SELECT * FROM high_earners;


-- ── 7. Verify HDFS location of the managed table ─────────────────────────────
DESCRIBE FORMATTED high_earners;


-- ── 8. Drop external tables (HDFS data is preserved) ─────────────────────────
-- Dropping an EXTERNAL table only removes the metadata from the metastore.
-- The CSV files in /data/employees/ and /data/departments/ remain intact.
-- Note: high_earners (managed table) is intentionally NOT dropped here.

USE company;

DROP TABLE IF EXISTS employees;
DROP TABLE IF EXISTS departments;

-- Verify the tables are gone (high_earners should still appear)
SHOW TABLES;
