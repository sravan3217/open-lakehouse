# Architecture

Detail behind the [README](../README.md): what each layer is responsible for,
what happens on a query, and how it fails.

---

## The three responsibilities

A lakehouse is worth building only if these three stay genuinely separate. When
one system owns two of them, you have a warehouse with extra steps.

**Storage — where the bytes are.** Cloudflare R2 holds Parquet data files and
Iceberg metadata (manifest lists, manifests, and versioned `metadata.json`
snapshots). R2 knows nothing about tables. It is a bucket.

**Catalog — which bytes are current.** The R2 Data Catalog maps a table
identifier such as `demo.orders` to the *current* `metadata.json` pointer, and
updates that pointer atomically on commit. This is the only stateful decision
point in the system, and it is the reason two engines can write safely.

**Compute — who does the work.** Spark and Snowflake both plan and execute
queries. Neither stores table state. Either can be stopped, rebuilt, or replaced
without touching data or metadata.

The separation is only real if the *protocol* between the layers is open. S3 API
for storage, Iceberg REST for the catalog. Both are implemented by more than one
vendor, which is what turns "decoupled" from an architecture diagram into a
property you can act on.

---

## What actually happens on a query

Tracing `SELECT ... FROM demo.orders WHERE order_date >= '2024-06-01'`:

1. The engine asks the catalog for `demo.orders` over HTTPS, authenticating with
   a bearer token. The catalog returns the current `metadata.json` location.
2. The engine reads that metadata from R2 — schema, partition spec, snapshot
   history, and the manifest list for the current snapshot.
3. It reads the manifests and prunes. Iceberg manifests carry per-file
   partition values and column min/max statistics, so files that cannot contain
   `order_date >= '2024-06-01'` are eliminated **without opening them**. This is
   the main reason Iceberg outperforms a Hive-style directory layout: no
   recursive listing of object storage.
4. It reads only the surviving Parquet files from R2.

Steps 3 and 4 are identical whichever engine is asking. That is the decoupling,
mechanically.

On a **write**, the engine writes new Parquet files, writes new manifests and a
new `metadata.json`, then asks the catalog to swap the pointer from the snapshot
it started with to the new one. The swap is a compare-and-set: if another engine
committed in the meantime, the swap is rejected and the writer retries against
the new base. Nothing is visible to readers until the pointer moves, so there is
no partially-visible write.

---

## Layer notes

### Spark cluster

Standalone mode, not YARN or Kubernetes — for three VMs, a resource manager is
overhead without a payoff. `spark-manager` runs the master daemon and tracks
cluster state only; the workers advertise 3 cores and 2 GB each.

The catalog is defined in the **driver's** SparkSession. That is why
`spark-defaults.conf` is deployed to the Zeppelin host as well as the cluster
nodes: the driver resolves tables, the executors only need the JARs on their
classpath.

`SPARK_WORKER_MEMORY` is an advertised capacity, not a cgroup limit. Set it
above what the VM actually has and the scheduler will happily accept work the
kernel then kills.

### Zeppelin

The notebook host doubles as the Spark driver, so it needs `JAVA_HOME`,
`SPARK_HOME` pointing at a full Spark distribution of the *same* version as the
cluster, and its own copy of `spark-defaults.conf`. A version mismatch between
driver and cluster surfaces as opaque serialization errors, not as a clear
version complaint.

### Snowflake

Two objects do two different jobs, and it is easy to conflate them:

- The **external volume** is storage access. It is how Snowflake reads and
  writes Parquet in the R2 bucket. `ALLOW_WRITES = TRUE` is what makes Snowflake
  a writer rather than a read-only consumer.
- The **catalog integration** is metadata access. It is how Snowflake discovers
  which snapshot is current.

Both are required. With only the volume, Snowflake can see bytes it cannot
interpret; with only the integration, it can resolve tables whose files it
cannot open.

---

## Troubleshooting reference

If something doesn't work, it is almost always one of these.

| Symptom | Likely cause |
|---|---|
| `SHOW TABLES` works, `SELECT` fails opening a file | `fs.s3a.*` set but catalog-scoped `s3.*` properties missing — `S3FileIO` never reads the Hadoop settings |
| `NoSuchCatalogException` / catalog does not resolve | `iceberg-spark-runtime` Scala or Spark-version suffix does not match the cluster |
| 401 from the catalog | OAuth2 flow still enabled; needs `rest.auth.type=none` plus an explicit `Authorization` header |
| Table exists in Spark, missing in Snowflake | Catalog-linked database has not synced yet — `ALTER DATABASE ... REFRESH` |
| Snowflake reads but cannot write | `ALLOW_WRITES` not set on the external volume |
| Commit fails under concurrent writes | Expected. Optimistic concurrency retry — the loser rebases and re-commits |
| Scans slow down after many small writes | Small-file accumulation. Iceberg has a compaction procedure; nothing runs it for you |
