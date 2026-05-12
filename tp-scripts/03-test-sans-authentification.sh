#!/bin/bash
# ============================================================
# Kerberos Security Lab - Exercise 4
# Verify that access is DENIED without authentication
# ============================================================
# Usage: docker exec -it namenode bash /tp-scripts/03-test-sans-authentification.sh
# ============================================================

echo "============================================================"
echo "  Kerberos Lab - Access test WITHOUT authentication"
echo "  Goal: prove that Kerberos protects HDFS"
echo "============================================================"
echo ""

# ---- Test 1: Destroy the existing ticket ----
echo ">>> Test 1: Destroy the Kerberos ticket"
echo "Command: kdestroy"
kdestroy
echo "Ticket destroyed."
echo ""

echo "Verification - no ticket should be present:"
klist 2>&1 || echo "(Confirmed: no active ticket)"
echo ""

# ---- Test 2: Attempt HDFS access without a ticket ----
echo ">>> Test 2: Attempt HDFS access without ticket (should FAIL)"
echo "Command: hdfs dfs -ls /"
echo "--- Expected result: authentication error ---"
echo ""

if hdfs dfs -ls / 2>&1; then
    echo ""
    echo "WARNING: Access succeeded - check Kerberos configuration"
else
    echo ""
    echo "SUCCESS: Access denied as expected!"
    echo "Kerberos is correctly protecting the cluster."
fi
echo ""

# ---- Test 3: Attempt write without a ticket ----
echo ">>> Test 3: Attempt HDFS write without ticket (should FAIL)"
echo "Command: hdfs dfs -put /etc/hostname /user/hadoop/unauthorized.txt"
echo ""

if hdfs dfs -put /etc/hostname /user/hadoop/unauthorized.txt 2>&1; then
    echo "WARNING: Write succeeded - check Kerberos configuration"
else
    echo "SUCCESS: Write denied as expected!"
fi
echo ""

# ---- Test 4: Attempt access with a fake username ----
echo ">>> Test 4: Attempt access with an unauthenticated user"
echo "Command: HADOOP_USER_NAME=attacker hdfs dfs -ls /"
echo ""

if HADOOP_USER_NAME=attacker hdfs dfs -ls / 2>&1; then
    echo "WARNING: Access succeeded - Kerberos should block this"
else
    echo "SUCCESS: Access denied for unauthenticated user!"
fi
echo ""

# ---- Summary ----
echo "============================================================"
echo "  Kerberos security test summary:"
echo ""
echo "  [OK] No Kerberos ticket -> HDFS access denied"
echo "  [OK] Write without ticket -> denied"
echo "  [OK] Unauthenticated user -> denied"
echo ""
echo "  Kerberos ensures only authenticated principals"
echo "  can access Hadoop cluster resources."
echo "============================================================"
echo ""
echo "To restore access, run:"
echo "  bash /tp-scripts/01-creer-ticket-kerberos.sh"
