#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# setup_hdfs.sh
# Run this script INSIDE the namenode container to upload CSV data to HDFS.
# Usage: bash /tmp/setup_hdfs.sh
# ─────────────────────────────────────────────────────────────────────────────

set -e

echo "=== Creating HDFS directories ==="
hdfs dfs -mkdir -p /user/hive/warehouse
hdfs dfs -mkdir -p /data/employees
hdfs dfs -mkdir -p /data/departments

echo "=== Setting permissions ==="
hdfs dfs -chmod -R 777 /user/hive/warehouse
hdfs dfs -chmod -R 777 /data

echo "=== Uploading CSV files ==="
hdfs dfs -put -f /tmp/employees.csv    /data/employees/employees.csv
hdfs dfs -put -f /tmp/departments.csv  /data/departments/departments.csv

echo "=== Verifying uploads ==="
hdfs dfs -ls /data/employees/
hdfs dfs -ls /data/departments/

echo ""
echo "✅ HDFS setup complete. Files are ready for Hive."
