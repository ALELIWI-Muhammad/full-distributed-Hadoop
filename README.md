# Full Distributed Hadoop Cluster — Sécurisé par Kerberos

Cluster Apache Hadoop 3.3.6 entièrement distribué sur Docker avec authentification **Kerberos (MIT KDC)**.  
1 KDC + 1 NameNode + 2 DataNodes.

> **Changement majeur** : SSH inter-nœuds supprimé. L'authentification est assurée exclusivement par Kerberos.  
> Les services Hadoop démarrent directement via keytabs sans nécessiter de connexion SSH.

---

## Architecture

```
┌──────────────────────────────────────────────────────────┐
│                  Docker Network: hadoop                   │
│                                                          │
│  ┌─────────┐   ┌──────────┐  ┌──────────┐  ┌─────────┐ │
│  │   kdc   │   │ namenode │  │datanode1 │  │datanode2│ │
│  │         │   │          │  │          │  │         │ │
│  │ MIT KDC │◄──│ HDFS NN  │  │ HDFS DN  │  │ HDFS DN │ │
│  │ kadmind │   │ YARN RM  │  │ YARN NM  │  │ YARN NM │ │
│  └─────────┘   └──────────┘  └──────────┘  └─────────┘ │
│  port: 88,749  ports: 9870                               │
│                        8088                              │
└──────────────────────────────────────────────────────────┘
```

| Conteneur  | Rôle                                      |
|------------|-------------------------------------------|
| kdc        | KDC Kerberos (MIT) + kadmind              |
| namenode   | NameNode HDFS + ResourceManager YARN      |
| datanode1  | DataNode HDFS + NodeManager YARN          |
| datanode2  | DataNode HDFS + NodeManager YARN          |

---

## Structure du projet

```
full-distributed-hadoop/
├── dockerfile                    # Image Hadoop (sans SSH, avec krb5-user)
├── dockerfile.kdc                # Image KDC Kerberos (MIT)
├── docker-compose.yaml           # Cluster: KDC + 1 NN + 2 DN
├── start.sh                      # Entrypoint: attend KDC, installe keytab, démarre services
├── lancer-cluster.sh             # Script de démarrage complet
│
├── config-hadoop/
│   ├── core-site.xml             # HDFS URI + config Kerberos globale
│   ├── hdfs-site.xml             # Réplication + principals/keytabs HDFS
│   ├── mapred-site.xml           # MapReduce sur YARN
│   └── yarn-site.xml             # YARN + principals/keytabs YARN
│
├── config-kerberos/
│   ├── krb5.conf                 # Config client Kerberos (realm, KDC)
│   ├── kdc.conf                  # Config serveur KDC
│   ├── kadm5.acl                 # ACL d'administration Kerberos
│   └── init-kdc.sh               # Initialise la DB, crée les principals, génère les keytabs
│
└── tp-scripts/
    ├── 01-creer-ticket-kerberos.sh       # Exercice 1 & 2: principal + ticket
    ├── 02-acces-hdfs-kerberos.sh         # Exercice 3: accès HDFS sécurisé
    ├── 03-test-sans-authentification.sh  # Exercice 4: accès refusé sans ticket
    └── 04-test-wordcount-kerberos.sh     # Test WordCount MapReduce sécurisé
```

---

## Prérequis

- Docker Desktop installé et en cours d'exécution
- Image de base `hadoop-preinstall:latest` disponible localement

---

## Démarrage rapide

```bash
# Construire et démarrer le cluster complet
docker-compose build
docker-compose up -d

# Ou utiliser le script tout-en-un
bash lancer-cluster.sh
```

### Vérifier l'état du cluster

```bash
# État des conteneurs
docker-compose ps

# Rapport HDFS (authentifié par keytab)
docker exec namenode bash -c "hdfs dfsadmin -report"

# Vérifier les principals Kerberos dans le KDC
docker exec kdc kadmin.local -q "listprincs"
```

### Interfaces Web

| Interface              | URL                       |
|------------------------|---------------------------|
| HDFS NameNode          | http://localhost:9870     |
| YARN ResourceManager   | http://localhost:8088     |

---

## TP Sécurité et Kerberos

### Exercice 1 — Configurer l'authentification Kerberos

La configuration Kerberos est déjà intégrée dans le cluster. Pour l'examiner :

```bash
# Voir la configuration Kerberos côté client
docker exec namenode cat /etc/krb5.conf

# Voir la configuration du KDC
docker exec kdc cat /etc/krb5kdc/kdc.conf

# Voir les principals créés automatiquement
docker exec kdc kadmin.local -q "listprincs"
```

Principals créés au démarrage :
- `hdfs/namenode@HADOOP.LOCAL` — service NameNode
- `hdfs/datanode1@HADOOP.LOCAL` — service DataNode 1
- `hdfs/datanode2@HADOOP.LOCAL` — service DataNode 2
- `yarn/namenode@HADOOP.LOCAL` — ResourceManager
- `HTTP/namenode@HADOOP.LOCAL` — interface web
- `hadoop@HADOOP.LOCAL` — utilisateur (mot de passe: `hadoop`)

---

### Exercice 2 — Créer un principal et obtenir un ticket

```bash
# Entrer dans le NameNode
docker exec -it namenode bash

# Obtenir un ticket Kerberos (mot de passe: hadoop)
kinit hadoop@HADOOP.LOCAL

# Vérifier le ticket
klist
```

Ou via le script TP :

```bash
docker exec -it namenode bash /tp-scripts/01-creer-ticket-kerberos.sh
```

Sortie attendue :
```
Ticket cache: FILE:/tmp/krb5cc_1000
Default principal: hadoop@HADOOP.LOCAL

Valid starting       Expires              Service principal
05/12/2026 10:00:00  05/13/2026 10:00:00  krbtgt/HADOOP.LOCAL@HADOOP.LOCAL
```

---

### Exercice 3 — Accéder à HDFS avec le ticket

```bash
docker exec -it namenode bash /tp-scripts/02-acces-hdfs-kerberos.sh
```

Ce script :
1. Vérifie le ticket Kerberos actif
2. Liste la racine HDFS
3. Crée un répertoire `/user/hadoop`
4. Uploade un fichier de test
5. Lit le fichier depuis HDFS
6. Affiche le rapport du cluster

Ou manuellement :

```bash
docker exec -it namenode bash

# Avec ticket valide
kinit hadoop@HADOOP.LOCAL   # mot de passe: hadoop
hdfs dfs -ls /
hdfs dfs -mkdir -p /user/hadoop/input
echo "test kerberos" | hdfs dfs -put - /user/hadoop/input/test.txt
hdfs dfs -cat /user/hadoop/input/test.txt
```

---

### Exercice 4 — Vérifier que l'accès est refusé sans authentification

```bash
docker exec -it namenode bash /tp-scripts/03-test-sans-authentification.sh
```

Ce script :
1. Détruit le ticket avec `kdestroy`
2. Tente `hdfs dfs -ls /` → **doit échouer**
3. Tente une écriture → **doit échouer**
4. Tente avec un faux utilisateur → **doit échouer**

Ou manuellement :

```bash
docker exec -it namenode bash

# Détruire le ticket
kdestroy

# Tenter l'accès — doit retourner une erreur d'authentification
hdfs dfs -ls /
# Erreur attendue: GSS initiate failed / No valid credentials
```

---

## Test du cluster — WordCount MapReduce

Test standard MapReduce avec authentification Kerberos.

### Via le script TP

```bash
docker exec -it namenode bash /tp-scripts/04-test-wordcount-kerberos.sh
```

### Manuellement

#### 1. Entrer dans le NameNode

```bash
docker exec -it namenode bash
```

#### 2. S'authentifier avec Kerberos

```bash
kinit hadoop@HADOOP.LOCAL
# Mot de passe: hadoop
klist
```

#### 3. Créer les données d'entrée et les uploader dans HDFS

```bash
# Créer un fichier texte local
echo "hello world hello hadoop world hadoop hadoop" > /tmp/input.txt

# Créer le répertoire d'entrée sur HDFS
hdfs dfs -mkdir -p /user/hadoop/input

# Uploader le fichier
hdfs dfs -put /tmp/input.txt /user/hadoop/input/
```

#### 4. Lancer le job WordCount

```bash
hadoop jar $HADOOP_HOME/share/hadoop/mapreduce/hadoop-mapreduce-examples-3.3.6.jar \
    wordcount /user/hadoop/input /user/hadoop/output
```

#### 5. Lire les résultats

```bash
hdfs dfs -cat /user/hadoop/output/part-r-00000
```

Résultat attendu :
```
hadoop  3
hello   2
world   2
```

#### 6. Nettoyer (pour relancer)

```bash
hdfs dfs -rm -r /user/hadoop/output
```

---

## Arrêter le cluster

```bash
docker-compose down

# Avec suppression des volumes (repart de zéro)
docker-compose down -v
```

---

## Explication des fichiers

### `dockerfile`
Image Hadoop sans SSH. Installe `krb5-user` et `krb5-config` pour l'authentification Kerberos.  
Les variables `HADOOP_OPTS` incluent le chemin vers `krb5.conf`.

### `dockerfile.kdc`
Image KDC MIT Kerberos. Installe `krb5-kdc` et `krb5-admin-server`.  
Le script `init-kdc.sh` initialise la base de données, crée tous les principals et génère les keytabs.

### `docker-compose.yaml`
- Le KDC démarre en premier avec un healthcheck sur le port 88
- Les nœuds Hadoop attendent que le KDC soit `healthy` avant de démarrer
- Les keytabs sont partagés via un volume Docker (`keytabs`)

### `start.sh`
Sans SSH. Séquence de démarrage :
1. Attend que le KDC soit accessible (port 88)
2. Copie le keytab approprié depuis le volume partagé
3. S'authentifie avec `kinit -kt`
4. Démarre les services Hadoop directement (`hdfs namenode`, `yarn resourcemanager`, etc.)

### `config-hadoop/core-site.xml`
Active `hadoop.security.authentication=kerberos` et définit les règles `auth_to_local` pour mapper les principals Kerberos vers les utilisateurs Unix.

### `config-hadoop/hdfs-site.xml`
Configure les principals et keytabs pour NameNode et DataNodes.  
Active `dfs.block.access.token.enable=true` (obligatoire avec Kerberos).

### `config-hadoop/yarn-site.xml`
Configure les principals et keytabs pour ResourceManager et NodeManagers.

### `config-kerberos/krb5.conf`
Configuration client Kerberos : realm `HADOOP.LOCAL`, KDC sur `kdc:88`.

### `config-kerberos/init-kdc.sh`
Initialise le KDC, crée les principals de service et utilisateur, génère les keytabs dans `/keytabs/`.
