#!/usr/bin/env bash
# =============================================================================
# zeppelin-env.sh  --  Zeppelin on the `mypc` VM
# Path: $ZEPPELIN_HOME/conf/zeppelin-env.sh
# =============================================================================
# Zeppelin here is the notebook UI *and* the Spark driver host. It submits to
# the standalone master on spark-manager; spark-defaults.conf on this VM
# supplies the Iceberg/R2 catalog definition.
# -----------------------------------------------------------------------------

# Java 17. Spark 3.5.x supports Java 8/11/17; pin it explicitly so Zeppelin
# does not inherit whatever `java` happens to be first on PATH.
export JAVA_HOME=/opt/jdk-17

# Must be a full Spark distribution matching the cluster version (3.5.8).
# Zeppelin's Spark interpreter calls spark-submit from here.
export SPARK_HOME=/opt/spark

# Submit to the standalone cluster rather than running local[*].
export MASTER=spark://spark-manager:7077

# --- Network -----------------------------------------------------------------
# Binds on all interfaces so the notebook is reachable across the LAN.
#
# SECURITY: 0.0.0.0 with no shiro.ini means an unauthenticated notebook that
# can run arbitrary JVM and shell code as the Zeppelin user, holding live R2
# credentials. Acceptable only on a trusted private network. Enable Shiro auth
# before exposing this anywhere else. See docs/architecture.md.
export ZEPPELIN_ADDR=0.0.0.0
export ZEPPELIN_ALLOWED_ORIGINS="*"
