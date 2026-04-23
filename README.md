# Full Distributed Hadoop + Spark Cluster

A fully distributed Apache Hadoop 3.3.6 cluster with an isolated Apache Spark 3.5.0 client node, running on Docker.

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                    Docker Network: hadoop                     │
│                                                              │
│  ┌──────────┐   ┌──────────┐  ┌──────────┐  ┌───────────┐  │
│  │ namenode │   │datanode1 │  │datanode2 │  │   spark   │  │
│  │          │   │          │  │          │  │           │  │
│  │ HDFS NN  │   │ HDFS DN  │  │ HDFS DN  │  │ Spark     │  │
│  │ YARN RM  │   │ YARN NM  │  │ YARN NM  │  │ client    │  │
│  └──────────┘   └──────────┘  └──────────┘  └───────────┘  │
│  ports: 9870, 8088, 9000                     port: 4040     │
└──────────────────────────────────────────────────────────────┘
```

| Node      | Role                                        |
|-----------|---------------------------------------------|
| namenode  | NameNode + ResourceManager                  |
| datanode1 | DataNode + NodeManager                      |
| datanode2 | DataNode + NodeManager                      |
| spark     | Spark client – submits jobs to YARN         |

The `spark` container runs **no Hadoop daemons**. It holds only the Spark binaries
and a Hadoop client config. All jobs are submitted to YARN on the Hadoop cluster.

---

## Project Structure

```
full-distributed-hadoop/
├── dockerfile               # Hadoop node image (namenode + datanodes)
├── Dockerfile.spark         # Isolated Spark client image
├── docker-compose.yaml      # Cluster topology
├── start.sh                 # Entrypoint: detects role, starts services,
│                            #   provisions HDFS user dirs automatically
├── config-hadoop/
│   ├── core-site.xml        # HDFS default filesystem
│   ├── hdfs-site.xml        # Replication factor, data/name dirs
│   ├── mapred-site.xml      # MapReduce framework + classpath
│   └── yarn-site.xml        # YARN services, RM addresses, env whitelist
└── config-spark/
    ├── spark-defaults.conf  # Default master=yarn, executor resources
    └── spark-env.sh         # JAVA_HOME, HADOOP_CONF_DIR, YARN_CONF_DIR
```

---

## Getting Started

### Prerequisites
- Docker Desktop installed and running
- Base image `hadoop-preinstall:latest` built locally
- `downloads/hadoop-3.3.6.tar.gz` and `downloads/spark-3.5.0-bin-hadoop3.tgz`
  present in the workspace root (used by `Dockerfile.spark`)

### Build and Start

```bash
# Run from the full-distributed-hadoop/ directory
docker compose build
docker compose up -d
```

Wait ~20 seconds for HDFS to format, YARN to start, and user directories to be provisioned.

### Check Cluster Status

```bash
# HDFS: should show namenode + 2 datanodes
docker exec namenode hdfs dfsadmin -report

# YARN: should show 2 NodeManagers
docker exec namenode yarn node -list
```

You can also open the YARN UI at **http://localhost:8088**.

### Web UIs

| UI                    | URL                    |
|-----------------------|------------------------|
| HDFS NameNode         | http://localhost:9870  |
| YARN ResourceManager  | http://localhost:8088  |
| Spark App UI (driver) | http://localhost:4040  |

> **Spark UI not loading (localhost:4040)?**
>
> The Spark driver runs inside the `spark` container and reports executor/task links
> using the container hostnames (`namenode`, `datanode1`, etc.). Your browser can't
> resolve those names unless you add them to your host machine's `hosts` file.
>
> **Windows** — edit `C:\Windows\System32\drivers\etc\hosts` as Administrator and add:
>
> ```
> 127.0.0.1   namenode
> 127.0.0.1   datanode1
> 127.0.0.1   datanode2
> 127.0.0.1   spark
> ```
>
> **Linux / macOS** — edit `/etc/hosts` and add the same lines.
>
> After saving, refresh the browser. No restart of Docker or the cluster is needed.

---

## HDFS User Directories

`start.sh` automatically creates and assigns ownership of HDFS home directories
on every fresh cluster start:

| HDFS path      | Owner          |
|----------------|----------------|
| `/user/hadoop` | hadoop:hadoop  |
| `/user/spark`  | spark:spark    |

No manual `chown` or `chmod` is needed after a rebuild.

---

## WordCount – MapReduce (Hadoop)

```bash
# 1. Upload input data
docker exec namenode bash -c "
  echo 'hello world hello hadoop world hadoop hadoop' > /tmp/input.txt
  hdfs dfs -mkdir -p /user/hadoop/input
  hdfs dfs -put /tmp/input.txt /user/hadoop/input/
"

# 2. Run the job
docker exec namenode bash -c "
  hadoop jar \$HADOOP_HOME/share/hadoop/mapreduce/hadoop-mapreduce-examples-3.3.6.jar \
    wordcount /user/hadoop/input /user/hadoop/output
"

# 3. Read results
docker exec namenode bash -c "hdfs dfs -cat /user/hadoop/output/part-r-00000"

# 4. Clean up for re-run
docker exec namenode bash -c "hdfs dfs -rm -r /user/hadoop/output"
```

---

## WordCount – Spark on YARN

All commands run from the **spark** container. No manual permission setup needed —
`start.sh` provisions `/user/spark` on HDFS automatically at cluster start.

### Step 1 — Open a shell in the spark container

```bash
docker exec -it spark bash
```

### Step 2 — Create the input file and upload it to HDFS

```bash
echo 'hello world hello hadoop spark hadoop world' > /tmp/input.txt
hdfs dfs -mkdir -p /user/spark/wordcount/input
hdfs dfs -put /tmp/input.txt /user/spark/wordcount/input/
```

Verify the file is in HDFS:

```bash
hdfs dfs -ls /user/spark/wordcount/input/
```

### Step 3 — Submit the Spark WordCount job on YARN

Still inside the spark container:

```bash
spark-submit \
  --master yarn \
  --deploy-mode client \
  --class org.apache.spark.examples.JavaWordCount \
  $SPARK_HOME/examples/jars/spark-examples_2.12-3.5.0.jar \
  hdfs://namenode:9000/user/spark/wordcount/input \
  hdfs://namenode:9000/user/spark/wordcount/output
```

> While the job runs, the Spark Application UI is available at **http://localhost:4040**
> and the YARN job tracker at **http://localhost:8088**.

### Step 4 — Read the results

> **Note:** `JavaWordCount` prints results to the driver logs (stdout), not to HDFS.
> The output path passed to the job is not used by this particular example —
> results appear directly in the terminal output of the `spark-submit` command above.

To save only the program results to a local file (filtering out Spark/YARN log noise),
run the job from your host terminal redirecting stderr away:

```bash
docker exec spark bash -c "spark-submit \
  --master yarn \
  --deploy-mode client \
  --class org.apache.spark.examples.JavaWordCount \
  \$SPARK_HOME/examples/jars/spark-examples_2.12-3.5.0.jar \
  hdfs://namenode:9000/user/spark/wordcount/input \
  hdfs://namenode:9000/user/spark/wordcount/output" 2>&1 > output.txt
```

- `2>&1` merges stderr (Spark/YARN logs) into stdout
- `> output.txt` saves everything to `output.txt` on your host machine
- The WordCount results are visible inside that file, mixed with the logs

To view just the result lines:

```bash
grep -E "^\([a-z]+,[0-9]+\)|^[a-z]+\s+[0-9]+$" output.txt
```

Expected output (visible in terminal or in `output.txt`):
```
hadoop  2
hello   2
spark   1
world   2
```

### Step 5 — Clean up (to re-run)

The output directory on HDFS must not exist before re-running. If you ran the job
before, delete it first:

```bash
# inside the spark container
hdfs dfs -rm -r /user/spark/wordcount/output
```

> **Note — Windows terminal:** If you run commands directly from Git Bash or PowerShell
> instead of an interactive container shell, always wrap them in `bash -c "..."` to
> prevent Windows from converting HDFS paths (e.g. `/user/spark`) into Windows paths
> (`C:\user\spark`):
> ```bash
> docker exec spark bash -c "hdfs dfs -mkdir -p /user/spark/wordcount/input"
> docker exec spark bash -c "spark-submit --master yarn --deploy-mode client \
>   --class org.apache.spark.examples.JavaWordCount \
>   \$SPARK_HOME/examples/jars/spark-examples_2.12-3.5.0.jar \
>   hdfs://namenode:9000/user/spark/wordcount/input \
>   hdfs://namenode:9000/user/spark/wordcount/output"
> ```

---

## Stopping the Cluster

```bash
docker compose down
```
