# Hive + HDFS Integration Test

This example creates two CSV datasets, uploads them to HDFS, then queries them
through Hive to demonstrate the full Hive ↔ HDFS integration.

---

## Files

| File | Purpose |
|---|---|
| `employees.csv` | 12 employee records |
| `departments.csv` | 4 department records |
| `setup_hdfs.sh` | Uploads CSVs to HDFS from inside the namenode container |
| `hive_queries.hql` | All Hive DDL + DML queries to run |

---

## Step-by-Step Instructions

### Step 1 — Start the cluster

From the `full-distributed-hadoop/` directory:

```bash
docker compose up -d
```

Wait until all containers are healthy (about 60–90 s). Check with:

```bash
docker compose ps
```

All services should show `running` or `healthy`.

---

### Step 2 — Verify HDFS is up

Open the HDFS Web UI in your browser:

```
http://localhost:9870
```

You should see 2 live DataNodes under **Datanodes**.

---

### Step 3 — Copy the CSV files into the namenode container

```bash
docker cp test-hive-hdfs/employees.csv    namenode:/tmp/employees.csv
docker cp test-hive-hdfs/departments.csv  namenode:/tmp/departments.csv
docker cp test-hive-hdfs/setup_hdfs.sh    namenode:/tmp/setup_hdfs.sh
```

---

### Step 4 — Upload CSVs to HDFS

Open a shell inside the namenode:

```bash
docker exec -it namenode bash
```

Then run the setup script as the `hadoop` user:

```bash
su - hadoop -c "bash /tmp/setup_hdfs.sh"
```

Expected output:
```
=== Creating HDFS directories ===
=== Setting permissions ===
=== Uploading CSV files ===
=== Verifying uploads ===
Found 1 items
-rw-r--r--   2 hadoop supergroup  ... /data/employees/employees.csv
Found 1 items
-rw-r--r--   2 hadoop supergroup  ... /data/departments/departments.csv
✅ HDFS setup complete. Files are ready for Hive.
```

Exit the namenode shell:
```bash
exit
```

---

### Step 5 — Copy the HQL file into the hiveserver2 container

```bash
docker cp test-hive-hdfs/hive_queries.hql hiveserver2:/tmp/hive_queries.hql
```

---

### Step 6 — Connect to HiveServer2 with Beeline

```bash
docker exec -it hiveserver2 bash
```

Inside the container, launch Beeline:

```bash
beeline -u "jdbc:hive2://localhost:10000" -n hive
```

---

### Step 7 — Run the queries

Once connected, run the HQL file:

```sql
!run /tmp/hive_queries.hql
```

Or paste queries one by one from `hive_queries.hql`.

---

### Step 8 — Verify results

You should see:

**Count per department:**
```
+---------------+------------------+
| department    | total_employees  |
+---------------+------------------+
| Engineering   | 5                |
| Marketing     | 3                |
| Finance       | 2                |
| HR            | 2                |
+---------------+------------------+
```

**High earners (salary > 70 000):**
```
+----+----------------+-------------+---------+
| id | name           | department  | salary  |
+----+----------------+-------------+---------+
| 5  | Emma Bernard   | Engineering | 91000   |
| 12 | Laura Girard   | Engineering | 88000   |
| 3  | Clara Nguyen   | Engineering | 82000   |
| 8  | Hugo Simon     | Engineering | 78000   |
| 1  | Alice Martin   | Engineering | 75000   |
| 10 | Julien Blanc   | Finance     | 71000   |
+----+----------------+-------------+---------+
```

---

### Step 9 — Confirm HDFS storage via Web UI

- External tables: `http://localhost:9870/explorer.html#/data`
- Managed table (ORC): `http://localhost:9870/explorer.html#/user/hive/warehouse/company.db/high_earners`

---

### Optional — Check from HDFS CLI

```bash
docker exec -it namenode bash
su - hadoop
hdfs dfs -ls /data/employees/
hdfs dfs -ls /user/hive/warehouse/company.db/
```

---

## What this test demonstrates

| Concept | Where |
|---|---|
| HDFS as storage backend for Hive | External tables point to `/data/*` |
| External vs Managed tables | `employees`/`departments` are EXTERNAL; `high_earners` is MANAGED |
| ORC format | `high_earners` is stored as ORC (columnar, compressed) |
| JOIN across tables | Query 5 joins employees ↔ departments |
| Hive Metastore (PostgreSQL) | All table metadata stored in `metastore_db` |
