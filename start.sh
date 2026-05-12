#!/bin/bash
# Hadoop node startup script with Kerberos authentication.
# Runs as root to fix volume permissions, then starts services.
# - NameNode/YARN : switches to hadoop user via exec su
# - DataNode      : uses jsvc (binds ports < 1024 as root, then drops to hadoop)

set -e

REALM="HADOOP.LOCAL"
KEYTAB_DIR="/etc/hadoop/keytabs"
HADOOP_HOME="/opt/hadoop"
JAVA_HOME="/usr/lib/jvm/java-11-openjdk-amd64"

echo "============================================"
echo "  Starting node: $HOSTNAME"
echo "  Authentication: Kerberos ($REALM)"
echo "============================================"

# ---- Step 1: Fix volume directory permissions (requires root) ----
echo "Preparing data directories..."
if [ "$HOSTNAME" == "namenode" ]; then
    mkdir -p /home/hadoop/hdfs/namenode
else
    mkdir -p /home/hadoop/hdfs/datanode
fi
chown -R hadoop:hadoop /home/hadoop/hdfs

# ---- Step 2: Wait for KDC to be available ----
echo "Waiting for KDC (kdc:88)..."
attempt=0
while ! nc -z kdc 88 2>/dev/null; do
    attempt=$((attempt + 1))
    if [ $attempt -ge 30 ]; then
        echo "ERROR: KDC not available after 30 attempts"
        exit 1
    fi
    echo "  KDC not ready yet (attempt $attempt/30)..."
    sleep 3
done
echo "KDC is available!"

# ---- Step 3: Install the keytab ----
echo "Installing keytab..."
if [ "$HOSTNAME" == "namenode" ]; then
    cp /keytabs/namenode.keytab $KEYTAB_DIR/namenode.keytab
    chown hadoop:hadoop $KEYTAB_DIR/namenode.keytab
    chmod 400 $KEYTAB_DIR/namenode.keytab
    echo "Namenode keytab installed."
else
    cp /keytabs/${HOSTNAME}.keytab $KEYTAB_DIR/datanode.keytab
    # root:hadoop ownership so jsvc (root) and hadoop user can both read it
    chown root:hadoop $KEYTAB_DIR/datanode.keytab
    chmod 440 $KEYTAB_DIR/datanode.keytab
    echo "Keytab for $HOSTNAME installed."
fi

# ============================================
# Start services based on node role
# ============================================

if [ "$HOSTNAME" == "namenode" ]; then
    echo ""
    echo "--- Role: NameNode + ResourceManager ---"

    exec su -s /bin/bash hadoop -c "
        export HADOOP_HOME=$HADOOP_HOME
        export JAVA_HOME=$JAVA_HOME
        export PATH=\$PATH:\$HADOOP_HOME/bin:\$HADOOP_HOME/sbin
        export KRB5_CONFIG=/etc/krb5.conf
        export HADOOP_OPTS=\"-Djava.security.krb5.conf=/etc/krb5.conf -Dsun.security.krb5.disableReferrals=true\"

        echo 'Kerberos login: hdfs/namenode@$REALM'
        kinit -kt $KEYTAB_DIR/namenode.keytab hdfs/namenode@$REALM
        echo 'Ticket obtained:'
        klist

        if [ ! -d /home/hadoop/hdfs/namenode/current ]; then
            echo 'Formatting HDFS NameNode...'
            hdfs namenode -format -force
        else
            echo 'NameNode already formatted, skipping format.'
        fi

        echo 'Starting HDFS NameNode...'
        hdfs namenode &
        NAMENODE_PID=\$!

        sleep 10

        echo 'Starting YARN ResourceManager...'
        yarn resourcemanager &

        echo ''
        echo '============================================'
        echo '  NameNode + ResourceManager started!'
        echo '  HDFS UI:  http://localhost:9870'
        echo '  YARN UI:  http://localhost:8088'
        echo '============================================'

        wait \$NAMENODE_PID
    "

else
    echo ""
    echo "--- Role: DataNode + NodeManager ($HOSTNAME) ---"

    # Wait for NameNode RPC port
    echo "Waiting for NameNode (namenode:9000)..."
    attempt=0
    while ! nc -z namenode 9000 2>/dev/null; do
        attempt=$((attempt + 1))
        if [ $attempt -ge 20 ]; then
            echo "ERROR: NameNode not available after 20 attempts"
            exit 1
        fi
        echo "  NameNode not ready yet (attempt $attempt/20)..."
        sleep 5
    done
    echo "NameNode is available!"

    # Start DataNode and NodeManager as hadoop user.
    # ignore.secure.ports.for.testing=true in hdfs-site.xml allows running
    # the DataNode on non-privileged ports without jsvc in Docker.
    exec su -s /bin/bash hadoop -c "
        export HADOOP_HOME=$HADOOP_HOME
        export JAVA_HOME=$JAVA_HOME
        export PATH=\$PATH:\$HADOOP_HOME/bin:\$HADOOP_HOME/sbin
        export KRB5_CONFIG=/etc/krb5.conf
        export HADOOP_OPTS=\"-Djava.security.krb5.conf=/etc/krb5.conf -Dsun.security.krb5.disableReferrals=true\"

        echo 'Kerberos login: hdfs/${HOSTNAME}@$REALM'
        kinit -kt $KEYTAB_DIR/datanode.keytab hdfs/${HOSTNAME}@$REALM
        echo 'Ticket obtained:'
        klist

        echo 'Starting HDFS DataNode...'
        hdfs datanode &
        DN_PID=\$!

        sleep 5

        echo 'Starting YARN NodeManager...'
        yarn nodemanager &

        echo 'DataNode $HOSTNAME is running.'
        wait \$DN_PID
    "
fi
