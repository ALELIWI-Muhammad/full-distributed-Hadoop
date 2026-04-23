# Full Distributed Hadoop Cluster + Spark on YARN

A fully distributed Apache Hadoop 3.3.6 cluster running on Docker with 1 NameNode, 2 DataNodes, and an isolated Spark 3.5.0 client container that submits jobs to YARN.

## Architecture

```
┌──────────────────────────────────────────────────────────┐
│                  Docker Network: hadoop                   │
│                                                          │
│  ┌──────────┐   ┌──────────┐  ┌──────────┐  ┌───────┐  │
│  │ namenode │   │datanode1 │  │datanode2 │  │ spark │  │
│  │          │   │          │  │          │  │       │  │
│  │ HDFS NN  │   │ HDFS DN  │  │ HDFS DN  │  │Spark  │  │
│  │ YARN RM  │   │ YARN NM  │  │ YARN NM  │  │Client │  │
│  └──────────┘   └──────────┘  └──────────┘  └───────┘  │
│  ports: 9870                                  port:4040  │
│          8088                                            │
└──────────────────────────────────────────────────────────┘
```

| Node      | Role                              |
|-----------|-----------------------------------|
| namenode  | NameNode + ResourceManager        |
| datanode1 | DataNode + NodeManager            |
| datanode2 | DataNode + NodeManager            |
| spark     | Spark client (no Hadoop daemons)  |

---

## Project Structure

```
full-distributed-hadoop/
├── dockerfile                   # Image for Hadoop nodes (NN + DN)
├── Dockerfile.spark             # Image for the isolated Spark client
├── docker-compose.yaml          # Cluster topology (1 NN + 2 DN + Spark)
├── start.sh                     # Entrypoint: detects role and starts services
├── config-hadoop/
│   ├── core-site.xml            # HDFS default filesystem
│   ├── hdfs-site.xml            # Replication factor, data/name dirs
│   ├── mapred-site.xml          # MapReduce framework + classpath
│   └── yarn-site.xml            # YARN services + ResourceManager addresses
└── config-spark/
    ├── spark-defaults.conf      # Default Spark settings (YARN master, memory)
    └── spark-env.sh             # Spark environment (JAVA_HOME, HADOOP_CONF_DIR)
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
- Declares explicit ResourceManager RPC addresses (`namenode:8032/8030/8031`) so the Spark container can reach YARN from outside the Hadoop nodes

---

## Spark Integration

### `Dockerfile.spark`
Builds a dedicated Spark client image (Ubuntu 22.04). Key points:
- Installs JDK 11, Python 3, and the Hadoop client binaries (no daemons)
- Installs Spark 3.5.0 to `/opt/spark`
- Copies `config-hadoop/` so the container can talk to HDFS and YARN
- Copies `config-spark/` for Spark-specific settings
- Runs as a non-root `spark` user

The container is **isolated**: it holds only Spark binaries and a Hadoop client config. All computation runs on the Hadoop cluster via YARN.

### `config-spark/spark-defaults.conf`
- Sets `spark.master=yarn` and `spark.submit.deployMode=client`
- Points `spark.hadoop.fs.defaultFS` to `hdfs://namenode:9000`
- Configures executor memory (512 MB) and 2 executor instances

### `config-spark/spark-env.sh`
Exports `JAVA_HOME`, `HADOOP_HOME`, `HADOOP_CONF_DIR`, and `YARN_CONF_DIR` so Spark can locate the YARN ResourceManager and HDFS at runtime.

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

| UI                      | URL                       |
|-------------------------|---------------------------|
| HDFS NameNode           | http://localhost:9870     |
| YARN ResourceManager    | http://localhost:8088     |
| Spark Application UI    | http://localhost:4040 *(only while a job is running)* |

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

---

## Spark on YARN — WordCount Example

### Prerequisites

Fix HDFS permissions once after the cluster is up (only needed the first time):

```bash
docker exec -u hadoop namenode hdfs dfs -chown spark:spark /user/spark
docker exec -u hadoop namenode hdfs dfs -chmod 755 /user/spark
docker exec -u hadoop namenode hdfs dfs -mkdir -p /tmp/hadoop-yarn/staging/spark
docker exec -u hadoop namenode hdfs dfs -chown spark:spark /tmp/hadoop-yarn/staging/spark
docker exec -u hadoop namenode hdfs dfs -chmod 777 /tmp/hadoop-yarn/staging
docker exec -u hadoop namenode hdfs dfs -chmod 1777 /tmp
```

### 1. Upload input data to HDFS

```bash
docker exec spark bash -c "echo 'hello world hello hadoop spark hadoop world' > /tmp/input.txt"
docker exec spark hdfs dfs -mkdir -p /user/spark/wordcount/input
docker exec spark hdfs dfs -put /tmp/input.txt /user/spark/wordcount/input/
```

### 2. Run the Spark WordCount job on YARN

```bash
docker exec spark spark-submit \
  --master yarn \
  --deploy-mode client \
  --class org.apache.spark.examples.JavaWordCount \
  $SPARK_HOME/examples/jars/spark-examples_2.12-3.5.0.jar \
  hdfs://namenode:9000/user/spark/wordcount/input \
  hdfs://namenode:9000/user/spark/wordcount/output
```

The word counts are printed to stdout at the end of the job output. To save them to a file:

```bash
docker exec spark bash -c "spark-submit \
  --master yarn \
  --deploy-mode client \
  --class org.apache.spark.examples.JavaWordCount \
  \$SPARK_HOME/examples/jars/spark-examples_2.12-3.5.0.jar \
  hdfs://namenode:9000/user/spark/wordcount/input \
  hdfs://namenode:9000/user/spark/wordcount/output" > output.txt 2>&1
```

### 3. Monitor the job

Open the YARN UI at **http://localhost:8088** to track the application status.
The Spark Application UI is available at **http://localhost:4040** while the job is running.

### 4. Clean up (to re-run)

```bash
docker exec spark hdfs dfs -rm -r /user/spark/wordcount/output
```
