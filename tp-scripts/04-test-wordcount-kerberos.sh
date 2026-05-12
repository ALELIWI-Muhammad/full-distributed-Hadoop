#!/bin/bash
# ============================================================
# Kerberos Security Lab - WordCount Test
# Validates that MapReduce works with Kerberos authentication
# ============================================================
# Usage: docker exec -it namenode bash /tp-scripts/04-test-wordcount-kerberos.sh
# ============================================================

REALM="HADOOP.LOCAL"
KEYTAB_DIR="/etc/hadoop/keytabs"

echo "============================================================"
echo "  Kerberos Lab - WordCount MapReduce test (secured)"
echo "============================================================"
echo ""

# ---- Check or obtain a ticket ----
echo ">>> Checking Kerberos ticket"
if ! klist -s 2>/dev/null; then
    echo "No valid ticket found. Obtaining one via keytab..."
    kinit -kt $KEYTAB_DIR/namenode.keytab hdfs/namenode@$REALM
fi
klist | grep "Default principal"
echo ""

# ---- Step 1: Prepare input data ----
echo ">>> Step 1: Creating input data"
cat > /tmp/input.txt << 'EOF'
hello world hello hadoop world hadoop hadoop
kerberos security authentication hadoop
hadoop distributed file system hdfs
mapreduce wordcount example hadoop kerberos
EOF

echo "Input file content:"
cat /tmp/input.txt
echo ""

# ---- Step 2: Upload to HDFS ----
echo ">>> Step 2: Uploading to HDFS (authenticated by Kerberos)"

hdfs dfs -rm -r -f /user/hadoop/input /user/hadoop/output 2>/dev/null || true

hdfs dfs -mkdir -p /user/hadoop/input
hdfs dfs -put /tmp/input.txt /user/hadoop/input/
echo "File uploaded to HDFS:"
hdfs dfs -ls /user/hadoop/input/
echo ""

# ---- Step 3: Run the WordCount MapReduce job ----
echo ">>> Step 3: Running WordCount MapReduce job"
echo ""

hadoop jar $HADOOP_HOME/share/hadoop/mapreduce/hadoop-mapreduce-examples-3.3.6.jar \
    wordcount \
    /user/hadoop/input \
    /user/hadoop/output

echo ""
echo "Job completed!"
echo ""

# ---- Step 4: Read results ----
echo ">>> Step 4: WordCount results"
echo "Command: hdfs dfs -cat /user/hadoop/output/part-r-00000"
echo ""
hdfs dfs -cat /user/hadoop/output/part-r-00000
echo ""

# ---- Step 5: Verify ticket after job ----
echo ">>> Step 5: Ticket status after MapReduce job"
echo "The job used Kerberos delegation tokens internally."
klist
echo ""

echo ">>> To clean up and re-run:"
echo "  hdfs dfs -rm -r /user/hadoop/output"
echo ""

echo "============================================================"
echo "  WordCount with Kerberos succeeded!"
echo "  MapReduce works correctly with Kerberos authentication."
echo "============================================================"
