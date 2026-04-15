#!/bin/bash

# Démarrer SSH
sudo /etc/init.d/ssh start

# Détecter rôle
if [ "$HOSTNAME" == "namenode" ]; then
    echo "Formatting HDFS..."
    $HADOOP_HOME/bin/hdfs namenode -format -force

    echo "Starting HDFS..."
    start-dfs.sh

    echo "Starting YARN..."
    start-yarn.sh

    tail -f /dev/null

else
    echo "Starting DataNode..."
    hdfs datanode &
    yarn nodemanager &

    tail -f /dev/null
fi