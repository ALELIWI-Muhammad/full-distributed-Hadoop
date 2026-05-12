#!/bin/bash
# ============================================================
# Script de lancement du cluster Hadoop sécurisé par Kerberos
# ============================================================

set -e

echo "============================================================"
echo "  Lancement du cluster Hadoop avec Kerberos"
echo "============================================================"
echo ""

# Nettoyer les conteneurs existants
echo ">>> Nettoyage des conteneurs existants..."
docker-compose down -v 2>/dev/null || true
echo ""

# Construire les images
echo ">>> Construction des images Docker..."
docker-compose build
echo ""

# Démarrer le cluster
echo ">>> Démarrage du cluster..."
docker-compose up -d
echo ""

# Attendre que les services soient prêts
echo ">>> Attente du démarrage des services..."
echo "  - KDC (Kerberos)..."
sleep 5

echo "  - NameNode..."
sleep 10

echo "  - DataNodes..."
sleep 5

echo ""
echo ">>> Vérification de l'état du cluster..."
docker-compose ps
echo ""

# Vérifier le KDC
echo ">>> Vérification du KDC Kerberos..."
docker exec kdc klist -k /keytabs/hadoop.keytab 2>/dev/null && echo "  ✓ KDC opérationnel" || echo "  ✗ Problème KDC"
echo ""

# Vérifier HDFS
echo ">>> Vérification du cluster HDFS..."
docker exec namenode bash -c "echo 'hadoop' | kinit hadoop@HADOOP.LOCAL && hdfs dfsadmin -report" | head -20
echo ""

echo "============================================================"
echo "  Cluster Hadoop démarré avec succès!"
echo ""
echo "  Interfaces Web:"
echo "    HDFS NameNode:  http://localhost:9870"
echo "    YARN ResourceManager: http://localhost:8088"
echo ""
echo "  Pour exécuter les exercices TP:"
echo "    docker exec -it namenode bash"
echo "    cd /tp-scripts"
echo "    bash 01-creer-ticket-kerberos.sh"
echo "    bash 02-acces-hdfs-kerberos.sh"
echo "    bash 03-test-sans-authentification.sh"
echo "    bash 04-test-wordcount-kerberos.sh"
echo "============================================================"
