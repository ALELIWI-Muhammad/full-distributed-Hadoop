#!/bin/bash
# ============================================================
# Kerberos Security Lab - Exercise 1 & 2
# Create a user principal and obtain a Kerberos ticket
# ============================================================
# Usage: run from inside the NameNode container
#   docker exec -it namenode bash /tp-scripts/01-creer-ticket-kerberos.sh
# ============================================================

REALM="HADOOP.LOCAL"
HADOOP_KEYTAB="/keytabs/hadoop.keytab"

echo "============================================================"
echo "  Kerberos Lab - Create principal and obtain ticket"
echo "  Realm: $REALM"
echo "============================================================"
echo ""

# ---- Step 1: Show Kerberos configuration ----
echo ">>> Step 1: Kerberos client configuration (/etc/krb5.conf)"
cat /etc/krb5.conf
echo ""

# ---- Step 2: List existing principals via kadmin ----
echo ">>> Step 2: Principals registered in the KDC"
kadmin -p admin/admin@$REALM -w admin -q "listprincs" 2>/dev/null \
    || echo "(Remote kadmin unavailable - verify KDC is reachable on port 749)"
echo ""

# ---- Step 3: Obtain a Kerberos ticket ----
# Method A: use the hadoop.keytab (non-interactive, always works in Docker)
# Method B: interactive kinit with password (shown for reference)
echo ">>> Step 3: Obtaining a Kerberos ticket for hadoop@$REALM"
echo ""
echo "Method used: kinit with keytab (non-interactive)"
echo "Command: kinit -kt $HADOOP_KEYTAB hadoop@$REALM"
echo ""

# Destroy any existing ticket first for a clean demo
kdestroy 2>/dev/null || true

kinit -kt $HADOOP_KEYTAB hadoop@$REALM

echo "Ticket obtained successfully!"
echo ""

# ---- Step 4: Display ticket details ----
echo ">>> Step 4: Ticket details"
echo "Command: klist"
echo ""
klist
echo ""

# ---- Step 5: Explain ticket fields ----
echo ">>> Step 5: Ticket field explanation"
echo ""
echo "  Ticket cache      : file storing the TGT on disk"
echo "  Default principal : authenticated identity (hadoop@HADOOP.LOCAL)"
echo "  Valid starting    : ticket issue time"
echo "  Expires           : ticket expiry time (24h by default)"
echo "  Renew until       : maximum renewal window (7 days)"
echo "  Service principal : krbtgt/HADOOP.LOCAL = Ticket Granting Ticket (TGT)"
echo ""
echo "Note: interactive kinit with password also works:"
echo "  kinit hadoop@$REALM   (password: hadoop)"
echo ""

echo "============================================================"
echo "  Kerberos ticket created successfully!"
echo "  You can now access HDFS securely."
echo "  Next: run 02-acces-hdfs-kerberos.sh"
echo "============================================================"
