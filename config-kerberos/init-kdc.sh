#!/bin/bash
# Kerberos KDC initialization script.
# Creates the database, registers all Hadoop service principals,
# generates keytabs, then starts kadmind and krb5kdc.

set -e

REALM="HADOOP.LOCAL"
KDC_PASSWORD="kdc_master_password_123"

echo "============================================"
echo "  Kerberos KDC initialization"
echo "  Realm: $REALM"
echo "============================================"

mkdir -p /var/lib/krb5kdc
mkdir -p /etc/krb5kdc

# Initialize the Kerberos database (only if it does not exist yet)
# Also recreate if the stash file is missing (can happen after partial volume loss)
if [ ! -f /var/lib/krb5kdc/principal ] || [ ! -f /etc/krb5kdc/.k5.HADOOP.LOCAL ]; then
    echo "Creating Kerberos database..."
    # Remove any partial state before recreating
    rm -f /var/lib/krb5kdc/principal* /etc/krb5kdc/.k5.HADOOP.LOCAL
    echo -e "$KDC_PASSWORD\n$KDC_PASSWORD" | kdb5_util create -r $REALM -s
    echo "Database created."
else
    echo "Kerberos database already exists."
fi

# Create Hadoop service principals (short hostname)
echo "Creating Hadoop service principals..."

kadmin.local -q "addprinc -randkey hdfs/namenode@$REALM"   2>/dev/null || echo "Principal hdfs/namenode already exists"
kadmin.local -q "addprinc -randkey hdfs/datanode1@$REALM"  2>/dev/null || echo "Principal hdfs/datanode1 already exists"
kadmin.local -q "addprinc -randkey hdfs/datanode2@$REALM"  2>/dev/null || echo "Principal hdfs/datanode2 already exists"
kadmin.local -q "addprinc -randkey yarn/namenode@$REALM"   2>/dev/null || echo "Principal yarn/namenode already exists"
kadmin.local -q "addprinc -randkey yarn/datanode1@$REALM"  2>/dev/null || echo "Principal yarn/datanode1 already exists"
kadmin.local -q "addprinc -randkey yarn/datanode2@$REALM"  2>/dev/null || echo "Principal yarn/datanode2 already exists"
kadmin.local -q "addprinc -randkey HTTP/namenode@$REALM"   2>/dev/null || echo "Principal HTTP/namenode already exists"
kadmin.local -q "addprinc -randkey HTTP/datanode1@$REALM"  2>/dev/null || echo "Principal HTTP/datanode1 already exists"
kadmin.local -q "addprinc -randkey HTTP/datanode2@$REALM"  2>/dev/null || echo "Principal HTTP/datanode2 already exists"

# Detect Docker Compose network suffix and create FQDN principals
# Docker Compose appends <project>_<network> to hostnames for internal DNS
# We detect the actual FQDN and register it so keytabs cover both forms
FQDN_SUFFIX=$(hostname -f 2>/dev/null | sed "s/^namenode\.//" || echo "")
if [ -n "$FQDN_SUFFIX" ] && [ "$FQDN_SUFFIX" != "namenode" ]; then
    echo "Detected Docker FQDN suffix: $FQDN_SUFFIX"
    echo "Creating FQDN principals for Kerberos compatibility..."
    kadmin.local -q "addprinc -randkey yarn/namenode.${FQDN_SUFFIX}@$REALM"   2>/dev/null || true
    kadmin.local -q "addprinc -randkey hdfs/namenode.${FQDN_SUFFIX}@$REALM"   2>/dev/null || true
    kadmin.local -q "addprinc -randkey HTTP/namenode.${FQDN_SUFFIX}@$REALM"   2>/dev/null || true
fi

# Create user principals (with password for interactive kinit)
kadmin.local -q "addprinc -pw hadoop hadoop@$REALM"       2>/dev/null || echo "Principal hadoop already exists"
kadmin.local -q "addprinc -pw admin admin/admin@$REALM"   2>/dev/null || echo "Principal admin/admin already exists"

# Generate keytabs for all service principals
echo "Generating keytabs..."
mkdir -p /keytabs

kadmin.local -q "ktadd -k /keytabs/namenode.keytab hdfs/namenode@$REALM HTTP/namenode@$REALM yarn/namenode@$REALM"
kadmin.local -q "ktadd -k /keytabs/datanode1.keytab hdfs/datanode1@$REALM HTTP/datanode1@$REALM yarn/datanode1@$REALM"
kadmin.local -q "ktadd -k /keytabs/datanode2.keytab hdfs/datanode2@$REALM HTTP/datanode2@$REALM yarn/datanode2@$REALM"
kadmin.local -q "ktadd -k /keytabs/hadoop.keytab hadoop@$REALM"

# Add FQDN principals to namenode keytab if they were created
if [ -n "$FQDN_SUFFIX" ] && [ "$FQDN_SUFFIX" != "namenode" ]; then
    kadmin.local -q "ktadd -k /keytabs/namenode.keytab yarn/namenode.${FQDN_SUFFIX}@$REALM hdfs/namenode.${FQDN_SUFFIX}@$REALM HTTP/namenode.${FQDN_SUFFIX}@$REALM" 2>/dev/null || true
fi

chmod 644 /keytabs/*.keytab

echo ""
echo "============================================"
echo "  KDC initialized successfully!"
echo "  Principals created:"
echo "    - hdfs/namenode@$REALM"
echo "    - hdfs/datanode1@$REALM"
echo "    - hdfs/datanode2@$REALM"
echo "    - yarn/namenode@$REALM"
echo "    - yarn/datanode1@$REALM"
echo "    - yarn/datanode2@$REALM"
echo "    - HTTP/namenode@$REALM"
echo "    - hadoop@$REALM  (password: hadoop)"
echo "    - admin/admin@$REALM  (password: admin)"
echo "============================================"

# Start the Kerberos administration server
echo "Starting kadmind..."
kadmind -nofork &

# Start the KDC
echo "Starting krb5kdc..."
exec krb5kdc -n
