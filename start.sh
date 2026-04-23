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

    # Provision HDFS user directories so external clients (e.g. spark container)
    # can write without manual permission fixes after every fresh build.
    echo "Provisioning HDFS user directories..."
    hdfs dfs -mkdir -p /user/hadoop
    hdfs dfs -chown hadoop:hadoop /user/hadoop

    hdfs dfs -mkdir -p /user/spark
    hdfs dfs -chown spark:spark /user/spark

    echo "HDFS user directories ready."

    tail -f /dev/null

else
    echo "Starting DataNode..."
    hdfs datanode &
    yarn nodemanager &

    tail -f /dev/null
fi