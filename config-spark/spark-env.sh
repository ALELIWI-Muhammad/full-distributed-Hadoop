#!/usr/bin/env bash
# ── Spark environment ──────────────────────────────────────────────────────────

export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
export HADOOP_HOME=/opt/hadoop
export HADOOP_CONF_DIR=$HADOOP_HOME/etc/hadoop
export SPARK_HOME=/opt/spark

# Tell Spark where to find YARN
export YARN_CONF_DIR=$HADOOP_CONF_DIR

# Python binary for PySpark (optional)
export PYSPARK_PYTHON=python3
