#!/bin/bash

# Start SSH
service ssh start

# Format only first time
if [ ! -d "/tmp/hadoop/namenode/current" ]; then
    hdfs namenode -format
fi

# Start HDFS
start-dfs.sh

# Start YARN
start-yarn.sh

tail -f /dev/null