# Setup Guide

Reproducing this end to end. The README explains *why*; this is *how*.

> **Paths are normalised in this repo** to `/opt/spark`, `/opt/jdk-17` and
> `$ZEPPELIN_HOME`. Adjust to wherever you actually installed things.

---

## Prerequisites

- Proxmox (or any hypervisor) with 4 VMs — Debian 13:
  `spark-manager`, `spark-worker1`, `spark-worker2`, and a notebook host.
  3 vCPU / 4 GB each is enough to follow along.
- A Cloudflare account with R2 enabled.
- A Snowflake account (the trial tier is sufficient).
- Java 17 on every node.

---

## 1. Cloudflare: bucket, catalog, credentials

1. **R2 → Create bucket.** Note the name.
2. **Enable the R2 Data Catalog on that bucket.** Cloudflare shows you the
   catalog URI and warehouse name — copy both. The warehouse is literally
   `<account_id>_<bucket_name>`.
3. **Create an R2 API token** with catalog read + write permission. You get:
   - a **bearer token** for the catalog, and
   - an **access key ID / secret access key** pair for S3-compatible data access.

   These are two different credentials for two different layers. Both are
   needed.
4. Copy `.env.example` to `.env` and fill in all five values.

---

## 2. Spark cluster

On **every** node — the three cluster VMs *and* the notebook host:

```bash
# Java 17
sudo apt update && sudo apt install -y openjdk-17-jdk

# Spark 3.5.8
wget https://archive.apache.org/dist/spark/spark-3.5.8/spark-3.5.8-bin-hadoop3.tgz
sudo tar -xzf spark-3.5.8-bin-hadoop3.tgz -C /opt
sudo ln -s /opt/spark-3.5.8-bin-hadoop3 /opt/spark
```

Make every hostname resolve on every node — add to `/etc/hosts` on all four:

```
192.168.x.10  spark-manager
192.168.x.11  spark-worker1
192.168.x.12  spark-worker2
```

Passwordless SSH from `spark-manager` to both workers, so `start-workers.sh`
can reach them:

```bash
ssh-keygen -t ed25519
ssh-copy-id spark@spark-worker1
ssh-copy-id spark@spark-worker2
```

Now the config from this repo:

```bash
# All nodes
cp spark/conf/spark-defaults.conf   /opt/spark/conf/

# Master
cp spark/conf/spark-env.sh          /opt/spark/conf/spark-env.sh
cp spark/conf/workers               /opt/spark/conf/workers

# Each worker
cp spark/conf/spark-env.worker.sh   /opt/spark/conf/spark-env.sh
```

Substitute your real values into `spark-defaults.conf` — the five `${...}`
placeholders from `.env`.

Start it:

```bash
/opt/spark/sbin/start-master.sh
/opt/spark/sbin/start-workers.sh
```

Both workers should show as ALIVE at `http://spark-manager:8080`.

Verify the catalog before going further:

```bash
/opt/spark/bin/spark-sql --master spark://spark-manager:7077
```

```sql
SHOW NAMESPACES IN r2;
```

If this returns without error, the REST catalog and its auth are working. It
does **not** yet prove data-file access — that comes at step 5.

---

## 3. Zeppelin

On the notebook host:

```bash
wget https://archive.apache.org/dist/zeppelin/zeppelin-0.11.2/zeppelin-0.11.2-bin-all.tgz
tar -xzf zeppelin-0.11.2-bin-all.tgz -C /opt
cp zeppelin/conf/zeppelin-env.sh /opt/zeppelin/conf/
/opt/zeppelin/bin/zeppelin-daemon.sh start
```

Zeppelin at `http://<host>:8080`. In **Interpreter → spark**, confirm
`spark.master` is `spark://spark-manager:7077`, then restart the interpreter.

Test with a `%spark.sql` paragraph:

```sql
SHOW NAMESPACES IN r2
```

> Zeppelin here has no authentication. Keep it on a private network, or
> configure `shiro.ini` before exposing it.

---

## 4. Snowflake

Run the three scripts in order, substituting your `${...}` values:

```
snowflake/01-external-volume.sql       -- storage access
snowflake/02-catalog-integration.sql   -- catalog access
snowflake/03-linked-database.sql       -- auto-sync
```

Both `SYSTEM$VERIFY_EXTERNAL_VOLUME` and `SYSTEM$VERIFY_CATALOG_INTEGRATION`
must pass before continuing. They fail loudly and specifically, which is more
than can be said for debugging it later from a query error.

---

## 5. Prove the decoupling

Run in order, switching engines as marked:

| Step | File | Engine |
|---|---|---|
| 1 | `sql/ddl/01-spark-create-tables.sql` | Spark / Zeppelin |
| 2 | `sql/dml/02-spark-write.sql` | Spark / Zeppelin |
| 3 | `sql/dml/03-snowflake-read-write.sql` | Snowflake |
| 4 | `sql/dml/04-spark-verify.sql` | Spark / Zeppelin |

Between steps 2 and 3, run `ALTER DATABASE r2_lakehouse REFRESH;` in Snowflake
rather than waiting for the sync interval.

What to look for at step 4: order `1007` was inserted by Snowflake and is
visible in Spark; order `1006` shows `REFUNDED`, which Snowflake set; and
`orders.snapshots` interleaves commits from both engines with no ingest step
between them.

That is the whole argument, and it either reproduces or it does not.
