# Full Distributed Hadoop Cluster with Hive

A fully distributed Apache Hadoop 3.3.6 cluster running on Docker with 1 NameNode, 2 DataNodes, and Apache Hive 4.0.0 (Metastore + HiveServer2) backed by PostgreSQL.

## Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                      Docker Network: hadoop                      │
│                                                                  │
│  ┌──────────┐   ┌──────────┐  ┌──────────┐                      │
│  │ namenode │   │datanode1 │  │datanode2 │                      │
│  │ HDFS NN  │   │ HDFS DN  │  │ HDFS DN  │                      │
│  │ YARN RM  │   │ YARN NM  │  │ YARN NM  │                      │
│  └──────────┘   └──────────┘  └──────────┘                      │
│                                                                  │
│  ┌──────────┐   ┌───────────────┐   ┌─────────────────────┐     │
│  │ postgres │──▶│   metastore   │──▶│    hiveserver2      │     │
│  │ (PG 15)  │   │ Hive 4.0.0   │   │    Hive 4.0.0       │     │
│  │          │   │ port: 9083    │   │ port: 10000 (JDBC)  │     │
│  └──────────┘   └───────────────┘   │ port: 10002 (Web UI)│     │
│                                     └─────────────────────┘     │
└──────────────────────────────────────────────────────────────────┘
```

| Container    | Role                                        |
|--------------|---------------------------------------------|
| namenode     | HDFS NameNode + YARN ResourceManager        |
| datanode1    | HDFS DataNode + YARN NodeManager            |
| datanode2    | HDFS DataNode + YARN NodeManager            |
| postgres     | PostgreSQL 15 — Hive Metastore backend      |
| metastore    | Hive Standalone Metastore (Thrift :9083)    |
| hiveserver2  | HiveServer2 (JDBC :10000, Web UI :10002)    |

---

## Project Structure

```
full-distributed-hadoop/
├── Dockerfile                   # Image for Hadoop nodes (namenode/datanodes)
├── Dockerfile.hive              # Image for Hive containers (adds PostgreSQL JDBC driver)
├── docker-compose.yaml          # Full cluster topology
├── start.sh                     # Entrypoint: detects role and starts Hadoop services
├── postgresql.jar               # PostgreSQL JDBC driver (not committed — see .gitignore)
├── .gitignore
├── config-hadoop/
│   ├── core-site.xml            # HDFS default filesystem
│   ├── hdfs-site.xml            # Replication factor, data/name dirs
│   ├── mapred-site.xml          # MapReduce framework + classpath
│   └── yarn-site.xml            # YARN services + env whitelist
└── config-hive/
    ├── hive-site.xml            # Hive config: HDFS, metastore URI, PostgreSQL, HS2
    └── log4j2.properties        # Logging config for Hive containers
```

---

## Prerequisites

- Docker Desktop installed and running
- Base image `hadoop-preinstall:latest` available locally
- Internet access to pull `apache/hive:4.0.0` and `postgres:15` from Docker Hub

---

## First-Time Setup

### 1. Download the PostgreSQL JDBC driver

The `apache/hive:4.0.0` image does not bundle the PostgreSQL driver. Download it once to the project root:

```bash
# PowerShell
Invoke-WebRequest -Uri "https://repo1.maven.org/maven2/org/postgresql/postgresql/42.7.3/postgresql-42.7.3.jar" -OutFile "postgresql.jar"

# or curl (Linux/Mac)
curl -O https://repo1.maven.org/maven2/org/postgresql/postgresql/42.7.3/postgresql-42.7.3.jar -o postgresql.jar
```

### 2. Build and start the cluster

```bash
docker compose build
docker compose up -d
```

Startup order is managed automatically via healthchecks:
`postgres` (healthy) → `metastore` (healthy, ~60s) → `hiveserver2`

### 3. Create HDFS directories for Hive

Run these once after the namenode is up (from inside the namenode container to avoid path issues on Windows):

```bash
docker exec -it namenode bash
```

Then inside:

```bash
hdfs dfs -mkdir -p /user/hive/warehouse
hdfs dfs -mkdir -p /tmp/hive
hdfs dfs -chmod -R 777 /user/hive
hdfs dfs -chmod -R 777 /tmp/hive
hdfs dfs -chown -R hive /user/hive
exit
```

---

## Web UIs

| UI                        | URL                        |
|---------------------------|----------------------------|
| HDFS NameNode             | http://localhost:9870      |
| YARN ResourceManager      | http://localhost:8088      |
| HiveServer2               | http://localhost:10002     |

---

## Connecting to Hive

### Beeline (inside the container)

```bash
docker exec -it hiveserver2 beeline -u 'jdbc:hive2://hiveserver2:10000/'
```

### Basic HiveQL commands

```sql
SHOW DATABASES;
CREATE DATABASE test;
USE test;
CREATE TABLE employees (id INT, name STRING, salary DOUBLE)
    ROW FORMAT DELIMITED FIELDS TERMINATED BY ',';
SHOW TABLES;
!quit
```

---

## Testing the Cluster — WordCount (MapReduce)

### 1. Enter the NameNode

```bash
docker exec -it namenode bash
```

### 2. Create input data and upload to HDFS

```bash
echo "hello world hello hadoop world hadoop hadoop" > /tmp/input.txt
hdfs dfs -mkdir -p /user/hadoop/input
hdfs dfs -put /tmp/input.txt /user/hadoop/input/
```

### 3. Run the WordCount job

```bash
hadoop jar $HADOOP_HOME/share/hadoop/mapreduce/hadoop-mapreduce-examples-3.3.6.jar \
    wordcount /user/hadoop/input /user/hadoop/output
```

### 4. Read the results

```bash
hdfs dfs -cat /user/hadoop/output/part-r-00000
```

Expected output:
```
hadoop  3
hello   2
world   2
```

### 5. Clean up

```bash
hdfs dfs -rm -r /user/hadoop/output
```

---

## Stopping the Cluster

```bash
# Stop containers (preserves volumes)
docker compose down

# Stop and remove all data volumes (full reset)
docker compose down -v
```
