# Full Distributed Hadoop Cluster

A fully distributed Apache Hadoop 3.3.6 cluster running on Docker with 1 NameNode and 2 DataNodes.

## Architecture

```
┌─────────────────────────────────────────────┐
│              Docker Network: hadoop          │
│                                             │
│  ┌──────────┐   ┌──────────┐  ┌──────────┐ │
│  │ namenode │   │datanode1 │  │datanode2 │ │
│  │          │   │          │  │          │ │
│  │ HDFS NN  │   │ HDFS DN  │  │ HDFS DN  │ │
│  │ YARN RM  │   │ YARN NM  │  │ YARN NM  │ │
│  └──────────┘   └──────────┘  └──────────┘ │
│  ports: 9870                                │
│          8088                               │
└─────────────────────────────────────────────┘
```

| Node      | Role                              |
|-----------|-----------------------------------|
| namenode  | NameNode + ResourceManager        |
| datanode1 | DataNode + NodeManager            |
| datanode2 | DataNode + NodeManager            |

---

## Project Structure

```
full-distributed-hadoop/
├── Dockerfile                   # Image definition for all nodes
├── docker-compose.yaml          # Cluster topology (1 NN + 2 DN)
├── start.sh                     # Entrypoint: detects role and starts services
└── config-hadoop/
    ├── core-site.xml            # HDFS default filesystem
    ├── hdfs-site.xml            # Replication factor, data/name dirs
    ├── mapred-site.xml          # MapReduce framework + classpath
    └── yarn-site.xml            # YARN services + env whitelist
```

---

## File Explanations

### `Dockerfile`
Builds a single image used by all nodes. Key steps:
- Installs OpenSSH, curl, net-tools, sudo
- Extracts Hadoop 3.3.6 to `/opt/hadoop`
- Creates a `hadoop` user with passwordless sudo for SSH
- Generates SSH keys and sets up passwordless SSH
- Exports `JAVA_HOME`, `HADOOP_HOME` into `hadoop-env.sh` and `.bashrc` so SSH sessions can find Java (required by `start-dfs.sh` / `start-yarn.sh`)

### `docker-compose.yaml`
Defines the 3-node cluster on a shared `hadoop` Docker network:
- `namenode` — exposes port `9870` (HDFS UI) and `8088` (YARN UI)
- `datanode1`, `datanode2` — no exposed ports, internal only

### `start.sh`
Entrypoint script that detects the container role via `$HOSTNAME`:
- **namenode**: formats HDFS, starts `start-dfs.sh` and `start-yarn.sh`
- **datanode**: starts `hdfs datanode` and `yarn nodemanager` directly

### `config-hadoop/core-site.xml`
Sets the default HDFS URI:
```xml
<property>
  <name>fs.defaultFS</name>
  <value>hdfs://namenode:9000</value>
</property>
```

### `config-hadoop/hdfs-site.xml`
- Replication factor: `2` (data is replicated on both datanodes)
- NameNode metadata dir: `/home/hadoop/hdfs/namenode`
- DataNode data dir: `/home/hadoop/hdfs/datanode`

### `config-hadoop/mapred-site.xml`
- Sets MapReduce to run on YARN (`mapreduce.framework.name=yarn`)
- Injects `HADOOP_MAPRED_HOME` into AM, Map, and Reduce container environments so YARN containers can find the MapReduce JARs
- Sets `mapreduce.application.classpath` explicitly for container classpath resolution

### `config-hadoop/yarn-site.xml`
- Enables `mapreduce_shuffle` auxiliary service (required for MapReduce)
- Whitelists environment variables (`JAVA_HOME`, `HADOOP_MAPRED_HOME`, etc.) that NodeManager propagates to containers

---

## Getting Started

### Prerequisites
- Docker Desktop installed and running
- Base image `hadoop-preinstall:latest` available locally

### Build and Start

```bash
docker-compose build
docker-compose up -d
```

### Check Cluster Status

```bash
# Check all containers are running
docker-compose ps

# Check HDFS nodes
docker exec -it namenode bash -c "hdfs dfsadmin -report"
```

### Web UIs

| UI              | URL                      |
|-----------------|--------------------------|
| HDFS NameNode   | http://localhost:9870    |
| YARN ResourceManager | http://localhost:8088 |

---

## Testing the Cluster — WordCount Example

WordCount is the standard MapReduce sample included with Hadoop.

### 1. Enter the NameNode

```bash
docker exec -it namenode bash
```

### 2. Create input data and upload to HDFS

```bash
# Create a local text file
echo "hello world hello hadoop world hadoop hadoop" > /tmp/input.txt

# Create input directory on HDFS
hdfs dfs -mkdir -p /user/hadoop/input

# Upload the file
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

### 5. Clean up (to re-run)

```bash
hdfs dfs -rm -r /user/hadoop/output
```

---

## Stopping the Cluster

```bash
docker-compose down
```
