#!/bin/bash
# ============================================================
# Kerberos Security Lab - Exercise 3
# Access HDFS using a Kerberos ticket
# ============================================================
# Prerequisite: run 01-creer-ticket-kerberos.sh first
# Usage: docker exec -it namenode bash /tp-scripts/02-acces-hdfs-kerberos.sh
# ============================================================

REALM="HADOOP.LOCAL"

echo "============================================================"
echo "  Kerberos Lab - HDFS access with Kerberos ticket"
echo "============================================================"
echo ""

# ---- Check for a valid ticket ----
echo ">>> Checking for a valid Kerberos ticket"
if ! klist -s 2>/dev/null; then
    echo "ERROR: No valid Kerberos ticket found!"
    echo "Run first: bash /tp-scripts/01-creer-ticket-kerberos.sh"
    exit 1
fi
echo "Valid ticket for:"
klist | grep "Default principal"
echo ""

# ---- Step 1: List HDFS root ----
echo ">>> Step 1: List HDFS root directory (authenticated)"
echo "Command: hdfs dfs -ls /"
hdfs dfs -ls /
echo ""

# ---- Step 2: Create user directory ----
echo ">>> Step 2: Create /user/hadoop directory"
hdfs dfs -mkdir -p /user/hadoop
echo "Directory created."
hdfs dfs -ls /user/
echo ""

# ---- Step 3: Write a file to HDFS ----
echo ">>> Step 3: Write a file to HDFS"
echo "HDFS access secured by Kerberos - $(date)" > /tmp/kerberos-test.txt
hdfs dfs -put /tmp/kerberos-test.txt /user/hadoop/kerberos-test.txt
echo "File uploaded."
echo ""

# ---- Step 4: Read the file from HDFS ----
echo ">>> Step 4: Read the file from HDFS"
echo "Command: hdfs dfs -cat /user/hadoop/kerberos-test.txt"
hdfs dfs -cat /user/hadoop/kerberos-test.txt
echo ""

# ---- Step 5: Check file permissions ----
echo ">>> Step 5: Check file permissions"
hdfs dfs -ls /user/hadoop/kerberos-test.txt
echo ""

# ---- Step 6: HDFS cluster report ----
echo ">>> Step 6: HDFS cluster report"
hdfs dfsadmin -report | head -30
echo ""

echo "============================================================"
echo "  HDFS access with Kerberos succeeded!"
echo "  Next: run 03-test-sans-authentification.sh"
echo "============================================================"
